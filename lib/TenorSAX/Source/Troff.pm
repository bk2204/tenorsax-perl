package TenorSAX::Source::Troff;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;
use re '/u';

use Moose;
use namespace::autoclean;
use experimental qw/smartmatch autoderef/;

use TenorSAX::Source::Troff::Argument;
use TenorSAX::Source::Troff::Environment;
use TenorSAX::Source::Troff::Lexer;
use TenorSAX::Source::Troff::Numerical::Implementation;
use TenorSAX::Source::Troff::Request;
use TenorSAX::Source::Troff::Request::Implementation;
use TenorSAX::Source::Troff::State;
use TenorSAX::Util::FancyContentHandler;
use TenorSAX::Util::NodeGenerator;

extends 'TenorSAX::Source::Parser';

has '_ec' => (
	is => 'rw',
	default => "\\",
	init_arg => undef,
);
has '_data' => (
	isa => 'ArrayRef[Str]',
	is => 'rw',
	default => sub { [] },
	init_arg => undef,
);
has '_requests' => (
	isa => 'HashRef[TenorSAX::Source::Troff::Stringy]',
	is => 'rw',
	default => sub { {} },
	init_arg => undef,
);
has '_numbers' => (
	isa => 'HashRef[TenorSAX::Source::Troff::Numerical]',
	is => 'rw',
	default => sub { {} },
	init_arg => undef,
);
has '_ch' => (
	is => 'rw',
	init_arg => 'Handler',
);
has '_macrodirs' => (
	is => 'rw',
	isa => 'ArrayRef[Str]',
	init_arg => 'MacroDirs',
	default => sub { [] },
);
has '_filename' => (
	is => 'rw',
	isa => 'Str',
	default => '',
);
has '_resolution' => (
	is => 'rw',
	isa => 'Int',
	init_arg => 'Resolution',
	default => 72000,
);
has '_compat' => (
	isa => 'Int',
	is => 'rw',
	default => 1,
	init_arg => undef,
);
has '_state' => (
	isa => 'TenorSAX::Source::Troff::State',
	is => 'rw',
	default => sub { TenorSAX::Source::Troff::State->new(); },
	init_arg => undef,
);
has '_env' => (
	isa => 'TenorSAX::Source::Troff::Environment',
	is => 'rw',
	default => sub { TenorSAX::Source::Troff::Environment->new(); },
	init_arg => undef,
);
has '_linenos' => (
	isa => 'HashRef[Int]',
	is => 'rw',
	default => sub { { text => 0, input => 0 } },
	init_arg => undef,
);
has '_traps' => (
	isa => 'HashRef',
	is => 'rw',
	default => sub { { text => {} } },
	init_arg => undef,
);
# Previous condition.
has '_condition' => (
	isa => 'Bool',
	is => 'rw',
	default => 1,
	init_arg => undef,
);
# For copy mode.
has '_copy' => (
	isa => 'HashRef',
	is => 'rw',
	default => sub { {enabled => 0} },
	init_arg => undef,
);
has '_stash' => (
	isa => 'HashRef',
	is => 'rw',
	default => sub { {} },
	init_arg => undef,
);
has '_xml_mode' => (
	isa => 'Bool',
	is => 'rw',
	default => 0,
);
has 'logger' => (
	isa => 'CodeRef',
	is => 'rw',
	init_arg => 'Logger',
	default => sub { sub {} },
);
# A set of flags.  1 forbids IO, 2 dies on IO (otherwise it is silently
# ignored), 4 forbids clearing flag 2.  Once set to a true value, cannot be set
# to 0 again.
has 'forbid_io' => (
	isa => 'Int',
	is => 'rw',
	init_arg => 'ForbidIO',
	default => 0,
);
has '_ng' => (
	isa => 'TenorSAX::Util::NodeGenerator',
	is => 'rw',
);

=head1 NAME

TenorSAX::Source::Troff - The great new TenorSAX::Source::Troff!

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use TenorSAX::Source::Troff;

    my $foo = TenorSAX::Source::Troff->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

sub _setup {
	my ($self, $options) = @_;

	#$self->_ch($options->{Handler});
	$self->_ch(TenorSAX::Util::FancyContentHandler->new(
			{
				Prefixes => {
					_t => 'http://ns.crustytoothpaste.net/troff',
					_tm => 'http://ns.crustytoothpaste.net/text-markup',
					xml => 'http://www.w3.org/XML/1998/namespace',
				},
				Handler => $self->_ch,
			}
		)
	);
	$self->_ng(TenorSAX::Util::NodeGenerator->new(prefixes =>
			$self->_ch->prefixes));
	$self->_requests(TenorSAX::Source::Troff::Request::Implementation->requests());
	$self->_numbers(TenorSAX::Source::Troff::Numerical::Implementation->numbers());

	my $state = {parser => $self, environment => $self->_env, state =>
		$self->_state};
	$self->_env->setup($state);
	$self->_state->setup($state);
	return;
}

sub _parse_string {
	my $self = shift;
	my $str = shift;
	my $options = shift;

	$self->_setup($options);

	my $forbidden = '[' . join('', map { chr(0x102200+$_) } (0..15)) . ']';
	die "TenorSAX::Source::Troff: text contains forbidden private-use characters"
		if $str =~ /$forbidden/;

	push @{$self->_data}, split /\R/, $str;
	$self->_do_parse();
	return;
}

sub _extract_attributes {
	my $self = shift;
	my $obj = shift;
	my $initial = shift;
	my %hr;
	my $state = {parser => $self, environment => $self->_env, state =>
		$self->_state};
	my $meta = $obj->meta;

	foreach my $attr (map { $meta->get_attribute($_) }
		$meta->get_attribute_list) {
		if ($attr->does('TenorSAX::Meta::Attribute::Trait::Serializable')) {
			my $name = $attr->name;
			my $values = $attr->serialize($obj, $state);

			foreach my $key (keys $values) {
				my $value = $values->{$key};
				$key =~ tr/_/-/;
				$hr{"_t:$key"} = $value;
				$hr{"xml:space"} = $value ? "default" : "preserve"
					if ($key eq "fill" && !$initial);
			}
		}
	}
	return %hr;
}

sub _state_to_hash {
	my $self = shift;
	my $initial = shift;
	my $hr = {};

	# This function must always return a new reference, because its stringified
	# representation will be used in the stash object as a key.
	return {
		$self->_extract_attributes($self->_env, $initial),
		$self->_extract_attributes($self->_state, $initial),
	};
}

# Note that args in this function includes the macro name as element 0.
sub _substitute_args {
	my $self = shift;
	my $text = shift;
	my $args = shift;
	my $opts = shift || {};
	my $compat = $opts->{compat};
	my $ec = $self->_ec;
	my $nargs = scalar @$args - 1;

	return $text unless defined $ec;

	$text =~ s/\Q$ec$ec\E/\x{102204}/g;
	my $argpat = $compat ? qr/\Q$ec\E\$(\(([0-9]{2})|([0-9]))/ :
		qr/\Q$ec\E\$(\(([0-9]{2})|\[([0-9]*?)\]|([0-9]))/;
	$text =~ s{$argpat}{$args->[int($2 // $3 // $4)] // ''}ge;
	my $nargspat = $compat ? qr/\Q$ec\En\(\.\$/ :
		qr/\Q$ec\En(\(\.\$|\[\.\$\])/;
	$text =~ s{$nargspat}{$nargs}g;
	$text =~ s/\x{102204}/$ec$ec/g;

	return $text;
}

sub _expand_strings {
	my $self = shift;
	my $text = shift;
	my $opts = shift || {};
	my $args = [];
	my $state = {parser => $self, environment => $self->_env, state =>
		$self->_state};
	my $lexer = TenorSAX::Source::Troff::Lexer->new(ec => $self->_ec,
		copy => $self->_copy->{enabled}, parser => $self,
		compat => $opts->{compat});

	$text = $lexer->preprocess_line($text);
	$text = $lexer->process_character_escapes($text);
	$text = $lexer->transform_escapes($text);
	$text = $lexer->postprocess_line($text);

	my $result = "";

	$text =~ s/\x{102200}s(\X*?)\x{102202}/$self->_lookup_request($1)->perform($state, $args) || ''/ge;

	return $text;
}

sub _expand_escapes {
	my $self = shift;
	my $text = shift;
	my $opts = shift || {};
	my $allowed = shift || { map { $_ => 1 } qw/n s x/ };
	my $args = [];
	my $state = {parser => $self, environment => $self->_env, state =>
		$self->_state, opts => $opts};

	my $result = "";
	my $count = 0;

	while (length $text) {
		$text =~ s/^([^\x{102200}]*)(\x{102200}(\X)(\X*?)((?:\x{102201}\X*?)*)\x{102202})?//p;
		$result .= $1;
		next unless $3;
		unless ($allowed->{$3} || $allowed->{all}) {
			$result .= $2;
			next;
		}
		if (defined $opts->{count} && $opts->{count} == $count++) {
			return "$result${^MATCH}$text";
		}
		for ($3) {
			when ("n") {
				$result .= $self->_lookup_number($4)->format($state);
			}
			when ("s") {
				$result .= $self->_lookup_request($4)->perform($state, $args) ||
					'';
			}
			when ("x") {
				my $name = $4;
				my (undef, @pieces) = split /\x{102201}/, $5;
				my $request = $self->_lookup_request($name);
				my $res = $request->perform($state, \@pieces);
				$result .= $res if defined $res;
			}
			when ("b") {
				my $element = $4;
				my (undef, $id) = split /\x{102201}/, $5;
				die "TenorSAX::Source::Troff: missing stash $id"
					unless exists $self->_stash->{$id};
				my $state = $self->_stash->{$id};
				$self->_ch->start_element($self->_ng->element($element,
						$state));
				# Don't waste memory.
				delete $self->_stash->{$id};
			}
			when ("e") {
				my $element = $4;
				my @flags = split /\x{102201}/, $5;
				my %flags = map { $_ => 1 } @flags;
				if ($flags{'if-open'}) {
					next unless $self->_ch->in_element({Name => $element});
				}
				$self->_ch->end_element($self->_ng->element($element))
			}
			default {
				$result .= $2;
			}
		}
	}

	return $result;
}

sub _expand {
	my $self = shift;
	my $text = shift;
	my $opts = shift || {};
	my $escapes = shift;
	my $ec = $self->_ec;

	$opts->{return} = 1;

	return $text unless defined $ec;

	$text = $self->_expand_strings($text, $opts);
	$text = $self->_expand_escapes($text, $opts, $escapes);

	return $text;
}

sub _emit_characters {
	my $self = shift;
	my $text = shift;
	my $suffix = shift;
	my $state = {parser => $self, environment => $self->_env, opts => {},
		state => $self->_state};

	$text =~ s{
		\x{102200}b_t:block[^\x{102202}]+\x{102202}
		\x{102200}e_t:block[^\x{102202}]+\x{102202}
	}{}gx;
	my @items = split /(\x{102200}\X*?\x{102202})/, $text;
	foreach my $item (@items) {
		if ($item =~ /\x{102200}(\X)(\X*)\x{102202}/) {
			my $cmd = $1;
			next unless $cmd =~ /^[xbe]/;
			my $result = $self->_expand_escapes($item, {}, {all => 1});

			# An x command can result in b and e commands, so process those.
			$self->_emit_characters($result) if $result =~ /\x{102200}/;
		}
		else {
			$self->_ch->characters({Data => $item});
		}
	}
	$self->_ch->characters({Data => $suffix}) if $suffix;
	return;
}

sub _do_request {
	my $self = shift;
	my $request = shift;
	my $opts = shift;
	my $line = shift // '';
	my $args = [];
	my $state = {parser => $self, environment => $self->_env, opts => $opts,
		state => $self->_state};

	$line = $self->_expand($line, $opts, {s => 1});

	for (my $i = 0; $i < $request->max_args && length $line; $i++) {
		my $argtype = $request->arg_type->[$i] //
			'TenorSAX::Source::Troff::Argument';
		my $arg = $argtype->parse($request, \$line);
		$arg = $self->_expand_escapes($arg, $opts, {n => 1})
			if $argtype->expand_ok;
		push @$args, $argtype->evaluate($request, $state, $arg);
		$request->modify($state, $args);
	}

	my $text = $request->perform($state, $args);
	$self->_emit_characters($text) if defined $text;
	return;
}

sub _lookup {
	my ($self, $name, $table, $type, $undef_ok) = @_;

	if (!exists $table->{$name}) {
		return if $undef_ok;
		$table->{$name} = $type->new();
	}
	my $clone = $table->{$name}->clone;
	$clone->name($name);
	return $clone;
}

sub _lookup_request {
	my $self = shift;
	my $name = shift;
	my $undef_ok = shift;

	return $self->_lookup($name, $self->_requests,
		'TenorSAX::Source::Troff::Request', $undef_ok);
}

sub _lookup_number {
	my $self = shift;
	my $name = shift;
	my $undef_ok = shift;

	return $self->_lookup($name, $self->_numbers,
		'TenorSAX::Source::Troff::Number', $undef_ok);
}

sub _copy_conditional {
	my $self = shift;
	my $data = "";
	my $ec = $self->_ec;

	while (@{$self->_data}) {
		my $line = shift @{$self->_data};
		if (defined $ec && $line =~ m/^(\X*)\Q$ec\E\}/) {
			return "$data$1";
		}

		$data .= "$line\n";
	}
	return $data;
}

sub _copy_until {
	my $self = shift;
	my $pattern = shift;
	my $data = "";

	$self->_copy->{enabled} = 1;
	$self->_copy->{pattern} = $pattern;
	$self->_copy->{data} = "";

	local $1;
	while (@{$self->_data} && $self->_copy->{enabled}) {
		my $line = shift @{$self->_data};

		if ($self->_compat) {
			$self->_parse_line_compat($line);
		}
		else {
			$self->_parse_line($line);
		}
	}
	return $self->_copy->{data};
}

sub _do_line_traps {
	my $self = shift;
	my $state = {parser => $self, environment => $self->_env, opts => {},
		state => $self->_state};

	foreach my $key (keys $self->_linenos) {
		my $lineno = $self->_linenos->{$key};
		if (exists $self->_traps->{$key}{$lineno}) {
			foreach my $trap (values $self->_traps->{$key}{$lineno}) {
				my $text = $trap->($state);
				$self->_expand_escapes($text, {}) if defined $text;
			}
		}
	}
	return;
}

sub _parse_line_compat {
	my $self = shift;
	my $line = shift;
	my $controls = $self->_env->cc . $self->_env->c2;
	my $opts = {compat => 1};
	my $lexer = TenorSAX::Source::Troff::Lexer->new(ec => $self->_ec,
		copy => $self->_copy->{enabled}, parser => $self,
		compat => $opts->{compat});

	$self->_linenos->{input}++;
	$line = $lexer->join_continuation_lines($line);
	if ($self->_copy->{enabled} && $line =~ $self->_copy->{pattern}) {
		$self->_copy->{enabled} = 0;
	}
	elsif ($self->_copy->{enabled}) {
		$self->_do_text_line($line, $opts);
	}
	elsif ($line =~ s/^([$controls])(\X{0,2}?)([ \t]+|$)//u ||
		$line =~ s/^([$controls])(\X{2}?)(\X+|$)//u) {
		my $request = $self->_lookup_request($2);
		$opts->{can_break} = $1 eq $self->_env->cc;
		$opts->{compat} = 0 if $request->disable_compat;
		$opts->{as_request} = 1;
		$self->_do_request($request, $opts, $line);
	}
	else {
		$self->_linenos->{text}++;
		$self->_do_text_line($line, $opts);
	}
	$self->_do_line_traps();
	return;
}

sub _parse_line {
	my $self = shift;
	my $line = shift;
	my $controls = $self->_env->cc . $self->_env->c2;
	my $opts = {compat => 0};
	my $lexer = TenorSAX::Source::Troff::Lexer->new(ec => $self->_ec,
		copy => $self->_copy->{enabled}, parser => $self,
		compat => $opts->{compat});

	$self->_linenos->{input}++;
	$line = $lexer->join_continuation_lines($line);
	if ($self->_copy->{enabled} && $line =~ $self->_copy->{pattern}) {
		$self->_copy->{enabled} = 0;
	}
	elsif ($self->_copy->{enabled}) {
		$self->_do_text_line($line, $opts);
	}
	elsif ($line =~ s/^([$controls])(\X*?)([ \t]+|$)//u) {
		my $request = $self->_lookup_request($2);
		$opts->{can_break} = $1 eq $self->_env->cc;
		$opts->{as_request} = 1;
		$self->_do_request($request, $opts, $line);
	}
	else {
		$self->_linenos->{text}++;
		$self->_do_text_line($line, $opts);
	}
	$self->_do_line_traps();
	return;
}

sub _do_text_line {
	my $self = shift;
	my $line = shift;
	my $opts = shift;

	$line = $self->_expand($line, $opts);

	if (!length $line) {
		# Most XML-based formats will undefine .sp to avoid adding unwanted
		# block elements, so simply emit a newline in that case.
		my $request = $self->_lookup_request("sp", 1);
		if ($request) {
			my $opts = {can_break => 1};
			return $self->_do_request($request, $opts, "1");
		}
		else {
			$self->_emit_characters("\n");
		}
	}
	elsif ($self->_copy->{enabled}) {
		$self->_copy->{data} .= "$line\n";
	}
	else {
		$self->_emit_characters($line, "\n");
	}
	return;
};

sub _lookup_prefix {
	my $self = shift;
	my $qname = shift;
	my $attribute = shift;
	my $result = {Name => $qname};
	my ($prefix, $local) = (($qname =~ /:/) ? (split /:/, $qname, 2) :
		(undef, $qname));
	my $uri;

	$prefix = "" unless $attribute || defined $prefix;

	if (defined $prefix) {
		$uri = $self->_ch->prefixes->{$prefix} //
			die "Prefix $prefix is not defined";
	}

	$result->{NamespaceURI} = $uri;
	$result->{Prefix} = $prefix;
	$result->{LocalName} = $local;
	return $result;
}

sub _do_parse {
	my $self = shift;
	my %prefixes = map { $_ => $self->_ch->prefixes->{$_} }
		keys %{$self->_ch->prefixes};
	my $prefix_count = scalar keys $self->_ch->prefixes;

	$self->_ch->start_document({});
	foreach my $prefix (keys %prefixes) {
		$self->_ch->start_prefix_mapping(
			{
				Prefix=>$prefix,
				NamespaceURI=>$prefixes{$prefix},
			}
		);
	}
	$self->_ch->element_trap(sub {
			my $ch = shift;
			my $element = shift;
			return if $element && $element->{NamespaceURI} ne $prefixes{_t};
			return if $self->_xml_mode;
			$ch->start_element($self->_ng->element('_t:main'));
			$ch->start_element($self->_ng->element('_t:block',
					$self->_state_to_hash(1)));
			return;
		}
	);

	while (@{$self->_data}) {
		my $line = shift @{$self->_data};
		$self->logger->($line);

		if ($self->_compat) {
			$self->_parse_line_compat($line);
		}
		else {
			$self->_parse_line($line);
		}
	}

	$self->_ch->end_element($self->_ng->element('_t:block'));
	$self->_ch->end_element($self->_ng->element('_t:main'));
	foreach my $prefix (keys %prefixes) {
		$self->_ch->end_prefix_mapping(
			{
				Prefix=>$prefix,
				NamespaceURI=>$prefixes{$prefix},
			}
		);
	}
	return $self->_ch->end_document({});
}

=head1 AUTHOR

brian m. carlson, C<< <sandals at crustytoothpaste.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tenorsax at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TenorSAX>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TenorSAX::Source::Troff


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=TenorSAX>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/TenorSAX>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/TenorSAX>

=item * Search CPAN

L<http://search.cpan.org/dist/TenorSAX/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 brian m. carlson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1; # End of TenorSAX::Source::Troff
