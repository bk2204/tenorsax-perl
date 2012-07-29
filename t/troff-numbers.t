#!perl -T

use Test::More tests => (72 * 3) + 10;
use TenorSAX::Source::Troff;
use TenorSAX::Output::Text;

sub run {
	my $input = shift;
	my $text = "";
	my $output = TenorSAX::Output::Text->new(Output => \$text);
	my $parser = TenorSAX::Source::Troff->new(Handler => $output,
		Resolution => 240);

	$input .= "\n" if $input !~ /\n\z/ms;

	$parser->parse_string($input);
	$text =~ s/\n\z//;
	return $text;
}

is(run(".nr A 5\n\\nA\n"), "5", "nr - can define and use a number register");
is(run(".nr A 5\n.nr B \\nA\n\\nB\n"), "5",
	"nr - can use a number register as argument to nr");
is(run(".nr A 5\n.nr B \\nA-1\n\\nB\n"), "4",
	"nr - can use an expression as argument to nr");
is(run(".nr A 5\n.nr B 3\n.nr C (\\nA-\\nB)\n\\nC\n"), "2",
	"nr - can use a parenthesized expression as argument to nr");
is(run(".nr A 5\n.nr B 3\n.nr C (\\nA - \\nB)\n\\nC\n"), "2",
	"nr - can have space inside parenthesized expressions");
is(run(".nr A 5*4-3\n\\nA\n"), "17", "nr - uses left-to-right evaluation");
is(run(".nr A 5-4*3\n\\nA\n"), "3", "nr - ignores order of operations");
is(run(".nr A (5*4-3)\n\\nA\n"), "17",
	"nr - uses left-to-right evaluation inside parentheses");
is(run(".nr A (5-4*3)\n\\nA\n"), "3",
	"nr - ignores order of operations inside parentheses");
is(run(".nr .s 1000000\n\\n(.s\n"), "10",
	"nr - can't set read-only registers");

my @tests = (
	['((5*4)-3)', 17],
	['(5*(4-3))', 5],
	['((5-4)*3)', 3],
	['(5-(4*3))', -7],
	['(5 * (4 - 3))', 5],
	['2+3+4+5', 14],
	['5-4-3-2', -4],
	['4/2+3', 5],
	['4%2+3', 3],
	['5%2+3', 4],
	['5+3%2', 0],
	['5<2', 0],
	['2<5', 1],
	['3<3', 0],
	['5>2', 1],
	['2>5', 0],
	['3>3', 0],
	['2<=5', 1],
	['5<=2', 0],
	['3<=3', 1],
	['2>=5', 0],
	['5>=2', 1],
	['3>=3', 1],
	['2=5', 0],
	['5=2', 0],
	['3=3', 1],
	['2==5', 0],
	['5==2', 0],
	['3==3', 1],
	['2<>5', 1],
	['5<>2', 1],
	['3<>3', 0],
	['2<?5', 2],
	['5<?2', 2],
	['3<?3', 3],
	['2>?5', 5],
	['5>?2', 5],
	['3>?3', 3],
	['2&5', 1],
	['5&2', 1],
	['3&3', 1],
	['0&0', 0],
	['0&1', 0],
	['1&0', 0],
	['1&1', 1],
	['2:5', 1],
	['5:2', 1],
	['3:3', 1],
	['0:0', 0],
	['0:1', 1],
	['1:0', 1],
	['1:1', 1],
	['(1020+80)/2', 550],
	['(1020 + 80)/2', 550],
	['2*(1020+80)', 2200],
	['2*(1020 + 80)', 2200],
	['2*(1020+80)/2', 1100],
	['2*(1020 + 80)/2', 1100],
	['1', 1],
	['1u', 1],
	['1s', 1],
	['1i', 240],
	['1c', 240 * 50 / 127],
	['1P', 240 / 6],
	['1p', 240 / 72],
	['1z', 240 / 72],
	['1t', 240 * 100 / 7227],
	['1T', 240 * 400 / 2409],
	['1D', 240 * 24 / 1621],
	['1C', 240 * 288 / 1621],
	['(4.25i+2P)/2u', 550],
	['\\n($$', $$],
);

foreach my $test (@tests) {
	is(run(".nr A $test->[0]\n\\nA\n"), int($test->[1]),
		"nr - expression $test->[0] produces $test->[1]");
	is(run(".nr A 5\n.nr A +$test->[0]\n\\nA\n"), 5 + int($test->[1]),
		"nr - expression $test->[0] produces " . (5 + int($test->[1])));
	is(run(".nr A 5\n.nr A -$test->[0]\n\\nA\n"), 5 - int($test->[1]),
		"nr - expression $test->[0] produces " . (5 - int($test->[1])));
}
