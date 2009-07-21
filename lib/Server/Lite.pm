package Server::Lite;

use strict;
use warnings;
use HTTP::Server::Simple;
use parent qw/HTTP::Server::Simple::Recorder HTTP::Server::Simple::CGI/;
use IO::Socket::SSL;
use IO::File;
use Regexp::Common qw /URI/;
use DateTime;
use FindBin qw/$Bin/;
use Getopt::Long;
use DateTime;

my $log_file = "server-lite.log";
my $pid_file = "server-lite.pid";
my $port     = "80808";

GetOptions(
    "l|log=s"         => \$log_file,    
    "pid|pidfile=s"   => \$pid_file,      
    "p|port"          => \$port     
);
  
my %dispatch = (

    '/do' => \&handle_it,

);

sub recorder_prefix {     # set the log file for recorder
    $log_file;
}

sub net_server {
    "Net::Server::PreForkSimple";
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
    
    my $dir             = "$Bin/../tasks" or $ARGV[1];      # second cmd line argument
    my $prefix          = $cgi->param('prefix');
    my $goes_in_queue   = $cgi->param('to_queue');
    my $to_url          = $cgi->param('url');
    my $now             = DateTime->now;
    
    print $cgi->header;
    
    unless ( !$prefix or !$goes_in_queue or $to_url !~ /$RE{URI}{HTTP}/ ) {
    
        my $fh = new IO::File;
        my $log = new IO::File;
        
        if ($fh->open("> $dir/$goes_in_queue$now") and $log->open(">> $log_file") ) {
        
            print $fh "$goes_in_queue" or print $cgi->h1("File IO Error:$!");
            $fh->close;
            
            print $log DateTime->now . "\t" . $cgi->remote_addr . "\t" . "URL: $to_url\t" .
                  "Prefix: $prefix \t Command: $goes_in_queue \t Status: Success\n" or print $cgi->h1("Logging error: $!");
            $log->close;
            
            
        }
        
                      
        print $cgi->start_html('Success!'),
              $cgi->h1("Successfully handled request"),
              $cgi->end_html;
        
    } else {
      
        my $log = new IO::File;
        print $cgi->start_html('Fail!'),
              $cgi->h1("Missing required parameters!"),
              $cgi->end_html;
        if ( $log->open(">> $log_file") ) {
            print $log DateTime->now . "\t" . $cgi->remote_addr . "\t" . "URL: $to_url\t" .
                      "Prefix: $prefix \t Command: $goes_in_queue \t Status: Failed \t Query string: $cgi->query_string\n" 
                      or print $cgi->h1("Logging error: $!");
            $log->close;
        }
              
    }
    
}

1;
