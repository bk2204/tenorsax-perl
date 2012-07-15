package TenorSAX::Util::FancyContentHandler;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
use feature qw/unicode_strings/;

use Moose;

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
	$self->handler->start_document(@args);
}

sub end_document {
	my ($self, @args) = @_;
	$self->handler->end_document(@args);
}

# Counts the number of parent elements that have the attributes specified by
# args.
sub in_element {
	my ($self, $args) = @_;
	my $count = 0;

	ITEM: foreach my $item (@{$self->_stack}) {
		next unless $item->{type} eq 'element';
		my $value = $item->{value};
		foreach my $key (keys $args) {
			next ITEM unless exists $value->{$key} &&
				$value->{$key} eq $args->{$key};
		}
		$count++;
	}
	return $count;
}

# This function automatically determines the required prefixes for the mappings
# and if they have not already been mapped, calls start_prefix_mapping to set
# them up.
sub start_element {
	my ($self, $element) = @_;
	my $item = {type => 'element', value => \%{$element}};

	my @prefixes = keys %{$self->prefixes};
	my %needed = map { $_ => 1 } ($element->{Prefix} // (),
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

	push @{$self->_stack}, $item;
	$self->handler->start_element($element);
}

sub start_prefix_mapping {
	my ($self, $mapping) = @_;
	my $item = {type => 'prefix', value => \%{$mapping}};

	push @{$self->_stack}, $item;
	$self->handler->start_prefix_mapping($mapping);
}

sub end_element {
	my ($self, $element) = @_;

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
			$self->handler->end_prefix_mapping($self, $item->{value});
		}
	}
	return $ret;
}

sub end_prefix_mapping {
	my ($self, @args) = @_;

	my $ret;
	while (@{$self->_stack}) {
		my $item = pop @{$self->_stack};
		if ($item->{type} eq 'element') {
			push @{$self->_stack}, $item;
			last;
		}
		elsif ($item->{type} eq 'prefix') {
			$self->handler->end_prefix_mapping($self, $item->{value});
		}
	}
}

sub characters {
	my ($self, @args) = @_;
	$self->handler->characters(@args);
}

sub ignorable_whitespace {
	my ($self, @args) = @_;
	$self->handler->ignorable_whitespace(@args);
}

sub processing_instruction {
	my ($self, @args) = @_;
	$self->handler->processing_instruction(@args);
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
