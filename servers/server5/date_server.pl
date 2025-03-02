#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket;
use Net::hostent;

my $PORT = 6000;

my $server = IO::Socket::INET->new(
    LocalHost => '127.0.0.3',
    Proto     => 'tcp',
    LocalPort => $PORT,
    Listen    => SOMAXCONN,
    Reuse     => 1
) or die "$!";

print "[Date server accepting clients]\n";

while (my $client = $server->accept()) {
    print "Main server send request\n";
    print $client scalar localtime, "\n";
    print $client "__END_OF_RESPONSE__\n";
    close $client;  
}
close $server; 

exit 0;
