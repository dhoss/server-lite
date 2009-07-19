package Server::Lite;

use strict;
use warnings;
use HTTP::Server::Simple;
use parent 'HTTP::Server::Simple::CGI';
use IO::Socket::SSL;
use IO::File;
use Regexp::Common qw /URI/;
use DateTime;
use FindBin qw/$Bin/;


my %dispatch = (

    '/do' => \&handle_it,

);

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
    
    unless ( !$prefix or $to_url !~ /$RE{URI}{HTTP}/ ) {
    
        my $fh = new IO::File;
        if ($fh->open("> $dir/$goes_in_queue$now")) {
        
            print $fh "$goes_in_queue" or print $cgi->h1("File IO Error:$!");
            $fh->close;
            
        }
                      
        print $cgi->start_html('Success!'),
              $cgi->h1("Successfully handled request"),
              $cgi->end_html;
        
    } else {
    
        print $cgi->start_html('Fail!'),
              $cgi->h1("Missing required parameters!"),
              $cgi->end_html;
              
    }
    
}

1;
