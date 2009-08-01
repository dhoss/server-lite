#!/usr/bin/env perl
 
package WMC::Server::Lite::App;
use Moose;
use namespace::autoclean;
use WMC::Server::Lite;
use IO::File;
use MooseX::Types::Moose qw/Str Int/;
 
with 'MooseX::Getopt';
 
has logfile => (
    is => 'ro',
    isa => Str,
    traits => [qw(Getopt)],
    cmd_aliases => 'l',
    documentation => qq{ specify a log name for syslog },
    required => 1,
);
 
has task_dir => (
    is => 'ro',
    isa => Str,
    traits => [qw(Getopt)],
    cmd_aliases => 'dir',
    documentation => qq{ the directory where task queues are stored },
    required => 1,
);
 
has pid_file => (
    is => 'ro',
    isa => Str,
    traits => [qw(Getopt)],
    cmd_aliases => 'pid',
    documentation => qq{ name of the pidfile to be written to },
    required => 1,
);
 
has port => (
    is => 'ro',
    isa => Int,
    traits => [qw(Getopt)],
    cmd_aliases => 'p',
    documentation => qq{ specify a port to listen to },
    required => 1,
);
 
 
sub recorder_prefix { # set the log file for recorder
    DateTime->now . shift->port;
}
 
sub net_server {
    "Net::Server::PreForkSimple";
}
 
sub bad_request {
    print "HTTP/1.0 404 Bad request\r\n";
}
 
sub write_pid {
    my ($self, $pid) = @_;
    my $fh = IO::File->new;
    my $pid_file = $self->pid_file;
 
    if ($fh->open("> $pid_file") ) {
        print $fh "$pid\n";
        undef $fh;
    } else {
        warn("Cannot open: $pid_file: $!");
    }
}
 
sub graceful_shutdown {
    my ($self, $server) = @_;
    my $pid = $self->pid;
    
    print "Shutting down...\n";
    $server->logger->log(
        level => "notice",
        message => "TERM received. Shutting down..."
    );
    `rm $pid`;
 
}
 
sub init {
    my ($self) = shift;
    ## start the server
    if (!@ARGV) {
        print "usage: perl bin/lite.pl [options]\n";
        exit;
    }
    
    my $server = WMC::Server::Lite->new($self->port);
    my $logger = Log::Dispatch::Syslog->new(
     name => $self->logfile,
     min_level => 'info', );
    $server->logger($logger);
    $server->dir($self->task_dir);
    my $pid = $server->background();
    $self->write_pid($pid);
}
 
my $server = __PACKAGE__->new_with_options;
$server->init;
$SIG{'TERM'} = sub { __PACKAGE__->graceful_shutdown($server) };
 
1;
