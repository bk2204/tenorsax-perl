package TenorSAX::Util::FancyContentHandler;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;
use MooseX::NonMoose;
use experimental qw/smartmatch/;

extends 'XML::SAX::Base';

has 'prefixes' => (
	isa => 'HashRef[Str]',
	is => 'rw',
	default => sub { {} },
	init_arg => 'Prefixes',
);
has 'handler' => (
	is => 'rw',
	init_arg => 'Handler',
);
has '_stack' => (
	isa => 'ArrayRef',
	is => 'rw',
	default => sub { [] },
	init_arg => undef
);
has '_ignored' => (
	isa => 'HashRef',
	is => 'rw',
	default => sub { {} },
	init_arg => undef
);
# This function is called on the first characters call if no start_element call
# has occurred before it.  This allows the caller to ensure that some element
# exists before outputting characters.
has 'element_trap' => (
	isa => 'CodeRef',
	is => 'rw',
	default => sub { sub {} },
);
has '_seen_first_element' => (
	isa => 'Bool',
	is => 'rw',
	default => 0,
);

=head1 NAME

TenorSAX::Util::FancyContentHandler - The great new TenorSAX::Source::Troff!

=head1 VERSION

Version 2.00

=cut

=head1 SYNOPSIS

This class provides a wrapper around another object providing the ContentHandler
interface and makes sure that beginning and ending tags, as well as prefix
mappings, are equally balanced.

Perhaps a little code snippet.

    use TenorSAX::Source::Troff;

    my $foo = TenorSAX::Source::Troff->new();
    ...

=cut

sub start_document {
	my ($self, @args) = @_;
	return $self->handler->start_document(@args);
}

sub end_document {
	my ($self, @args) = @_;

	while (@{$self->_stack}) {
		my $item = pop @{$self->_stack};
		if ($item->{type} eq 'element') {
			$self->handler->end_element($item->{value});
		}
		elsif ($item->{type} eq 'prefix') {
			$self->handler->end_prefix_mapping($self, $item->{value});
		}
		elsif ($item->{type} eq 'characters') {
			$self->handler->characters($item->{value})
				if $self->_is_space_preserving;
		}
	}
	return $self->handler->end_document(@args);
}

sub _is_space_preserving {
	my ($self) = @_;

	foreach my $item (reverse @{$self->_stack}) {
		next unless $item->{type} eq 'element';
		my $value = $item->{value};
		my $avalue =
			$value->{Attributes}{'{http://www.w3.org/XML/1998/namespace}space'};
		return $avalue eq "preserve" if defined $avalue;
	}
	return;
}

# Counts the number of parent elements that have the attributes specified by
# args.
sub in_element {
	my ($self, $args) = @_;
	my $count = 0;

	ITEM: foreach my $item (@{$self->_stack}) {
		next unless $item->{type} eq 'element';
		my $value = $item->{value};
		foreach my $key (keys %$args) {
			next ITEM unless exists $value->{$key} &&
				$value->{$key} eq $args->{$key};
		}
		$count++;
	}
	return $count;
}

sub ignore_element {
	my ($self, $qname) = @_;

	$self->_ignored->{$qname} = 1;
	return;
}

# This function automatically determines the required prefixes for the mappings
# and if they have not already been mapped, calls start_prefix_mapping to set
# them up.
sub start_element {
	my ($self, $element) = @_;

	return if $self->_ignored->{$element->{Name}};

	if (!$self->_seen_first_element) {
		$self->_seen_first_element(1);
	}
	elsif (!@{$self->_stack}) {
		die "TenorSAX::Util::FancyContentHandler: attempting to start new root element!";
	}

	my $item = {type => 'element', value => \%{$element}};

	my @prefixes = keys %{$self->prefixes};
	my %needed = map { $_ => 1 } grep { defined $_ } ($element->{Prefix} // (),
		map { $element->{Attributes}->{$_}->{Prefix}  }
		(defined $element->{Attributes} ? keys %{$element->{Attributes}} : ()));
	my %defined = map { $_->{value}->{Prefix} => 1 }
		grep { $_->{type} eq 'prefix' } @{$self->_stack};

	foreach my $prefix (keys %needed) {
		next unless defined $prefix;
		next if $defined{$prefix};
		die "Invalid prefix '$prefix' is not mapped" unless defined
			$self->prefixes->{$prefix};
		$self->start_prefix_mapping({Prefix => $prefix, NamespaceURI =>
				$self->prefixes->{$prefix}});
	}
	my $trap = $self->element_trap;
	$self->element_trap(sub {});
	$self->$trap($element);

	push @{$self->_stack}, $item;
	return $self->handler->start_element($element);
}

sub start_prefix_mapping {
	my ($self, $mapping) = @_;
	my $item = {type => 'prefix', value => \%{$mapping}};

	push @{$self->_stack}, $item;
	return $self->handler->start_prefix_mapping($mapping);
}

sub end_element {
	my ($self, $element) = @_;

	return if $self->_ignored->{$element->{Name}};

	my $state = 0;
	my $ret;
	while (@{$self->_stack}) {
		my $item = pop @{$self->_stack};
		if (!$state && $item->{type} eq 'element') {
			$ret = $self->handler->end_element($item->{value});
			$state = 1 if ($element->{Name} eq $item->{value}->{Name});
			next;
		}
		elsif ($state && $item->{type} eq 'element') {
			push @{$self->_stack}, $item;
			last;
		}
		elsif ($item->{type} eq 'prefix') {
			$self->handler->end_prefix_mapping($item->{value});
		}
		elsif ($item->{type} eq 'characters') {
			$self->handler->characters($item->{value})
				if $self->_is_space_preserving;
		}
	}
	return $ret;
}

sub end_prefix_mapping {
	my ($self, @args) = @_;

	my $ret;
	while (@{$self->_stack}) {
		my $item = pop @{$self->_stack};
		if ($item->{type} =~ m/element|characters/) {
			push @{$self->_stack}, $item;
			last;
		}
		elsif ($item->{type} eq 'prefix') {
			$self->handler->end_prefix_mapping($item->{value});
		}
	}
	return;
}

sub characters {
	my ($self, $data) = @_;
	my $trap = $self->element_trap;

	$self->element_trap(sub {});
	$self->$trap(undef);

	while (@{$self->_stack}) {
		my $item = pop @{$self->_stack};
		if ($item->{type} eq 'characters') {
			$self->handler->characters($item->{value});
		}
		else {
			push @{$self->_stack}, $item;
			last;
		}
	}
	if ($data->{Data} =~ s/\n\z//ms) {
		push @{$self->_stack}, {type => 'characters', value => {Data => "\n"}};
	}
	return $self->handler->characters($data);
}

sub ignorable_whitespace {
	my ($self, @args) = @_;
	return $self->handler->ignorable_whitespace(@args);
}

sub processing_instruction {
	my ($self, @args) = @_;
	return $self->handler->processing_instruction(@args);
}


=pod

=head1 AUTHOR

brian m. carlson, C<< <sandals at crustytoothpaste.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tenorsax at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TenorSAX>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TenorSAX::Util::FancyContentHandler

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

1;
