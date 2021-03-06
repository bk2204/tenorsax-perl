package TenorSAX::Source::Troff::Argument;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;
use re '/u';

use Moose;
use experimental qw/smartmatch/;

sub parse {
	my ($class, undef, $lineref) = @_;
	my $arg;

	if ($$lineref =~ s/^"(([^"]*|"")*)"([ \t]+|$)//u) {
		$arg = $1;
		$arg =~ s/""/"/g;
		return $arg;
	}
	$$lineref =~ s/^(\X*?)([ \t]+|$)//u;
	return $1;
}

sub evaluate {
	my ($class, undef, $state, $arg) = @_;

	return $arg;
}

sub expand_ok {
	return 1;
}

no Moose;
__PACKAGE__->meta->make_immutable;

package TenorSAX::Source::Troff::FinalArgument;

use Moose;

extends 'TenorSAX::Source::Troff::Argument';

sub parse {
	my ($class, undef, $lineref) = @_;
	my $arg;

	$$lineref =~ s/^(.*)$//;
	return $1;
}

no Moose;
__PACKAGE__->meta->make_immutable;

package TenorSAX::Source::Troff::UnparsedArgument;

use Moose;

extends 'TenorSAX::Source::Troff::FinalArgument';

sub expand_ok {
	return 0;
}

no Moose;
__PACKAGE__->meta->make_immutable;

package TenorSAX::Source::Troff::FinalStringArgument;

use Moose;

extends 'TenorSAX::Source::Troff::Argument';

sub parse {
	my ($class, undef, $lineref) = @_;
	my $arg;

	if ($$lineref =~ s/^"(.*)$//u) {
		$arg = $1;
		$arg =~ s/""/"/g;
		return $arg;
	}
	$$lineref =~ s/^(\X*?)$//u;
	return $1;
}

no Moose;
__PACKAGE__->meta->make_immutable;

package TenorSAX::Source::Troff::NumericArgument;

use Moose;
use experimental qw/smartmatch autoderef/;

extends 'TenorSAX::Source::Troff::Argument';

my $dispatch = {
	'+' => sub { $_[0] + $_[1] },
	'-' => sub { $_[0] - $_[1] },
	'*' => sub { $_[0] * $_[1] },
	'/' => sub { $_[0] / $_[1] },
	'%' => sub { $_[0] % $_[1] },
	'<' => sub { $_[0] < $_[1] },
	'>' => sub { $_[0] > $_[1] },
	'<=' => sub { $_[0] <= $_[1] },
	'>=' => sub { $_[0] >= $_[1] },
	'=' => sub { $_[0] == $_[1] },
	'==' => sub { $_[0] == $_[1] },
	'!=' => sub { $_[0] != $_[1] },
	'<>' => sub { $_[0] != $_[1] },
	'&' => sub { ($_[0] && $_[1]) ? 1 : 0 },
	':' => sub { ($_[0] || $_[1]) ? 1 : 0 },
	'>?' => sub { ($_[0] > $_[1]) ? $_[0] : $_[1] },
	'<?' => sub { ($_[0] < $_[1]) ? $_[0] : $_[1] },
};

sub _parse_unparenthesized {
	my ($class, $arg, $lineref) = @_;

	my $level = 0;

	while (!$level && $$lineref =~ s/^(\X)//u) {
		my $char = $1;

		if ($char eq "(") {
			$arg .= $char;
			$level++;
		}
		elsif ($char =~ m/[ \t]/) {
			$$lineref =~ s/^([ \t]+|$)//;
			last;
		}
		else {
			$arg .= $char;
		}
	}
	return ($level, $arg);
}

sub parse {
	my ($class, undef, $lineref) = @_;

	# The quoted form is not interpreted as a number.
	if ($$lineref =~ s/^("(([^"]*|"")*)")([ \t]+|$)//u) {
		return $1;
	}
	elsif ($$lineref =~ m/\(/) {
		my $level = 0;
		my $arg = "";

		for (;;) {
			if (!$level) {
				($level, $arg) = $class->_parse_unparenthesized($arg, $lineref);
				last unless $level;
			}
			else {
				last unless $$lineref =~ s/^(\X)//;
				my $char = $1;

				if ($char eq "(") {
					$level++;
				}
				elsif ($char eq ")") {
					$level--;
				}
				$arg .= $char;
			}
		}

		$$lineref =~ s/^([ \t]+|$)//;
		return $arg;
	}
	$$lineref =~ s/^(\X*?)([ \t]+|$)//u;
	return $1;
}

# All the escapes have already been expanded by now.
sub evaluate {
	my ($class, $request, $state, $arg) = @_;

	$arg =~ s/[ \t]+//g;

	return $class->_evaluate($request, $state, \$arg);
}

sub _compute_unit {
	my ($class, $res, $value, $unit, $ptsize) = @_;

	for ($unit) {
		return $value when /^[us]$/;
		return $value * $res when 'i';
		return $value * $res * 50 / 127 when 'c';
		return $value * $res / 6 when 'P';
		return $value * $res / 72 when /^[pz]/;
		return $value * $res * 100 / 7227 when 't';
		return $value * $res * 400 / 2409 when 'T';
		return $value * $res * 24 / 1621 when 'D';
		return $value * $res * 288 / 1621 when 'C';
		return $value * $ptsize when 'm';
		return $value * $ptsize / 2 when 'n';
		return $value * $ptsize / 100 when 'M';
		default { return $value; }
		# TODO: implement v.
	}
}

sub _map_units {
	my ($class, $request, $state, $value, $unit) = @_;
	my $parser = $state->{parser};
	my $res = $parser->_resolution;
	my $ptsize = $state->{environment}->font_size;

	$unit ||= $request->default_unit || 'u';

	return $class->_compute_unit($res, $value, $unit, $ptsize);
}

sub _evaluate {
	my ($class, $request, $state, $ref) = @_;

	my $level = 1;
	my @vals;
	my @ops;

	for (;;) {
		if ($$ref =~ s/^([0-9]+(?:\.[0-9]+)?)([icPmnMpzustTDCv]?)//) {
			push @vals, $class->_map_units($request, $state, $1 + 0, $2);
		}
		else {
			last unless $$ref =~ s/^(\X)//;

			for ($1) {
				when ($_ eq "(") {
					$level++;
					push @vals, $class->_evaluate($request, $state, $ref);
				}
				when ($_ eq ")") {
					$level--;
				}
				when (/^([-+*\/%&:])/) {
					my $op = $1;
					push @ops, $1;
				}
				when (/^([<>=])/) {
					my $op = $1;
					if ($op eq "<" && $$ref =~ s/^>//) {
						$op = "<>";
					}
					elsif ($$ref =~ s/^([=?])//) {
						$op .= $1;
					}
					if ($op eq "=") {
						$op = "==";
					}
					push @ops, $op;
				}
			}
		}
	}
	my $value = shift @vals;
	while (@vals) {
		my $second = shift @vals;
		my $op = shift @ops;

		last unless defined $op;

		$value = $dispatch->{$op}->($value, $second);
	}

	return $value || 0;
}

no Moose;
__PACKAGE__->meta->make_immutable;

package TenorSAX::Source::Troff::OffsetNumericArgument;

use Moose;

extends 'TenorSAX::Source::Troff::NumericArgument';

sub parse {
	my ($class, undef, $lineref) = @_;

	if ($$lineref =~ s/^([+-])//) {
		return $1 . $class->SUPER::parse(undef, $lineref);
	}
	return $class->SUPER::parse(undef, $lineref);
}

sub evaluate {
	my ($class, $request, $state, $arg) = @_;

	my $offset = "";

	$arg =~ s/[ \t]+//g;
	$offset = $1 if ($arg =~ s/^([+-])//);

	return $offset . $class->_evaluate($request, $state, \$arg);
}

no Moose;
__PACKAGE__->meta->make_immutable;

package TenorSAX::Source::Troff::ConditionalArgument;

use Moose;
use experimental qw/smartmatch autoderef/;

extends 'TenorSAX::Source::Troff::Argument';

sub parse {
	my ($class, undef, $lineref) = @_;
	my $arg = "";

	if ($$lineref =~ s/^!//) {
		$arg = "!";
	}

	if ($$lineref =~ s/^([oetn])([ \t]+|$)//) {
		return "$arg$1";
	}

	if ($$lineref =~ s/^([cdr][ \t]*\X*?)([ \t]+|$)//) {
		return "$arg$1";
	}

	if ($$lineref =~ s/^f//) {
		$arg .= "f";
	}

	if ($$lineref =~ m/^[^0-9(]/ &&
		$$lineref =~ s/^((\X)(\X*?)\2(\X*?)\2)([ \t]+|$)//) {
		return "$arg$1";
	}

	return $arg . TenorSAX::Source::Troff::NumericArgument->parse(undef,
		$lineref);
}

sub evaluate {
	my ($class, $request, $state, $arg) = @_;
	my $negated = 0;

	if ($arg =~ s/^!//) {
		$negated = 1;
	}

	return (($class->_evaluate($request, $state, $arg) > 0) xor $negated) ? 1 : 0;
}

sub _evaluate {
	my ($class, $request, $state, $arg) = @_;

	if ($arg =~ s/^[oe]//) {
		return 0;
	}

	# FIXME: add support for troff vs. nroff when we add support for units.
	if ($arg =~ s/^([tn])//) {
		return $1 eq 't' ? 1 : 0;
	}

	if ($arg =~ s/^([cdr])[ \t]*(\X*)//) {
		my $name = $2;
		for ($1) {
			# FIXME: ask the layout engine to look this up for us.
			when (/c/) {
				return 1;
			}
			when (/d/) {
				return exists $state->{parser}->_requests->{$name} ? 1 : 0;
			}
			when (/r/) {
				return exists $state->{parser}->_numbers->{$name} ? 1 : 0;
			}
		}
	}

	if ($arg =~ m/^[^0-9(]/ &&
		$arg =~ m/^((\X)(\X*?)\2(\X*?)\2)[ \t]*$/) {
		return $3 eq $4 ? 1 : 0;
	}

	$arg =~ s/^f//;

	return TenorSAX::Source::Troff::NumericArgument->evaluate($request, $state,
		$arg);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
