package Token;

use 5.010;
use strict;
use warnings;

use Carp;
use Crypt::OpenSSL::Random;

# an edit is just an unblessed hash reference

use base 'Exporter';
our @EXPORT = qw(new_token);

sub new_token {
    my %param = @_;
    my $token = { 
        access_token => 
            $param{access_token} ||
            unpack("H*", Crypt::OpenSSL::Random::random_bytes(10)),
        map { $_ => $param{$_} // '' } qw(dbkeys ilns tags),
    };

    my @mal;

    while (my ($name,$t) = each %$token ) {
        $t =~ s/\s+//g;
        $t = join ',', sort grep { $_ ne '' } split ',', $t;
        $token->{$name} = $t;
        if ( $t =~ qr{[^a-z0-9_/\@:,()\[\].+?*-]}i or !eval { qr/$t/ } ) {
            push @mal, $name;
        }
    }

    $token->{malformed} = { map { $_ => "invalid" } @mal } if @mal;

    return $token;
}

1;
