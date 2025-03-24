#!/usr/bin/perl -w
use strict;
use warnings;
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

    # Форким процесс для обработки клиента
    my $pid = fork();
    if (!defined $pid) {
        die "Cannot fork: $!";
    } elsif ($pid == 0) {
        # Дочерний процесс
        close($server); # Закрываем слушающий сокет в дочернем процессе
        handle_client($client, $server);
        exit(0); # Завершаем дочерний процесс после обработки клиента
    } else {
        # Родительский процесс
        close($client); # Закрываем клиентский сокет в родительском процессе
    }
}

close $server;
