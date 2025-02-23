#!/usr/bin/perl -w
### load_balancer.pl - Главный распределяющий сервер ###
use strict;
use warnings;
use IO::Socket;
use JSON::PP;
use Proc::Daemon;

my $PORT = 9000;
my $services = {}; # Хранилище сервисов: {command => [host, port]}

# Запуск в режиме демона
Proc::Daemon::Init;

my $server = IO::Socket::INET->new(
    LocalPort => $PORT,
    Listen    => SOMAXCONN,
    Reuse     => 1,
    Proto     => 'tcp'
) or die "Can't create server: $!";

print "Main server started on port $PORT\n";

while (my $client = $server->accept()) {
    $client->autoflush(1);
    my $pid = fork();
    
    unless ($pid) {
        handle_connection($client);
        exit;
    }
    close $client;
}

sub handle_connection {
    my ($client) = @_;
    my $msg;
    
    while (<$client>) {
        chomp;
        $msg = decode_json($_);
        
        if ($msg->{type} eq 'REGISTER') {
            # Регистрация сервиса
            $services->{$msg->{command}} = {
                host => $msg->{host},
                port => $msg->{port}
            };
            print "Registered service for command $msg->{command}\n";
        } 
        elsif ($msg->{type} eq 'REQUEST') {
            # Перенаправление запроса клиента
            my $service = $services->{$msg->{command}};
            
            if ($service) {
                my $response = forward_request($service, $msg->{data});
                print $client encode_json({status => 'OK', data => $response});
            } else {
                print $client encode_json({status => 'ERROR', data => 'Service not found'});
            }
        }
    }
    close $client;
}

sub forward_request {
    my ($service, $data) = @_;
    my $sock = IO::Socket::INET->new(
        PeerAddr => $service->{host},
        PeerPort => $service->{port},
        Proto    => 'tcp'
    ) or return "Service unavailable";
    
    print $sock encode_json({data => $data});
    my $response = <$sock>;
    close $sock;
    return decode_json($response)->{data};
}
