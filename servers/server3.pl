#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket;
use Net::hostent;

my $PORT = 9001;
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
                handle_client($client);
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

# Функции обработки клиентов (без изменений)
sub handle_client {
    my ($client) = @_;
    while (my $data = <$client>) {
        chomp $data;
        next unless $data =~ /\S/;
        handle_client_command($client, $data);
    }
    close($client);
    print "[Connection closed]\n";
}

sub handle_client_command {
    my ($client, $command) = @_;
    if ($command =~ /000/i) {
        print $client "Goodbye!\n";
        $client->shutdown(1);
    } elsif ($command =~ /001/i) {
        print $client "Commands: 001 - help, 002 - addr, 003 - date, 004 - upload <filename> <mode>, 005 - download <filename>, 000 - quit\n";
    } elsif ($command =~ /002/i) {
        my $client_addr = $client->peerhost;
        print $client "Client address: $client_addr, Server address: ", $server->sockhost, "\n";
    } elsif ($command =~ /003/i) {
        print $client scalar localtime, "\n";
    } elsif ($command =~ /004 (\S+) (\d)/i) {
        my ($filename, $mode) = ($1, $2);
        print $client "Ready to receive file: $filename\n";
        receive_file($client, $filename, $mode);
    } elsif ($command =~ /005 (\S+)/i) {
        my $filename = $1;
        send_file($client, $filename);
    } else {
        print $client "Unknown command. Type '001' for help.\n";
    }
    print $client "__END_OF_RESPONSE__\n";
}

# Остальные функции (receive_file, send_file, r2a, a2r) остаются без изменений
# ... (вставить реализации из оригинального кода)

sub receive_file {
    my ($client, $filename, $mode) = @_;
    open(my $fh, '>', $filename) or die "Can't open file: $!";
    my @content;
    my $line = <$client>;
    $line = <$client>;
    while (my $line = <$client>) {
        last if $line =~ /__END__/; # Маркер конца файла
        chomp $line;
        push @content, $line;
    }
    if ($mode == 1) {
        foreach my $line (@content) {
            $line =~ s/(M{1,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})|M{0,4}(CM|C?D|D?C{1,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})|M{0,4}(CM|CD|D?C{0,3})(XC|X?L|L?X{1,3})(IX|IV|V?I{0,3})|M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|I?V|V?I{1,3}))/r2a($&)/ge;
            print $fh "$line\n";
        }
    } elsif ($mode == 2) {
        foreach my $line (@content) {
            $line =~ s/([0-9]+)/a2r($&)/ge;
            print $fh "$line\n";
        }
    } else {
        print $fh "$_\n" foreach @content;
    }
    close($fh);
    print $client "File $filename uploaded successfully.\n";
}

sub send_file {
    my ($client, $filename) = @_;
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
