#!/usr/bin/perl -w
### client.pl - Пример клиента ###
use strict;
use warnings;
use IO::Socket;
use JSON::PP;

my $server = IO::Socket::INET->new(
    PeerAddr => 'localhost',
    PeerPort => 9000,
    Proto    => 'tcp'
) or die "Can't connect: $!";

print "Enter command (e.g. 003): ";
my $command = <STDIN>;
chomp $command;

print $server encode_json({
    type    => 'REQUEST',
    command => $command,
    data    => {} # Можно передавать параметры
});

my $response = <$server>;
print "Response: ", decode_json($response)->{data}, "\n";
close $server;
