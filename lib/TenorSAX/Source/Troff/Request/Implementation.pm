package TenorSAX::Source::Troff::Request::Implementation;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;

use Moose;
use TenorSAX::Source::Troff::Request;

my $requests = [
	{
		name => 'ds',
		arg_types => ['', ''],
		code => sub {
			my ($self, $state, $args) = @_;
		}
	},
];

sub make_request {
	my ($class, $data) = @_;
	my @arg_types = map {
		"TenorSAX::Source::Troff::{$_}Argument"
	} @{$data->{arg_types}};
	my $req = TenorSAX::Source::Troff::Request->new(
		max_args => scalar @{$data->{arg_types}},
		arg_type => [@arg_types],
		disable_compat => $data->{disable_compat} || 0,
		code => $data->{code},
	);
	return $req;
}

sub requests {
	my $class = shift;

	return {map { $_->{name} => __PACKAGE__->make_request($_) } @$requests};
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

1;
