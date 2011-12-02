# @(#)$Id: Util.pm 321 2011-11-30 00:01:49Z pjf $

package File::DataClass::Util;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.7.%d', q$Rev: 321 $ =~ /\d+/gmx );

use Class::MOP;
use File::DataClass::Constants;
use File::DataClass::IO ();
use File::Spec;
use List::Util qw(first);
use Moose::Role;
use Try::Tiny;

requires qw(exception_class);

sub basename {
   my ($self, $path, @suffixes) = @_;

   return $self->io( NUL.$path )->basename( @suffixes );
}

sub catdir {
   my $self = shift; return File::Spec->catdir( @_ );
}

sub catfile {
   my $self = shift; return File::Spec->catfile( @_ );
}

sub dirname {
   my ($self, $path) = @_; return $self->io( NUL.$path )->dirname;
}

sub ensure_class_loaded {
   my ($self, $class, $opts) = @_; $opts ||= {};

   my $package_defined = sub { Class::MOP::is_class_loaded( $class ) };

   not $opts->{ignore_loaded} and $package_defined->() and return TRUE;

   try   { Class::MOP::load_class( $class ) }
   catch { $self->throw( $_ ) };

   $package_defined->() and return TRUE;

   $self->throw( error => 'Class [_1] loaded but package undefined',
                 args  => [ $class ] );
   return; # Not reached
}

sub io {
   my ($self, @rest) = @_; my $io = File::DataClass::IO->new( @rest );

   $io->exception_class( $self->exception_class );

   return $io;
}

sub is_member {
   my ($self, $candidate, @rest) = @_; $candidate or return;

   return (first { $_ eq $candidate } @rest) ? TRUE : FALSE;
}

sub throw {
   shift->exception_class->throw( @_ ); return;
}

no Moose::Role;

1;

__END__

=pod

=head1 Name

File::DataClass::Util - Moose Role defining utility methods

=head1 Version

0.7.$Revision: 321 $

=head1 Synopsis

   use Moose;

   with qw(File::DataClass::Util);

=head1 Description

=head1 Subroutines/Methods

=head2 basename

=head2 catdir

=head2 catfile

=head2 dirname

=head2 ensure_class_loaded

=head2 io

=head2 is_member

=head2 throw

=head1 Configuration and Environment

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::MOP>

=item L<File::DataClass::IO>

=item L<List::Util>

=item L<Moose::Role>

=item L<Try::Tiny>

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

Copyright (c) 2010 Peter Flanigan. All rights reserved

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