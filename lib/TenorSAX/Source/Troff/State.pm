package TenorSAX::Source::Troff::State;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;
use TenorSAX::Meta::Attribute::Trait::Serializable;
use TenorSAX::Util::Font;
use TenorSAX::Util::Font::Family;

has 'font_number' => (
	is => 'rw',
	isa => 'ArrayRef',
	default => sub {
		[undef, ['T', 'R'], ['T', 'I'], ['T', 'B'], ['T', 'BI']]
	},
);
has 'page_length' => (
	is => 'rw',
	isa => 'Num',
	traits => ['Serializable'],
	serializer => sub {
		my ($self, $obj, $state) = @_;

		my $reader = $self->get_read_method;
		my $number = $obj->$reader;
		$number = $number / $state->{parser}->_resolution;

		return {
			'page-length' => "${number}in",
		};
	},
);
has 'paper_size' => (
	is => 'rw',
	isa => 'Str',
	default => 'letter',
	traits => ['Serializable'],
);
has 'fonts' => (
	is => 'rw',
	isa => 'HashRef[TenorSAX::Util::Font::Family]',
	default => sub {
		{
			'T' => TenorSAX::Util::Font::Family->new(name => 'Times',
				variants => {
					'R' => TenorSAX::Util::Font->new(name => 'Times',
						weight => 'normal',
						variant => 'normal',
						type => 'postscript-builtin'),
					'B' => TenorSAX::Util::Font->new(name => 'Times-Bold',
						weight => 'bold',
						variant => 'normal',
						type => 'postscript-builtin'),
					'I' => TenorSAX::Util::Font->new(name => 'Times-Italic',
						weight => 'normal',
						variant => 'italic',
						type => 'postscript-builtin'),
					'BI' => TenorSAX::Util::Font->new(name => 'Times-BoldItalic',
						weight => 'bold',
						variant => 'italic',
						type => 'postscript-builtin'),
				},
			),
		}
	},
);

sub setup {
	my ($self, $state) = @_;

	$self->page_length(11 * $state->{parser}->_resolution);
}

=head1 NAME

TenorSAX::Source::Troff::State - The great new TenorSAX::Source::Troff!

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

    perldoc TenorSAX::Source::Troff::State

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
