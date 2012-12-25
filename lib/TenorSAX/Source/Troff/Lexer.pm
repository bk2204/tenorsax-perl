package TenorSAX::Source::Troff::Lexer;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;
use re '/u';

use Moose;
use namespace::autoclean;

# Escape character.
has 'ec' => (
	is => 'rw',
	isa => 'Str',
	default => "\\",
);
# Compatibility mode.
has 'compat' => (
	is => 'rw',
	isa => 'Bool',
	default => 0,
);
# Copy mode.
has 'copy' => (
	is => 'rw',
	isa => 'Bool',
	default => 0,
);
has 'parser' => (
	is => 'rw'
);

sub transform_escapes {
	my $self = shift;
	my $text = shift;
	my $ec = $self->ec;

	# The more complex forms are first because \X will match a ( or [.
	my $numpat = $self->compat ? qr/\Q$ec\En(\((\X{2})|(\X))/ :
		qr/\Q$ec\En(\((\X{2})|\[(\X*?)\]|(\X))/;
	$text =~ s{$numpat}{"\x{102200}n" . ($2 || $3 || $4) . "\x{102202}"}ge;

	my $strpat = $self->compat ? qr/\Q$ec\E\*(\((\X{2})|(\X))/ :
		qr/\Q$ec\E\*(\((\X{2})|\[(\X*?)\]|(\X))/;
	$text =~ s{$strpat}
		{"\x{102200}s" . ($2 || $3 || $4) . "\x{102202}"}ge;

	if (!$self->copy) {
		my $fontpat = $self->compat ? qr/\Q$ec\Ef(\((\X{2})|(\X))/ :
			qr/\Q$ec\Ef(\((\X{2})|\[(\X*?)\]|(\X))/;
		$text =~ s{$fontpat}
			{"\x{102200}xft\x{102201}" . ($2 || $3 || $4) . "\x{102202}"}ge;
	}

	return $text;
}

sub process_character_escapes {
	my $self = shift;
	my $text = shift;
	my $ec = $self->ec;

	my $charmap = {
		e => "\x{102204}",
		t => "\t",
		a => "\x{1}",
		'&' => "\x{200b}",
		';' => "\x{200b}",
	};

	# FIXME: handle the case where one of these letters is followed by a
	# combining mark.
	$text =~ s/\Q$ec\E([eta&;])/$charmap->{$1}/ge;

	if (!$self->copy) {
		$text =~ s{\Q$ec\EU'([A-Fa-f0-9]+)'}{chr(hex($1))}ge;
	}

	return $text;
}

sub preprocess_line {
	my $self = shift;
	my $text = shift;
	my $ec = $self->ec;
	my $copy = $self->copy;

	return $text unless defined $ec;

	# Temporarily save doubled backslashes.
	$text =~ s/\Q$ec$ec\E/\x{102204}/g;

	1 while $text =~ s{\Q$ec\E$}{shift $self->parser->_data}ge;
	$text =~ s{\Q$ec\E#.*$}{shift $self->parser->_data}ge;
	$text =~ s{\Q$ec\E".*$}{}g;

	return $text;
}

sub postprocess_line {
	my $self = shift;
	my $text = shift;
	my $ec = $self->ec;

	# Turn doubled backslashes into regular ones.
	$text =~ s/\x{102204}/$ec/g;

	return $text;
}

1;
