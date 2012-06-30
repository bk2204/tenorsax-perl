#!perl -T

use Test::More tests => 16;
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
	['S', '.S', '\\*S'],
	['ST', '.ST', '\\*(ST'],
);

foreach my $test (@tests) {
	my ($name, $req, $esc) = @$test;

	foreach my $x (qw/call eval/) {
		my $eval = $x eq "call" ? $req : $esc;

		is(run(".ds $name text\n$eval\n"), "text",
			"ds - $name - can define and $x a string");
		is(run(qq{.ds $name "text"\n$eval\n}), 'text"',
			"ds - $name - handles final quote okay in $x");
		is(run(qq{.ds $name "Have a nice day!\n$eval\n}), 'Have a nice day!',
			"ds - $name - handles complex text okay in $x");
		is(run(qq{.ds $name\n$eval\n}), '',
			"ds - $name - handles missing argument okay in $x");
	}
}
