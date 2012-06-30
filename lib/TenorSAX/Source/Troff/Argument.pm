package TenorSAX::Source::Troff::Argument;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

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

1;
