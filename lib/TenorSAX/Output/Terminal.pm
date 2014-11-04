package TenorSAX::Output::Terminal;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;
use Scalar::Util;

extends 'TenorSAX::Output::LayoutEngine';

=head1 NAME

TenorSAX::Output::Terminal - The great new TenorSAX::Source::Troff!

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

sub _columns {
	return $ENV{COLUMNS} || 80;
}

sub _line_length {
	my $self = shift;
	my $columns = $self->_columns;

	return $self->_char_width * $columns;
}

sub _adjust_line {
	my ($self, @chunks) = @_;
	my $spaces = 0;
	my $chars = 0;
	my $columns = $self->_columns;
	my @results;

	return @chunks unless $chunks[0]{adjust} eq "both";

	foreach my $chunk (@chunks) {
		$spaces += $chunk->{text} =~ tr/ //;
		$chars += length($chunk->{text});
	}

	my $each = int(($columns - $chars) / $spaces);
	my $extra = ($columns - $chars) % $spaces;
	my $each_space = " " x $each;

	# Insert the minimum number of spaces into each chunk.
	@chunks = map {
		my $chunk = {%$_};

		$chunk->{text} =~ s/ / $each_space/g;

		$chunk;
	} @chunks;

	# Split out spaces into their own chunks.
	@chunks = map {
		my $item = $_;
		map { {%$item, text => $_} } split m/([.?!]? +)/, $item->{text};
	} @chunks;

	# Insert spaces after punctuation.
	@chunks = map {
		$extra-- if $extra && $_->{text} =~ s/(. +)/$1 /;
		$_;
	} @chunks;

	# If there are any spaces left over, insert them between words.
	if ($extra > 0) {
		my $items = scalar @chunks;

		for (my $i = 0; $i < $items && $extra > 0; $i++) {
			my $item = $chunks[$i];
			$extra-- if $extra && $item->{text} =~ s/( +)/$1 /;

			$item = $chunks[$items-$i-1];
			$extra-- if $extra && $item->{text} =~ s/( +)/$1 /;
		}
	}

	return @chunks;
}

sub _do_line {
	my ($self, @chunks) = @_;
	my $text = join('', map { $_->{text} } @chunks) . "\n";

	$self->_print($text);
	return;
}

sub end_element {
	my ($self, $element) = @_;

	my $ns = do {
		no warnings 'once';
		$TenorSAX::Output::LayoutEngine::TROFF_NS;
	};

	$self->SUPER::end_element($element);
	if ($element->{NamespaceURI} eq $ns &&
		$element->{LocalName} eq "block") {

		$self->_print("\n");
	}
	return;
}


=head1 AUTHOR

brian m. carlson, C<< <sandals at crustytoothpaste.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tenorsax at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TenorSAX>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TenorSAX::Output::Terminal

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
