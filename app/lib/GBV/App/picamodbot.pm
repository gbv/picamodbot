package PICA::App::picamodbot;

use 5.010;
use strict;
use warnings;

use Dancer ':syntax';
use PICA::Record;
use Dancer::Plugin::Database;
use Dancer::Plugin::REST;
use LWP::Simple qw();

our $VERSION = '0.1';

my %PARAM = (
	record	  => qr{[a-z]([a-z0-9-]?[a-z0-9])*:ppn:\d+[0-9Xx]},
	deltags   => qr{[01]\d\d[A-Z@](/\d\d)?(,[01]\d\d[A-Z@](/\d\d)?)*},
	addfields => qr{.*},
	iln 	  => qr{\d*},
);

sub check_params {
	my $par = { 
		map { $_ => param($_) // '' } keys %PARAM,
	};
	my $badquery = { };

	$par->{deltags} =~ s/\s*,+\s*/,/g;
	$par->{deltags} =~ s/,\s*$//;

	foreach my $p ( keys %$par ) {
		$par->{$p} =~ s/^\s+|\s+$//mg; # trim
		next if $par->{$p} eq '';
		my $reg = $PARAM{$p};
		if ($par->{$p} !~ /^$reg$/) {
			$badquery->{$p} = "invalid format";
		}
	}

	if ($par->{addfields}) {
  	    my $pica = eval { PICA::Record->new( $par->{addfields} ) };
	    if ($pica) {
			$par->{addfields} = "$pica";
	    } else { # TODO: not shown in UI?!
			$badquery->{addfields} = "invalid format";
		}
	}

	if (!$par->{record}) {
		$par->{error} = "missing record ID";
		$badquery->{record} = "missing";
	} else {
        if ($par->{record} !~ /^test/) {
            my $pica = LWP::Simple::get("http://unapi.gbv.de/?id=".$par->{record}."&format=pp" );
            $pica = eval { PICA::Record->new( $pica ); };
            if (!$pica) {
                $par->{error} = $badquery->{record} = "Datensatz nicht gefunden!";
            }
        }
    }

	if (!$par->{error} and !$par->{addfields} and !$par->{deltags}) {
		$par->{error} = "please provide some changes";
    }

	if (%$badquery) {
		$par->{badquery} = $badquery;
		$par->{error} //= "bad query";
	}
	$par;
}

sub get_status {
    my $id = shift;
    my $edits = database->quick_select("edits", { edit => $id }, { 
        order_by => 'timestamp', limit => 1 
    } );
#debug($edits);
    my $status = $edits ? $edits->[0]->{status} : 0;
    return $status;
}

sub get_changes {
	my $changes = [ database->quick_select("changes", { }) ]; 
	foreach my $i ( 0..(@$changes-1) ) {
        my $edit = $changes->[$i];
		my $pica = $edit->{addfields} or next;
		$pica = PICA::Record->new($pica);
		$edit->{addtags} = "$pica"; # TODO: get tags only
        $edit->{status} = get_status( $edit->{edit} );
	}
	return $changes;
}

sub change_as_txt {
	my $c = shift;
	my $txt = sprintf ":%s\n", join "|", (
		$c->{edit} // '',
		$c->{created} // '',
		$c->{record} // '',
		$c->{iln} // '',
		# TODO: STATUS?
	);
	if ($c->{deltags}) {
		$txt .= join("\n", map { "-$_" } split ",", $c->{deltags})."\n";
	}
	if ($c->{addfields}) {
		$txt .= join("\n", map { "+$_" } split "\n", $c->{addfields})."\n";
	}
	return $txt;
}

get '/' => sub {
	my $pica = <<'PICA';
204@/99 $xfoo
PICA
    template 'index', { add => $pica };
};

get '/changes' => sub {
	template 'changes', {
		title 	=> 'Änderungen',
		changes => get_changes,
	};
};

get '/edits' => sub {
	# TODO: list edits
};

get '/webapi' => sub {
    template 'webapi', check_params;
};

sub submit_change {
	my $vars = shift;
	if ($vars->{record} and !$vars->{error}) {
        $vars->{ip} = request->address;
		database->quick_insert('changes', { 
			map { $_ => $vars->{$_} } qw(record deltags addfields iln ip)
		} );
		$vars->{success} = "Änderung angenommen!";
		my $edit = database->last_insert_id("","","","");
		$vars->{edit} = $edit;
	}
	my @empty = grep { !$vars->{$_} } keys %$vars;
	delete $vars->{$_} for @empty;
}

post '/webapi' => sub {
	my $vars = check_params;

	if (param('preview')) {
		return (template 'webapi', $vars);
	} else {
		submit_change($vars);
		template 'webapi', $vars;
	}
};


## REST API ####################################################################

sub get_edit {
    # TODO: weitere Anfrage-Parameter
    my $edit = database->quick_select( 'changes', { edit => param('id') } );
    if ($edit) {
        $edit->{status} = get_status( $edit->{edit} );
        return $edit;
    } else {
        status(404); # not found
        { error => "edit not found" };
    };
}

sub create_edit {
    my $edit = check_params;
    submit_change($edit);
    if ($edit->{error}) {
        status(500); # $edit;
    } else {
        status(202); # accepted
    }
    return $edit;
}

sub update_edit {
    # status(403); # Forbidden
    status(503);
    return { "error" => "Service Unavailable" };
};

set serializer => 'JSON';

get '/edit/:id.html' => sub {
    my $edit = database->quick_select( 'changes', { edit => param('id') } );
    my $vars = { edit => $edit };
    if (!$edit) {
        status(404);
        $vars->{title} = "Bearbeitung nicht gefunden";
    }
    template 'edit' => $vars;
};

get '/edit' => \&get_edit;

resource 'edit' =>
    get    => \&get_edit,
    create => \&create_edit,
    delete => sub {
        status(503);
        return { "error" => "Service Unavailable" };
    },
    update => \&update_edit;

################################################################################

prepare_serializer_for_format;

get "/changes.txt" => sub {
	my $changes = get_changes;
	my $txt = <<'TXT';
#
# This plain text, line based format contains a list of PICA+ record changes.
#
# lines that start with `#` are comments. Ignore comments and empty lines
# lines that start with `-` denote PICA+ tags to remove.
# lines that start with `|` denote which PICA+ record to modify. Such lines
#   have format `|id|timestamp|record|iln|` where 
#     `id` is the unique id of a changeset
#     `timestamp` is the date and time when the change was received
#     `record` is the qualified record id (format `DBKEY:ppn:PPN`)
#     `iln` is the internal library number
#
TXT
	$txt .= join("\n", map { change_as_txt($_) } @$changes)."\n";
	content_type("text/plain");
	return $txt;
};

get "/changes.:format" => sub {
	{ changes => get_changes };
};

sub init_db {
	my $sql = <<'SQL';
create table if not exists "changes" (
    edit    INTEGER PRIMARY KEY,
	record  NOT NULL,
	created DATETIME DEFAULT CURRENT_TIMESTAMP,
	deltags,
	addfields,
    ip,
	iln
);
SQL
	database->do($sql);
	$sql = <<'SQL';
create table if not exists "edits" (
    edit 	  INTEGER NOT NULL,
	timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
	status,
	message
);
SQL
	database->do($sql);

}

my $db_init = 0;
hook 'before' => sub {
    return if $db_init;
    $db_init = 1;
    init_db;
};

true;
