package GBV::PICA::Edit;
#ABSTRACT: Modification at an identified PICA+ record

use 5.010;
use strict;
use warnings;

use Carp;
use PICA::Record;

# an edit is just an unblessed hash reference

use base 'Exporter';
our @EXPORT = qw(new_edit validate_edit);

# Creates an new edit with partly normalized (but not validated) values
sub new_edit {
    my $self = { }; #bless { }, shift;
    my %args = @_;

    foreach (qw(record deltags addfields iln epn ip)) {
        $self->{$_} = $args{$_} // '';
        $self->{$_} =~ s/^\s+|\s+$//g;
    }

    $self->{deltags} = join ',', sort grep { $_ !~ /^\s*$/ }
        split /\s*,\s*/, $self->{deltags};

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
        $self->{deltags} =~ qr{^([01]\d\d[A-Z@](/\d\d)?(,[01]\d\d[A-Z@](/\d\d)?)*)?$};

	if ($self->{addfields}) {
		push @mal, 'addfields' unless
  	        eval { PICA::Record->new( $self->{addfields} ) };
	}

    return @mal;
}

# Checks whether the edit could be performed
sub validate_edit {
    my $self = shift;

    croak "missing record ID"
        unless $self->{record};

    croak "please provide some changes" 
        if !$self->{addfields} and !$self->{deltags};

    my $pica;
    if ($self->{record} !~ /^test/) {
        $pica = LWP::Simple::get("http://unapi.gbv.de/?id=".$self->{record}."&format=pp" );
        $pica = eval { PICA::Record->new( $pica ); };
        if (!$pica) {
            $self->{malformed}->{record} //= "not found";
            croak "Failed to get PICA+ record";
        }

        if ($self->{iln} and !$pica->holdings($self->{iln})) {
            $self->{malformed}->{iln} //= "not found";
            croak "ILN not found in this record";
        }
    }

    return 1;
}

1;
