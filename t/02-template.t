#!/usr/bin/env perl
#

use strict;
use warnings;

use Test::More;
use lib qw( t/MOCKLIB );

use_ok( 'KeyNanny' );
my $kn;

my $perl = $^X;
my $script = 'bin/keynanny';

$kn = KeyNanny->new();

sub okdiff {
    my ($n1, $n2, $text) = @_;
    my $diff = `diff $n1 $n2 2>&1`;
    chomp($diff);
    return is($diff, '', $text);
}

my $stdout = `$perl -It/MOCKLIB $script --variable=key1 template t/02-template.d/tt-1.conf.in`;
is($?, 0, 'rc of template tt-1.in');
like($stdout, qr{pass = "1yek"}, 'check that key1 was reversed');

system($perl, '-It/MOCKLIB', $script, '--variable=key1', '--outfile', 't/02-template.d/tt-1.conf',
    'template', 't/02-template.d/tt-1.conf.in');
is($?, 0, 'rc of template tt-1.conf.in written to tt-1.conf');

okdiff('t/02-template.d/tt-1.conf', 't/02-template.d/tt-1.conf.orig');

done_testing;
