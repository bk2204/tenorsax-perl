#!perl -T

use Test::More tests => 4;
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
