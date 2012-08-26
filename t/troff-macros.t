#!perl -T

use Test::More tests => 46;
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

my $aas = <<EOM;
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

my $dd = <<EOM;
.de DD
DD.
..
EOM

my $ee = <<EOM;
.de EE
\\\\\$1.
.if !"\\\\\$2"" \\\\\$2.
..
EOM

my $ff = <<EOM;
.de FF
\\\\\$0.
..
EOM

my $gg = <<EOM;
.de GG
\\\\n(.\$.
..
EOM

my $aaa = $aas =~ s/^/.nop /msgr;
$aaa =~ s/^/.cp 0\n/;
$aaa =~ s/\.nop \.\./../;

foreach my $aa ($aas, $aaa) {
	diag "Using " . ($aa eq $aas ? "simple" : "prefixed") . " forms";

	is(run("$bb.BB\n"), "BB.", "de - can define and call a macro");
	like(run("$aa$bb.AA\n"), qr/Before.\s+BB.\s+After/ms,
			"de - can call a macro from within a macro");
	like(run("$aa.ds BB BB. \n.AA\n"), qr/Before.\s+BB.\s+After/ms,
			"de - can call a string from within a macro");
	like(run(".ds BB CC\n$aa.ds BB BB. \n.AA\n"), qr/Before.\s+BB.\s+After/ms,
			"de - calls are delayed until macro runtime");
	like(run("$ee.EE A\n"), qr/A\./ms,
			"de - arguments are interpolated");
	like(run("$ee.EE A B\n"), qr/A\..*B\./ms,
			"de - multiple arguments are interpolated");
	like(run("$ff.FF A\n"), qr/FF\./ms,
			"de - argument 0 works");
	is(run("$gg.GG A B C D\n"), '4.', 'de - \\n(.$ is properly expanded');
	is(run("$gg.GG\n"), '0.', 'de - \\n(.$ is properly expanded with no args');

	is(run("$bb.rm BB\n.BB\n"), '', "rm - can remove a macro");
	like(run("$aa$bb.rm BB\n.AA\n"), qr/Before.\s+After/ms,
			"rm - removed macro does not persist in other macros");
	is(run("$aa$bb.rm BB\n.AA\n"), run("$aa.AA"),
			"rm - removed macro treated like nonexistent macro");
	is(run("$aa$bb$cc.CC\n.AA\n"), '', "rm - removal inside macro works");
	is(run(".ds AA text\n.rm AA\n.AA\n"), '', "rm - removal of string works");

	is(run(".ig\nLine\nMore lines\n.."), '', "ig - produces no data");
	is(run("$aa$bb.ig\n.AA\n.BB\n..\n"), '', "ig - no macros called");
	like(run("$aa$bb$cc.ig\n.CC\n..\n.AA\n"), qr/Before.\s+BB.\s+After/ms,
			"ig - no side effects because no macros called");
	like(run("$aa$bb$cc.ig\n\\*(CC\n..\n.AA\n"), qr/Before.\s+BB.\s+After/ms,
			"ig - no side effects from strings interpolated");

	is(run("$bb.rn BB XX\n.XX\n"), 'BB.', "rn - can rename a macro");
	like(run("$aa$dd.rn DD BB\n.AA\n"), qr/Before.\s+DD.\s+After/ms,
			"rn - can rename a macro over another one");

	is(run(".cp 0\n$bb.als XX BB\n.XX\n"), 'BB.', "als - can alias a macro");
	like(run(".cp 0\n$aa$dd.als BB DD\n.AA\n"), qr/Before.\s+DD.\s+After/ms,
			"als - alias works when called from macro");
	is(run(".cp 0\n$bb.als XX BB\n.rn BB\n.XX\n"), 'BB.',
		"als - alias works even after original is removed");
}
