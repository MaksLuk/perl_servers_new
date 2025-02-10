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
        elsif (/004 (\S+)\s+(|0|1|2)/i) {
            my $expected_filename = <$client>; # Получаем имя файла
            chomp($expected_filename);
            my $mode = $2;

            print $client "Ready to receive file: $expected_filename\n";
            open(my $fh, '>', $expected_filename) or die "Can't open file: $!";
            my @content;
            while (<$client>) {
                last if /__END__/; # Маркер конца файла
                push @content, $_;
            }
            
            if ($mode eq "1") {
            	@content = map { roman_to_arabic($_) } @content;
            }
            elsif ($mode eq "2") {
            	@content = map { arabic_to_roman($_) } @content;
            }
            print $fh $_ foreach @content;
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


sub roman_to_arabic {
    my ($line) = @_;
    my %roman = (
    	"M" => 1000, "CM" => 900, "D" => 500, "CD" => 400,
    	"C" => 100, "XC" => 90, "L" => 50, "XL" => 40,
    	"X" => 10, "IX" => 9, "V" => 5, "IV" => 4, "I" => 1
    );
    my $result = 0;
    foreach my $s (sort { length($b) <=> length($a) } keys %roman) {
    	while ($line =~ s/\b$s\b//i) {
    	    $result += $roman{$s};
    	}
    }
    return $result . "\n";
}

sub arabic_to_roman {
    my ($line) = @_;
    my %arabic = (
    	1000 => "M", 900 => "CM", 500 => "D", 400 => "CD",
    	100 => "C", 90 => "XC", 50 => "L", 40 => "XL",
    	10 => "X", 9 => "IX", 5 => "V", 4 => "IV", 1 => "I"
    );
    chomp($line);
    my $num = int($line);
    my $result = '';
    foreach my $val (sort { $b <=> $a } keys %arabic) {
    	while ($num >= $val) {
    	    $result .= $arabic{$val};
    	    $num -= $val;
    	}
    }
    return "$result\n";
}
