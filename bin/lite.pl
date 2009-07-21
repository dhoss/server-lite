#!/usr/bin/env perl

use strict;
use warnings;
use Server::Lite;

## start the server
my $pid = Server::Lite->new->background();
Server::Lite->write_pid($$) or die "issues: $!\n";
print "Use (sudo) kill $pid to stop server.\n";
