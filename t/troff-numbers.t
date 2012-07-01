#!perl -T

use Test::More tests => 2;
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
