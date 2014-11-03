package TenorSAX::Output::LayoutEngine;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;
use Scalar::Util;

use experimental qw/smartmatch autoderef/;

has '_output' => (
	is => 'rw',
	default => sub { \*STDOUT },
	init_arg => 'Output',
);
has '_print_func' => (
	is => 'rw'
);
has '_resolution' => (
	is => 'ro',
	isa => 'Int',
	default => 72000,
	init_arg => 'Resolution',
);
has '_text' => (
	is => 'rw',
	isa => 'ArrayRef[HashRef[Str]]',
	default => sub { [] },
);
has '_attrs' => (
	is => 'rw',
	isa => 'ArrayRef[HashRef[Str]]',
	default => sub { [{}] },
);
# Is the output format binary?
has '_binary_output' => (
	is => 'ro',
	isa => 'Bool',
	default => 0,
);

=head1 NAME

TenorSAX::Output::LayoutEngine - The great new TenorSAX::Source::Troff!

=head1 VERSION

Version 2.00

=cut

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use TenorSAX::Source::Troff;

    my $foo = TenorSAX::Source::Troff->new();
    ...

=cut

our $TROFF_NS = "http://ns.crustytoothpaste.net/troff";

# FIXME: handle proportional-width fonts.
sub _char_width {
	my ($self, $char, $attrs) = @_;

	return $self->_resolution / 10;
}

sub _line_length {
	...
}

sub _do_line {
	my ($self, $chunks) = @_;

	...
}

sub _new_page {
	my $self = shift;

	...
}

sub _move_to {
	my ($self, $x, $y) = @_;

	...
}

sub _format_block {
	my $self = shift;
	my @blocks;

	# First, coalesce like blocks together...
	foreach my $block (@{$self->_text}) {
		next unless $block->{text};
		# ... unless they're no-fill.
		my $prev = $blocks[-1];
		if ($block->{fill} && @blocks && keys %$prev == grep {
			$_ eq "text" ||
				(exists $block->{$_} && $prev->{$_} eq $block->{$_}) } %$prev) {
				$blocks[-1]->{text} .= $block->{text};
		}
		else {
			push @blocks, $block;
		}
	}
	$self->_text([]);

	my $width = 0;
	my $line_length = $self->_line_length();
	my @output;
	foreach my $block (@blocks) {
		my $sofar = "";
		my $broken = 0;
		foreach my $char (grep { $_ } split /(\X)/, $block->{text}) {
			my $char_width = $self->_char_width($char, $block);
			if ($block->{fill} && $width + $char_width > $line_length) {
				$broken = 1;
				if ("$sofar$char" =~ m/\A(\X+)\s(\S*)\z/) {
					my @data = $self->_adjust_line(@output, {%{$block},
								text => $1});
					$self->_do_line(@data);
					@output = ();
					$sofar = $2;
					$width = 0;
					foreach my $c (grep { $_ } split /(\X)/, $sofar) {
						$width += $self->_char_width($char, $block);
					}
				}
				else {
					# Non-Latin script, probably.  Japanese, maybe?
					# TODO: handle this better.
					my @data = $self->_adjust_line(@output, {%{$block},
								text => $sofar});
					$self->_do_line(@data);
					@output = ();
					$sofar = $char;
					$width = $char_width;
				}
			}
			elsif (!$block->{fill} && $char =~ m/\R/) {
				$broken = 1;
				$self->_do_line(@output, {%{$block}, text => $sofar});
				@output = ();
				$sofar = "";
				$width = 0;
			}
			else {
				$sofar .= $char;
				$width += $char_width;
			}
		}
		if ($broken) {
			push @output, {%{$block}, text => $sofar};
		}
		else {
			push @output, $block;
		}
	}
	if (@output && ($output[0]->{fill} + 0) &&
		$output[0]->{adjust} eq "center") {
		@output = $self->_adjust_line(@output);
	}
	$self->_do_line(@output);
	return;
}

sub start_document {
	my ($self, @args) = @_;

	$self->_setup_output;
	return;
}

sub end_document {
	my ($self, @args) = @_;

	if (blessed $self->_output && $self->_output->can('finalize')) {
		$self->_output->finalize();
	}
	return;
}

sub start_element {
	my ($self, $element) = @_;

	return unless $element->{NamespaceURI} eq $TROFF_NS;
	if ($element->{LocalName} =~ m/^(?:block|inline)$/) {
		# Inherit any attributes that aren't specified.  At the moment, we pass
		# all the attributes every time, but we may change that in the future.
		#
		# The hash contains unprefixed names for items in the troff namespace
		# and prefixed otherwise; this is only for xml:space and the like, since
		# prefixes are not otherwise guaranteed.
		my %attrs = map {
			($element->{Attributes}{$_}{NamespaceURI} eq $TROFF_NS ?
				$element->{Attributes}{$_}{LocalName} :
				$element->{Attributes}{$_}{Name}) =>
			$element->{Attributes}{$_}{Value}
		} keys $element->{Attributes};
		push $self->_attrs, {%{$self->_attrs->[-1]}, %attrs};
	}
	return;
}

sub start_prefix_mapping {
	my ($self, $mapping) = @_;
	return;
}

sub end_element {
	my ($self, $element) = @_;

	return unless $element->{NamespaceURI} eq $TROFF_NS;
	if ($element->{LocalName} eq "block") {
		$self->_format_block();
		pop $self->_attrs;
	}
	elsif ($element->{LocalName} eq "inline") {
		pop $self->_attrs;
	}
	return;
}

sub end_prefix_mapping {
	my ($self, @args) = @_;
	return;
}

sub characters {
	my ($self, $ref) = @_;
	my $text = $ref->{Data} // '';
	my %attrs = %{$self->_attrs->[-1]};
	my $space = $attrs{'xml:space'} // '';

	$text =~ s/\R/ /g if $space ne "preserve";
	push $self->_text, {%attrs, text => $text};
	return;
}

sub ignorable_whitespace {
	my ($self, @args) = @_;
	return;
}

sub processing_instruction {
	my ($self, @args) = @_;
	return;
}

sub _print {
	my ($self, @args) = @_;;
	my $method = $self->_print_func;

	return $self->$method(@args);
}

sub _setup_output {
	my ($self) = @_;

	if (ref $self->_output eq '') {
		my $filename = $self->_output;
		open(my $fh, '>', $filename) or
			die "Can't open $filename for writing: $!";
		binmode $fh if $self->_binary_output;
		$self->_output($fh);
		$self->_print_func(\&_do_output_fh);
	}
	elsif (ref $self->_output eq 'ARRAY') {
		$self->_print_func(\&_do_output_push);
	}
	elsif (ref $self->_output eq 'SCALAR') {
		$self->_print_func(\&_do_output_scalar);
	}
	elsif ($self->_output->can('output')) {
		$self->_print_func(\&_do_output_method);
	}
	else {
		# We don't know if either of these will work; if they don't, we'll get
		# some pretty broken PDFs.
		if ($self->_binary_output) {
			eval {
				$self->_output->binmode();
			};
			eval {
				binmode $self->_output;
			};
		}
		$self->_print_func(\&_do_output_print);
	}
	return;
}

sub _do_output_fh {
	my ($self, $text) = @_;

	return print {$self->_output} $text;
}

sub _do_output_push {
	my ($self, $text) = @_;

	push $self->_output, $text;
	return 1;
}

sub _do_output_scalar {
	my ($self, $text) = @_;

	${$self->_output} .= $text;
	return 1;
}

sub _do_output_method {
	my ($self, $text) = @_;

	return $self->_output->output($text);
}

sub _do_output_print {
	my ($self, $text) = @_;

	return $self->_output->print($text);
}

=head1 AUTHOR

brian m. carlson, C<< <sandals at crustytoothpaste.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tenorsax at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TenorSAX>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TenorSAX::Output::LayoutEngine

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 brian m. carlson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1;
