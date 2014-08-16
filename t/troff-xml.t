#!perl -T

use Test::More tests => 4;
use TenorSAX::Source::Troff;
use XML::SAX::Writer;
use XML::LibXML;

sub run {
	my $input = shift;
	my $text = "";
	my $output = XML::SAX::Writer->new(Output => \$text);
	my $parser = TenorSAX::Source::Troff->new(Handler => $output);

	$parser->parse_string($input);
	$text =~ s/\n\z//;
	return $text;
}

sub num_start_tags {
	my $text = shift;
	my $tag = shift;
	my @matches = $text =~ /<\Q$tag\E\s+/g;

	return scalar @matches;
}

sub num_end_tags {
	my $text = shift;
	my $tag = shift;
	my @matches = $text =~ /<\/\Q$tag\E>/g;

	return scalar @matches;
}

sub has_num_tags {
	my $text = shift;
	my $tag = shift;
	my $num = shift;
	my $expl = shift;
	subtest $expl => sub {
		plan tests => 2;
		is(num_start_tags($text, $tag), $num,
			"exactly $num opening $tag element");
		is(num_end_tags($text, $tag), $num,
			"exactly $num closing $tag element");
	}
}

sub is_troff_xml {
	my $text = shift;
	my $expl = shift;
	my $tag = "_t:main";
	subtest $expl => sub {
		plan tests => 3;
		like($text, qr/\A<\Q$tag\E\s+/, "first open element is $tag");
		like($text, qr{</\Q$tag\E>\z}, "last closed element is $tag");
		has_num_tags($text, $tag, 1, "exactly one $tag element");
	}
}

# This checks whether the data is well-formed only.
sub is_ok_xml {
	my $text = shift;
	my $expl = shift;
	subtest $expl => sub {
		plan tests => 1;
		ok(defined eval { XML::LibXML->load_xml(string => $text) },
			"data is well-formed") or note $@;
	}
}

my $escapes = run("\\fI\\n(.f\\fP \\n(.f\n");
is_ok_xml($escapes, "escapes XML is well-formed") or note $escapes;
is_troff_xml($escapes, "escapes XML is troff/le format");
has_num_tags($escapes, "_t:block", 1, "escapes has one block");
has_num_tags($escapes, "_t:inline", 2, "escapes has two inlines");
