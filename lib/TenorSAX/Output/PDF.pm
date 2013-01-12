package TenorSAX::Output::PDF;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
#use feature qw/unicode_strings/;

use Moose;
use Scalar::Util;
use PDF::API2;

extends 'TenorSAX::Output::PageLayoutEngine';

has '_pdf' => (
	is => 'ro',
	isa => 'PDF::API2',
	default => sub { PDF::API2->new() },
	init_arg => undef,
);
has '_binary_output' => (
	is => 'ro',
	isa => 'Bool',
	default => 1,
);
has '_last_chunk' => (
	is => 'rw',
	isa => 'HashRef',
	default => sub {
		{
			'paper-size' => 'letter',
			'line-length' => '6.5in',
		}
	},
);
has '_font_cache' => (
	is => 'rw',
	isa => 'HashRef',
	default => sub { {} },
);

=head1 NAME

TenorSAX::Output::PDF - The great new TenorSAX::Source::Troff!

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

our $TROFF_NS = $TenorSAX::Output::LayoutEngine::TROFF_NS;

sub _lookup_font {
	my ($self, $name, $chunk) = @_;
	my $cache = $self->_font_cache;
	my $bold = $chunk->{'font-weight'} eq "bold";
	my $italic = $chunk->{'font-variant'} eq "italic";
	my $fcname = $name . ($bold ? ":bold" : "") . ($italic ? ":italic" : "");

	return $cache->{$fcname} if exists $cache->{$fcname};

	my $font;
	my @suffixes = ("");
	@suffixes = map { "${_}Bold" } @suffixes if $bold;
	@suffixes = map { ("${_}Italic", "${_}Oblique") } @suffixes if $italic;
	@suffixes = map { $_ ? "-$_" : $_ } @suffixes;

	foreach my $suffix (@suffixes) {
		my $string = "$name$suffix";
		eval {
			$font = $self->_pdf->corefont($string, -dokern => 1, -encoding => 'UTF-8');
		};
		return $cache->{$fcname} = $font if $font;
	}
	return;

	eval {
		$font = $self->_pdf->ttfont($name, -dokern => 1, -encoding => 'UTF-8');
	} or eval {
		$font = $self->_pdf->psfont($name, -dokern => 1, -encoding => 'UTF-8');
	};
	return $cache->{$name} = $font;
}

sub _char_width {
	my ($self, $char, $attrs) = @_;
	my $font = $self->_lookup_font($attrs->{'font-family'}, $attrs);

	return $self->_res($attrs->{'font-size'}) * $font->width($char);
}

sub _line_length {
	my $self = shift;
	my $chunk = shift // $self->_last_chunk;

	# FIXME: look up when laying out.
	return $self->_res($chunk->{'line-length'});
}

sub _new_page {
	my $self = shift;

	my $page = $self->_pdf->page();
	my $chunk = $self->_last_chunk;
	# FIXME: don't create first page until we lay out text.
	$page->mediabox($chunk->{'paper-size'});
	$self->_move_to($self->_res($chunk->{'page-offset'}),
			$self->_res($chunk->{'page-length'}) -
			$self->_res($chunk->{'vertical-space'}));
	return;
}

# Convert from resolution units to PDF units.
sub _units {
	my ($self, $x) = @_;
	if ($x =~ /^(\d+(\.\d+)?)pt/) {
		return $1;
	}
	elsif ($x =~ /^(\d+(\.\d+)?)in/) {
		return $1 * 72;
	}
	return $x * 72 / $self->_resolution;
}

# Convert from PDF units to resolution units.
sub _res {
	my ($self, $x) = @_;
	if ($x =~ /^(\d+(\.\d+)?)pt/) {
		$x = $1;
	}
	elsif ($x =~ /^(\d+(\.\d+)?)in/) {
		$x = $1 * 72;
	}
	return $x * $self->_resolution / 72;
}

sub _move_to {
	my ($self, $x, $y) = @_;

	$self->_x($x);
	$self->_y($y);
	return;
}

sub _adjust_line {
	my ($self, @chunks) = @_;

	for ($chunks[0]{adjust}) {
		return $self->_adjust_line_both(@chunks) when "both";
		return $self->_adjust_line_center(@chunks) when "center";
		default { return @chunks; }
	}
}

sub _adjust_line_center {
	my ($self, @chunks) = @_;
	my $length;

	if (@chunks) {
		$chunks[0]->{text} =~ s/^\s+//;
		$chunks[-1]->{text} =~ s/\s+$//;
	}
	foreach my $chunk (@chunks) {
		$length += $self->_char_width($chunk->{text}, $chunk);
	}

	my $diff = $self->_line_length($chunks[0]) - $length;
	my $each_gap = $diff / 2;
	my $gap = $self->_units($each_gap) . "pt";

	$chunks[0]->{'space-before'} = $gap;

	return @chunks;
}

sub _adjust_line_both {
	my ($self, @chunks) = @_;
	my @results;
	my $spaces = 0;
	my $length = 0;

	# Split out spaces into their own chunks.
	@chunks = map {
		my $item = $_;
		map { {%$item, text => $_} } split m/( +)/, $item->{text};
	} @chunks;

	foreach my $chunk (@chunks) {
		$length += $self->_char_width($chunk->{text}, $chunk);
		$spaces += !!($chunk->{text} =~ tr/ //);
	}

	my $diff = $self->_line_length($chunks[0]) - $length;

	return @chunks unless $spaces && $diff > 0;

	my $each_gap = $diff / $spaces;

	foreach my $chunk (@chunks) {
		$chunk->{'space-before'} = $self->_units($each_gap) . "pt"
			if $chunk->{text} =~ m/ /;
	}

	return @chunks;
}


sub _do_line {
	my ($self, @chunks) = @_;

	# Delay initialization of the first page until here so we can get the
	# appropriate parameters.
	unless ($self->_pdf->pages()) {
		return unless @chunks;
		$self->_last_chunk($chunks[0]);
		$self->_new_page();
	}
	my $page = $self->_pdf->openpage(-1);
	my $obj = $page->text();
	my ($x, $y) = ($self->_x, $self->_y);

	$obj->translate($self->_units($x), $self->_units($y));

	my $offset = $self->_units($x);
	foreach my $chunk (@chunks) {
		my $font = $self->_lookup_font($chunk->{'font-family'}, $chunk);
		my $text = $chunk->{text};

		if ($chunk->{'space-before'}) {
			$offset += $self->_units($chunk->{'space-before'});
			$obj->translate($offset, $self->_units($y));
		}
		$offset += $self->_units($self->_char_width($chunk->{text}, $chunk));

		$obj->font($font, $self->_units($chunk->{'font-size'}));
		$obj->fillcolor('black');
		$obj->text($text);
		$self->_last_chunk($chunk);
	}
	my $vertical = $self->_res($self->_last_chunk->{'vertical-space'});

	if ($y < $vertical) {
		$self->_new_page();
	}
	else {
		$self->_move_to($x, $y - $vertical);
	}

	return;
}

sub start_document {
	my ($self, @args) = @_;

	return $self->SUPER::start_document(@args);
}

sub end_document {
	my ($self, @args) = @_;

	$self->SUPER::end_document(@args);
	return $self->_print($self->_pdf->stringify());
}

sub end_element {
	my ($self, $element) = @_;

	return $self->SUPER::end_element($element);
}


=head1 AUTHOR

brian m. carlson, C<< <sandals at crustytoothpaste.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tenorsax at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TenorSAX>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TenorSAX::Output::PDF

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 brian m. carlson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
