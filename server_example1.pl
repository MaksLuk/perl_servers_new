#!/usr/bin/perl -w
use IO::Socket;
use Net::hostent;

# for OO version of gethostbyaddr
$PORT = 9000;

$server = IO::Socket::INET->new(
    Proto => 'tcp',
    LocalPort => $PORT,
    Listen => SOMAXCONN,
    Reuse => 1
);
die "can't setup server" unless $server;

print "[Server $0 accepting clients]\n";

while ($client = $server->accept()) {
    $client->autoflush(1);
    print $client "Welcome to $0; type help for command list.\n";
    $hostinfo = gethostbyaddr($client->peeraddr);
    printf "[Connect from %s]\n", $hostinfo->name || $client->peerhost;
    print $client "Command? ";
    while ( <$client>) {
        next unless /\S/;
        if (/quit|exit/i) { last; }
        elsif (/date|time/i) { printf $client "%s\n", scalar localtime; }
        elsif (/who/i ) { print $client `who 2>&1`; }
        elsif (/cookie/i ) { print $client `/usr/games/fortune 2>&1`; }
        elsif (/motd/i ) { print $client `cat /etc/motd 2>&1`; }
        else {
            print $client "Commands: quit date who cookie motd\n";
        }
    } continue {
        print $client "Command? ";
    }
    close $client;
}
