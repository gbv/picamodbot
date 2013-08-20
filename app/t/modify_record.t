use Test::More;
use v5.14;

use PICA::Record;

ok(1);

done_testing;

__END__
use lib './lib';
use Edit;

my $pica = PICA::Record->new(join '',<DATA>);
#TODO: teste hinzufügen eines Feld
#
my $edit = {
    addfields => '144Z $aTag: testeintrag',
    iln => 22,
    deltags => '',
};
my $after = modify_record($edit,$pica);

is $after->sf('144Z$a'), 'Tag: testeintrag';
done_testing;

__DATA__
001@ $022
001A $00018:29-05-06
001B $01999:11-12-09$t22:24:52.000
001D $00018:29-05-06
001U $0utf8
001X $00
002@ $0Aau
003@ $0512482578
003O $aOCoLC$0255180429$v2009-06-15
010@ $ager
011@ $a1982
013@ $0ho
019@ $aXA-DE
021A $a@Eberhard Fechners Fernsehspiel "Tadellöser & Wolf" im Vergleich zur Romanvorlage von Walter Kempowski$deine Analyse unter besonderer Berücksichtigung des Massenmediums Fernsehen$hBirgit Klischewski
028A $dBirgit$aKlischewski
033A $pHamburg
034D $aII, 152 Bl
037C $b@Hamburg$aUniv., Magisterarbeit, 1982
044K $aHochschulschrift
101@ $a22
201B/01 $021-08-09$t14:56:10.000
201D/01 $021-08-09$b4863$a0018/0156
201U/01 $0utf8
203@/01 $0766719448
208@/01 $a29-05-06$bzi15607
209A/01 $f18/156$aGCa 7 fc 4.982$di$x00
209C/01 $aMag 619/82/847$x00
209G/01 $a096674985
245Z/01 $aH156 Magisterarbeit$x00
245Z/01 $aT 69 k 7 t$x01
