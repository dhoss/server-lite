#!/usr/bin/env perl

use strict;
use warnings;
use WMC::Server::Lite;

## start the server
my $pid = Server::Lite->new->background();
print "Use (sudo) kill $pid to stop server.\n";
