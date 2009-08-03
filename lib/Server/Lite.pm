package Server::Lite;
 
use Moose;
use HTTP::Server::Simple;
use IO::Socket::SSL;
use IO::File;
use Regexp::Common qw /URI/;
use DateTime;
use File::Spec;
use Log::Dispatch::Syslog;
use MooseX::Types::Moose qw/Str Int/;
use namespace::autoclean;
 
extends qw/HTTP::Server::Simple::CGI/ ;
 
has logger => (
    is => 'rw',
    isa => 'Log::Dispatch::Output',
    required => 1,
);
 
has dir => (
    is => 'rw',
    isa => Str,
    required => 1,
);
 
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
         $handler->($self, $cgi);
         
     } else {
         print "HTTP/1.0 404 Not found\r\n";
         print $cgi->header,
               $cgi->start_html('Not found'),
               $cgi->h1('Not found'),
               $cgi->end_html;
 
     }
         
}
 
#sub accept_hook {
# my $self = shift;
# my $fh = $self->stdio_handle;
 
# $self->SUPER::accept_hook(@_);
 
# my $newfh =
# IO::Socket::SSL->start_SSL( $fh,
# SSL_server => 1,
# SSL_use_cert => 1,
# SSL_cert_file => 'myserver.crt',
# SSL_key_file => 'myserver.key',
# )
# or warn "problem setting up SSL socket: " . IO::Socket::SSL::errstr();
 
# $self->stdio_handle($newfh) if $newfh;
#}
 
sub handle_it {
    my ($self, $cgi) = @_;
    
    return if !ref $cgi;
    
    my $dir = $self->dir;
    my $prefix = $cgi->param('prefix');
    my $goes_in_queue = $cgi->param('to_queue');
    my $to_url = $cgi->param('url');
    my $now = DateTime->now;
    my $activity = File::Spec->catdir($dir, "$goes_in_queue$now");
    
    print $cgi->header;
    
    unless ( !$prefix or !$goes_in_queue or $to_url !~ /$RE{URI}{HTTP}/ ) {
    
        my $fh = new IO::File;
        if ( $fh->open(">$activity") ){
            
            print $fh "$goes_in_queue" or print $cgi->h1("File IO Error:$!");
            $fh->close;
            
            $self->logger->log( level => "error", message =>$cgi->remote_addr . "\t" . "URL: $to_url\t" .
                          "Prefix: $prefix \t Command: $goes_in_queue \t Status: Success\n" ); # or die "Error: $!";
            
        }
                      
        print $cgi->start_html('Success!'),
              $cgi->h1("Successfully handled request"),
              $cgi->p("Dir: " . $self->dir),
              $cgi->end_html;
        
    } else {
     
        print $cgi->start_html('Fail!'),
              $cgi->h1("Missing required parameters!"),
              $cgi->end_html;
              
        $self->logger->log( level => "error", message => $cgi->remote_addr . "\t" . "URL: $to_url\t" .
                      "Prefix: $prefix \t Command: $goes_in_queue \t Status: Failed\n" ) or die "Error: $!";
                    
    }
    
}

# ABSTRACT: A really simple server + web application implementation with SSL, HTTP authentication *and* preforking options

=head1 NAME

Server::Simple

=cut

=head1 DESCRIPTION

A really simple server + web application implementation with SSL, HTTP authentication *and* preforking options

=cut 

=head1 SYNOPSIS

    perl  bin/lite.pl --pid /tmp/server-lite.pid --logfile local1 --dir tasks/ --port 3001

=cut

=head1 OPTIONS

pid: specify a pidfile for the server

logfile: a valid syslog service to connect to

dir: the dir to which command queue files will be written to

port: a port to listen to 

=cut

=head1 SEE ALSO

Moose, HTTP::Server::Simple, Log::Dispatch::Syslog

=cut

=head1 AUTHOR

Devin Austin <dhoss@cpan.org>, Jay Kuri <jayk@cpan.org>

=cut

1;
