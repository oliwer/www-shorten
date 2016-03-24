use strict;
use warnings;

use Test::More;
use Try::Tiny qw(try catch);
use WWW::Shorten;

my $res = try { WWW::Shorten->import(':invalid'); undef } catch { $_ };
ok($res, 'Importing invalid tag failed');

done_testing();
