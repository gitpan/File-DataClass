# @(#)$Id: HashMerge.pm 321 2011-11-30 00:01:49Z pjf $

package File::DataClass::HashMerge;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.7.%d', q$Rev: 321 $ =~ /\d+/gmx );

use File::DataClass::Constants;
use Carp;

sub merge {
   my ($self, $dest_ref, $src, $filter) = @_; my $updated = FALSE;

   $dest_ref or croak 'No destination reference specified';

   ${ $dest_ref } ||= {}; $src ||= {}; $filter ||= sub { keys %{ $_[ 0 ] } };

   for my $attr ($filter->( $src )) {
      if (defined $src->{ $attr }) {

         my $res = $self->_merge_attr
            ( \${ $dest_ref }->{ $attr }, $src->{ $attr } );

         $updated ||= $res;
      }
      elsif (exists ${ $dest_ref }->{ $attr }) {
         delete ${ $dest_ref }->{ $attr }; $updated = TRUE;
      }
   }

   $updated and ${ $dest_ref }->{name} = $src->{name};

   return $updated;
}

# Private methods

sub _merge_attr {
   my ($self, $to_ref, $from) = @_; my $to = ${ $to_ref }; my $updated = FALSE;

   if ($to and ref $to eq HASH) {
      $updated = $self->_merge_attr_hashes( $to, $from );
   }
   elsif ($to and ref $to eq ARRAY) {
      $updated = $self->_merge_attr_arrays( $to, $from );
   }
   elsif ($to and $to ne $from) {
      $updated = TRUE; ${ $to_ref } = $from;
   }
   elsif (not $to and defined $from) {
      if (ref $from eq HASH) {
         scalar keys %{ $from } > 0 and $updated = TRUE
            and ${ $to_ref } = $from;
      }
      elsif (ref $from eq ARRAY) {
         scalar @{ $from } > 0 and $updated = TRUE; ${ $to_ref } = $from;
      }
      else { $updated = TRUE; ${ $to_ref } = $from }
   }

   return $updated;
}

sub _merge_attr_arrays {
   my ($self, $to, $from) = @_; my $updated = FALSE;

   for (0 .. $#{ $to }) {
      if ($from->[ $_ ]) {
         my $res = $self->_merge_attr( \$to->[ $_ ], $from->[ $_ ] );

         $updated ||= $res;
      }
      elsif ($to->[ $_ ]) { splice @{ $to }, $_; $updated = TRUE; last }
   }

   if (@{ $from } > @{ $to }) {
      push @{ $to }, (splice @{ $from }, $#{ $to } + 1); $updated = TRUE;
   }

   return $updated;
}

sub _merge_attr_hashes {
   my ($self, $to, $from) = @_; my $updated = FALSE;

   for (keys %{ $to }) {
      if ($from->{ $_ }) {
         my $res = $self->_merge_attr( \$to->{ $_ }, $from->{ $_ } );

         $updated ||= $res;
      }
      elsif ($to->{ $_ }) { delete $to->{ $_ }; $updated = TRUE }
   }

   if (keys %{ $from } > keys %{ $to }) {
      for (keys %{ $from }) {
         if ($from->{ $_ } and not exists $to->{ $_ }) {
            $to->{ $_ } = $from->{ $_ }; $updated = TRUE;
         }
      }
   }

   return $updated;
}

1;

__END__

=pod

=head1 Name

File::DataClass::HashMerge - Merge hashes with update flag

=head1 Version

0.7.$Revision: 321 $

=head1 Synopsis

   use File::DataClass::HashMerge;

   $class   = q(File::DataClass::HashMerge);
   $updated = $class->merge( $dest_ref, $src, $condition );

=head1 Description

Merge the attributes from the source hash ref into destination ref

=head1 Subroutines/Methods

=head2 merge

   $class = q(File::DataClass::HashMerge);
   $bool  = $class->merge( $dest_ref, $src, $filter );

Only merge the attributes from C<$src> to C<$dest_ref> if the
C<$filter> coderef evaluates returns the,. Return true if the destination
ref was updated

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

None

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Author

Peter Flanigan, C<< <Support at RoxSoft.co.uk> >>

=head1 License and Copyright

Copyright (c) 2011 Peter Flanigan. All rights reserved

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