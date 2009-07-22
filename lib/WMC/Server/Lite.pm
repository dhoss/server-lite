package Server::Lite;

use strict;
use warnings;
use HTTP::Server::Simple;
use parent qw/HTTP::Server::Simple::Recorder HTTP::Server::Simple::CGI/;
use IO::Socket::SSL;
use IO::File;
use Regexp::Common qw /URI/;
use DateTime;
use File::Spec;
use Getopt::Long;
use DateTime;
use Log::Dispatch::Syslog;

$SIG{'TERM'} = \&graceful_shutdown;

my $log_file = "server-lite.log";
my $task_dir  = File::Spec->catdir('tasks');
my $pid_file = "server-lite.pid";
my $port     = "8080";

GetOptions(
    "l|log=s"         => \$log_file, 
    "dir=s"           => \$task_dir,   
    "pid|pidfile=s"   => \$pid_file,      
    "p|port=i"        => \$port     
);

if ($pid_file) {
    my $fh = IO::File->new;
    if (! $fh->open("> $pid_file") ) {
        warn("Cannot open: $pid_file: $!");
    }
    print $fh $$+1 . "\n";
    undef $fh;
}

my $logger = Log::Dispatch::Syslog->new( name      => File::Spec->curdir . $log_file,
                                         min_level => 'info', );


my %dispatch = (

    '/do' => \&handle_it,

);

sub port {
    $port;
}



sub recorder_prefix {     # set the log file for recorder
    $log_file;
}

sub net_server {
    "Net::Server::PreForkSimple";
}

sub bad_request {
    print "HTTP/1.0 404 Bad request\r\n";
}

sub handle_request {
    my ($self, $cgi) = @_;
   
    my $path = $cgi->path_info();
    my $handler = $dispatch{$path};

    if (ref($handler) eq "CODE") {
         print "HTTP/1.0 200 OK\r\n";
         $handler->($cgi);
         
         
     } else {
         print "HTTP/1.0 404 Not found\r\n";
         print $cgi->header,
               $cgi->start_html('Not found'),
               $cgi->h1('Not found'),
               $cgi->end_html;

     }
         
}

#sub accept_hook {
#    my $self = shift;
#    my $fh   = $self->stdio_handle;

#    $self->SUPER::accept_hook(@_);

#    my $newfh =
#    IO::Socket::SSL->start_SSL( $fh, 
#        SSL_server    => 1,
#        SSL_use_cert  => 1,
#        SSL_cert_file => 'myserver.crt',
#        SSL_key_file  => 'myserver.key',
#    )
#    or warn "problem setting up SSL socket: " . IO::Socket::SSL::errstr();

#    $self->stdio_handle($newfh) if $newfh;
#}

sub handle_it {
    my ($cgi) = @_;
    
    return if !ref $cgi;
    
    my $dir             = $task_dir;      # second cmd line argument
    my $prefix          = $cgi->param('prefix')   || "";
    my $goes_in_queue   = $cgi->param('to_queue') || "";
    my $to_url          = $cgi->param('url')      || "";
    my $now             = DateTime->now;
    my $activity        = File::Spec->catdir($dir, "$goes_in_queue$now");
    
    print $cgi->header;
    
    unless ( !$prefix or !$goes_in_queue or $to_url !~ /$RE{URI}{HTTP}/ ) {
    
        my $fh = new IO::File;
        my $log = new IO::File;
        print "activity file: $activity\n";
        if ( $fh->open(">$activity") ){
        
            print $fh "$goes_in_queue" or print $cgi->h1("File IO Error:$!");
            $fh->close;
            
            $logger->log( level => "info", message =>$cgi->remote_addr . "\t" . "URL: $to_url\t" .
                          "Prefix: $prefix \t Command: $goes_in_queue \t Status: Success\n" );
             
            
        }
                      
        print $cgi->start_html('Success!'),
              $cgi->h1("Successfully handled request"),
              $cgi->end_html;
        
    } else {
     
        print $cgi->start_html('Fail!'),
              $cgi->h1("Missing required parameters!"),
              $cgi->end_html;
              
        $logger->log( level => "error", message => $cgi->remote_addr . "\t" . "URL: $to_url\t" .
                      "Prefix: $prefix \t Command: $goes_in_queue \t Status: Failed\n" );
                    
    }
    
}

sub graceful_shutdown {
    my ($cgi) = shift;
    
    print "Shutting down...\n";
    $logger->log( level => "notice", message => "TERM received.  Shutting down..." );
    `rm $pid_file`;

}

1;
