#!perl

use v5.14;
use warnings;
use open qw/:encoding(UTF-8) :std/;
use utf8;

use FindBin;
use Test::XML;
use Test::More;
use Test::NoWarnings;

use Pod::SAX;
use TenorSAX::Filter::PodSAXToTextMarkup;
use XML::SAX::Writer;

use Carp::Always;

my $testdir = "$FindBin::Bin/support";

opendir(my $dh, $testdir) or
	die "Can't find support directory: $!";
my @roots = sort map { s/\.pod$//r; } grep { /^pod-tm-\d+\.pod$/ } readdir $dh;
die "No tests to run!?" unless @roots;
plan tests => (2 * scalar @roots) + 1;

foreach my $root (@roots) {
	my $output = "";
	my $writer = XML::SAX::Writer->new(Output => \$output);
	my $processor = TenorSAX::Filter::PodSAXToTextMarkup->new(Handler =>
		$writer);
	my $parser = Pod::SAX->new(Handler => $processor);
	open(my $ifh, "<", "$testdir/$root.pod") or die "Can't open $root.pod: $!";
	$parser->parse_file($ifh);
	close($ifh);

	local $/;
	open(my $fh, "<", "$testdir/$root.xml") or die "Can't open $root.xml: $!";
	my $expected = <$fh>;
	close($fh);

	is_well_formed_xml($output, "$root produces well-formed XML");

	TODO: {
		local $TODO = "see Debian bugs 702740, 702742, and 702743"
			if $root eq "pod-tm-0004";
		is_xml($output, $expected, "$root produces expected XML");
	}
}
