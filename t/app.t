#!/usr/bin/perl

use v5.14;
use warnings;
use strict;
use open qw/:encoding(UTF-8) :std/;
use utf8;

use Test::More;
use Test::FailWarnings;
use TenorSAX::App;

my $default      = 72000;
my $text_default = 240;
my $random       = 42;

test_resolution($default);
test_resolution($default,      OutputDevice => "pdf");
test_resolution($random,       OutputDevice => "pdf", Resolution => $random);
test_resolution($text_default, OutputDevice => "utf8");
test_resolution($random,       OutputDevice => "utf8", Resolution => $random);

sub test_resolution {
	my ($val, %params) = @_;

	my $app = TenorSAX::App->new(%params);
	isa_ok($app, "TenorSAX::App");
	is($app->resolution, $val, "resolution is as expected ($val)");
	return;
}

done_testing;
