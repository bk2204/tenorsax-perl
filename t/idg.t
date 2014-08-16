#!/usr/bin/perl

use v5.14;
use warnings;
use strict;
use open qw/:encoding(UTF-8) :std/;
use utf8;

use Test::More tests => 18 + 1;
use Test::NoWarnings;
use TenorSAX::Util::IDGenerator;
use Digest::SHA		qw/sha256 sha256_hex/;
use Encode;

my $gen = TenorSAX::Util::IDGenerator->new(seed => 'abc');

is($gen->version, 0, "default version is 0");
is($gen->length, 20, "default length is correct");
is($gen->counter, 0, "counter starts at 0");

my %saved_values;
note "Testing _hash_value";
my $hashed = $gen->_hash_value(undef);
is($hashed, sha256("0"), "undef hashes to 0");
$saved_values{$hashed} = undef;
my @input_values = (qw/0 15 Monkeys © undef/, "\N{U+00c2}\N{U+00a9}");
foreach my $text (@input_values) {
	$hashed = $gen->_hash_value($text);
	$saved_values{$hashed} = $text;
	is($hashed, sha256("1$text"), "'$text' hashes as expected");
}
is(scalar @input_values + 1, scalar keys %saved_values,
	"all values are unique");

my $expected_key = "\x8d\x28\x74\xa1\x6f\xe7\x89\x64\xaa\x8e\x44\x47\x90\x28" .
	"\xa8\x89\x28\xb9\x9b\x43\x48\x5e\x72\x09\xc0\xe9\x19\xf3\x1e\xa3\x9c\x65";
is($gen->key, undef, "key starts off undef");
is($gen->id, "tsidPlLW4czAg4Lgjv.jAV1y", "id is as expected");
is($gen->key, $expected_key, "key is now set");
is($gen->counter, 1, "counter is 1");
is($gen->id, "tsidPdfYO1YjuJw75m.8imWO", "second id is as expected");
is($gen->key, $expected_key, "key does not change");
is($gen->counter, 2, "counter is now 2");
