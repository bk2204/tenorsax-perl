#!perl -T

use Test::More tests => 27;
use TenorSAX::Source::Troff;
use TenorSAX::Output::Text;

sub run {
	my $input = shift;
	my $text = "";
	my $output = TenorSAX::Output::Text->new(Output => \$text);
	my $parser = TenorSAX::Source::Troff->new(Handler => $output,
		Resolution => 72000);

	$input .= "\n" if $input !~ /\n\z/ms;

	$parser->parse_string($input);
	$text =~ s/\n\z//;
	return $text;
}

is(run("\\n(.s\n"), "10", "ps - default is 10 points");
is(run(".cp 0\n\\n[.ps]\n"), "10000", "ps - default is 10000 units");
is(run(".ps 12\n\\n(.s\n"), "12", "ps - affects .s register");
is(run(".cp 0\n.ps 12\n\\n[.ps]\n"), "12000", "ps - affects .ps register");
is(run(".ps +12\n\\n(.s\n"), "22", "ps - increment affects .s register");
is(run(".cp 0\n.ps +12\n\\n[.ps]\n"), "22000",
	"ps - increment affects .ps register");
is(run(".ps -2\n\\n(.s\n"), "8", "ps - decrement affects .s register");
is(run(".cp 0\n.ps -2\n\\n[.ps]\n"), "8000",
	"ps - decrement affects .ps register");

is(run("\\n(.p\n"), "792000", "pl - default is 11 inches");
is(run(".pl 5i\n\\n(.p\n"), "360000", "pl - affects .p register");
is(run(".pl +1i\n\\n(.p\n"), "864000", "pl - increment affects .p register");
is(run(".pl -1i\n\\n(.p\n"), "720000", "pl - decrement affects .p register");

is(run("\\n(.o\n"), "72000", "po - default is 1 inch");
is(run(".po 5i\n\\n(.o\n"), "360000", "po - affects .o register");
is(run(".po +1i\n\\n(.o\n"), "144000", "po - increment affects .o register");
is(run(".po -1i\n\\n(.o\n"), "0", "po - decrement affects .o register");

is(run("\\n(.l\n"), "468000", "ll - default is 6.5 inches");
is(run(".ll 5i\n\\n(.l\n"), "360000", "ll - affects .l register");
is(run(".ll +1i\n\\n(.l\n"), "540000", "ll - increment affects .o register");
is(run(".ll -1i\n\\n(.l\n"), "396000", "ll - decrement affects .o register");

is(run("\\n(.v\n"), "12000", "vs - default is 1/6 inches");
is(run(".vs 10p\n\\n(.v\n"), "10000", "vs - affects .v register");

is(run("\\n(.j\n"), "b", "ad - default is both");
is(run(".ad l\n\\n(.j\n"), "l", "ad - setting l affects .j register");
is(run(".ad c\n\\n(.j\n"), "c", "ad - setting c affects .j register");
is(run(".ad r\n\\n(.j\n"), "r", "ad - setting r affects .j register");
is(run(".na\n\\n(.j\n"), "b", "na - no affect on .j register");
