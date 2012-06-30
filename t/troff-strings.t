#!perl -T

use Test::More tests => 56;
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
		my $cp = ".cp $cpval\n";

		is(run("$cp.ds $name text\n$eval\n"), "text",
			"ds - $name ($cpval) - can define and $x a string");
		is(run(qq{$cp.ds $name "text"\n$eval\n}), 'text"',
			"ds - $name ($cpval) - handles final quote okay in $x");
		is(run(qq{$cp.ds $name "Have a nice day!\n$eval\n}), 'Have a nice day!',
			"ds - $name ($cpval) - handles complex text okay in $x");
		is(run(qq{$cp.ds $name\n$eval\n}), '',
			"ds - $name ($cpval) - handles missing argument okay in $x");
	}
}
