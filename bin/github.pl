#!/usr/bin/perl

use strict;
use warnings;

use App::GitHub;

App::GitHub->new->run(@ARGV);

1;