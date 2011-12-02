# @(#)$Id: ResultSet.pm 321 2011-11-30 00:01:49Z pjf $

package File::DataClass::ResultSet;

use strict;
use namespace::autoclean;
use version; our $VERSION = qv( sprintf '0.7.%d', q$Rev: 321 $ =~ /\d+/gmx );

use File::DataClass::Constants;
use Moose;

use File::DataClass::List;
use File::DataClass::Result;

extends qw(File::DataClass);

has 'list_class'   => is => 'ro', isa => 'ClassName',
   default         => q(File::DataClass::List);
has 'result_class' => is => 'ro', isa => 'ClassName',
   default         => q(File::DataClass::Result);
has 'source'       => is => 'ro', isa => 'Object',
   required        => TRUE, weak_ref => TRUE,
   handles         => [ qw(attributes defaults
                           exception_class label_attr path storage) ];
has '_iterator'    => is => 'rw', isa => 'Int',
   default         => 0, init_arg => undef;
has '_operators'   => is => 'ro', isa => 'HashRef',
   lazy_build      => TRUE;
has '_results'     => is => 'rw', isa => 'ArrayRef',
   default         => sub { [] }, init_arg => undef;

with qw(File::DataClass::Util);

sub all {
   my $self = shift; return @{ $self->_results };
}

sub create {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $res = $self->_txn_do( sub { $self->_create_result( $args )->insert } );

   return $res ? $name : undef;
}

sub create_or_update {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $res = $self->_txn_do( sub {
      my $result = $self->_find( $name )
         or return $self->_create_result( $args )->insert;

      for (grep { exists $args->{ $_ } } @{ $self->attributes }) {
         $result->$_( $args->{ $_ } );
      }

      return $result->update;
   } );

   return $res ? $name : undef;
}

sub delete {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $res = $self->_txn_do( sub {
      my ($result, $error);

      unless ($result = $self->_find( $name )) {
         $args->{optional} and return FALSE;
         $error = 'File [_1] element [_2] does not exist';
         $self->throw( error => $error, args => [ $self->path, $name ] );
      }

      $result->delete and return TRUE;
      $error = 'File [_1] element [_2] not deleted';
      $self->throw( error => $error, args => [ $self->path, $name ] );
   } );

   return $res ? $name : undef;
}

sub find {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   return $self->_txn_do( sub { $self->_find( $name ) } );
}

sub find_and_update {
   my ($self, $args) = @_;

   my $name   = $args->{name} or return;
   my $result = $self->_find( $name ) or return;

   for (grep { exists $args->{ $_ } } @{ $self->attributes }) {
      $result->$_( $args->{ $_ } );
   }

   return $result->update;
}

sub first {
   my $self = shift; return $self->_results ? $self->_results->[0] : undef;
}

sub last {
   my $self = shift; return $self->_results ? $self->_results->[-1] : undef;
}

sub list {
   my ($self, $args) = @_;

   return $self->_txn_do( sub { $self->_list( $args->{name} ) } );
}

sub next {
   my $self = shift; my $index = $self->_iterator || 0;

   $self->_results and $self->_iterator( $index + 1 );

   return $self->_results ? $self->_results->[ $index ] : undef;
}

sub push {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $list  = $args->{list} or $self->throw( 'No list name specified' );
   my $items = $args->{items} || []; my ($added, $attrs);

   $items->[0] or $self->throw( 'List contains no items' );

   my $res = $self->_txn_do( sub {
      ($attrs, $added) = $self->_push( $name, $list, $items );
      $self->find_and_update( $attrs );
   } );

   return $res ? $added : $res;
}

sub reset {
   my $self = shift; return $self->_iterator( 0 );
}

sub select {
   my $self = shift;

   return $self->storage->select( $self->path, $self->source->name );
}

sub search {
   my ($self, $args) = @_;

   return $self->_txn_do( sub { $self->_search( $args ) } );
}

sub splice {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $list  = $args->{list} or $self->throw( 'No list name specified' );
   my $items = $args->{items} || []; my ($attrs, $removed);

   $items->[0] or $self->throw( 'List contains no items' );

   my $res = $self->_txn_do( sub {
      ($attrs, $removed) = $self->_splice( $name, $list, $items );
      $self->find_and_update( $attrs );
   } );

   return $res ? $removed : $res;
}

sub update {
   my ($self, $args) = @_; my $name = $self->_validate_params( $args );

   my $res = $self->_txn_do( sub { $self->find_and_update( $args ) } );

   return $res ? $name : $res;
}

# Private methods

sub _build__operators {
   return {
      q(eq) => sub { return $_[0] eq $_[1] },
      q(==) => sub { return $_[0] == $_[1] },
      q(ne) => sub { return $_[0] ne $_[1] },
      q(!=) => sub { return $_[0] != $_[1] },
      q(>)  => sub { return $_[0] >  $_[1] },
      q(>=) => sub { return $_[0] >= $_[1] },
      q(<)  => sub { return $_[0] <  $_[1] },
      q(<=) => sub { return $_[0] <= $_[1] },
      q(=~) => sub { return $_[0] =~ $_[1] },
      q(!~) => sub { return $_[0] !~ $_[1] },
   };
}

sub _create_result {
   my ($self, $args) = @_;

   my $attrs = { %{ $self->defaults }, _resultset => $self };

   for (grep { exists $args->{ $_ } and defined $args->{ $_ } }
            @{ $self->attributes }, qw(name)) {
      $attrs->{ $_ } = $args->{ $_ };
   }

   return $self->result_class->new( $attrs );
}

sub _eval_clause {
   my ($self, $clause, $lhs) = @_; my $type = ref $clause;

   if ($type eq HASH) {
      for (keys %{ $clause }) {
         $self->_eval_op( $lhs, $_, $clause->{ $_ } ) or return FALSE;
      }

      return TRUE;
   }

   # TODO: Handle case of 2 arrays
   $type eq ARRAY and return ref $lhs eq ARRAY
                           ? FALSE : $self->is_member( $lhs, @{ $clause } );

   return ref $lhs eq ARRAY
        ? $self->is_member( $clause, @{ $lhs } )
        : $clause eq $lhs ? TRUE : FALSE;
}

sub _eval_criteria {
   my ($self, $criteria, $attrs) = @_; my $lhs;

   for (keys %{ $criteria }) {
      defined ($lhs = $attrs->{ $_ } ) or return FALSE;
      $self->_eval_clause( $criteria->{ $_ }, $lhs ) or return FALSE;
   }

   return TRUE;
}

sub _eval_op {
   my ($self, $lhs, $op, $rhs) = @_;

   my $subr = $self->_operators->{ $op } or return FALSE;

   $_ or return FALSE for (map { $subr->( $_, $rhs ) }
                           ref $lhs eq ARRAY ? @{ $lhs } : ( $lhs ));

   return TRUE;
}

sub _find {
   my ($self, $name) = @_; my $results = $self->select;

   ($name and exists $results->{ $name }) or return;

   my $attrs = { %{ $results->{ $name } }, name => $name };

   return $self->_create_result( $attrs );
}

sub _list {
   my ($self, $name) = @_; my ($attr, $attrs, $labels); my $found = FALSE;

   my $results = $self->select; my $list = [ sort keys %{ $results } ];

   $attr = $self->label_attr
      and $labels = { map { $_ => $results->{ $_ }->{ $attr } } @{ $list } };

   if ($name and exists $results->{ $name }) {
      $attrs = { %{ $results->{ $name } }, name => $name }; $found = TRUE;
   }
   else { $attrs = { name => $name } }

   my $result = $self->_create_result( $attrs );

   $attrs = { found => $found, list => $list, result => $result, };

   $labels and $attrs->{labels} = $labels;

   return $self->list_class->new( $attrs );
}

sub _push {
   my ($self, $name, $attr, $items) = @_;

   my $attrs = { %{ $self->select->{ $name } || {} }, name => $name };
   my $list  = [ @{ $attrs->{ $attr } || [] } ];
   my $in    = [];

   for my $item (grep { not $self->is_member( $_, @{ $list } ) } @{ $items }) {
      CORE::push @{ $list }, $item;
      CORE::push @{ $in   }, $item;
   }

   $attrs->{ $attr } = $list;
   return ($attrs, $in);
}

sub _search {
   my ($self, $where) = @_; my $results = $self->_results; my @tmp;

   unless ($results) { $self->_results( [] ); $self->_iterator( 0 ) }

   if (not defined $results->[0]) {
      $results = $self->select;

      for (keys %{ $results }) {
         my $attrs = { %{ $results->{ $_ } }, name => $_ };

         if (not $where or $self->_eval_criteria( $where, $attrs )) {
            CORE::push @{ $self->_results }, $self->_create_result( $attrs );
         }
      }
   }
   elsif ($where and defined $results->[0]) {
      for (@{ $results }) {
         $self->_eval_criteria( $where, $_ ) and CORE::push @tmp, $_;
      }

      $self->_results( \@tmp );
   }

   return wantarray ? $self->all : $self;
}

sub _splice {
   my ($self, $name, $attr, $items) = @_;

   my $attrs = { %{ $self->select->{ $name } || {} }, name => $name };
   my $list  = [ @{ $attrs->{ $attr } || [] } ];
   my $out   = [];

   for my $item (@{ $items }) {
      last unless (defined $list->[0]);

      for (0 .. $#{ $list }) {
         if ($list->[ $_ ] eq $item) {
            CORE::splice @{ $list }, $_, 1;
            CORE::push   @{ $out  }, $item;
            last;
         }
      }
   }

   $attrs->{ $attr } = $list;
   return ($attrs, $out);
}

sub _txn_do {
   my ($self, $coderef) = @_;

   return $self->storage->txn_do( $self->path, $coderef );
}

sub _validate_params {
   my ($self, $args) = @_; $args ||= {};

   my $name = $args->{name}
      or $self->throw( error => 'No element name specified', level => 4 );

   return $name;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=pod

=head1 Name

File::DataClass::ResultSet - Core element methods

=head1 Version

0.7.$Revision: 321 $

=head1 Synopsis

   use File:DataClass;

   $attrs = { result_source_attributes => { schema_attributes => { ... } } };

   $result_source = File::DataClass->new( $attrs )->result_source;

   $rs = $result_source->resultset( { path => q(path_to_data_file) } );

   $result = $rs->search( $hash_ref_of_where_clauses );

   for $result_object ($result->next) {
      # Do something with the result object
   }

=head1 Description

Find, search and update methods for element objects

=head1 Configuration and Environment

Defines these attributes

=over 3

=item B<list_class>

List class name, defaults to L<File::DataClass::List>

=item B<result_class>

Result class name, defaults to L<File::DataClass::Result>

=item B<source>

An object reference to the L<File::DataClass::ResultSource> instance
that created this result set

=item B<_iterator>

Contains the integer count of the position within the B<_results> hash.
Incremented by each call to L</next>

=item B<_operators>

A hash ref of coderefs that implement the comparison operations performed
by the L</search> method

=item B<_results>

An array of result objects. Produced by calling L</search>

=back

=head1 Subroutines/Methods

=head2 all

   @elements = $rs->search()->all;

Returns all the elements that are returned by the L</search> call

=head2 create

   $new_element_name = $rs->create( $args );

Creates and inserts an new element. The C<$args> hash requires these
keys; I<name> of the element to create and I<fields> is a hash
containing the attributes of the new element. Missing attributes are
defaulted from the I<defaults> attribute of the
L<File::DataClass::Schema> object. Returns the new element's name

=head2 create_or_update

   $element_name = $rs->create_or_update( $args );

Creates a new element if it does not already exist, updates the existsing
one if it does. Calls L</find_and_update>

=head2 delete

   $rs->delete( { name => $of_element_to_delete } );

Deletes an element

=head2 find

   $result_object = $rs->find( { name => $of_element_to_find } );

Finds the named element and returns an
L<element|File::DataClass::Result> object for it

=head2 find_and_update

   $updated_element_name = $rs->_find_and_update( $name, $attrs );

Finds the named element object and updates it's attributes. Does not wrap
the find and update in a transaction

=head2 first

   $result_object = $rs->search( $where_clauses )->first;

Returns the first element object that is the result of the search call

=head2 list

   $list_obect = $rs->list( { name => $name } );

Returns a L<list|File::DataClass::List> object

Retrieves the named element and a list of elements

=head2 last

   $result_object = $rs->search( $where_clauses )->last;

Returns the last element object that is the result of the search call

=head2 next

   $result_object = $rs->search( $where_clauses )->next;

Iterate over the elements returned by the search call

=head2 path

   $path = $rs->path;

Attribute L<File::DataClass::Schema/path>

=head2 push

   $added = $rs->push( { name => $name, list => $list, items => $items } );

Adds items to the attribute list. The C<$args> hash requires these
keys; I<name> the element to edit, I<list> the attribute of the named
element containing the list of existing items, I<req> the request
object and I<items> the field on the request object containing the
list of new items

=head2 reset

   $rs->reset

Resets the resultset's cursor, so you can iterate through the elements again

=head2 search

   $result = $rs->search( $hash_ref_of_where_clauses );

Search for elements that match the given criterion. The criterion is a hash
ref whose keys are element attribute names. The criterion values are either
scalar values or hash refs. The scalar values are tested for equality with
the corresponding element attribute values. Hash ref keys are treated as
comparison operators, the hash ref values are compared with the element
attribute values, e.g.

   { 'some_element_attribute_name' => { '>=' => 0 } }

=head2 select

   $hash = $rs->select;

Returns a hash ref of elements

=head2 splice

   $removed = $rs->splice( { name => $name, list => $list, items => $items } );

Removes items from the attribute list

=head2 storage

   $storage = $rs->storage;

Attribute L<File::DataClass::Schema/storage>

=head2 update

   $rs->update( { name => $of_element, fields => $attr_hash } );

Updates the named element

=head2 _txn_do

Calls L<File::DataClass::Storage/txn_do>

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<File::DataClass::List>

=item L<File::DataClass::Result>

=item L<File::DataClass::Util>

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