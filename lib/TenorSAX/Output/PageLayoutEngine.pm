package TenorSAX::Output::PageLayoutEngine;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;
use Scalar::Util;

extends 'TenorSAX::Output::LayoutEngine';

has '_x' => (
	is => 'rw',
	isa => 'Num',
);
has '_y' => (
	is => 'rw',
	isa => 'Num',
);

=head1 NAME

TenorSAX::Output::PageLayoutEngine - The great new TenorSAX::Source::Troff!

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

sub _line_length {
	my $self = shift;

	...
}

sub _page_length {
	my $self = shift;

	# FIXME: this is bad.
	return $self->_resolution * 9;
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

=head1 AUTHOR

brian m. carlson, C<< <sandals at crustytoothpaste.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tenorsax at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TenorSAX>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TenorSAX::Output::PageLayoutEngine

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 brian m. carlson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
