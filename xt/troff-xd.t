#!perl -T

use warnings;
use strict;

use Test::More tests => 8;

use Carp::Always;

use TenorSAX;
use TenorSAX::Source::Troff;
use XML::SAX::Writer;
use XML::LibXML;
use XML::Filter::XSLT;

sub run {
	my $input      = shift;
	my $text       = "";
	my @init_files = map { File::Path::Expand::expand_filename($_) }
		@{$TenorSAX::Config->{troff}->{init_tmac}};
	my $data = "";

	foreach my $file (@init_files) {
		local $/;
		open(my $fh, '<', $file) or next;
		$data .= ".do tenorsax filename \"$file\"\n";
		$data .= <$fh>;
		close($fh);
	}

	my $stylesheet;
	my @xslt_dirs = map { File::Path::Expand::expand_filename($_) }
		@{$TenorSAX::Config->{troff}->{xslt}};
	foreach my $dir (reverse @xslt_dirs) {
		$stylesheet = "$dir/format-db5.xsl";
		last if -r $stylesheet;
		$stylesheet = undef;
	}
	die "Can't load stylesheet for device db5"
		unless $stylesheet;
	my $output = XML::SAX::Writer->new(Output => \$text);
	my $xslt = XML::Filter::XSLT->new(Handler => $output);
	my $parser = TenorSAX::Source::Troff->new(Handler => $xslt);

	$xslt->set_stylesheet_uri($stylesheet);

	$data .= ".do mso \"xd\"\n$input";
	$parser->parse_string($data);
	$text =~ s/\n\z//;
	return $text;
}

sub num_start_tags {
	my $text    = shift;
	my $tag     = shift;
	my @matches = $text =~ /<\Q$tag\E\s*(?:\s|>)/g;

	return scalar @matches;
}

sub num_end_tags {
	my $text    = shift;
	my $tag     = shift;
	my @matches = $text =~ /<\/\Q$tag\E>/g;

	return scalar @matches;
}

sub has_num_tags {
	my $text = shift;
	my $tag  = shift;
	my $num  = shift;
	my $expl = shift;
	subtest $expl => sub {
		plan tests => 2;
		is(num_start_tags($text, $tag),
			$num, "exactly $num opening $tag element");
		is(num_end_tags($text, $tag), $num,
			"exactly $num closing $tag element");
		}
}

sub is_article {
	my $text = shift;
	my $expl = shift;
	my $tag  = "d:article";
	subtest $expl => sub {
		plan tests => 3;
		like(
			$text,
			qr/\A(?:<\?xml.*?\?>)?\s*<\Q$tag\E\s+/,
			"first open element is $tag"
		);
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
			"data is well-formed") or
			note $@;
		}
}

{
	my $poem = run(<<'EOM');
.poem
.tt "Test"
.au "Tracy K. Smith"
.nf
text
moar text
EOM

	is_ok_xml($poem, "data is well-formed XML");
	is_article($poem, "XML is article");
	foreach my $element (qw/literallayout article info title/) {
		has_num_tags($poem, "d:$element", 1, "XML has one $element");
	}
	has_num_tags($poem, "_t:inline", 0, "XML has no inlines");
	has_num_tags($poem, "_t:block",  0, "XML has no blocks");
}
