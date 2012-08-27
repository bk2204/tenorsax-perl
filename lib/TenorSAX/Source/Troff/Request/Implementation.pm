package TenorSAX::Source::Troff::Request::Implementation;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;

use File::Spec;
use File::Path::Expand ();
use Moose;
use TenorSAX::Source::Troff::Macro;
use TenorSAX::Source::Troff::Number;
use TenorSAX::Source::Troff::Request;
use TenorSAX::Source::Troff::String;

sub _do_break {
	my ($state) = @_;
	my $p = $state->{parser};

	if ($state->{opts}->{can_break}) {
		$p->_ch->end_element($p->_lookup_element('_t:block'))
			if $p->_ch->in_element({Name => '_t:block'});
		$p->_ch->start_element($p->_lookup_element('_t:block',
			$p->_state_to_hash));
	}
}

sub _load_file {
	my ($filename, $parser) = @_;

	local $/;
	open(my $fh, '<', $filename) or die "Can't source '$filename': $!";
	my $data = <$fh>;
	close($fh);

	chomp $data;

	$data = join("\n", ".do tenorsax filename \"$filename\"", $data,
		".do tenorsax filename \"" . $parser->_filename .
		"\"\n");
	unshift @{$parser->_data}, split /\R/, $data;
}

sub _do_offset {
	my ($cur, $value) = @_;

	if ($value =~ s/^([+-])//) {
		$value ||= 0;

		if ($1 eq "+") {
			$value = $cur + $value;
		}
		else {
			$value = $cur - $value;
		}
	}
	return $value;
}

my $requests = [
	{
		name => 'ad',
		arg_types => [''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $value = $args->[0];
			my $current = $state->{environment}->adjust;
			my $table = {
				l => 'l',
				r => 'r',
				c => 'c',
				b => 'b',
				n => 'b',
			};
			$current =~ s/^n//;

			if ($value) {
				$value = $table->{$value} || $current;
			}
			else {
				$value = $current;
			}

			$state->{environment}->adjust($value);
			return;
		}
	},
	{
		name => 'als',
		arg_types => ['', ''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $new = $args->[0] or return;
			my $old = $args->[1] or return;
			my $requests = $state->{parser}->_requests;

			$requests->{$new} = $requests->{$old};
			return;
		}
	},
	{
		name => 'br',
		arg_types => [],
		code => sub {
			my ($self, $state, $args) = @_;

			_do_break($state);
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
		name => 'do',
		max_args => 99999,
		arg_types => [],
		disable_compat => 1,
		substitute => sub {
			my ($self, $state, $args) = @_;

			if (scalar @$args == 1) {
				my $p = $state->{parser};
				my $request = $p->_lookup_request($args->[0]);
				$request->max_args($request->max_args+1);
				shift @$args;
				unshift @{$request->arg_type},
					"TenorSAX::Source::Troff::Argument";
				return $request;
			}
		},
		code => sub {
			...
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
		name => 'ec',
		arg_types => [''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $char = $args->[0] || "\\";
			$state->{parser}->_ec($char);

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
		name => 'end',
		arg_types => [''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $tag = $args->[0] or return;
			my $parser = $state->{parser};

			$parser->_ch->end_element($parser->_lookup_element($tag));

			return;
		}
	},
	{
		name => 'eo',
		arg_types => [],
		code => sub {
			my ($self, $state, $args) = @_;
			$state->{parser}->_ec(undef);

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
		name => 'fi',
		arg_types => [],
		code => sub {
			my ($self, $state, $args) = @_;

			$state->{parser}->_env->fill(1);
			_do_break($state);
			return;
		}
	},
	{
		name => 'ft',
		arg_types => [''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $font = $args->[0] || 'P';
			my $env = $state->{environment};
			my $prev = $env->prev_font;
			my $family = $env->font_family;
			my $p = $state->{parser};
			my $fonts = $state->{state}->fonts;

			if ($font eq "P") {
				$env->prev_font($env->font);
				$env->font($prev);
			}
			elsif ($font =~ /^[0-9]+$/) {
				$env->prev_font($env->font);
				$env->font(int($font));
			}
			elsif (exists $fonts->{$family}) {
				my $ffamily = $fonts->{$family};
				my $choice;
				my $s = $state->{state};
				if (exists $ffamily->variants->{$font}) {
					# Look up the font number for this font.
					foreach my $idx (keys $s->font_number) {
						next unless ref $s->font_number->[$idx] eq 'ARRAY';
						my @curpair = @{$s->font_number->[$idx]};

						if ($curpair[0] eq $family && $curpair[1] eq $font) {
							$choice = $idx;
							last;
						}
					}
				}
				else {
					foreach my $idx (keys $s->font_number) {
						if (ref $s->font_number->[$idx] eq 'ARRAY' &&
							join('', @{$s->font_number->[$idx]}) eq $font) {

							$choice = $idx;
							last;
						}
					}

				}
				$env->prev_font($env->font);
				$env->font($choice) if defined $choice;
			}
			$p->_ch->characters({Data => "\n"}) if $state->{opts}->{as_request};
			$p->_ch->end_element($p->_lookup_element('_t:inline'))
				if $p->_ch->in_element({Name => '_t:inline'});
			$p->_ch->start_element($p->_lookup_element('_t:inline', $p->_state_to_hash));

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
			my $rest = $args->[1] || '';
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
		name => 'll',
		arg_types => ['OffsetNumeric'],
		default_unit => 'm',
		code => sub {
			my ($self, $state, $args) = @_;
			my $value = $args->[0] or return;
			my $cur = $state->{environment}->line_length;

			$state->{environment}->line_length(_do_offset($cur, $value));
			return;
		}
	},
	{
		name => 'mso',
		arg_types => [''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $name = $args->[0] or return;

			foreach my $dir (@{$state->{parser}->_macrodirs}) {
				$dir = File::Path::Expand::expand_filename($dir);
				for my $suffix ("", ".tmac") {
					eval {
						my $filename = File::Spec->catfile($dir,
							"$name$suffix");
						_load_file($filename, $state->{parser});
					};
					return unless $@;
				}
			}

			die "Can't find macro package '$name': $!";
			return;
		}
	},
	{
		name => 'na',
		arg_types => [''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $current = $state->{environment}->adjust;
			$current =~ s/^n?/n/;

			$state->{environment}->adjust($current);
			return;
		}
	},
	{
		name => 'namespace',
		arg_types => ['', ''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $prefix = $args->[0] or return;
			my $uri = $args->[1] or return;

			$state->{parser}->_ch->prefixes->{$prefix} = $uri;

			return;
		}
	},
	{
		name => 'nf',
		arg_types => [],
		code => sub {
			my ($self, $state, $args) = @_;

			$state->{parser}->_env->fill(0);
			_do_break($state);
			return;
		}
	},
	{
		name => 'nop',
		arg_types => ['Final'],
		code => sub {
			my ($self, $state, $args) = @_;
			my $text = $args->[0] // '';

			unshift @{$state->{parser}->_data}, split /\R/, $text;
			return;
		}
	},
	{
		name => 'nr',
		arg_types => ['', 'OffsetNumeric', 'Numeric'],
		code => sub {
			my ($self, $state, $args) = @_;
			my $name = $args->[0] or return;
			my $value = $args->[1] || 0;
			my $increment = $args->[2] || 0;
			my $existing = $state->{parser}->_numbers->{$name};

			return if defined $existing && $existing->immutable;

			if ($value =~ s/^([+-])//) {
				$value = int($value || 0);

				my $cur = 0;
				if (exists $state->{parser}->_numbers->{$name}) {
					$cur = $state->{parser}->_numbers->{$name}->value;
				}
				if ($1 eq "+") {
					$value = $cur + $value;
				}
				else {
					$value = $cur - $value;
				}
			}

			eval {
				$state->{parser}->_numbers->{$name} =
					TenorSAX::Source::Troff::Number->new(value => int($value),
						inc_value => int($increment));
			};
			return if $@;
			return;
		}
	},
	{
		name => 'papersize',
		arg_types => [''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $value = $args->[0] or return;

			$state->{state}->paper_size($value);
			return;
		}
	},
	{
		name => 'pl',
		arg_types => ['OffsetNumeric'],
		default_unit => 'v',
		code => sub {
			my ($self, $state, $args) = @_;
			my $value = $args->[0] or return;
			my $cur = $state->{state}->page_length;

			$state->{state}->page_length(_do_offset($cur, $value));
			return;
		}
	},
	{
		name => 'po',
		arg_types => ['OffsetNumeric'],
		default_unit => 'v',
		code => sub {
			my ($self, $state, $args) = @_;
			my $value = $args->[0] or return;
			my $cur = $state->{state}->page_offset;

			$state->{state}->page_offset(_do_offset($cur, $value));
			return;
		}
	},
	{
		name => 'ps',
		arg_types => ['OffsetNumeric'],
		default_unit => 'p',
		code => sub {
			my ($self, $state, $args) = @_;
			my $value = $args->[0] or return;
			my $cur = $state->{environment}->font_size;

			$state->{environment}->font_size(_do_offset($cur, $value));
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
	{
		name => 'rn',
		arg_types => ['', ''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $old = $args->[0] or return;
			my $new = $args->[1] or return;
			my $requests = $state->{parser}->_requests;

			$requests->{$new} = $requests->{$old};
			delete $requests->{$old};
			return;
		}
	},
	{
		name => 'so',
		arg_types => [''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $filename = $args->[0] or return;

			if ($filename !~ m{^/}) {
				my @pieces = File::Spec->splitpath($state->{parser}->_filename);
				$filename = File::Spec->catpath(@pieces[0, 1], $filename);
			}

			_load_file($filename, $state->{parser});
			return;
		}
	},
	{
		name => 'sp',
		arg_types => ['Numeric'],
		code => sub {
			my ($self, $state, $args) = @_;
			my $value = $args->[0] || 0;
			my $p = $state->{parser};

			_do_break($state);
			my $curfill = $state->{parser}->_env->fill;
			$state->{parser}->_env->fill(0);
			$p->_ch->start_element($p->_lookup_element('_t:block',
				$p->_state_to_hash));
			$p->_ch->characters({Data => ("\n" x $value)});
			$p->_ch->end_element($p->_lookup_element('_t:block'));
			$state->{parser}->_env->fill($curfill);
			return;
		}
	},
	{
		name => 'start',
		max_args => 99999,
		arg_types => ['', ''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $tag = shift @$args or return;
			my $parser = $state->{parser};
			my $attrs = {};

			foreach my $arg (@$args) {
				my ($name, $value) = split /=/, $arg, 2;

				$attrs->{$name} = $value;
			}
			$parser->_ch->start_element($parser->_lookup_element($tag, $attrs));

			return;
		}
	},
	{
		name => 'tenorsax',
		arg_types => ['', ''],
		code => sub {
			my ($self, $state, $args) = @_;
			my $cmd = $args->[0] or return;
			my $arg = $args->[1] or return;

			given ($cmd) {
				when (/^ext$/) {
					$state->{parser}->_compat($arg ? 0 : 1);
				}
				when (/^macrodir$/) {
					push $state->{parser}->_macrodirs, $arg;
				}
				when (/^get-implementation$/) {
					$state->{parser}->_numbers->{$arg} =
						TenorSAX::Source::Troff::Number->new(value =>
							0x01626d63);
				}
				when (/^get-ext$/) {
					$state->{parser}->_numbers->{$arg} =
						TenorSAX::Source::Troff::Number->new(value =>
							$state->{parser}->_compat ? 0 : 1);
				}
				when (/^ignore-element$/) {
					$state->{parser}->_ch->ignore_element($arg);
				}
			}

			return;
		}
	},
	{
		name => 'vs',
		arg_types => ['Numeric'],
		default_unit => 'p',
		code => sub {
			my ($self, $state, $args) = @_;
			my $value = $args->[0] or return;

			$state->{environment}->vertical_space($value);
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
		max_args => $data->{max_args} // scalar @{$data->{arg_types}},
		arg_type => [@arg_types],
		disable_compat => $data->{disable_compat} || 0,
		code => $data->{code},
		substitute => $data->{substitute},
		default_unit => $data->{default_unit} // 'u',
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

no Moose;
__PACKAGE__->meta->make_immutable;

1;
