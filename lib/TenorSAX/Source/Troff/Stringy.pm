package TenorSAX::Source::Troff::Stringy;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;

with 'MooseX::Clone';

has 'text' => (
	isa => 'Str',
	is => 'rw',
	default => '',
);
has 'max_args' => (
	isa => 'Int',
	is => 'rw',
	default => 99999,
);
has 'code' => (
	isa => 'CodeRef',
	is => 'rw',
	default => sub { sub {} },
);
has 'substitute' => (
	is => 'rw',
	default => undef,
);
has 'arg_type' => (
	isa => 'ArrayRef[Str]',
	is => 'rw',
	default => sub { [] },
);
has 'disable_compat' => (
	isa => 'Bool',
	is => 'rw',
	default => 0,
);
has 'default_unit' => (
	isa => 'Str',
	is => 'ro',
	default => 'u',
);

=head1 NAME

TenorSAX::Source::Troff::Stringy - The great new TenorSAX::Source::Troff!

=head1 VERSION

Version 2.00

=cut

sub modify {
	my ($self, $state, $args) = @_;
	my $method = $self->substitute;

	return unless defined $method;
	$_[0] = $self->$method($state, $args);
}

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

    perldoc TenorSAX::Source::Troff::Stringy

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
