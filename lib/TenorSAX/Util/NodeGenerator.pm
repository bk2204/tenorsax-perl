package TenorSAX::Util::NodeGenerator;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;
use re '/u';

use Moose;
use namespace::autoclean;

has 'prefixes' => (
	is => 'rw',
	default => sub { {} },
);

=head1 Methods

=over 4

=item $ng->element($qname, [$attributes])

Takes a QName of the element to create, and optionally a hash containing a
mapping from QNames to values.  Returns a hash suitable for passing to a SAX
start_element handler.  Dies if the prefix is not defined.

=cut

sub element {
	my ($self, $qname, $attributes) = @_;
	$attributes //= {};

	my $result = $self->_node($qname);

	$result->{Attributes} = {};

	foreach my $attr (keys %$attributes) {
		my $hr = $self->attribute($attr, $attributes->{$attr});
		my $key = '{' . ($hr->{NamespaceURI} // '') . '}' . $hr->{LocalName};
		$result->{Attributes}->{$key} = $hr;
	}
	return $result;
}

=item $ng->attribute($qname, $value)

Takes a QName of the attribute and its value.  Returns a hash suitable as a
value in the Attributes element of a start_element argument.  Dies if the prefix
is not defined.

=cut

sub attribute {
	my ($self, $qname, $value) = @_;
	my $result = $self->_node($qname, 1);

	$result->{Value} = $value;
	return $result;
}

sub _node {
	my ($self, $qname, $attribute) = @_;
	my $result = {Name => $qname};
	my ($prefix, $local) = (($qname =~ /:/) ? (split /:/, $qname, 2) :
		(undef, $qname));
	my $uri;

	$prefix = "" unless $attribute || defined $prefix;

	if (defined $prefix) {
		$uri = $self->prefixes->{$prefix} //
			die "Prefix $prefix is not defined";
	}

	$result->{NamespaceURI} = $uri;
	$result->{Prefix} = $prefix;
	$result->{LocalName} = $local;
	return $result;
}

=back

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1;
