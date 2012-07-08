package TenorSAX::Source::Troff::Request::Implementation;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;

use Moose;
use TenorSAX::Source::Troff::Macro;
use TenorSAX::Source::Troff::Number;
use TenorSAX::Source::Troff::Request;
use TenorSAX::Source::Troff::String;

my $requests = [
	{
		name => 'br',
		arg_types => [],
		code => sub {
			my ($self, $state, $args) = @_;
			my $p = $state->{parser};

			if ($state->{opts}->{can_break}) {
				$p->_ch->end_element($p->_lookup_element('_t:block'));
				$p->_ch->start_element($p->_lookup_element('_t:block',
					$p->_state_to_hash));
			}

			return;
		}
	},
	{
		name => 'cp',
		arg_types => ['Numeric'],
		code => sub {
			my ($self, $state, $args) = @_;
			my $value = $args->[0];

			return unless defined $value;

			$state->{parser}->_compat($value);
			return;
		}
	},
	{
		name => 'de',
		arg_types => ['', ''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $cc = $state->{environment}->cc;
			my $name = $args->[0] or return;
			my $end = $args->[1] // $cc;
			my $text = $state->{parser}->_copy_until(qr/^\Q$cc$end\E/);

			$state->{parser}->_requests->{$name} =
				TenorSAX::Source::Troff::Macro->new(text => $text);
			return;
		}
	},
	{
		name => 'ds',
		arg_types => ['', 'FinalString'],
		code => sub {
			my ($self, $state, $args) = @_;
			my $name = $args->[0] or return;
			my $text = $args->[1] // '';

			$state->{parser}->_requests->{$name} =
				TenorSAX::Source::Troff::String->new(text => $text);
			return;
		}
	},
	{
		name => 'el',
		arg_types => ['FinalString'],
		code => sub {
			my ($self, $state, $args) = @_;
			my $cond = !$state->{parser}->_condition;
			my $rest = $args->[0];
			my $input = "";

			if ($rest =~ m/\\\{(\X*)/) {
				$input = "$1\n" . $state->{parser}->_copy_conditional();
			}
			else {
				$input = $rest;
			}
			unshift @{$state->{parser}->_data}, split /\R/, $input if $cond;
			# Don't allow stray .el requests.
			$state->{parser}->_condition(1);

			return;
		}
	},
	{
		name => 'ex',
		arg_types => [],
		code => sub {
			my ($self, $state, $args) = @_;

			# From the manual:
			# Text processing is terminated exactly as if all input had ended.
			$state->{parser}->_data([]);
			return;
		}
	},
	{
		name => 'ie',
		arg_types => ['Conditional', 'FinalString'],
		code => sub {
			my ($self, $state, $args) = @_;
			my $cond = $args->[0];
			my $rest = $args->[1];
			my $input = "";

			if ($rest =~ m/\\\{(\X*)/) {
				$input = "$1\n" . $state->{parser}->_copy_conditional();
			}
			else {
				$input = $rest;
			}
			unshift @{$state->{parser}->_data}, split /\R/, $input if $cond;
			$state->{parser}->_condition($cond);

			return;
		}
	},
	{
		name => 'if',
		arg_types => ['Conditional', 'FinalString'],
		code => sub {
			my ($self, $state, $args) = @_;
			my $cond = $args->[0];
			my $rest = $args->[1];
			my $input = "";

			if ($rest =~ m/\\\{(\X*)/) {
				$input = "$1\n" . $state->{parser}->_copy_conditional();
			}
			else {
				$input = $rest;
			}
			unshift @{$state->{parser}->_data}, split /\R/, $input if $cond;

			# Don't allow stray .el requests.
			$state->{parser}->_condition(1);

			return;
		}
	},
	{
		name => 'ig',
		arg_types => [''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $cc = $state->{environment}->cc;
			my $end = $args->[0] // $cc;

			$state->{parser}->_copy_until(qr/^\Q$cc$end\E/);
			return;
		}
	},
	{
		name => 'nr',
		arg_types => ['', 'Numeric'],
		code => sub {
			my ($self, $state, $args) = @_;
			my $name = $args->[0] or return;
			my $value = $args->[1] // '';
			my $existing = $state->{parser}->_numbers->{$name};

			return if defined $existing && $existing->immutable;

			eval {
				$state->{parser}->_numbers->{$name} =
					TenorSAX::Source::Troff::Number->new(value => $value);
			};
			return if $@;
			return;
		}
	},
	{
		name => 'rm',
		arg_types => [''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $name = $args->[0] or return;

			delete $state->{parser}->_requests->{$name};
			return;
		}
	},
];

sub make_request {
	my ($class, $data) = @_;
	my @arg_types = map {
		"TenorSAX::Source::Troff::${_}Argument"
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
