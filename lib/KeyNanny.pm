package KeyNanny;
#
# KeyNanny provides a framework to protect sensitive data on a Unix host.
#
# Copyright (c) 2014 The CertNanny Project
#
# Licensed under the Apache License, Version 2.0 and the GNU General Public License, Version 2.0.
# See the LICENSE file for details.
#
use strict;
use warnings;


# empty base class
sub new {
    my $class = shift;
    my $arg = shift;

    my $self = {};

    bless($self, $class);
    return $self;
}


1;
