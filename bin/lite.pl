#!/usr/bin/env perl

use Moose;
use namespace::autoclean;
use WMC::Server::Lite;
use IO::File;
use MooseX::Types::Moose qw/Str Int/;

with 'MooseX::Getopt';

has logfile     => ( 
    is            => 'ro', 
    isa           => Str,
    traits        => [qw(Getopt)],
    cmd_aliases   => 'l',
    documentation => qq{ specify a log name for syslog },
);

has task_dir => (
    is            => 'ro', 
    isa           => Str,
    traits        => [qw(Getopt)],
    cmd_aliases   => 'dir',
    documentation => qq{ the directory where task queues are stored },
);

has pid_file => (
    is            => 'ro',
    isa           => Str,
    traits        => [qw(Getopt)],
    cmd_aliases   => 'pid',
    documentation => qq{ name of the pidfile to be written to },
);

has port     => (
    is            => 'ro',
    isa           => Int,
    traits        => [qw(Getopt)],
    cmd_aliases   => 'p',
    documentation => qq{ specify a port to listen to },
);

has logger   => (
    is            => 'ro', 
    isa           => Int,
    default       => 
        sub {
            Log::Dispatch::Syslog->new( 
	                   name      => $self->logfile,
                       min_level => 'info', )
        }
);

sub port {
    shift->{port};
}



sub recorder_prefix {     # set the log file for recorder
    shift->{logger};
}

sub net_server {
    my $self = shift;
    "Net::Server::PreForkSimple";
}

sub bad_request {
    print "HTTP/1.0 404 Bad request\r\n";
}

sub write_pid {
    my ($self, $pid) = @_;
    my $fh = IO::File->new;
    my $pid_file = $self->pidfile;

    if ($fh->open("> $pid_file") ) {
        print $fh "$pid\n";
        undef $fh;
    } else {
        warn("Cannot open: $pid_file: $!");
    }
}

## start the server
my $server = WMC::Server::Lite->new_with_args(@ARGV);
my $pid = $server->background();
write_pid($pid);

