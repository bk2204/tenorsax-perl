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

sub _transform_named_escapes {
	my ($self, $text, $char, $type) = @_;
	my $ec = $self->ec;

	# The more complex forms are first because \X will match a ( or [.
	my $pat = $self->compat ? qr/\Q$ec$char\E(\((\X{2})|(\X))/ :
		qr/\Q$ec$char\E(\((\X{2})|\[(\X*?)\]|(\X))/;

	# We might end up with something like \*(\*(NA.  In this case, parse the
	# second escape first, and then stick that into the proper place.
	while ($text =~ /$pat/p) {
		my $desc = $1;
		my $name = $2 || $3 || $4;
		my ($pre, $post) = (${^PREMATCH}, ${^POSTMATCH});
		my $repl = "$desc$post";
		if ($name =~ /^\Q$ec\E/) {
			$repl = $self->transform_escapes($repl);
			$text = "$pre$ec$char$repl";
			next;
		}
		elsif ($name =~ /^\x{102200}/) {
			$repl = $self->parser->_expand_escapes($repl, {count => 1}, {n => 1, s => 1});
			$text = "$pre$ec$char$repl";
			next;
		}
		$text =~ s{$pat}{\x{102200}$type$name\x{102202}};
	}

	return $text;
}

sub transform_escapes {
	my $self = shift;
	my $text = shift;
	my $ec = $self->ec;

	return $text unless $text =~ /\Q$ec\E/;

	$text = $self->_transform_named_escapes($text, "n", "n");
	$text = $self->_transform_named_escapes($text, "*", "s");

	if (!$self->copy) {
		$text = $self->_transform_named_escapes($text, "f", "xft\x{102201}");
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

sub join_continuation_lines {
	my $self = shift;
	my $text = shift;
	my $ec = $self->ec;
	my $copy = $self->copy;

	return $text unless defined $ec;

	$text = $self->preprocess_line($text);
	$text =~ s/\x{102204}/$ec$ec/g;
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
