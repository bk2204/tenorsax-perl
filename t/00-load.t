#!perl -T

use Test::More tests => 2;

BEGIN {
    use_ok( 'TenorSAX' ) || print "Bail out!\n";
    use_ok( 'TenorSAX::Source::Troff' ) || print "Bail out!\n";
}

diag( "Testing TenorSAX $TenorSAX::VERSION, Perl $], $^X" );
