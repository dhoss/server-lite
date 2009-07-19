#!/usr/bin/env perl

use strict;
use warnings;
use Server::Lite;

## start the server
my $pid = Server::Lite->new($ARGV[0])->background();
print "Use (sudo) kill $pid to stop server.\n";
