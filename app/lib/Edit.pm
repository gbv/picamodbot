package Edit;
#ABSTRACT: Modification at an identified PICA+ record

use 5.010;
use strict;
use warnings;

use Carp;
use PICA::Record;

# an edit is just an unblessed hash reference

use base 'Exporter';
our @EXPORT = qw(new_edit validate_edit modify_record);

# Creates an new edit with partly normalized (but not validated) values
sub new_edit {
    my $self = { }; #bless { }, shift;
    my %args = @_;

    foreach (qw(record deltags addfields iln epn ip)) {
        $self->{$_} = $args{$_} // '';
        $self->{$_} =~ s/^\s+|\s+$//g;
    }

    $self->{deltags} = join (',', sort grep { $_ !~ /^\s*$/ }
        split /\s*,\s*/, $self->{deltags});

    my $pica = $self->{addfields} eq '' ? undef : 
        eval { PICA::Record->new( $self->{addfields} ) };
	if ($pica) {
        $pica->sort;
		$self->{addfields} = "$pica";
    }
	
    if ( my @mal = malformed_edit($self) ) {
        $self->{malformed} = { map { $_ => "invalid" } @mal },
        $self->{error}     = "invalid edit";
    }

    return $self;
}

# Returns list of malformed fields
sub malformed_edit {
    my $self = shift;
    my @mal;

    push @mal, 'record' unless 
        $self->{record} =~ /^([a-z]([a-z0-9-]?[a-z0-9])*:ppn:\d+[0-9Xx])?$/;
    push @mal, 'iln' unless 
        $self->{iln} =~ /^\d*$/;
    push @mal, 'epn' unless 
        $self->{epn} =~ /^\d*$/;
    push @mal, 'deltags' unless 
        $self->{deltags} =~ qr{^([012]\d\d[A-Z@](/\d\d)?(,[012]\d\d[A-Z@](/\d\d)?)*)?$};

	if ($self->{addfields}) {
		push @mal, 'addfields' unless
  	        eval { PICA::Record->new( $self->{addfields} ) };
	}

    return @mal;
}

# Checks whether the edit could be performed
sub validate_edit {
    my $self  = shift;
    my $unapi = shift or croak 'Missing unAPI configuration';

    croak "missing record ID"
        unless $self->{record};

    croak "please provide some changes" 
        if !$self->{addfields} and !$self->{deltags};

    my $pica;
    if ($self->{record} !~ /^test/) {
        $pica = LWP::Simple::get( "$unapi?id=".$self->{record}."&format=pp" );
        $pica = eval { PICA::Record->new( $pica ); };
        if (!$pica) {
            $self->{malformed}->{record} //= "not found";
            croak "Failed to get PICA+ record";
        }

        my ($holding, $item);
        if ( $self->{iln} ) {
            unless ( $holding = $pica->holdings($self->{iln}) ) {
                $self->{malformed}->{iln} //= "not found";
                croak "ILN not found in this record";
            }
            # TODO: was wenn mehrere items?
            ($item) = $holding->items; # TODO: select multiple!
        }

        # predict outcome
        $self->{predict} = { deltag => { }, add => { } };
        if ($self->{deltags}) {
            foreach my $tag ( split ',', $self->{deltags} ) {
                my $status = -1;
                given($tag) {
                    when(/^0/) { # exact tag
                        my @fields = $pica->field($tag);
                        $status = scalar @fields; 
                    };
                    when(/^1/) { 
                        my $t = $tag =~ qr{/} ? $tag : "$tag/..";
                        if ($holding) {
                            my @f = $holding->field($t);
                            $status = scalar @f;
                        }
                    };
                    when(/^2/) {
                        my $t = $tag =~ qr{/} ? $tag : "$tag/..";
                        if ($item) {
                            my @f = $item->field($t);
                            $status = scalar @f;
                        }
                    };
                }
                $self->{predict}->{deltag}->{$tag} = $status;
            }
        }

        if ($self->{addfields}) {
            foreach my $f ( PICA::Record->new( $self->{addfields} )->fields ) {
                # TODO: testen, ob Feld schon so vorhanden, dann löschen
                $self->{predict}->{add}->{"$f"} = "0"
            }
        }

        $self->{modrec} = "".edit_record($self, $pica);
    }

    return 1;
}

# create a minimal record for editing
sub edit_record {
    my $edit = shift;
    my $pica = shift;

    my $n = PICA::Record->new;
    $n->ppn( $pica->ppn );

    return $n;
}

# remove tags from a PICA record
# PICA, TAGS (as array), ILN, ELN
# may die
sub modify_record {
    my ($edit, $pica) = @_;

    my $iln = $edit->{iln};
    my $epn = $edit->{epn};
    my $tags = [ split ',', $edit->{deltags} ];

    my $add = PICA::Record->new( $edit->{addfields} || '' );

    # new PICA record with all level0 fields but the ones to remove
    my @delevel0 = grep /^0/, @$tags;
    my @delevel1 = grep /^1/, @$tags;
    my @delevel2 = grep /^2/, @$tags;

    # Level 0
    my $result = PICA::Record->new( $pica->main );
    $result->remove( @delevel0 ) if @delevel0;
    $result->append( $add->main );    

#$pica->append( PICA::Field->new( '144Z' => '$aTag: testeintrag' ));
$pica->sort;
#is $after->as_string, $pica->as_string, 'modified record';

    # Level 1
    foreach my $h ( $pica->holdings ) {
        if (@delevel1 and (!$iln or $h->iln eq $iln)) {
            $h->remove( map { $_ =~ qr{/} ? $_ : "$_/.." } @delevel1 );
        } 
        if ($iln and $h->iln eq $iln) {
            $result->append( grep { $_->tag =~ /^1/ } $add->fields );
        }

        $result->append( $h->fields );

        # TODO: level2 noch nicht nicht unterstützt
    }

    $pica->sort;
    $result->sort;
    return $result;
}

1;
