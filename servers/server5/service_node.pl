#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket;
use JSON::PP;
use Sys::Syslog;

# Аргументы: <команда> <порт>
my ($command, $port) = @ARGV;
die "Usage: $0 <command> <port>\nExample: $0 003 9001\n" unless ($command && $port);

# Конфигурация
my $MAIN_SERVER = 'localhost:9000';
my $MAX_RETRIES = 3;
my $TIMEOUT = 5;

# Инициализация логгера
openlog('service_node', 'pid', 'daemon');
syslog('info', "Starting service node for command $command on port $port");

# Регистрация в главном сервере
my $registered = 0;
for (my $attempt = 1; $attempt <= $MAX_RETRIES; $attempt++) {
    my ($main_host, $main_port) = split(/:/, $MAIN_SERVER);
    
    my $main = IO::Socket::INET->new(
        PeerAddr => $main_host,
        PeerPort => $main_port,
        Proto    => 'tcp',
        Timeout  => $TIMEOUT
    );
    
    if ($main) {
        print $main encode_json({
            type    => 'REGISTER',
            command => $command,
            host    => 'localhost',
            port    => $port,
            pid     => $$
        });
        close $main;
        $registered = 1;
        last;
    }
    
    syslog('warning', "Connection to main server failed (attempt $attempt)");
    sleep 1;
}

unless ($registered) {
    syslog('err', "Failed to register in main server");
    die "Registration failed after $MAX_RETRIES attempts\n";
}

# Запуск сервисного сервера
my $server = IO::Socket::INET->new(
    LocalPort => $port,
    Listen    => SOMAXCONN,
    Reuse     => 1,
    Proto     => 'tcp'
) or do {
    syslog('err', "Can't create service socket: $!");
    die "Service creation failed: $!\n";
};

syslog('info', "Service node ready on port $port");
print STDERR "Service '$command' running on port $port\n";

# Основной цикл обработки запросов
while (1) {
    next unless my $client = $server->accept();
    
    $client->autoflush(1);
    my $pid = fork();
    
    if (!defined $pid) {
        syslog('err', "Fork failed: $!");
        close $client;
        next;
    }
    elsif ($pid == 0) { # Дочерний процесс
        handle_request($client, $command);
        exit 0;
    }
    else { # Родительский процесс
        close $client;
    }
}

sub handle_request {
    my ($client, $cmd) = @_;
    my $peer = $client->peerhost;
    syslog('info', "New connection from $peer");
    
    eval {
        local $SIG{ALRM} = sub { die "Timeout\n" };
        alarm $TIMEOUT;
        
        my $request = <$client>;
        unless ($request) {
            syslog('warning', "Empty request from $peer");
            return;
        }
        
        my $data = decode_json($request);
        my $response;
        
        # Обработка команд
        if ($cmd eq '003') { # Время
            $response = { result => scalar localtime };
        }
        elsif ($cmd eq '004') { # Загрузка файла
            $response = handle_file_upload($data);
        }
        elsif ($cmd eq '002') { # Адресная информация
            $response = {
                client_ip => $peer,
                server_ip => 'localhost'
            };
        }
        else {
            $response = { error => "Unknown command: $cmd" };
        }
        
        print $client encode_json($response);
        alarm 0;
    };
    
    if ($@) {
        syslog('err', "Processing error: $@");
        print $client encode_json({ error => "Internal server error" });
    }
    
    close $client;
    syslog('info', "Connection with $peer closed");
}

sub handle_file_upload {
    my ($data) = @_;
    my $filename = $data->{filename} || 'unnamed.dat';
    my $mode = $data->{mode} || 0;
    my $content = $data->{content} || '';
    
    # Обработка режимов (пример)
    if ($mode == 1) {
        $content =~ s/([IVXLCDM]+)/r2a($1)/ge;
    }
    elsif ($mode == 2) {
        $content =~ s/(\d+)/a2r($1)/ge;
    }
    
    # Сохранение файла
    open(my $fh, '>', $filename) or return { error => "Can't open file: $!" };
    print $fh $content;
    close $fh;
    
    return { 
        status => 'success',
        file   => $filename,
        size   => length($content)
    };
}

sub r2a {
    my ($in) = @_;
    my $result = 0;
    my @chars = split("", $in);
    my %r = (
        'M' => 1000,
        'CM' => 900,
        'D' => 500,
        'CD' => 400,
        'C' => 100,
        'XC' => 90,
        'L' => 50,
        'XL' => 40,
        'X' => 10,
        'IX' => 9,
        'V' => 5,
        'IV' => 4,
        'I' => 1
    );
    for (my $i=0; $i < @chars; $i++) {
        if($i + 1 < @chars && defined($r{$chars[$i] . $chars[$i + 1]})) {
            $result += $r{$chars[$i] . $chars[$i + 1]};
            $i++;
        } else {
            $result += $r{$chars[$i]};
        }
    }
    return $result;
}

sub a2r {
    my ($in) = @_;
    my $result = "";
    my @ra = ('M', 'CM', 'D', 'CD', 'C', 'XC', 'L', 'XL', 'X', 'IX', 'V', 'IV', 'I');
    my %r = (
        'M' => 1000,
        'CM' => 900,
        'D' => 500,
        'CD' => 400,
        'C' => 100,
        'XC' => 90,
        'L' => 50,
        'XL' => 40,
        'X' => 10,
        'IX' => 9,
        'V' => 5,
        'IV' => 4,
        'I' => 1
    );

    foreach my $i (@ra) {
        my $repeat = int($in / $r{$i});
        $in -= $repeat * $r{$i};
        $result .= $i x $repeat;
    }
    return $result;
}

END {
    closelog();
    unlink $PID_FILE if $PID_FILE;
}
