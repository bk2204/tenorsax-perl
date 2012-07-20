#!perl -T

use Test::More tests => 49;
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

is(run(".ex\nmessage"), '', 'ex - no further code is executed');

my @tests = (
	# condition, multiline, result, prefix
	['dif', 0, 1],
	['dif', 1, 1],
	['dNO', 0, 0],
	['dNO', 1, 0],
	['rNO', 0, 0],
	['rNO', 0, 1, '.nr NO 2'],
	['rNO', 1, 0],
	['rNO', 1, 1, '.nr NO 2'],
	['"a"a"', 0, 1],
	['"a"a"', 1, 1],
	['"ab"a"', 0, 0],
	['"ab"a"', 1, 0],
);

foreach my $test (@tests) {
	my ($condition, $multiline, $result, $prefix) = @$test;
	$prefix = defined $prefix ? "$prefix\n" : '';

	if ($multiline) {
		is(run("$prefix.if $condition \\{\nmessage\n.\\}\n"),
			$result ? 'message' : '',
			"if - multiline - condition '$condition' should be " .
			($result ? "true" : "false"));
		is(run("$prefix.if !$condition \\{\nmessage\n.\\}\n"),
			$result ? '' : 'message',
			"if - multiline - condition '!$condition' should be " .
			($result ? "false" : "true"));
		is(run("$prefix.ie $condition \\{\nmessage\n.\\}\n" .
				".el \\{\nsomething else\n.\\}"),
			$result ? 'message' : 'something else',
			"ie - multiline - condition '$condition' should be " .
			($result ? "true" : "false"));
		is(run("$prefix.ie !$condition \\{\nmessage\n.\\}\n" .
				".el \\{\nsomething else\n.\\}"),
			$result ? 'something else' : 'message',
			"ie - multiline - condition '$condition' should be " .
			($result ? "false" : "true"));
	}
	else {
		is(run("$prefix.if $condition message\n"),
			$result ? 'message' : '',
			"if - simple - condition '$condition' should be " .
			($result ? "true" : "false"));
		is(run("$prefix.if !$condition message\n"),
			$result ? '' : 'message',
			"if - simple - condition '!$condition' should be " .
			($result ? "false" : "true"));
		is(run("$prefix.ie $condition message\n.el something else"),
			$result ? 'message' : 'something else',
			"ie - simple - condition '$condition' should be " .
			($result ? "true" : "false"));
		is(run("$prefix.ie !$condition message\n.el something else"),
			$result ? 'something else' : 'message',
			"ie - simple - condition '$condition' should be " .
			($result ? "false" : "true"));
	}
}
