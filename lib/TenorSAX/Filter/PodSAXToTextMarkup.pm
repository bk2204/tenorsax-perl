package TenorSAX::Filter::PodSAXToTextMarkup;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;

use TenorSAX;
use TenorSAX::Util::NodeGenerator;
use Moose;
use MooseX::NonMoose;
use namespace::autoclean;
use experimental qw/smartmatch autoderef/;

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
			tm => "http://ns.crustytoothpaste.net/text-markup",
			xl => "http://www.w3.org/1999/xlink",
			xml => 'http://www.w3.org/XML/1998/namespace',
		}
	},
);
# 0 for normal processing, 1 for tenorsax markup block, 2 for ignored markup
# block
has '_state' => (
	is => 'rw',
	isa => 'Int',
	default => 0,
);
has '_seen_meta' => (
	is => 'rw',
	isa => 'Bool',
	default => 0,
);
has '_charstore' => (
	is => 'rw',
	isa => 'Str',
	default => "",
);
has '_ng' => (
	is => 'rw',
	isa => 'TenorSAX::Util::NodeGenerator',
);

sub _get_prefixes {
	my ($self) = @_;
	my $prefixes = $self->_prefixes;

	return map {
		{ Prefix => $_, NamespaceURI => $prefixes->{$_} }
	} sort keys $prefixes;
}

sub start_document {
	my ($self) = @_;

	$self->_ng(TenorSAX::Util::NodeGenerator->new(prefixes =>
			$self->_prefixes));

	$self->SUPER::start_document({});
	foreach my $mapping ($self->_get_prefixes) {
		$self->SUPER::start_prefix_mapping($mapping);
	}
	return $self->SUPER::start_element($self->_ng->element("tm:root"));
}

sub end_document {
	my ($self) = @_;

	$self->SUPER::end_element($self->_ng->element("tm:section"))
		for 1 .. $self->_depth;
	$self->SUPER::end_element($self->_ng->element("tm:root"));
	foreach my $mapping (reverse $self->_get_prefixes) {
		$self->SUPER::end_prefix_mapping($mapping);
	}
	return $self->SUPER::end_document({});
}

sub characters {
	my ($self, $hr) = @_;

	return $self->SUPER::characters($hr) if $self->_state == 0;
	return if $self->_state == 2;
	# state == 1
	$self->_charstore($self->_charstore . $hr->{Data});
	return;
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
				$self->SUPER::start_element($self->_ng->element("tm:section"))
					for 1 .. $diff;
			}
			elsif ($diff < 0) {
				$self->SUPER::end_element($self->_ng->element("tm:section"))
					for 0 .. -$diff;
				$self->SUPER::start_element($self->_ng->element("tm:section"));
			}
			else {
				$self->SUPER::end_element($self->_ng->element("tm:section"));
				$self->SUPER::start_element($self->_ng->element("tm:section"));
			}
			$self->SUPER::start_element($self->_ng->element("tm:title"));
			$self->_depth($level);
			return;
		}
		$name = $_ when /^(?:para|(?:itemized|ordered)list|listitem)$/;
		when ("xlink") {
			my $elem = $self->_ng->element("tm:link", {
					"xl:href" => $element->{Attributes}->{"{}href"}->{Value},
					"xl:type" => "simple",
				}
			);
			$self->SUPER::start_element($elem);
		}
		when (/^([BIFC])$/) {
			my $type = $1;
			my %inlines = (
				"B" => {
					type => "strong",
				},
				"I" => {
					type => "emphasis",
				},
				"C" => {
					type => "monospace",
				},
				"F" => {
					type => "emphasis",
					semantic => "filename",
				},
			);
			return unless exists $inlines{$type};
			my $elem = $self->_ng->element("tm:inline", $inlines{$type});
			$self->SUPER::start_element($elem);
		}
		when ("verbatim") {
			my $elem = $self->_ng->element("tm:verbatim", {
					"xml:space" => "preserve"
				}
			);
			$self->SUPER::start_element($elem);
		}
		when ("markup") {
			my $type = $element->{Attributes}->{"{}type"}->{Value};
			$self->_state($type eq "tenorsax" ? 1 : 2);
		}
	}

	return $self->SUPER::start_element($self->_ng->element("tm:$name"))
		if $name;
	return;
}

sub end_element {
	my ($self, $element) = @_;
	my $name;

	for ($element->{Name}) {
		return when "pod";
		$name = "title" when /^head(\d+)$/;
		$name = $_ when /^(?:para|(?:itemized|ordered)list|listitem|verbatim)$/;
		return $self->SUPER::end_element($self->_ng->element("tm:link"))
			when "xlink";
		$name = "inline" when /^[BIFC]$/;
		when ("markup") {
			$self->_state(0);
			$self->_parse_tenorsax_block($self->_charstore);
			$self->_charstore("");
		}
	}
	return $self->SUPER::end_element($self->_ng->element("tm:$name")) if $name;
	return;
}

# Eat those annoying Pod::SAX comments.
sub comment {
	return;
}

sub _parse_tenorsax_block {
	my ($self, $text) = @_;
	my %attrs = map {
		/^\s*([^:]+):\s?(.*)$/ ? ($1, $2) : ()
	} split /\R/, $text;

	if (exists $attrs{title}) {
		$self->SUPER::start_element($self->_ng->element("tm:title"));
		$self->SUPER::characters({Data => $attrs{title}});
		$self->SUPER::end_element($self->_ng->element("tm:title"));
	}
	if (!$self->_seen_meta) {
		$self->_seen_meta(1);

		$self->SUPER::start_element($self->_ng->element("tm:meta"));
		if (exists $attrs{author}) {
			$self->SUPER::start_element($self->_ng->element("tm:author"));
			$self->SUPER::characters({Data => $attrs{author}});
			$self->SUPER::end_element($self->_ng->element("tm:author"));
		}
		my $version = $TenorSAX::VERSION // "development";
		my $elem = $self->_ng->element("tm:generator", {
				name => "TenorSAX",
				version => $version
			}
		);
		$self->SUPER::start_element($elem);
		$self->SUPER::end_element($elem);
		$self->SUPER::end_element($self->_ng->element("tm:meta"));
	}
	if (exists $attrs{image}) {
		my ($uri, $alt) = split /\s+/, $attrs{image}, 2;
		my $elem = $self->_ng->element("tm:image", {
				uri => $uri,
				description => $alt,
			}
		);
		$self->SUPER::start_element($elem);
		$self->SUPER::end_element($self->_ng->element("tm:image"));
	}
	return;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
