package TenorSAX::Source::Troff::Environment;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;
use TenorSAX::Meta::Attribute::Trait::Serializable;

has 'cc' => (
	is => 'rw',
	isa => 'Str',
	default => '.'
);
has 'c2' => (
	is => 'rw',
	isa => 'Str',
	default => "'"
);
has 'fill' => (
	is => 'rw',
	isa => 'Bool',
	default => 1,
	traits => ['Serializable'],
);
has 'font_size' => (
	is => 'rw',
	isa => 'Num',
	default => 10,
	traits => ['Serializable'],
	serializer => sub {
		my ($self, $obj, $state) = @_;

		my $reader = $self->get_read_method;
		my $number = $obj->$reader;
		$number = $number * 72 / $state->{parser}->_resolution;

		return {
			'font-size' => "${number}pt",
		};
	},
);
has 'adjust' => (
	is => 'rw',
	isa => 'Str',
	traits => ['Serializable'],
	default => 'b',
	serializer => sub {
		my ($self, $obj, $state) = @_;

		my $reader = $self->get_read_method;
		my $value = $obj->$reader;

		return { adjust => 'none' } if $value =~ /^n/;

		my $table = {
			l => 'left',
			r => 'right',
			c => 'center',
			b => 'both',
		};

		return {
			'adjust' => $table->{$value}
		};
	},
);
has 'line_length' => (
	is => 'rw',
	isa => 'Num',
	traits => ['Serializable'],
	serializer => sub {
		my ($self, $obj, $state) = @_;

		my $reader = $self->get_read_method;
		my $number = $obj->$reader;
		$number = $number / $state->{parser}->_resolution;

		return {
			'line-length' => "${number}in",
		};
	},
);
has 'prev_font' => (
	is => 'rw',
	isa => 'Int',
	default => 1,
);
has 'font' => (
	is => 'rw',
	isa => 'Int',
	default => 1,
	traits => ['Serializable'],
	serializer => sub {
		my ($self, $obj, $state) = @_;

		my $reader = $self->get_read_method;
		my $number = $obj->$reader;
		my $keys = $state->{state}->font_number->[$number];
		$keys ||= ['T', 'R'];
		my $group = $state->{state}->fonts->{$keys->[0]};
		my $fontinfo = $group->variants->{$keys->[1]};

		return {
			'font-family' => $group->name,
			'font-weight' => $fontinfo->weight,
			'font-variant' => $fontinfo->variant,
		};
	},
);
has 'font_family' => (
	is => 'rw',
	isa => 'Str',
	default => 'T',
);
has 'vertical_space' => (
	is => 'rw',
	isa => 'Num',
	traits => ['Serializable'],
	serializer => sub {
		my ($self, $obj, $state) = @_;

		my $reader = $self->get_read_method;
		my $number = $obj->$reader;
		$number = $number / $state->{parser}->_resolution;

		# FIXME: change to pts for nroff.
		return {
			'vertical-space' => "${number}in",
		};
	},
);

sub setup {
	my ($self, $state) = @_;
	my $value = $self->font_size;

	$self->font_size($value * $state->{parser}->_resolution / 72);
	$self->line_length(6.5 * $state->{parser}->_resolution);
	$self->vertical_space($state->{parser}->_resolution / 6);
	return;
}

=head1 NAME

TenorSAX::Source::Troff::Environment - The great new TenorSAX::Source::Troff!

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

    perldoc TenorSAX::Source::Troff::Environment

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
