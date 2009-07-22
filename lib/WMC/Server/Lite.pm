package WMC::Server::Lite;

use strict;
use warnings;
use HTTP::Server::Simple;
use parent qw/HTTP::Server::Simple::CGI/;
use IO::Socket::SSL;
use IO::File;
use Regexp::Common qw /URI/;
use DateTime;
use File::Spec;
use Getopt::Long;
use DateTime;
use Log::Dispatch::Syslog;
use Data::Dumper;

$SIG{'TERM'} = \&graceful_shutdown;

sub new {
    my $class = ref $_[0] || $_[0];
    
    my $log_file;
    my $task_dir;
    my $pid_file;
    my $port;
       
    GetOptions(
        "l|log=s"         => \$log_file, 
        "d|dir=s"         => \$task_dir,   
        "pid|pidfile=s"   => \$pid_file,      
        "p|port=i"        => \$port     
    );

	my $self = bless {
		task_dir  => $task_dir,
	    pidfile   => $pid_file,
	    port      => $port,	
	    logger    => Log::Dispatch::Syslog->new( 
	                   name      => $log_file,
                       min_level => 'info', ),
    }, $class;

	$self;


}

sub get_dispatch {
     my ($self, $path) = @_;
     my %dispatch = (
        '/do' => \&handle_it,
     );
     
     return $dispatch{$path};

}

sub background {
    my $self = shift;
    my $pid_file = $self->{pidfile};
    my $pid = $self->SUPER::background;
    
    my $fh = IO::File->new;
    if ($fh->open("> $pid_file") ) {
        print $fh "$pid\n";
        undef $fh;
    } else {
        warn("Cannot open: $pid_file: $!");
    }
    
    $pid;
        
}

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

sub graceful_shutdown {
    my ($self, $cgi) = @_;
    
    print "Shutting down...\n";
    $self->{logger}->log( level => "notice", message => "TERM received.  Shutting down..." );
    `rm $self->{pidfile}`;

}

sub get_logger {
    my $self = shift;
    return $self->{logger};
}

sub get_task_dir {
    my $self = shift;
    return $self->{task_dir};
}

1;
