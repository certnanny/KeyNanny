#!/usr/bin/env perl
#

use strict;
use warnings;

use Test::More;

use_ok( 'KeyNanny::Connector' );

my $conn = KeyNanny::Connector->new({
    LOCATION => 'tmp/keynanny.socket',
});

ok($conn->exists('foo'), 'foo exists');
is($conn->get_meta('foo')->{TYPE}, 'scalar', 'Meta');
is($conn->get('foo'), 'secret', 'foo');
is($conn->get('bar'), 'othersecret', 'bar');
is($conn->get('baz'), '', 'non existing');

done_testing;

