use strict;
use warnings;
use Try::Tiny qw(try catch);
use WWW::Shorten 'TinyURL';
use Test::More tests => 6;

my $url = 'https://metacpan.org/release/WWW-Shorten';
my $prefix = 'http://tinyurl.com/';

{
    my $err = try { makeashorterlink(); } catch { $_ };
    ok($err, 'makeashorterlink: proper error response');
    $err = undef;

    $err = try { makealongerlink(); } catch { $_ };
    ok($err, 'makealongerlink: proper error response');
}

my $return = makeashorterlink($url);

ok($return, 'not a error');
my ($code) = $return =~ /(\w+)$/;
is ( makeashorterlink($url), $prefix.$code, 'make it shorter');
# Slight pause to increase the chance that all of TinyURL's servers
# know about the new link
diag "Sleeping 5 seconds...";
sleep(5);
is ( makealongerlink($prefix.$code), $url, 'make it longer');
is ( makealongerlink($code), $url, 'make it longer by Id',);
