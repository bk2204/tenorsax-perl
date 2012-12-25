package TenorSAX::Filter::PodSAXToTextMarkup;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;

extends 'XML::SAX::Base';

has 'handler' => (
	is => 'rw',
	init_arg => 'Handler',
);
has '_depth' => (
	is => 'rw',
	isa => 'Num',
	default => 0,
);
has '_prefixes' => (
	is => 'rw',
	isa => 'HashRef[Str]',
	default => sub {
		{
			"tm" => "http://ns.crustytoothpaste.net/text-markup",
			"xl" => "http://www.w3.org/1999/xlink",
		}
	},
);

sub _element {
	my ($self, $name, $prefix) = @_;
	$prefix //= "tm";

	my $uri = $self->_prefixes->{$prefix};
	die "No such prefix $prefix" unless defined $uri;

	return {
		Name => "$prefix:$name",
		Attributes => {},
		NamespaceURI => $uri,
		Prefix => $prefix,
		LocalName => $name,
	};
}

sub _attribute {
	my ($self, $name, $value, $prefix) = @_;
	$prefix //= "tm";

	my $uri = $self->_prefixes->{$prefix};
	die "No such prefix $prefix" unless defined $uri;

	return (
		"\{$uri\}$name" => {
			Name => "$prefix:$name",
			NamespaceURI => $uri,
			Prefix => $prefix,
			LocalName => $name,
			Value => $value,
		}
	);
}

sub _get_prefixes {
	my ($self) = @_;
	my $prefixes = $self->_prefixes;

	return map {
		{ Prefix => $_, NamespaceURI => $prefixes->{$_} }
	} sort keys $prefixes;
}

sub start_document {
	my ($self) = @_;

	$self->SUPER::start_document({});
	foreach my $mapping ($self->_get_prefixes) {
		$self->SUPER::start_prefix_mapping($mapping);
	}
	$self->SUPER::start_element($self->_element("root"));
}

sub end_document {
	my ($self) = @_;

	$self->SUPER::end_element($self->_element("section"))
		for 1 .. $self->_depth;
	$self->SUPER::end_element($self->_element("root"));
	foreach my $mapping (reverse $self->_get_prefixes) {
		$self->SUPER::end_prefix_mapping($mapping);
	}
	return $self->SUPER::end_document({});
}

sub start_element {
	my ($self, $element) = @_;
	my $name;

	for ($element->{Name}) {
		return when "pod";
		when (/^head(\d+)$/) {
			my $level = $1;
			my $diff = $level - $self->_depth;
			if ($diff > 0) {
				$self->SUPER::start_element($self->_element("section"))
					for 1 .. $diff;
			}
			elsif ($diff < 0) {
				$self->SUPER::end_element($self->_element("section"))
					for 1 .. -$diff;
				$self->SUPER::start_element($self->_element("section"));
			}
			else {
				$self->SUPER::end_element($self->_element("section"));
				$self->SUPER::start_element($self->_element("section"));
			}
			$self->SUPER::start_element($self->_element("title"));
			$self->_depth($level);
			return;
		}
		$name = $_ when /^(?:para|(?:itemized|ordered);list|listitem)$/;
		when ("xlink") {
			my $elem = $self->_element("xlink", "xl");
			$elem->{Attributes} = {
				$self->_attribute("href", 
					$element->{Attributes}->{"{}href"}->{Value},
					"xl")
			};
			$self->SUPER::start_element($elem);
		}
		when (/^(B|I)$/) {
			my $elem = $self->_element("inline");
			my $type = $1;
			my %inlines = (
				"B" => {
					"font-weight" => "bold"
				},
				"I" => {
					"font-variant" => "italic"
				}
			);
			return unless exists $inlines{$type};
			my @attrs;
			foreach my $key (keys $inlines{$type}) {
				push @attrs, $self->_attribute($key, $inlines{$type}->{$key});
			}
			$elem->{Attributes} = {@attrs};
			$self->SUPER::start_element($elem);
		}
	}

	return $self->SUPER::start_element($self->_element($name)) if $name;
	return;
}

sub end_element {
	my ($self, $element) = @_;
	my $name;

	for ($element->{Name}) {
		return when "pod";
		$name = "title" when /^head(\d+)$/;
		$name = $_ when /^(?:para|(?:itemized|ordered);list|listitem)$/;
		return $self->SUPER::end_element($self->_element("xlink", "xl"))
			when "xlink";
		$name = "inline" when /^(?:B|I)$/;
	}
	return $self->SUPER::end_element($self->_element($name)) if $name;
	return;
}

no Moose;
__PACKAGE__->meta->make_immutable;
