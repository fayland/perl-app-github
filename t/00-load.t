#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok('App::GitHub');
}

diag(
"Testing App::GitHub $App::GitHub::VERSION, Perl $], $^X"
);
