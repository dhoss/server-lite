#!/usr/bin/env perl

use strict;
use warnings;
use WMC::Server::Lite;

## start the server
my $server = WMC::Server::Lite->new(@ARGV);
$server->background();
