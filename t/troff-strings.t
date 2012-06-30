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


is(run(".ds ST text\n.ST\n"), "text", "ds - can define and call a string");
is(run(qq{.ds ST "text"\n.ST\n}), 'text"', "ds - handles final quote okay");
is(run(qq{.ds ST "Have a nice day!\n.ST\n}), 'Have a nice day!',
	"ds - handles complex text okay");
is(run(qq{.ds ST\n.ST\n}), '', "ds - handles missing argument okay");
