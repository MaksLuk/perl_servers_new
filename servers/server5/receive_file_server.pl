#!/usr/bin/perl -w
use strict;
use warnings;
use IO::Socket;
use Net::hostent;

my $PORT = 7000;

my $server = IO::Socket::INET->new(
    LocalHost => '127.0.0.4',
    Proto     => 'tcp',
    LocalPort => $PORT,
    Listen    => SOMAXCONN,
    Reuse     => 1
) or die "$!";

print "[Receive file server accepting clients]\n";

while (my $client = $server->accept()) {
    print "Main server send request\n";

    my $filename = <$client>;
    my $mode = <$client>;

    open(my $fh, '>', $filename) or die "Can't open file: $!";
    my @content;

    while (my $line = <$client>) {
        chomp $line;
        last if $line =~ /__END__/; # Маркер конца файла
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
    print "File $filename uploaded successfully.\n";

    close $client;  
}
close $server; 

exit 0;

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
