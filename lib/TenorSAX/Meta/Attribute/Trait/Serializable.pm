package TenorSAX::Meta::Attribute::Trait::Serializable;

use v5.14;
use strict;
use warnings;

# This code is based on the example provided in
# Moose::Cookbook::Meta::Labeled_AttributeTrait.

use Moose::Role;

has serializer => (
	is => 'rw',
	isa => 'CodeRef',
	default => sub { sub {
		my ($self, $obj, $state) = @_;

		my $reader = $self->get_read_method;
		return {$self->name => $obj->$reader};
	}},
);

sub serialize {
	my ($self, $obj, $state) = @_;
	my $serializer = $self->serializer;

	return $self->$serializer($obj, $state);
}

Moose::Util::meta_attribute_alias('Serializable');

1;
