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

my $aa = <<EOM;
.ds [ compat
.ds ST regular
EOM

my $bb = <<EOM;
$aa
.ec !
EOM

is(run("$bb!*[ST]\n"), 'compatST]',
	"ec - change escape character works (long)");
is(run("$bb!*(ST\n"), 'regular', "ec - change escape character works (compat)");
