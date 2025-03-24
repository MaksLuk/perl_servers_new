#!/usr/bin/perl -w

use strict;
use IO::Socket;
use Net::hostent;

require "/home/student/Загрузки/perl_servers_new/servers/funcs.pl";

# Порт сервера
my $PORT = 9000;

# Создаем серверный сокет
my $server = IO::Socket::INET->new(
    Proto     => 'tcp',
    LocalPort => $PORT,
    Listen    => SOMAXCONN,
    Reuse     => 1
) or die "Can't setup server: $!";

print "[Server $0 accepting clients on port $PORT]\n";

# Основной цикл сервера
while (my $client = $server->accept()) {
    $client->autoflush(1);

    # Информация о клиенте
    my $hostinfo = gethostbyaddr($client->peeraddr);
    printf "[Connect from %s]\n", $hostinfo->name || $client->peerhost;

    handle_client($client, $server);
}

close $server;

