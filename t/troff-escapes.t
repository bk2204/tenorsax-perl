#!perl -T

use strict;
use warnings;
use Test::More tests => 19;
use TenorSAX::Source::Troff;
use TenorSAX::Output::Text;

sub run {
	my $input  = shift;
	my $text   = "";
	my $output = TenorSAX::Output::Text->new(Output => \$text);
	my $parser = TenorSAX::Source::Troff->new(Handler => $output);

	$input .= "\n" if $input !~ /\n\z/ms;

	$parser->parse_string($input);
	$text =~ s/\n\z//;
	return $text;
}

my $aa = <<EOM;
.ds [ compat
.ds ST regular
EOM

my $bb = <<EOM;
$aa
.ec !
EOM

my $cc = <<EOM;
$aa
.eo
EOM

is(run("$bb!*[ST]\n"), 'compatST]',
	"ec - change escape character works (long)");
is(run("$bb!*(ST\n"), 'regular', "ec - change escape character works (compat)");

is(run("$aa\\e*[ST]\n"), '\\*[ST]', "\\e - emits escape character (long)");
is(run("$aa\\e*(ST\n"),  '\\*(ST',  "\\e - emits escape character (compat)");

is(run("$bb!e*[ST]\n"), '!*[ST]', "ec - emits escape character (long)");
is(run("$bb!e*(ST\n"),  '!*(ST',  "ec - emits escape character (compat)");

is(run("$cc\\*[ST]\n"), '\\*[ST]', "eo - escapes off (long)");
is(run("$cc\\*(ST\n"),  '\\*(ST',  "eo - escapes off (compat)");

is(run("$cc.ec\n\\*[ST]\n"), 'compatST]', "ec - restore escapes (long)");
is(run("$cc.ec\n\\*(ST\n"),  'regular',   "ec - restore escapes (compat)");

is(run("\\U'200b'\n"),  "\x{200b}",  "\\U - prints ZWSP");
is(run("\\U'1F4A9'\n"), "\x{1f4a9}", "\\U - prints PILE OF POO");

is(run("ABC\\\nDEF\n"),  "ABCDEF",  "\\\\n - swallows newline");
is(run("ABC \\\nDEF\n"), "ABC DEF", "\\\\n - swallows newline but not space");

is(run("ABC\\\"other\nDEF\n"),
	"ABC\nDEF", "\\\" - comment without swallowing newline");
is(run("ABC\\#other\nDEF\n"), "ABCDEF", "\\# - comment swallowing newline");

is(run("\\fI\\n(.f\\fP \\n(.f\n"), "2 1", "\\f - \\n(.f reflects changes");
is(run("\\fI\\n(.f\\fP \\fB\\n(.f\\fP \\n(.f\n"),
	"2 3 1", "\\f - \\n(.f reflects changes");
is(run("\\fI\n\\n(.f\\fP\n\\n(.f\n"), "\n2\n1",
	"\\f - \\n(.f reflects changes");
