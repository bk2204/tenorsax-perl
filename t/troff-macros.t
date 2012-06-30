#!perl -T

use Test::More tests => 4;
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

is(run("$bb.BB\n"), "BB.", "de - can define and call a macro");
like(run("$aa$bb.AA\n"), qr/Before.\s+BB.\s+After/ms,
		"de - can call a macro from within a macro");
like(run("$aa.ds BB BB. \n.AA\n"), qr/Before.\s+BB.\s+After/ms,
		"de - can call a string from within a macro");
like(run(".ds BB CC\n$aa.ds BB BB. \n.AA\n"), qr/Before.\s+BB.\s+After/ms,
		"de - calls are delayed until macro runtime");
