# @(#)$Id: Simple.pm 321 2011-11-30 00:01:49Z pjf $

package File::DataClass::Storage::XML::Simple;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.7.%d', q$Rev: 321 $ =~ /\d+/gmx );

use File::DataClass::Constants;
use XML::Simple;
use Moose;

extends qw(File::DataClass::Storage::XML);

augment '_read_file' => sub {
   my ($self, $rdr) = @_;

   my $data = $self->_dtd_parse( $rdr->all );
   my $xs   = XML::Simple->new( SuppressEmpty => TRUE );

   return $xs->xml_in( $data, ForceArray => [ keys %{ $self->_arrays } ] );
};

augment '_write_file' => sub {
   my ($self, $wtr, $data) = @_;

   my $xs = XML::Simple->new( NoAttr   => TRUE, SuppressEmpty => TRUE,
                              RootName => $self->root_name );

   $self->_dtd->[ 0 ] and $wtr->println( @{ $self->_dtd } );
   $wtr->append( $xs->xml_out( $data ) );
   return $data;
};

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::Storage::XML::Simple - Read/write XML data storage model

=head1 Version

0.7.$Revision: 321 $

=head1 Synopsis

   use Moose;

   extends qw(File::DataClass::Schema);

   has '+storage_class' => default => q(XML::Simple);

=head1 Description

Uses L<XML::Simple> to read and write XML files

=head1 Subroutines/Methods

=head2 _read_file

Defines the closure that reads the file, parses the DTD, parses the
file using L<XML::Simple>. Calls
L<read file with locking|File::DataClass::Storage::XML/_read_file_with_locking>
in the base class

=head2 _write_file

Defines the closure that writes the DTD and data to file

=head1 Diagnostics

None

=head1 Configuration and Environment

None

=head1 Dependencies

=over 3

=item L<File::DataClass::Storage::XML>

=item L<XML::Simple>

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

Copyright (c) 2009 Peter Flanigan. All rights reserved

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