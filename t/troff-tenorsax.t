#!perl -T

use Test::More tests => 6;
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


my $test1 = <<'EOM';
.cp 0
.nf
.tenorsax get-no-io nn
\n(nn
.tenorsax no-io 1
.tenorsax get-no-io nn
\n(nn
.tenorsax no-io 0
.tenorsax get-no-io nn
\n(nn
EOM
is(run($test1), "0\n1\n1", 'no-io - flag cannot be set to 0');

my $test2 = <<'EOM';
.cp 0
.nf
.tenorsax get-no-io nn
\n(nn
.tenorsax no-io 3
.tenorsax get-no-io nn
\n(nn
.tenorsax no-io 1
.tenorsax get-no-io nn
\n(nn
.tenorsax no-io 7
.tenorsax get-no-io nn
\n(nn
.tenorsax no-io 1
.tenorsax get-no-io nn
\n(nn
EOM
is(run($test2), "0\n3\n1\n7\n7", 'no-io - honors force-die flag');

foreach my $request (qw/so mso/) {
	my $test3 = <<EOM;
.cp 0
.nf
.tenorsax no-io 1
.$request /etc/passwd
EOM
	is(run($test3), "", "no-io - silently ignores $request request");

	my $test4 = <<EOM;
.cp 0
.nf
.tenorsax no-io 7
.$request /etc/passwd
EOM
	dies_ok { run($test4) } "no-io - dies on $request request";
}

