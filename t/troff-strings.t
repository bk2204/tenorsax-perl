#!perl -T

use Test::More tests => 100;
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

my @tests = (
	['S', '.S', '\\*S', 0],
	['S', '.S', '\\*[S]', 0],
	['S', '.S', '\\*S', 1],
	['ST', '.ST', '\\*(ST', 0],
	['ST', '.ST', '\\*[ST]', 0],
	['ST', '.ST', '\\*(ST', 1],
	['STR', '.STR', '\\*[STR]', 0],
);

foreach my $test (@tests) {
	my ($name, $req, $esc, $cpval) = @$test;

	foreach my $x (qw/call eval/) {
		my $eval = $x eq "call" ? $req : $esc;
		my $type = $cpval;
		my $cp = ".cp $cpval\n";
		my @prefixes = $cpval ? (".cp 1\n.") : (".cp 0\n.", ".do ");

		is(run("$cp.ds $name text\n$eval\n"), "text",
			"ds - $name ($type) - can define and $x a string");
		is(run(qq{$cp.ds $name "text"\n$eval\n}), 'text"',
			"ds - $name ($type) - handles final quote okay in $x");
		is(run(qq{$cp.ds $name "Have a nice day!\n$eval\n}), 'Have a nice day!',
			"ds - $name ($type) - handles complex text okay in $x");
		is(run(qq{$cp.ds $name\n$eval\n}), '',
			"ds - $name ($type) - handles missing argument okay in $x");

		if ($cpval == 0) {
			is(run(".do ds $name text\n.cp 0\n$eval\n"), "text",
				"ds - $name (2) - can define and $x a string");
			is(run(qq{.do ds $name "text"\n.cp 0\n$eval\n}), 'text"',
				"ds - $name (2) - handles final quote okay in $x");
			is(run(qq{.do ds $name "Have a nice day!\n.cp 0\n$eval\n}), 'Have a nice day!',
				"ds - $name (2) - handles complex text okay in $x");
			is(run(qq{.do ds $name\n.cp 0\n$eval\n}), '',
				"ds - $name (2) - handles missing argument okay in $x");
		}
	}
}

my $aa = <<EOM;
.ds [ compat
.ds ST regular
EOM

is(run("$aa\\*[ST]\n"), 'compatST]', "ds - eval bracket string in compat mode");
is(run("$aa\\*(ST\n"), 'regular', "ds - eval paren string in compat mode");

# Based off groff's me macro set.
my $bb = <<'EOM';
.de BB
.ds FT \\n(.f
.ft 3
.if \\n(.$ \\$1\f\\*(FT\\n(.f
..
.BB A
EOM
is(run($bb), "A1", "string substituted before escapes interpreted");

my $cc = <<'EOM';
.de BB
.ds FT \\n(.f
.ds TX FT
.ft 3
.if \\n(.$ \\$1\\*(\\*(TX\\n(.f
..
.BB A
EOM
is(run($cc), "A13", "string substituted before escapes interpreted");
