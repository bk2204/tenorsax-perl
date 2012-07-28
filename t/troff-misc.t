#!perl -T

use Test::More tests => 16;
use Test::Exception;
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

foreach my $char (map { chr(0x102200 + $_) } (0..15)) {
	my $val = sprintf "%X", ord($char);
	throws_ok { run($char); } qr/forbidden private-use/,
		"misc - character U+$val is forbidden";
}
