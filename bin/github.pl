#!/usr/bin/perl

# ABSTRACT: GitHub Command Tools

use strict;
use warnings;

use App::GitHub;

App::GitHub->new->run(@ARGV);

1;