package TenorSAX::Output::Text;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;

has '_output' => (
	is => 'rw',
	default => sub { \*STDOUT },
	init_arg => 'Output',
);

=head1 NAME

TenorSAX::Output::Text - The great new TenorSAX::Source::Troff!

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

sub start_document {
	my ($self, @args) = @_;

	$self->_setup_output;
}

sub end_document {
	my ($self, @args) = @_;

	if ($self->_output->can('finalize')) {
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
}

sub end_prefix_mapping {
	my ($self, @args) = @_;
}

sub characters {
	my ($self, $ref) = @_;

	$self->_do_output($ref->{Data} // '');
}

sub ignorable_whitespace {
	my ($self, @args) = @_;
}

sub processing_instruction {
	my ($self, @args) = @_;
}

sub _setup_output {
	my ($self) = @_;

	if (ref $self->_output eq '') {
		my $filename = $self->_output;
		open(my $fh, '>', $filename) or
			die "Can't open $filename for writing: $!";
		$self->_output = $fh;
	}
}

sub _do_output {
	my ($self, $text) = @_;

	if (ref $self->_output eq 'ARRAY') {
		push $self->_output, $text;
	}
	elsif (ref $self->_output eq 'SCALAR') {
		${$self->_output} .= $text;
	}
	elsif ($self->_output->can('output')) {
		$self->_output->output($text);
	}
	else {
		$self->_output->print($text);
	}
}

=head1 AUTHOR

brian m. carlson, C<< <sandals at crustytoothpaste.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tenorsax at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TenorSAX>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TenorSAX::Output::Text

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 brian m. carlson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
