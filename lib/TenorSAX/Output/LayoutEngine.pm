package TenorSAX::Output::LayoutEngine;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;
use Scalar::Util;

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

sub _format_block {
	my $self = shift;
	my @blocks = ({fill => 1, text => ''});

	# First, coalesce like blocks together...
	foreach my $block (@{$self->_text}) {
		next unless $block->{text};
		# ... unless they're no-fill.
		my $prev = $blocks[$#blocks];
		if ($block->{fill} && keys %$prev == grep {
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
			if ($width + $char_width > $line_length) {
				$broken = 1;
				if ("$sofar$char" =~ m/\A(\X+)\s(\S*)\z/) {
					$self->_do_line([@output, {%{$block}, text => $1}]);
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
					$self->_do_line([@output, {%{$block}, text => $sofar}]);
					@output = ();
					$sofar = $char;
					$width = $char_width;
				}
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
	$self->_do_line(\@output);
}

sub start_document {
	my ($self, @args) = @_;

	$self->_setup_output;
}

sub end_document {
	my ($self, @args) = @_;

	if (blessed $self->_output && $self->_output->can('finalize')) {
		$self->_output->finalize();
	}
}

sub start_element {
	my ($self, $element) = @_;
}

sub start_prefix_mapping {
	my ($self, $mapping) = @_;
}

sub end_element {
	my ($self, $element) = @_;

	return unless $element->{NamespaceURI} eq $TROFF_NS;
	if ($element->{LocalName} eq "block") {
		$self->_format_block();
	}
}

sub end_prefix_mapping {
	my ($self, @args) = @_;
}

sub characters {
	my ($self, $ref) = @_;
	my $text = $ref->{Data} // '';

	$text =~ s/\R/ /g;
	push $self->_text, {fill => 1, text => $text};
}

sub ignorable_whitespace {
	my ($self, @args) = @_;
}

sub processing_instruction {
	my ($self, @args) = @_;
}

sub _print {
	my ($self, @args) = @_;;
	my $method = $self->_print_func;

	$self->$method(@args);
}

sub _setup_output {
	my ($self) = @_;

	if (ref $self->_output eq '') {
		my $filename = $self->_output;
		open(my $fh, '>', $filename) or
			die "Can't open $filename for writing: $!";
		$self->_output = $fh;
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
		$self->_print_func(\&_do_output_print);
	}
}

sub _do_output_fh {
	my ($self, $text) = @_;

	print {$self->_output} $text;
}

sub _do_output_push {
	my ($self, $text) = @_;

	push $self->_output, $text;
}

sub _do_output_scalar {
	my ($self, $text) = @_;

	${$self->_output} .= $text;
}

sub _do_output_method {
	my ($self, $text) = @_;

	$self->_output->output($text);
}

sub _do_output_print {
	my ($self, $text) = @_;

	$self->_output->print($text);
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

1;