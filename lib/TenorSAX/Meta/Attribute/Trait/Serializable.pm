package TenorSAX::Meta::Attribute::Trait::Serializable;

use v5.14;
use strict;
use warnings;

# This code is based on the example provided in
# Moose::Cookbook::Meta::Labeled_AttributeTrait.

use Moose::Role;

Moose::Util::meta_attribute_alias('Serializable');

1;
