package PICA::App::picamodbot;
use Dancer ':syntax';

use 5.010;
use strict;
use warnings;

use PICA::Record;
use Dancer::Plugin::Database;

our $VERSION = '0.1';

my %PARAM = (
	id 		=> qr{[a-z]([a-z0-9-]?[a-z0-9])*:ppn:\d+[0-9Xx]},
	deltags => qr{[01]\d\d[A-Z@](/\d\d)?(,[01]\d\d[A-Z@](/\d\d)?)*},
	add 	=> qr{},
	iln 	=> qr{\d*},
);

sub check_params {
	my $par = { 
		map { $_ => param($_) // '' } keys %PARAM,
	};
	my $badparam = { };

	$par->{deltags} =~ s/\s*,+\s*/,/g;
	$par->{deltags} =~ s/,\s*$//;

	foreach my $p ( keys %$par ) {
		$par->{$p} =~ s/^\s+|\s+$//mg; # trim
		next if $par->{$p} eq '';
		my $reg = $PARAM{$p};
		if ($par->{$p} !~ /^$reg$/) {
			$badparam->{$p} = "invalid format";
		}
	}

	if ($par->{add}) {
  	    my $pica = eval { PICA::Record->new( $par->{add} ) };
	    if ($pica) {
			$par->{add} = "$pica";
	    } else { # TODO: not shown in UI?!
			$badparam->{add} = "invalid format";
		}
	}

	$par->{badparam} = $badparam;
	$par;
}

get '/' => sub {
	my $pica = <<'PICA';
203@/99 $056321
001@ $0x
204@/99 $xfoo
This is an error
123X $a
PICA
    template 'index', { add => $pica };
};

get '/changes' => sub {
	# TODO: list changes
};

get '/edits' => sub {
	# TODO: list edits
};

get '/webapi' => sub {
    template 'webapi', { };
};

post '/webapi' => sub {
	my $vars = check_params;
	use Data::Dumper;
	$vars->{dump} = Dumper($vars);
	template 'webapi', $vars;
};

sub init_db {
	my $sql = <<'SQL';
create table if not exists "changes" (
    change_id integer primary key,
	record_id not null,
	received DATETIME DEFAULT CURRENT_TIMESTAMP,
	deltags,
	add_record,
	iln
);
SQL
	database->do($sql);
	$sql = <<'SQL';
create table if not exists "edits" (
    change_id integer not null,
	timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
	status,
	message
);
SQL
	database->do($sql);

}

init_db;
true;
