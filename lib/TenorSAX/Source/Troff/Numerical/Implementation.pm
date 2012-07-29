package TenorSAX::Source::Troff::Numerical::Implementation;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;

use Moose;
use TenorSAX::Source::Troff::Numerical;
use TenorSAX::Source::Troff::Number;
use TenorSAX::Source::Troff::SpecialNumber;

my $registers = [
	{
		name => '.ps',
		code => sub {
			my ($self, $state) = @_;

			return $state->{environment}->font_size;
		}
	},
	{
		name => '.s',
		code => sub {
			my ($self, $state) = @_;

			return $state->{environment}->font_size * 72 /
				$state->{parser}->_resolution;
		}
	},
];

sub make_number {
	my ($class, $data) = @_;
	my $num = TenorSAX::Source::Troff::SpecialNumber->new(
		code => $data->{code},
	);
	return $num;
}

sub numbers {
	my $class = shift;

	return {map { $_->{name} => __PACKAGE__->make_number($_) } @$registers};
}

=head1 NAME

TenorSAX::Source::Troff::Request - The great new TenorSAX::Source::Troff!

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

    perldoc TenorSAX::Source::Troff::Request

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
