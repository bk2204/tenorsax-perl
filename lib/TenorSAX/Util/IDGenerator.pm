package TenorSAX::Util::IDGenerator;

use v5.14;
use strict;
use warnings;

use warnings qw/FATAL utf8/;
use utf8;
no feature 'unicode_strings';

use Moose;
use namespace::autoclean;
use Digest::SHA;

has 'seed' => (
	is => 'ro',
	default => sub {
		require Bytes::Random::Secure;
		return Bytes::Random::Secure::random_bytes(32);
	},
);
has 'counter' => (
	is => 'rw',
	default => 0,
);
has 'version' => (
	is => 'ro',
	default => 0,
);
has 'key' => (
	is => 'rw',
	default => undef,
);
has 'prefix' => (
	is => 'ro',
	default => 'tsid',
);
has 'length' => (
	is => 'ro',
	default => 20,
);

# Hashes distinctly for undef and all defined values.  Numbers are converted to
# their string representation.
sub _hash_value {
	my ($self, $value) = @_;

	# This is the SHA-256 hash of "0".
	return
		"\x5f\xec\xeb\x66\xff\xc8\x6f\x38\xd9\x52\x78\x6c\x6d\x69\x6c\x79" .
		"\xc2\xdb\xc2\x39\xdd\x4e\x91\xb4\x67\x29\xd7\x3a\x27\xfb\x57\xe9"
		unless defined $value;
	return Digest::SHA::sha256("1$value");
}

sub _init_key {
	my ($self) = @_;

	return if defined $self->key;

	$self->key(Digest::SHA::sha256(join("", map { $self->_hash_value($_) }
				($self->version, $self->seed, $self->prefix))));

	return;
};

=head1 Methods

=over 4

=item $idg->id(%attrs)

Generates an ID suitable for use with in an xml:id attribute.  attrs can
include:

=over 4

=item text

The text over which to process the data.  This is optional.

=back

If no attributes are provided, the overhead is that of three single-block
SHA-256 hashes.  The algorithm used does not guarantee unique IDs.  However, the
likelihood of generating two identical IDs is 1 in 2**(6*C<length>), which is
extremely unlikely.  There is a similar, but weaker guarantee, if the ID is
treated case-insensitively.

=cut

sub id {
	my ($self, %attrs) = @_;

	$self->_init_key;

	my $rand_val = Digest::SHA::hmac_sha256_base64(join("", map {
				$self->_hash_value($_)
			} ($attrs{text}, $self->counter)), $self->key);
	$rand_val =~ tr{+/}{_.};
	$self->counter($self->counter + 1);

	return $self->prefix . substr($rand_val, 0, $self->length);
}

=back

=cut

no Moose;
__PACKAGE__->meta->make_immutable;

1;
