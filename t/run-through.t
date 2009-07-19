use Test::More tests => 5;
use Socket;
use strict;
use Server::Lite;
my $PORT = 8000 + $$;


my $cmd = "pwd";
my $fileregex = /$cmd.+/;
my $host = gethostbyaddr(inet_aton('localhost'), AF_INET);

my $server=Server::Lite->new($PORT);
is($server->port(),$PORT,'Constructor set port correctly');

my $content=fetch("GET /do HTTP/1.1");
like($content, '/<h1>Missing required parameters!</h1>/', "No parameters, right message");

my $content2=fetch("GET /do?prefix=1 HTTP/1.1");
like($content2, '/<h1>Missing required parameters!</h1>/', "Missing parameters");

my $content3=fetch("GET /do?prefix=1;to_queue=pwd HTTP/1.1");
like($content3, '/<h1>Missing required parameters!</h1>/', "Missing parameters");

my $content4=fetch("GET /do?prefix=1;to_queue=$cmd;url=http://server.com HTTP/1.1");
like($content4, '/<h1>Successfully handled request</h1>/', "All parameters");

ok (-e "../tasks/$fileregex", "File created");
system('rm ../tasks/$fileregex');

sleep(3); # wait just a moment

my $pid=$server->background;


is(kill(9,$pid),1,'Signaled 1 process successfully');




# this function may look excessive, but hopefully will be very useful
# in identifying common problems
sub fetch {

    my @response;
    my $alarm = 0;
    my $stage = "init";

    my %messages =
	( "init" => "inner contemplation",
	  "lookup" => ("lookup of `localhost' - may be caused by a "
		       ."missing hosts entry or broken resolver"),
	  "sockaddr" => "call to sockaddr_in() - ?",
	  "proto" => ("call to getprotobyname() - may be caused by "
		      ."bizarre NSS configurations"),
	  "socket" => "socket creation",
	  "connect" => ("connect() - may be caused by a missing or "
			."broken loopback interface, or firewalling"),
	  "send" => "network send()",
	  "recv" => "collection of response",
	  "close" => "closing socket"
	);

    $SIG{ALRM} = sub {
	@response = "timed out during $messages{$stage}";
	$alarm = 1;
    };

    my ($iaddr, $paddr, $proto, $message);

    $message = join "", map { "$_\015\012" } @_;

    my %states =
	( 'init'     => sub { "lookup"; },
	  "lookup"   => sub { ($iaddr = inet_aton("localhost"))
				  && "sockaddr"			    },
	  "sockaddr" => sub { ($paddr = sockaddr_in($PORT, $iaddr))
				  && "proto"			    },
	  "proto"    => sub { ($proto = getprotobyname('tcp'))
				  && "socket"			    },
	  "socket"   => sub { socket(SOCK, PF_INET, SOCK_STREAM, $proto)
				  && "connect"			    },
	  "connect"  => sub { connect(SOCK, $paddr) && "send"	    },
	  "send"     => sub { (send SOCK, $message, 0) && "recv"    },
	  "recv"     => sub {
	      my $line;
	      while (!$alarm and defined($line = <SOCK>)) {
		  push @response, $line;
	      }
	      ($alarm ? undef : "close");
	  },
	  "close"    => sub { close SOCK; "done"; },
	);

    # this entire cycle should finish way before this timer expires
    alarm(5);

    my $next;
    $stage = $next
	while (!$alarm && $stage ne "done"
	       && ($next = $states{$stage}->()));

    warn "early exit from `$stage' stage; $!" unless $next;

    # bank on the test testing for something in the response.
    return join "", @response;


}


