#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket;
use Net::hostent;

require "/home/student/Загрузки/perl_servers_new/servers/funcs.pl";

my $PORT = 9000;
my $num_workers = 5;  # Количество предварительно созданных воркеров

# Создание серверного сокета
my $server = IO::Socket::INET->new(
    Proto     => 'tcp',
    LocalPort => $PORT,
    Listen    => SOMAXCONN,
    Reuse     => 1
) or die "Can't setup server: $!";

print "[Server $0 with $num_workers workers started on port $PORT]\n";

# Создание пула воркеров
for (1..$num_workers) {
    my $pid = fork();
    die "Can't fork worker: $!" unless defined $pid;
    
    if ($pid == 0) {
        # Код для воркера
        $SIG{__WARN__} = sub {};  # Подавление предупреждений
        $SIG{__DIE__} = sub {};   # Подавление фатальных ошибок
        
        while (1) {
            my $client;
            eval {
                $client = $server->accept();
            };
            
            if ($@ || !$client) {
                warn "Accept error: $!" if !$client;
                next;
            }
            
            $client->autoflush(1);
            my $hostinfo = gethostbyaddr($client->peeraddr);
            printf "[Connect from %s]\n", $hostinfo->name || $client->peerhost;
            
            eval {
                handle_client($client, $server);
            };
            if ($@) {
                warn "Client handling error: $@";
            }
            close($client);
        }
        exit 0;  # Воркер не должен сюда дойти
    }
}

# Родитель закрывает сокет и следит за воркерами
close($server);
while (1) {
    my $pid = wait();
    last if $pid == -1;
    print "Worker $pid exited. Consider restarting.\n";
}

