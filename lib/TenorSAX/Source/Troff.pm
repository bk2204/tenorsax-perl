package TenorSAX::Source::Troff;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;
use re '/u';

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;

use TenorSAX::Source::Troff::Argument;
use TenorSAX::Source::Troff::Environment;
use TenorSAX::Source::Troff::Request;
use TenorSAX::Source::Troff::Request::Implementation;
use TenorSAX::Source::Troff::State;
use TenorSAX::Util::FancyContentHandler;

extends 'XML::SAX::Base';

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

=head1 NAME

TenorSAX::Source::Troff - The great new TenorSAX::Source::Troff!

=head1 VERSION

Version 2.00

=cut

our $VERSION = '2.00';


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
	$self->_requests(TenorSAX::Source::Troff::Request::Implementation->requests());
}

sub _parse_string {
	my $self = shift;
	my $str = shift;
	my $options = shift;

	$self->_setup($options);

	push @{$self->_data}, split /\R/, $str;
	$self->_do_parse();
}

sub _state_to_hash {
	my $self = shift;
	my $initial = shift;
	my $hr = {};
	my $meta = $self->_env->meta;
	my $state = {parser => $self, environment => $self->_env, state =>
		$self->_state};

	foreach my $attr (map { $meta->get_attribute($_) }
		$meta->get_attribute_list) {
		if ($attr->does('TenorSAX::Meta::Attribute::Trait::Serializable')) {
			my $name = $attr->name;
			my $values = $attr->serialize($self->_env, $state);

			foreach my $key (keys $values) {
				$key =~ tr/_/-/;
				$hr->{"_t:$key"} = $values->{$key};
				$hr->{"xml:space"} = $values->{$key} ? "default" : "preserve"
					if ($key eq "fill" && !$initial);
			}
		}
	}
	return $hr;
}

# Note that args in this function includes the macro name as element 0.
sub _substitute_args {
	my $self = shift;
	my $text = shift;
	my $args = shift;
	my $opts = shift || {};
	my $compat = $opts->{compat};
	my $ec = $self->_ec;

	return $text unless defined $ec;

	$text =~ s/\Q$ec$ec\E/\x{102204}/g;
	my $argpat = $compat ? qr/\Q$ec\E\$(\(([0-9]{2})|([0-9]))/ :
		qr/\Q$ec\E\$(\(([0-9]{2})|\[([0-9]*?)\]|([0-9]))/;
	$text =~ s{$argpat}{$args->[int($2 // $3 // $4)] // ''}ge;
	$text =~ s/\x{102204}/$ec$ec/g;

	return $text;
}

sub _expand {
	my $self = shift;
	my $text = shift;
	my $opts = shift || {};
	my $compat = $opts->{compat};
	my $copy = $self->_copy->{enabled}; # copy mode
	my $args = [];
	my $state = {parser => $self, environment => $self->_env, state =>
		$self->_state};
	my $ec = $self->_ec;

	$opts->{return} = 1;

	return $text unless defined $ec;

	# Temporarily save doubled backslashes.
	$text =~ s/\Q$ec$ec\E/\x{102204}/g;
	$text =~ s/\Q$ec\Ee/\x{102204}/g;
	$text =~ s/\Q$ec\Et/\t/g;
	$text =~ s/\Q$ec\Ea/\x{1}/g;

	# The more complex forms are first because \X will match a ( or [.
	my $numpat = $compat ? qr/\Q$ec\En(\((\X{2})|(\X))/ :
		qr/\Q$ec\E\\n(\((\X{2})|\[(\X*?)\]|(\X))/;
	$text =~ s{$numpat}{$self->_lookup_number($2 || $3 || $4)->format()}ge;

	my $strpat = $compat ? qr/\Q$ec\E\*(\((\X{2})|(\X))/ :
		qr/\Q$ec\E\*(\((\X{2})|\[(\X*?)\]|(\X))/;
	$text =~ s{$strpat}
		{$self->_lookup_request($2 || $3 || $4)->perform($state, $args)||''}ge;

	$text =~ s{\Q$ec\E$}{shift $self->_data}ge;
	$text =~ s{\Q$ec\E#.*$}{shift $self->_data}ge;
	$text =~ s{\Q$ec\E".*$}{}g;

	if (!$copy) {
		$text =~ s{\Q$ec\EU'([A-Fa-f0-9]+)'}{chr(hex($1))}ge;

		my $fontpat = $compat ? qr/\Q$ec\Ef(\((\X{2})|(\X))/ :
			qr/\Q$ec\Ef(\((\X{2})|\[(\X*?)\]|(\X))/;
		$text =~ s{$fontpat}
			{"\x{102200}xft\x{102201}" . ($2 || $3 || $4) . "\x{102202}"}ge;
	}

	# Turn doubled backslashes into regular ones.
	$text =~ s/\x{102204}/$ec/g;

	return $text;
}

sub _emit_characters {
	my $self = shift;
	my $text = shift;
	my $suffix = shift;
	my $state = {parser => $self, environment => $self->_env, opts => {},
		state => $self->_state};

	my @items = split /(\x{102200}\X*?\x{102202})/, $text;
	foreach my $item (@items) {
		if ($item =~ /\x{102200}(\X)(\X*)\x{102202}/) {
			my $cmd = $1;
			next unless $cmd eq "x";
			my @pieces = split /\x{102201}/, $2;
			my $name = shift @pieces;
			my $request = $self->_lookup_request($name);
			my $res = $request->perform($state, \@pieces);
			$self->_emit_characters($res) if defined $res;
		}
		else {
			$self->_ch->characters({Data => $item});
		}
	}
	$self->_ch->characters({Data => $suffix}) if $suffix;
}

sub _do_request {
	my $self = shift;
	my $request = shift;
	my $opts = shift;
	my $line = shift // '';
	my $args = [];
	my $state = {parser => $self, environment => $self->_env, opts => $opts,
		state => $self->_state};

	$line = $self->_expand($line, $opts);

	for (my $i = 0; $i < $request->max_args && length $line; $i++) {
		my $argtype = $request->arg_type->[$i] //
			'TenorSAX::Source::Troff::Argument';
		my $arg = $argtype->parse($request, \$line);
		push @$args, $argtype->evaluate($request, $state, $arg);
		$request->modify($state, $args);
	}

	my $text = $request->perform($state, $args);
	$self->_emit_characters($text) if defined $text;
}

sub _lookup {
	my ($self, $name, $table, $type) = @_;

	if (!exists $table->{$name}) {
		$table->{$name} = $type->new();
	}
	my $clone = $table->{$name}->clone;
	$clone->name($name);
	return $clone;
}

sub _lookup_request {
	my $self = shift;
	my $name = shift;

	return $self->_lookup($name, $self->_requests,
		'TenorSAX::Source::Troff::Request');
}

sub _lookup_number {
	my $self = shift;
	my $name = shift;

	return $self->_lookup($name, $self->_numbers,
		'TenorSAX::Source::Troff::Number');
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

sub _parse_line_compat {
	my $self = shift;
	my $line = shift;
	my $controls = $self->_env->cc . $self->_env->c2;
	my $opts = {compat => 1};

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
		$self->_do_text_line($line, $opts);
	}
}

sub _parse_line {
	my $self = shift;
	my $line = shift;
	my $controls = $self->_env->cc . $self->_env->c2;
	my $opts = {compat => 0};

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
		$self->_do_text_line($line, $opts);
	}
}

sub _do_text_line {
	my $self = shift;
	my $line = shift;
	my $opts = shift;

	$line = $self->_expand($line, $opts);

	if (!length $line) {
		# FIXME: don't depend on .br not being redefined.
		my $request = $self->_lookup_request("br");
		my $opts = {can_break => 1};
		return $self->_do_request($request, $opts);
	}
	elsif ($self->_copy->{enabled}) {
		$self->_copy->{data} .= "$line\n";
	}
	else {
		$self->_emit_characters($line, "\n");
	}
};

sub _lookup_prefix {
	my $self = shift;
	my $qname = shift;
	my $result = {Name => $qname};
	my ($prefix, $local) = (($qname =~ /:/) ? (split /:/, $qname, 2) :
		(undef, $qname));
	my $uri;
	
	if (defined $prefix) {
		$uri = $self->_ch->prefixes->{$prefix} //
			die "Prefix $prefix is not defined";
	}

	$result->{NamespaceURI} = $uri;
	$result->{Prefix} = $prefix;
	$result->{LocalName} = $local;
	return $result;
}

sub _lookup_attribute {
	my ($self, $qname, $value) = @_;
	my $result = $self->_lookup_prefix($qname);

	$result->{Value} = $value;
	return $result;
}

sub _lookup_element {
	my $self = shift;
	my $qname = shift;
	my $attributes = shift // {};
	my $result = $self->_lookup_prefix($qname);

	$result->{Attributes} = {};

	foreach my $attr (keys %$attributes) {
		my $hr = $self->_lookup_attribute($attr, $attributes->{$attr});
		my $key = '{' . ($hr->{NamespaceURI} // '') . '}' . $hr->{LocalName};
		$result->{Attributes}->{$key} = $hr;
	}
	return $result;
}

sub _do_parse {
	my $self = shift;
	my %prefixes = map { $_ => $self->_ch->prefixes->{$_} }
		keys %{$self->_ch->prefixes};

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
			return if !$element || $element->{NamespaceURI} ne $prefixes{_t};
			$ch->start_element($self->_lookup_element('_t:main'));
			$ch->start_element($self->_lookup_element('_t:block',
					$self->_state_to_hash(1)));
			return;
		}
	);

	while (@{$self->_data}) {
		my $line = shift @{$self->_data};

		if ($self->_compat) {
			$self->_parse_line_compat($line);
		}
		else {
			$self->_parse_line($line);
		}
	}

	$self->_ch->end_element($self->_lookup_element('_t:block'));
	$self->_ch->end_element($self->_lookup_element('_t:main'));
	foreach my $prefix (keys %prefixes) {
		$self->_ch->end_prefix_mapping(
			{
				Prefix=>$prefix, 
				NamespaceURI=>$prefixes{$prefix},
			}
		);
	}
	$self->_ch->end_document({});
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
