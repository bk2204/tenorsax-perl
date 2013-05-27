package TenorSAX::Util::HandlerGenerator;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;

use Moose;
use namespace::autoclean;

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

no Moose;
__PACKAGE__->meta->make_immutable;

1;

