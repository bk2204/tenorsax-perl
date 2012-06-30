package TenorSAX::Source::Troff;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;

use TenorSAX::Source::Troff::Argument;
use TenorSAX::Source::Troff::Environment;
use TenorSAX::Source::Troff::Request;
use TenorSAX::Source::Troff::Request::Implementation;
use TenorSAX::Util::FancyContentHandler;

extends 'XML::SAX::Base';

has '_ec' => (
	isa => 'Str',
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
has '_ch' => (
	is => 'rw',
	init_arg => 'Handler',
);
has '_compat' => (
	isa => 'Int',
	is => 'rw',
	default => 1,
	init_arg => undef,
);
has '_state' => (
	isa => 'Int',
	is => 'rw',
	default => 0,
	init_arg => undef,
);
has '_env' => (
	isa => 'TenorSAX::Source::Troff::Environment',
	is => 'rw',
	default => sub { TenorSAX::Source::Troff::Environment->new(); },
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
					t => 'http://ns.crustytoothpaste.net/troff',
					tm => 'http://ns.crustytoothpaste.net/text-markup',
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

sub _do_request {
	my $self = shift;
	my $request = shift;
	my $opts = shift;
	my $line = shift;
	my $args = [];
	my $state = {parser => $self, environment => $self->_env};

	for (my $i = 0; $i < $request->max_args && $line; $i++) {
		my $argtype = $request->arg_type->[$i] //
			'TenorSAX::Source::Troff::Argument';
		my $arg = $argtype->parse($request, \$line);
		push @$args, $arg;
	}

	my $text = $request->perform($state, $args);
	$self->_ch->characters({Data => $text}) if defined $text;
}

sub _lookup_request {
	my $self = shift;
	my $request = shift;
	my $table = $self->_requests;

	if (!exists $table->{$request}) {
		$table->{$request} = TenorSAX::Source::Troff::Request->new();
	}
	return $table->{$request};
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
		$self->_do_text_line($line);
	}
	elsif ($line =~ s/^([$controls])(\X{0,2}?)([ \t]+|$)//u ||
		$line =~ s/^([$controls])(\X{2}?)(\X+|$)//u) {
		my $request = $self->_lookup_request($2);
		$opts->{can_break} = $1 eq $self->_env->cc;
		$opts->{compat} = 0 if $request->disable_compat;
		$self->_do_request($request, $opts, $line);
	}
	else {
		$self->_do_text_line($line);
	}
}

sub _parse_line {
	my $self = shift;
	my $line = shift;
	my $controls = $self->_env->cc . $self->_env->c2;
	my $opts = {compat => 1};

	if ($self->_copy->{enabled} && $line =~ $self->_copy->{pattern}) {
		$self->_copy->{enabled} = 0;
	}
	elsif ($self->_copy->{enabled}) {
		$self->_do_text_line($line);
	}
	elsif ($line =~ s/^([$controls])(\X*?)([ \t]+|$)//u) {
		my $request = $self->_lookup_request($2);
		$opts->{can_break} = $1 eq $self->_env->cc;
		$self->_do_request($request, $opts, $line);
	}
	else {
		$self->_do_text_line($line);
	}
}

sub _do_text_line {
	my $self = shift;
	my $line = shift;

	if (!length $line) {
		# FIXME: don't depend on .br not being redefined.
		my $request = $self->_lookup_request("br");
		my $opts = {can_break => 1};
		return $self->_do_request($opts, $request, $line);
	}
	elsif ($self->_copy->{enabled}) {
		$self->_copy->{data} .= "$line\n";
	}
	else {
		# TODO: process this.
		$self->_ch->characters({Data => "$line\n"});
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

sub _lookup_attribute{
	my ($self, $qname, $value) = @_;
	my $result = $self->_lookup_prefix($qname);

	$result->{Value} = $value;
	return $result;
}

sub _lookup_element{
	my $self = shift;
	my $qname = shift;
	my $attributes = shift // {};
	my $result = $self->_lookup_prefix($qname);

	$result->{Attributes} = {};

	foreach my $attr (keys %$attributes) {
		my $hr = $self->_lookup_attribute($attr);
		my $key = '{' . $hr->{NamespaceURI} // '' . '}' . $hr->{LocalName};
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
	$self->_ch->start_element($self->_lookup_element('t:main'));

	while (@{$self->_data}) {
		my $line = shift @{$self->_data};

		if ($self->_compat) {
			$self->_parse_line_compat($line);
		}
		else {
			$self->_parse_line($line);
		}
	}

	$self->_ch->end_element($self->_lookup_element('t:main'));
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

1; # End of TenorSAX::Source::Troff
