#!perl -T

use Test::More tests => 12;
use TenorSAX::Source::Troff;
use TenorSAX::Output::Text;

sub run {
	my $input = shift;
	my $text = "";
	my $output = TenorSAX::Output::Text->new(Output => \$text);
	my $parser = TenorSAX::Source::Troff->new(Handler => $output);

	$input .= "\n" if $input !~ /\n\z/ms;

	$parser->parse_string($input);
	$text =~ s/\n\z//;
	return $text;
}

my $aa = <<EOM;
.de AA
Before.
.BB
After
..
EOM

my $bb = <<EOM;
.de BB
BB.
..
EOM

my $cc = <<EOM;
.de CC
.rm AA
..
EOM

is(run("$bb.BB\n"), "BB.", "de - can define and call a macro");
like(run("$aa$bb.AA\n"), qr/Before.\s+BB.\s+After/ms,
		"de - can call a macro from within a macro");
like(run("$aa.ds BB BB. \n.AA\n"), qr/Before.\s+BB.\s+After/ms,
		"de - can call a string from within a macro");
like(run(".ds BB CC\n$aa.ds BB BB. \n.AA\n"), qr/Before.\s+BB.\s+After/ms,
		"de - calls are delayed until macro runtime");

is(run("$bb.rm BB\n.BB\n"), '', "rm - can remove a macro");
like(run("$aa$bb.rm BB\n.AA\n"), qr/Before.\s+After/ms,
		"rm - removed macro does not persist in other macros");
is(run("$aa$bb.rm BB\n.AA\n"), run("$aa.AA"),
		"rm - removed macro treated like nonexistent macro");
is(run("$aa$bb$cc.CC\n.AA\n"), '', "rm - removal inside macro works");

is(run(".ig\nLine\nMore lines\n.."), '', "ig - produces no data");
is(run("$aa$bb.ig\n.AA\n.BB\n..\n"), '', "ig - no macros called");
like(run("$aa$bb$cc.ig\n.CC\n..\n.AA\n"), qr/Before.\s+BB.\s+After/ms,
		"ig - no side effects because no macros called");
like(run("$aa$bb$cc.ig\n\\*(CC\n..\n.AA\n"), qr/Before.\s+BB.\s+After/ms,
		"ig - no side effects from strings interpolated");
