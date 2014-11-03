#!perl -T

use strict;
use warnings;
use Test::More tests => 1;
use Test::Exception;
use TenorSAX::Source::Troff;
use TenorSAX::Output::Text;

sub run {
	my $input  = shift;
	my $text   = "";
	my $output = TenorSAX::Output::Text->new(Output => \$text);
	my $parser = TenorSAX::Source::Troff->new(Handler => $output);

	$input .= "\n" if $input !~ /\n\z/ms;

	$parser->parse_string($input);
	$text =~ s/\n\z//;
	return $text;
}

lives_ok { run(".ce 1\n* * *\n.ce 0\n") } 'deleting traps works ok';
