#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket;
use Net::hostent;

my $PORT = 9001;

my $server = IO::Socket::INET->new(
    LocalHost => '0.0.0.0',
    Proto     => 'tcp',
    LocalPort => $PORT,
    Listen    => SOMAXCONN,
    Reuse     => 1
) or die "$!";

print "[Server $0 accepting clients]\n";

while (my $client = $server->accept()) {
    distributed_handle_client($server, $client);
    print "Client disconnected.\n";
    close $client;
}
close $server; 
print "[Server shutting down]\n";

exit 0;

sub distributed_handle_client {
    my ($server, $client) = @_;
    $client->autoflush(1);
    while (my $command = <$client>) {
        chomp $command;
        next unless $command =~ /\S/; # Пропуск пустых строк

        if ($command =~ /000/i) {
            print $client "Goodbye!\n";
            $client->shutdown(1); # Закрываем запись
            last;
        } elsif ($command =~ /001/i) {
            print $client "Commands: 001 - help, 002 - addr, 003 - date, 004 - upload <filename> <mode>, 005 - download <filename>, 000 - quit\n";
        } elsif ($command =~ /002/i) {
            my $client_addr = $client->peerhost;
            print $client "Client address: $client_addr, Server address: ", $server->sockhost, "\n";
        } elsif ($command =~ /003/i) {
            call_the_server_date('127.0.0.3', 6000, $client);
        } elsif ($command =~ /004 (\S+) (\d)/i) {
            my $filename = $1;
            my $mode = $2;
            print "Ready to receive file: $filename\n";
            call_the_server_receive('127.0.0.4', 7000, $client, $filename, $mode);
        } elsif ($command =~ /005 (\S+)/i) {
            my $filename = $1;
            call_the_server_send('127.0.0.5', 8000, $client, $filename);
        } else {
            print $client "Unknown command. Type 'help' for command list.\n";
        }

        # Отправляем маркер конца передачи
        print $client "__END_OF_RESPONSE__\n";
    }
}

sub call_the_server_date {
    my ($host, $port, $client) = @_;
    my $aux_socket = new IO::Socket::INET (
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp'
    ) or die "Could not create socket: $@\n";
    
    while (my $response = <$aux_socket>){
        chomp $response;
        if ($response eq "__END_OF_RESPONSE__"){
            last;
        }
        print $client "$response\n";
    }
    close $aux_socket;
}

sub call_the_server_receive {
    my ($host, $port, $client, $filename, $mode) = @_;
    my $aux_socket = new IO::Socket::INET (
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp'
    ) or die "Could not create socket: $@\n";
    
    print $aux_socket "$filename\n";
    print $aux_socket "$mode\n";
    
    while (<$client>){
        chomp $_;
        print $aux_socket "$_\n";
        last if $_ =~ /__END__/;
    }
    print "File $filename uploaded successfully.\n";
    close $aux_socket;
}

sub call_the_server_send {
    my ($host, $port, $client, $filename) = @_;
    my $aux_socket = new IO::Socket::INET (
        PeerAddr => $host,
        PeerPort => $port,
        Proto    => 'tcp'
    ) or die "Could not create socket: $@\n";
    
    print $aux_socket "$filename\n";
    
    while (<$aux_socket>){
        print $client $_;
        last if $_ eq "END \n";
    }
    print "File $filename uploaded successfully.\n";
    close $aux_socket;
}
