# @(#)$Id: Storage.pm 431 2013-04-01 01:11:58Z pjf $

package File::DataClass::Storage;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev: 431 $ =~ /\d+/gmx );

use Moose;
use Class::Null;
use English qw(-no_match_vars);
use File::Copy;
use File::DataClass::Constants;
use File::DataClass::Functions qw(is_stale merge_hash_data throw);
use File::DataClass::HashMerge;
use Try::Tiny;

has 'backup'   => is => 'ro', isa => 'Str', default => NUL;

has 'encoding' => is => 'ro', isa => 'Str', default => NUL;

has 'extn'     => is => 'ro', isa => 'Str', default => NUL;

has 'schema'   => is => 'ro', isa => 'Object',
   handles     => { _cache => q(cache), _debug => q(debug), _lock => q(lock),
                    _log   => q(log),   _perms => q(perms) }, required => TRUE,
   weak_ref    => TRUE;

sub create_or_update {
   my ($self, $path, $result, $updating, $cond) = @_;

   my $element = $result->_resultset->source->name;

   $self->validate_params( $path, $element ); my $updated;

   my $data = ($self->_read_file( $path, TRUE ))[ 0 ] || {};

   try {
      my $filter = sub { __get_src_attributes( $cond, $_[ 0 ] ) };
      my $name   = $result->name; $data->{ $element } ||= {};

      not $updating and exists $data->{ $element }->{ $name }
         and throw error => 'File [_1] element [_2] already exists',
                   args  => [ $path, $name ], level => 4;

      $updated = File::DataClass::HashMerge->merge
         ( \$data->{ $element }->{ $name }, $result, $filter );
   }
   catch { $self->_lock->reset( k => $path ); throw $_ };

   if ($updated) { $self->_write_file( $path, $data, not $updating ) }
   else { $self->_lock->reset( k => $path ) }

   return $updated;
}

sub delete {
   my ($self, $path, $result) = @_;

   my $element = $result->_resultset->source->name;

   $self->validate_params( $path, $element );

   my $data = ($self->_read_file( $path, TRUE ))[ 0 ] || {};
   my $name = $result->name;

   if (exists $data->{ $element } and exists $data->{ $element }->{ $name }) {
      delete $data->{ $element }->{ $name };
      scalar keys %{ $data->{ $element } } or delete $data->{ $element };
      $self->_write_file( $path, $data );
      return TRUE;
   }

   $self->_lock->reset( k => $path );
   return FALSE;
}

sub dump {
   my ($self, $path, $data) = @_;

   return $self->txn_do( $path, sub {
      $self->_lock->set( k => $path );
      $self->_write_file( $path, $data, TRUE ) } );
}

sub insert {
   my ($self, $path, $result) = @_;

   return $self->create_or_update( $path, $result, FALSE, sub { TRUE } );
}

sub load {
   my ($self, @paths) = @_; $paths[ 0 ] or return {};

   scalar @paths == 1
      and return ($self->_read_file( $paths[ 0 ], FALSE ))[ 0 ] || {};

   my ($data, $meta, $newest) = $self->_cache->get_by_paths( \@paths );
   my $cache_mtime  = $self->meta_unpack( $meta );

   not is_stale $data, $cache_mtime, $newest and return $data;

   $data = {}; $newest = 0;

   for my $path (@paths) {
      my ($red, $path_mtime) = $self->_read_file( $path, FALSE ); $red or next;

      $path_mtime > $newest and $newest = $path_mtime;
      merge_hash_data $data, $red;
   }

   $self->_cache->set_by_paths( \@paths, $data, $self->meta_pack( $newest ) );

   return $data;
}

sub meta_pack {
   # Can be modified in a subclass
   my ($self, $mtime) = @_; return { mtime => $mtime };
}

sub meta_unpack {
   # Can be modified in a subclass
   my ($self, $attrs) = @_; return $attrs ? $attrs->{mtime} : undef;
}

sub read_file {
   return shift->_read_file( @_ );
}

sub select {
   my ($self, $path, $element) = @_;

   $self->validate_params( $path, $element );

   my $data = ($self->_read_file( $path, FALSE ))[ 0 ] || {};

   return exists $data->{ $element } ? $data->{ $element } : {};
}

sub txn_do {
   my ($self, $path, $code_ref) = @_; my $wantarray = wantarray;

   $self->validate_params( $path, TRUE ); my $key = q(txn:).$path; my $res;

   $self->_lock->set( k => $key );

   try {
      if ($wantarray) { @{ $res } = $code_ref->() }
      else { $res = $code_ref->() }
   }
   catch { $self->_lock->reset( k => $key ); throw error => $_, level => 7 };

   $self->_lock->reset( k => $key );

   return $wantarray ? @{ $res } : $res;
}

sub update {
   my ($self, $path, $result, $updating, $cond) = @_;

   defined $updating or $updating = TRUE; $cond ||= sub { TRUE };

   my $updated = $self->create_or_update( $path, $result, $updating, $cond )
      or throw class => 'NothingUpdated', error => 'Nothing updated',
               level => 5;

   return $updated;
}

sub validate_params {
   my ($self, $path, $element) = @_;

   $path or throw error => 'No file path specified', level => 4;

   blessed $path or throw error => 'Path [_1] is not blessed',
                          args  => [ $path ], level => 4;

   $element or throw error => 'Path [_1] no element specified',
                     args  => [ $path ], level => 4;

   return;
}

# Private methods

sub _read_file {
   my ($self, $path, $for_update) = @_;

   $self->_lock->set( k => $path ); my ($data, $meta, $path_mtime);

   try {
      ($data, $meta)  = $self->_cache->get( $path );
      $path_mtime     = $path->stat->{mtime};

      my $cache_mtime = $self->meta_unpack( $meta );

      if (is_stale $data, $cache_mtime, $path_mtime) {
         if ($for_update and not $path->exists) { $data = undef }
         else {
            $data = inner( $path->lock ); $path->close;
            $meta = $self->meta_pack( $path_mtime );
            $self->_cache->set( $path, $data, $meta );
            $self->_debug and $self->_log->debug( "Read file  ${path}" );
         }
      }
      else { $self->_debug and $self->_log->debug( "Read cache ${path}" ) }
   }
   catch { $self->_lock->reset( k => $path ); throw $_ };

   $for_update or $self->_lock->reset( k => $path );

   return ($data, $path_mtime);
}

sub _write_file {
   my ($self, $path, $data, $create) = @_;

   try {
      $create or $path->exists
         or throw error => 'File [_1] not found', args => [ $path ];

      $path->exists or $path->perms( $self->_perms );

      if ($self->backup and $path->exists and not $path->empty) {
         copy( $path.NUL, $path.$self->backup ) or throw $ERRNO;
      }

      try   { $data = inner( $path->atomic->lock, $data ); $path->close }
      catch { $path->delete; throw $_ };

      $self->_cache->remove( $path );
      $self->_debug and $self->_log->debug( "Write file ${path}" )
   }
   catch { $self->_lock->reset( k => $path ); throw $_ };

   $self->_lock->reset( k => $path );
   return $data;
}

# Private subroutines

sub __get_src_attributes {
   my ($cond, $src) = @_;

   return grep { not m{ \A _ }mx
                 and $_ ne q(name)
                 and $cond->( $_ ) } keys %{ $src };
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage - Storage base class

=head1 Version

0.15.$Revision: 431 $

=head1 Synopsis

=head1 Description

Storage base class

=head1 Subroutines/Methods

=head2 create_or_update

   $bool = $self->create_or_update( $path, $result, $updating, $condition );

Does the heavy lifting for L</insert> and L</update>

=head2 delete

   $bool = $storage->delete( $path, $result );

Deletes the specified element object returning true if successful. Throws
an error otherwise. Path is an instance of L<File::DataClass::IO>

=head2 dump

   $data = $storage->dump( $path, $data );

Dumps the data to the specified path. Path is an instance of
L<File::DataClass::IO>

=head2 insert

   $bool = $storage->insert( $path, $result );

Inserts the specified element object returning true if successful. Throws
an error otherwise. Path is an instance of L<File::DataClass::IO>

=head2 load

   $hash_ref = $storage->load( @paths );

Loads each of the specified files merging the resultant hash ref which
it returns. Paths are instances of L<File::DataClass::IO>

=head2 meta_pack

=head2 meta_unpack

=head2 read_file

   ($data, $mtime) = $self->read_file( $path, $for_update ):

Read a file from cache or disk

=head2 select

   $hash_ref = $storage->select( $path );

Returns a hash ref containing all the elements of the type specified in the
schema. Path is an instance of L<File::DataClass::IO>

=head2 txn_do

Executes the supplied coderef wrapped in lock on the pathname

=head2 update

   $bool = $storage->update( $path, $result, $updating, $condition );

Updates the specified element object returning true if successful. Throws
an error otherwise. Path is an instance of L<File::DataClass::IO>

=head2 validate_params

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::HashMerge>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
