package WMC::Server::Lite;

use Moose;
use HTTP::Server::Simple;
use IO::Socket::SSL;
use IO::File;
use Regexp::Common qw /URI/;
use DateTime;
use File::Spec;
use Log::Dispatch::Syslog;
use Data::Dumper;
use MooseX::Types::Moose qw/Str Int/;
use namespace::autoclean;

extends qw/HTTP::Server::Simple::CGI/ ;

sub get_dispatch {
     my ($self, $path) = @_;
     my %dispatch = (
        '/do' => \&handle_it,
     );
     
     return $dispatch{$path};

}

sub handle_request {
    my ($self, $cgi) = @_;
   
    my $path = $cgi->path_info();
    my $handler = $self->get_dispatch($path);

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
    
    my $dir             = get_task_dir();
    my $prefix          = $cgi->param('prefix');
    my $goes_in_queue   = $cgi->param('to_queue');
    my $to_url          = $cgi->param('url');
    my $now             = DateTime->now;
    my $activity        = File::Spec->catdir($dir, "$goes_in_queue$now");
    
    print $cgi->header;
    
    unless ( !$prefix or !$goes_in_queue or $to_url !~ /$RE{URI}{HTTP}/ ) {
    
        my $fh = new IO::File;
        if ( $fh->open(">$activity") ){
            
            print $fh "$goes_in_queue" or print $cgi->h1("File IO Error:$!");
            $fh->close;
            
            get_logger->log( level => "info", message =>$cgi->remote_addr . "\t" . "URL: $to_url\t" .
                          "Prefix: $prefix \t Command: $goes_in_queue \t Status: Success\n" ) or die "Error: $!";
            
        }
                      
        print $cgi->start_html('Success!'),
              $cgi->h1("Successfully handled request"),
              $cgi->p("Dir: " . get_task_dir()),
              $cgi->end_html;
        
    } else {
     
        print $cgi->start_html('Fail!'),
              $cgi->h1("Missing required parameters!"),
              $cgi->end_html;
              
        get_logger->log( level => "error", message => $cgi->remote_addr . "\t" . "URL: $to_url\t" .
                      "Prefix: $prefix \t Command: $goes_in_queue \t Status: Failed\n" ) or die "Error: $!";
                    
    }
    
}

1;
