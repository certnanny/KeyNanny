#!/usr/bin/env perl
#

use strict;
use warnings;

use Test::More;

use_ok( 'KeyNanny' );
my $kn;

eval { $kn = KeyNanny->new() };
like($@, qr{Attribute \(socketfile\) is required at}, "Check when no socketfile is specified");

my $tmpsockfile = "/tmp/client-lib-test-$$";
eval { $kn = KeyNanny->new( socketfile => $tmpsockfile ) };
like($@, qr{Socketfile .+ does not exist. Stopped}, "Check when no socketfile exists");

# TODO: add mock creation of socketfile and test that it has correct ownership, permissions, etc.



done_testing;
