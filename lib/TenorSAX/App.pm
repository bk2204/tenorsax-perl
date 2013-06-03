package TenorSAX::App;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;

use Moose;
use namespace::autoclean;
use Getopt::Long;
use TenorSAX;
use TenorSAX::Util::HandlerGenerator;

has 'input_device' => (
	is => 'rw',
	isa => 'Str',
	init_arg => 'InputDevice',
);
has 'output_device' => (
	is => 'rw',
	isa => 'Str',
	init_arg => 'OutputDevice',
	default => "xml",
);
has 'resolution' => (
	is => 'rw',
	init_arg => 'Resolution',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $default = 72000;
		return $default unless defined $self->output_device;
		my $device = $self->output_devices->{$self->output_device};
		return $device->{resolution} // $default;
	},
);
has 'output_devices' => (
	is => 'ro',
	default => sub { 
		{
			text => {
				name => "TenorSAX::Output::Text",
				takes => "tm",
			},
			utf8 => {
				name => "TenorSAX::Output::Terminal",
				resolution => 240,
				takes => "le",
			},
			xml => {
				name => "XML::SAX::Writer",
				takes => "xml",
			},
			tmxml => {
				name => "XML::SAX::Writer",
				takes => "tm",
			},
			lexml => {
				name => "XML::SAX::Writer",
				takes => "le",
			},
			pdf => {
				name => "TenorSAX::Output::PDF",
				takes => "le",
			},
		}
	},
);
has 'options' => (
	is => 'rw',
	isa => 'ArrayRef',
	default => sub { [] },
);
has 'output' => (
	is => 'rw',
);

sub parse_options {
	my ($self, $args) = @_;

	my $options = {};
	local @ARGV = @$args;
	my $p = Getopt::Long::Parser->new();
	$p->configure('no_ignore_case', 'bundling');
	$p->getoptions($options,
		@{$self->options},
	);
	@$args = @ARGV;
	my $map = {
		device => 'output_device',
		format => 'input_device',
	};

	foreach my $opt (keys $options) {
		my $value = $options->{$opt};
		$opt = $map->{$opt} if exists $map->{$opt};
		my $method = $self->can($opt);
		$self->$method($value);
	}
}

sub build_output_chain {
	my ($self, $provided_inputs, $takes) = @_;
	my @chain;
	my $devicename = $self->output_device;
	my $device = $self->output_devices->{$devicename};
	my $output = $self->output;

	if (defined $device) {
		my $name = $device->{name};
		push @chain, {
			name => $name,
			attributes => {
				(defined $output ? (Output => $output) : ()),
				Resolution => $self->resolution,
			},
		};
		$takes = $device->{takes};
	}
	else {
		require File::Path::Expand;

		my $stylesheet;
		my @xslt_dirs = map { File::Path::Expand::expand_filename($_) }
			@{$TenorSAX::Config->{troff}->{xslt}};
		foreach my $dir (reverse @xslt_dirs) {
			$stylesheet = "$dir/format-$devicename.xsl";
			last if -r $stylesheet;
			$stylesheet = undef;
		}
		die "Can't load stylesheet for device $devicename"
			unless $stylesheet;
		unshift @chain, {
			name => "XML::SAX::Writer",
			attributes => $output ? { Output => $output } : {},
		};
		unshift @chain, {
			name => "XML::Filter::XSLT",
			methods => [
				{
					name => "set_stylesheet_uri",
					args => [$stylesheet],
				}
			],
		};
		$takes = "tm" unless defined $takes;
	}
	$self->insert_filters(\@chain, $takes, $provided_inputs);
	return @chain;
}

sub generate_output_chain {
	my ($self, @args) = @_;
	my @chain = $self->build_output_chain(@args);
	return TenorSAX::Util::HandlerGenerator->new->generate(@chain);
}

sub insert_filters {
	my ($self, $chain, $takes, $provided_inputs) = @_;

	return if $takes eq "xml";

	say "inputs are @$provided_inputs";
	for ($takes) {
		when (@$provided_inputs) {
			return;
		}
		when ("le") {
			unshift $chain, {
				name => "TenorSAX::Filter::TextMarkupToLayoutEngine",
				attributes => {
					Resolution => $self->resolution,
				},
			};
			$takes = "tm";
			redo;
		}
		when ("tm") {
			if ("xml-Pod::SAX" ~~ @$provided_inputs) {
				unshift $chain, {
					name => "TenorSAX::Filter::PodSAXToTextMarkup",
				};
				$takes = "xml-Pod::SAX";
				redo;
			}
			continue;
		}
		default {
			die "Can't convert $takes to one of [@$provided_inputs]";
		}
	}
	return;
}

sub load_file {
	my ($self, $file) = @_;

	local $/;
	open(my $fh, '<', $file) or die "Can't open file '$file': $!";
	my $data = <$fh>;
	close($fh) or die "Can't close file '$file': $!";
	return $data;
}

sub load_files {
	my ($self, @args) = @_;
	my $data = "";
	if (@args) {
		foreach my $file (@args) {
			$data .= $self->load_file($file);
		}
	}
	else {
		local $/;
		$data = <STDIN>;
	}
	return $data;
}

1;
