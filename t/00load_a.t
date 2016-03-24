use strict;
use warnings;
use Test::More;

BEGIN { use_ok('WWW::Shorten::TinyURL') or BAIL_OUT("Can't use module"); }

can_ok('WWW::Shorten::TinyURL', qw(shorterlink_start shorterlink_result longerlink_start longerlink_result));

done_testing();
