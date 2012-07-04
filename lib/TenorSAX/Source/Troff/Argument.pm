package TenorSAX::Source::Troff::Argument;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;
use re '/u';

use Moose;

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

package TenorSAX::Source::Troff::NumericArgument;

use Moose;

extends 'TenorSAX::Source::Troff::Argument';

sub parse {
	my ($class, undef, $lineref) = @_;

	# The quoted form is not interpreted as a number.
	if ($$lineref =~ s/^("(([^"]*|"")*)")([ \t]+|$)//u) {
		return $1;
	}
	elsif ($$lineref =~ s/^\(//u) {
		my $level = 1;
		my $arg = "(";

		while ($level) {
			$$lineref =~ s/^(\X)//;
			my $char = $1;

			if ($char eq "(") {
				$level++;
			}
			elsif ($char eq ")") {
				$level--;
			}
			$arg .= $char;
		}
		$$lineref =~ s/^([ \t]+|$)//;
		return $arg;
	}
	$$lineref =~ s/^(\X*?)([ \t]+|$)//u;
	return $1;
}

# All the escapes have already been expanded by now.
sub evaluate {
	my ($class, undef, $state, $arg) = @_;

	$arg =~ s/[ \t]+//g;

	return $class->_evaluate(undef, $state, \$arg);
}

sub _evaluate {
	my ($class, undef, $state, $ref) = @_;

	my $level = 1;
	my @vals;
	my @ops;

	while ($level) {
		if ($$ref =~ s/^([0-9]+(\.[0-9]+)?)//) {
			push @vals, $1 + 0;
		}
		else {
			last unless $$ref =~ s/^(\X)//;

			given ($1) {
				when ($_ eq "(") {
					$level++;
					push @vals, $class->_evaluate(undef, $state, $ref);
				}
				when ($_ eq ")") {
					last;
				}
				when (/^([-+*\/%])/) {
					my $op = $1;
					push @ops, $1;
				}
				when (/^([<>=])/) {
					my $op = $1;
					if ($op eq "<" && $$ref =~ s/^>//) {
						$op = "!=";
					}
					elsif ($$ref =~ s/^([=?])//) {
						$op .= $1;
					}
					if ($op eq "=") {
						$op = "==";
					}
					push @ops, $op;
				}
				when (/^&/) {
					push @ops, '&&';
				}
				when (/^:/) {
					push @ops, '||';
				}
			}
		}
	}
	my $value = shift @vals;
	while (@vals) {
		my $second = shift @vals;
		my $op = shift @ops;
		if ($op eq "<?") {
			$value = $second if $second < $value;
		}
		elsif ($op eq ">?") {
			$value = $second if $second > $value;
		}
		elsif ($op =~ m/(&&|\|\|)/) {
			$value = eval "!!\$value $op !!\$second";
		}
		else {
			$value = eval "\$value $op \$second";
		}
	}

	return $value;
}

package TenorSAX::Source::Troff::ConditionalArgument;

use Moose;

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

	if ($$lineref =~ s/^([cdr]\X*?)([ \t]+|$)//) {
		return "$arg$1";
	}

	if ($$lineref =~ s/^f//) {
		$arg .= "f";
	}

	if ($$lineref =~ m/^[^0-9]/ &&
		$$lineref =~ s/^((\X)(\X*?)\1(\X*?)\1)([ \t]+|$)//) {
		return "$arg$1";
	}

	return $arg . TenorSAX::Source::Troff::NumericArgument->parse($class, undef,
		$lineref);
}

sub evaluate {
	my ($class, undef, $state, $arg) = @_;
	my $negated = 0;

	if ($arg =~ s/^!//) {
		$negated = 1;
	}

	return (($class->_evaluate(undef, $state, $arg) > 0) xor $negated) ? 1 : 0;
}

sub _evaluate {
	my ($class, undef, $state, $arg) = @_;

	if ($arg =~ s/^[oe]//) {
		return 0;
	}

	# FIXME: add support for troff vs. nroff when we add support for units.
	if ($arg =~ s/^([tn])//) {
		return $1 eq 't';
	}

	if ($arg =~ s/^([cdr])(\X*)//) {
		my $name = $2;
		given ($1) {
			# FIXME: ask the layout engine to look this up for us.
			when (/c/) {
				return 1;
			}
			when (/d/) {
				return exists $state->{parser}->_requests->{$name};
			}
			when (/r/) {
				return exists $state->{parser}->_numbers->{$name};
			}
		}
	}

	$arg =~ s/^f//;

	return TenorSAX::Source::Troff::NumericArgument->evaluate($class, undef,
		$arg);
}


1;
