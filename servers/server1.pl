#!/usr/bin/perl -w

use strict;
use IO::Socket;
use Net::hostent;

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

    while (<$client>) {
        chomp;
        next unless /\S/; # Пропуск пустых строк

        if (/000/i) {
            print $client "Goodbye!\n";
            last;
        }
        elsif (/001/i) {
            print $client "Commands: 001 - help, 002 - addr, 003 - date, 004 - upload <filename>, 005 - download <filename>, 000 - quit\n";
        }
        elsif (/002/i) {
            my $client_addr = $client->peerhost;
            my $server_addr = $server->sockhost;
            print $client "Client address: $client_addr, Server address: $server_addr\n";
        }
        elsif (/003/i) {
            print $client scalar localtime, "\n";
        }
        elsif (/004 (\S+) (\d)/i) {
            my $expected_filename = $1;
            my $mode = $2;

            print $client "Ready to receive file: $expected_filename\n";
            open(my $fh, '>', $expected_filename) or die "Can't open file: $!";
            my @content;
            while (<$client>) {
                last if /__END__/; # Маркер конца файла
                push @content, $_;
            }

            if ($mode eq "1") {
                foreach my $line (@content){
                    $line =~ s/(M{1,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})|M{0,4}(CM|C?D|D?C{1,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})|M{0,4}(CM|CD|D?C{0,3})(XC|X?L|L?X{1,3})(IX|IV|V?I{0,3})|M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|I?V|V?I{1,3}))/r2a($&)/ge;
                    print $fh "$line";
                  
                }
            }
            elsif ($mode eq "2") {
                foreach my $line (@content){
                    $line =~ s/([0-9]+)/a2r($&)/ge;;
                    print $fh "$line";  
                }
            }
            else {
                print $fh $_ foreach @content;
            }

            close($fh);
            print $client "File $expected_filename uploaded successfully.\n";
        }
        elsif (/005 (\S+)/i) {
            my $filename = $1;
            if (-e $filename) {
                print $client "Sending file: $filename\n";
                open(my $fh, '<', $filename) or die "Can't open file: $!";
                while (<$fh>) {
                    print $client $_;
                }
                close($fh);
                print $client "END \n"; # Маркер конца файла
            } else {
                print $client "File $filename not found.\n";
            }
        }
        else {
            print $client "Unknown command. Type 'help' for command list.\n";
        }

        # Отправляем маркер конца передачи
        print $client "__END_OF_RESPONSE__\n";
    }

    # Закрытие соединения
    close $client;
    print "[Connection closed]\n";
}

close $server;

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

    for (my $i=0; $i < @chars; $i++)
    {
        if($i + 1 < @chars && defined($r{$chars[$i] . $chars[$i + 1]}))
        {
            $result += $r{$chars[$i] . $chars[$i + 1]};
            $i++;
        }
        else
        {
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
    
    foreach my $i (@ra){
        my $repeat = int($in / $r{$i});
        $in -= $repeat * $r{$i};
        $result .= $i x $repeat;
    }
    return $result
}
