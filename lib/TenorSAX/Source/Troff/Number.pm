package TenorSAX::Source::Troff::Number;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;

has 'inc_value' => (
	isa => 'Int',
	is => 'rw',
	default => 0,
);
has 'value' => (
	isa => 'Int',
	is => 'rw',
	default => 0,
);
has 'format_type' => (
	isa => 'Str',
	is => 'rw',
	default => '1',
);

extends 'TenorSAX::Source::Troff::Numerical';

sub format {
	my $self = shift;
	# TODO: implement formats.
	return $self->value;
}

sub increment {
	my $self = shift;
	$self->value += $self->inc_value;
}

sub decrement {
	my $self = shift;
	$self->value -= $self->inc_value;
}

=head1 NAME

TenorSAX::Source::Troff::Number - The great new TenorSAX::Source::Troff!

=head1 VERSION

Version 2.00

=cut

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use TenorSAX::Source::Troff;

    my $foo = TenorSAX::Source::Troff->new();
    ...

=head1 AUTHOR

brian m. carlson, C<< <sandals at crustytoothpaste.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tenorsax at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TenorSAX>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TenorSAX::Source::Troff::Number

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
