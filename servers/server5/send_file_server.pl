#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket;
use Net::hostent;

my $PORT = 8000;

my $server = IO::Socket::INET->new(
    LocalHost => '127.0.0.5',
    Proto     => 'tcp',
    LocalPort => $PORT,
    Listen    => SOMAXCONN,
    Reuse     => 1
) or die "$!";

print "[Send file server accepting clients]\n";

while (my $client = $server->accept()) {
    print "Main server send request\n";

    my $filename = <$client>;
    chomp $filename;

    print $client "Sending file: $filename\n";
    open(my $fh, '<', $filename) or die "Can't open file: $!";
    while (<$fh>) {
        print $client $_;
    }
    close($fh);
    print $client "END \n"; # Маркер конца файла
    close $client;

    print "File sending successfully\n";
}
close $server; 

exit 0;

