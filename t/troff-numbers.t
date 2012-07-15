#!perl -T

use Test::More tests => 183;
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
);

foreach my $test (@tests) {
	is(run(".nr A $test->[0]\n\\nA\n"), $test->[1],
		"nr - expression $test->[0] produces $test->[1]");
	is(run(".nr A 5\n.nr A +$test->[0]\n\\nA\n"), 5 + $test->[1],
		"nr - expression $test->[0] produces " . (5 + $test->[1]));
	is(run(".nr A 5\n.nr A -$test->[0]\n\\nA\n"), 5 - $test->[1],
		"nr - expression $test->[0] produces " . (5 - $test->[1]));
}
