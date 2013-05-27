package TenorSAX::Util::HandlerGenerator;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;

use Moose;
use namespace::autoclean;

=head1 Methods

=over 4

=item $hg->generate(@stack)

Takes a list of hashrefs defining a series of SAX filters and writers and
returns the first item in the chain.  The writer should be the last item in the
list.  Each hashref may have one or more of the following items:

=over 4

=item name (mandatory)

The name of the filter or writer class.  This will be passed to require, so do
not pass untrusted input.

=item attributes

A hashref of attributes to pass to the constructor.

=item methods

An arrayref of methods to call on the constructed object.  This can be useful
when the filter needs additional input, such as with XML::Filter::XSLT.  Each
item should be a hashref with the key B<name> providing the method name and
B<args> providing the list of arguments to be passed to the method.

=back

=cut


sub generate {
	my ($self, @stack) = @_;
	my $previous;
	foreach my $handler_args (reverse @stack) {
		my $attributes = $handler_args->{attributes} // {};
		my $methods = $handler_args->{methods} // [];
		my $class = $handler_args->{name};
		eval "require $class" or die "Can't load $class: $@";
		my $handler = $class->new(%$attributes,
			($previous ? (Handler => $previous) : ())
		);
		foreach my $method (@$methods) {
			my $args = $method->{args} || [];
			my $func = $handler->can($method->{name}) or
				die "Can't call method $method->{name} on objects of type $class";
			$handler->$func(@$args);
		}
		$previous = $handler;
	}

	return $previous;
}

=back

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1;

