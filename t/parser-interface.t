#!perl -T

use utf8;

use Test::More;
use Test::FailWarnings;
use Test::Warn;
use File::Temp;
use XML::SAX::Writer;
use Encode;

my $dir = File::Temp->newdir;
my $tempfile = "$dir/test";

my $text = "\N{U+00a9}\n";
my $bytes = Encode::encode("UTF-8", $text);
my $uri = "file://$tempfile";

open(my $testfh, ">", $tempfile);
binmode $testfh;
print {$testfh} $bytes;
close($testfh);

my @sources = qw/Troff/;
foreach my $source (@sources) {
	my $module = "TenorSAX::Source::$source";

	require_ok($module);

	my $output = "";
	my $parser = new_chain($module, \$output);
	eval { $parser->parse({Source => { SystemId => $uri }}); };
	check_output($@, $output, "SystemId for $source");

	$output = "";
	$parser = new_chain($module, \$output);
	eval { $parser->parse({Source => { String => $text }}); };
	check_output($@, $output, "Unicode String for $source");

	$output = "";
	$parser = new_chain($module, \$output);
	eval { $parser->parse({Source => { String => $bytes }}); };
	check_output($@, $output, "Byte String for $source");

	$output = "";
	$parser = new_chain($module, \$output);
	open(my $fh, "<", $tempfile);
	binmode $fh;
	eval { $parser->parse({Source => { ByteStream => $fh }}); };
	check_output($@, $output, "ByteStream for $source");
	close $fh;

	$output = "";
	$parser = new_chain($module, \$output);
	open($fh, "<", $tempfile);
	binmode $fh, ":encoding(UTF-8)";
	warnings_like {
		eval { $parser->parse({Source => { CharacterStream => $fh }}); };
	} qr/parse charstream/, "bizarre and needless warning from XML::SAX::Base";
	check_output($@, $output, "CharacterStream for $source");
	close $fh;

	$output = "";
	$parser = new_chain($module, \$output);
	eval { $parser->parse_uri($uri); };
	check_output($@, $output, "URI for $source");

	$output = "";
	$parser = new_chain($module, \$output);
	eval { $parser->parse_file($tempfile); };
	check_output($@, $output, "File (filename) for $source");

	$output = "";
	$parser = new_chain($module, \$output);
	open($fh, "<", $tempfile);
	binmode $fh;
	eval { $parser->parse_file($fh); };
	check_output($@, $output, "File (filehandle) for $source");
	close $fh;

	$output = "";
	$parser = new_chain($module, \$output);
	eval { $parser->parse_string($bytes); };
	check_output($@, $output, "parse_string for $source");
}

done_testing();

sub check_output {
	my ($exception, $output, $desc) = @_;
	is($@, "", "no exception occurred for $desc");
	like($output, qr/\N{U+00a9}/, "output was as expected for $desc");
}

sub new_chain {
	my ($module, $output_ref) = @_;
	my $writer = XML::SAX::Writer->new(Output => $output_ref);
	my $parser = $module->new(Handler => $writer);
	return $parser;
}
