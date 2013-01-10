package TenorSAX::Source::Troff::Util;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

sub command_string {
	my ($type, $name, @args) = @_;
	my $result = "\x{102200}$type$name";
	$result .= "\x{102201}" . join("\x{102201}", @args);
	return "$result\x{102202}";
}

1;
