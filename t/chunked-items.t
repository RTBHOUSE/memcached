#!/usr/bin/perl
# Networked logging tests.

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;

my $server = new_memcached('-m 48');
my $sock = $server->sock;

# We're testing to ensure item chaining doesn't corrupt or poorly overlap
# data, so create a non-repeating pattern.
my @parts = ();
for (1 .. 4000) {
    push(@parts, $_);
}
my $pattern = join(':', @parts);

my $plen = length($pattern);
print STDERR "PATTERN LENGTH: $plen\n";

print $sock "set pattern 0 0 $plen\r\n$pattern\r\n";
is(scalar <$sock>, "STORED\r\n", "stored pattern successfully");

mem_get_is($sock, "pattern", $pattern);

for (1..5) {
    my $size = 400 * 1024;
    my $data = "x" x $size;
    print $sock "set foo$_ 0 0 $size\r\n$data\r\n";
    my $res = <$sock>;
    is($res, "STORED\r\n", "stored some big items");
}

{
    my $max = 1024 * 1024;
    my $big = "a big value that's > .5M and < 1M. ";
    while (length($big) * 2 < $max) {
        $big = $big . $big;
    }
    my $biglen = length($big);

    for (1..100) {
        print $sock "set toast$_ 0 0 $biglen\r\n$big\r\n";
        is(scalar <$sock>, "STORED\r\n", "stored big");
        mem_get_is($sock, "toast$_", $big);
    }
}

done_testing();