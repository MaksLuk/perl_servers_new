#!/usr/bin/perl -w

use strict;
use IO::Socket;
use File::Basename; # Для извлечения имени файла

# Адрес и порт сервера
my $HOST = '127.0.0.1'; # или другой IP-адрес сервера
my $PORT = 9001;

# Создаем клиентский сокет
my $socket = IO::Socket::INET->new(
    PeerAddr => $HOST,
    PeerPort => $PORT,
    Proto    => 'tcp'
) or die "Cannot connect to the server $HOST:$PORT\n";

print "Connected to server $HOST:$PORT\n";

$socket->autoflush(1);

# Функция для чтения всех доступных данных от сервера
sub read_server_response {
    my ($socket) = @_;
    my @response_lines;

    while (my $line = <$socket>) {
        chomp($line);
        push @response_lines, $line;

        # Проверяем, содержит ли строка маркер конца передачи
        if ($line eq '__END_OF_RESPONSE__') {
            last; # Заканчиваем чтение
        }
    }

    # Удаляем маркер из результата
    pop @response_lines if @response_lines && $response_lines[-1] eq '__END_OF_RESPONSE__';

    return @response_lines;
}

print "Commands: help, addr, date, upload <filename>, download <filename>, quit\n";

# Главный цикл обработки команд
while (1) {
    print "> "; # Приглашение для ввода команды
    my $raw_command = <STDIN>;
    chomp($raw_command);

    last if $raw_command =~ /^(quit|exit)$/i; # Выход из программы
    
    my $command;
    if($raw_command eq "help") { $command = "001"; }
    elsif($raw_command eq "addr") { $command = "002"; }
    elsif($raw_command eq "date") { $command = "003"; }
    elsif($raw_command =~ /^upload (\S+) (0|1|2)/i) { $command = "004 $1 $2"; }
    elsif($raw_command =~ /^download\s+(\S+)$/i) { $command = "005 $1"; }
    else {
    	print "Неизвестная команда\n";
    	next;
    }

    print $socket "$command\n"; # Отправляем команду на сервер

    # Если команда upload, начинаем отправку файла
    if ($command =~ /^004 (\S+) (0|1|2)/i) {
        my $full_path = $1;
        my $mode = $2;
        my $filename = basename($full_path); # Извлекаем только имя файла

        if (-e $full_path) {
            open(my $fh, '<', $full_path) or die "Can't open file: $!";
            while (my $line = <$fh>) {
                print $socket $line;
            }
            close($fh);
            print $socket "__END__\n"; # Маркер конца файла
        } else {
            print "File $full_path not found.\n";
        }
    }
    elsif ($command =~ /^005\s+(\S+)$/i) {
        my $filename = $1;
        open(my $fh, '>', $filename) or die "Can't open file: $!";
        my $line = <$socket>;
        print $line;
        while ($line = <$socket>) {
       	    last if $line eq "END \n";
            print $fh $line;
        }
        close($fh);
        print "File $filename downloaded successfully\n";
    }

    # Читаем ответ сервера
    my @server_response = read_server_response($socket);
    print "$_\n" foreach @server_response;
}

close($socket);
print "Connection closed.\n";
