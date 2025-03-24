#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket;
use Net::hostent;
use Proc::Daemon;
use Sys::Syslog;
use POSIX qw(WNOHANG); 

# Конфигурация
my $PORT = 9000;
my $PID_FILE = '/var/run/myserver.pid';
my $LOG_FILE = '/home/student/Загрузки/perl_servers_new/servers/myserver.txt';
my $ERR_FILE = '/var/log/myserver.err';

require "/home/student/Загрузки/perl_servers_new/servers/funcs.pl";

# Инициализация демона
my $daemon = Proc::Daemon->new(
    pid_file => $PID_FILE,
    work_dir => '/',
    close_all_fds => 1,
    child_STDOUT => $LOG_FILE,
    child_STDERR => $ERR_FILE
);

my $server_pid = $daemon->Init;

unless ($server_pid) {
    # Код, выполняемый только в дочернем процессе (демоне)
    openlog('myserver', 'pid', 'daemon');
    syslog('info', "Server started (PID $$)");

    # Обработчики сигналов
    $SIG{TERM} = \&graceful_shutdown;
    $SIG{CHLD} = sub { while (waitpid(-1, WNOHANG) > 0) {} };

    # Создание серверного сокета
    my $server = IO::Socket::INET->new(
        Proto     => 'tcp',
        LocalPort => $PORT,
        Listen    => SOMAXCONN,
        Reuse     => 1
    ) or do {
        syslog('err', "Can't setup server: $!");
        closelog();
        exit(1);
    };

    syslog('info', "Server accepting clients on port $PORT");

    # Основной цикл
    while (1) {
        next unless my $client = $server->accept();
        
        my $hostinfo = gethostbyaddr($client->peeraddr);
        syslog('info', "Connect from %s", $hostinfo->name || $client->peerhost);

        # Обработка подключения
        my $pid = fork();
        if (!defined $pid) {
            syslog('err', "Cannot fork: $!");
            next;
        } elsif ($pid == 0) {
            close($server);
            handle_client($client, $server);
            exit(0);
        } else {
            close($client);
        }
    }

    close $server;
    closelog();
}

if (-e $PID_FILE) {
    chmod 0644, $PID_FILE;  # Разрешить чтение другим пользователям
} else {
    syslog('err', "Failed to create PID file!");
}

sub graceful_shutdown {
    syslog('info', "Shutting down server");
    unlink $PID_FILE;
    exit(0);
}

