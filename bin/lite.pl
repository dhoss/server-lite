#!/usr/bin/env perl

use strict;
use warnings;
use Server::Lite;

## start the server
my $pid = Server::Lite->new->background();
$pid->run;
print "Use (sudo) kill $pid to stop server.\n";
