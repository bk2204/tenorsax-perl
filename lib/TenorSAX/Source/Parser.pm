package TenorSAX::Source::Parser;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;
use MooseX::NonMoose;
use Encode;
use namespace::autoclean;

extends "XML::SAX::Base";

sub _parse_characterstream {
	my ($self, $stream) = @_;
	return $self->_parse_string(join("", $stream->getlines));
}

sub _parse_bytestream {
	my ($self, $stream) = @_;
	my $text = join("", $stream->getlines);
	my $encoding = $self->{ParseOptions}{Encoding} || "UTF-8";
	return $self->_parse_string(Encode::decode($encoding, $text));
}

sub _parse_systemid {
	my ($self, $sysid) = @_;

	# This can be a filename, not just a URI.
	if (-e $sysid) {
		open(my $fh, "<", $sysid);
		return $self->_parse_bytestream($fh);
	}
	require LWP::UserAgent;
	my $ua = LWP::UserAgent->new;
	my $resp = $ua->get($sysid);
	die $resp->status_line unless $resp->is_success;
	return $self->_parse_string($resp->decoded_content);
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
