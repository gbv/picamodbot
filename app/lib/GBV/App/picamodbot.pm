package GBV::App::picamodbot;

use 5.010;
use strict;
use warnings;

use Dancer ':syntax';
use PICA::Record;
use Dancer::Plugin::Database;
use Dancer::Plugin::REST;
use LWP::Simple qw();
use JSON::Any;

use Try::Tiny;

# local libraries
use Edit;
use Token;

# Returns an edit created from request params and enriched
# with `malformed` and `error` field.
sub checked_edit {
	my $edit = new_edit(
		map { $_ => (param($_) // '') } qw(record deltags addfields iln eln),
        ip => (request->address // ''),
	);

    return $edit if $edit->{error};

    try {
        validate_edit($edit);
    } catch {
        $edit->{error} = $_ // "invalid query";
        $edit->{error} =~ s/ at .* line .*$//sm;
        return $edit;
    };

    # TODO: authentifizieren
    #my $access;
    #if ($access) {
    #    if ($access->{iln} 
    #}

    return $edit;
}

sub get_status {
    my $id = shift;
    my $edits = database->quick_select("edits", { edit => $id }, { 
        order_by => 'timestamp', limit => 1 
    } );
    return (0,undef,'') unless $edits;

    return ($edits->{status}, $edits->{timestamp}, $edits->{message});
}

sub get_changes {
	my $changes = [ database->quick_select("changes", { }) ]; 
	foreach my $i ( 0..(@$changes-1) ) {
        my $edit = $changes->[$i];
        ($edit->{status}, $edit->{timestamp}, $edit->{message}) = get_status( $edit->{edit} );
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

sub get_edit {
    my $id = shift // param('id');
    # TODO: weitere Anfrage-Parameter
    my $edit = database->quick_select( 'changes', { edit => $id } );
    if ($edit and $edit->{edit}) {
        my $attempts = [ 
            database->quick_select( 'edits', { edit => $id }, { order_by => { desc => 'timestamp' } } ) 
        ]; # TODO order by
        if ($attempts and @$attempts) {
            delete $_->{edit} for @$attempts;
            $edit->{attempts} = $attempts;
            $edit->{$_} = $edit->{attempts}->[0]->{$_} for qw(status timestamp message);
        } else {
            $edit->{status} = 0;
        }
        return $edit;
    } else {
        status(404); # not found
        { error => "edit not found" };
    };
}

sub create_edit {
    my $edit = checked_edit;

    store_edit($edit);

    if ($edit->{error}) {
        status(500); # $edit;
    } else {
        status(202); # accepted
        # header( Location => "$baseurl/edit/".$edit->{edit} ); # TODO
    }

    return $edit;
}

sub store_edit {
	my $vars = shift;
	if ($vars->{record} and !$vars->{error}) {
        try {
    		database->quick_insert('changes', { 
	    		map { $_ => $vars->{$_} } qw(record deltags addfields iln ip)
		    } );
    		$vars->{success} = "Änderung angenommen!";
	    	my $id = database->last_insert_id("","","","");
		    $vars->{edit} = $id;
        } catch {
            $vars->{error} = ($_ // "failed to insert into database");
        }
	}
	my @empty = grep { !$vars->{$_} } keys %$vars;
	delete $vars->{$_} for @empty;
}

## HTML Interface ##############################################################

get '/' => sub {
    template 'index', { };
};

get qr{^/edit/?} => sub {
	template 'edit-list', { changes => get_changes };
};

get '/webapi' => sub {
    template 'webapi', checked_edit;
};

post '/webapi' => sub {
	my $edit = checked_edit;
	if (param('preview')) {
		template 'webapi', $edit;
	} else {
		store_edit($edit);
		redirect '/edit/'.$edit->{edit};
	}
};

get qr{/edit/([^./]+)(\.html)?$} => sub {
    my ($id) = splat;
    my $edit = get_edit($id);
    if (!$edit->{edit}) {
        status(404);
        $edit->{title} = "Änderung nicht gefunden";
    } else {
        $edit->{json} = JSON::Any->new(pretty =>1)->encode( $edit );
    }
    template 'edit' => $edit;
};

sub edit_done {
    my $status  = 1*(param('status') || 0);
    my $edit    = param('edit') // '';
    my $message = param('message') // '';

    my $error;
    my @mal;

    if ( $status !~ /^(-1|0|1|2)$/ ) {
        $error = "unknown status";
    } elsif ( !$status ) {
        # ignore
    } elsif ( $edit =~ /^\d+$/ ) {
        my $e = get_edit($edit);
        if ($e->{edit}) {
            # INSERT INTO "edits" ("edit","status","message") VALUES (2,2,"warum?");
            database->quick_insert('edits', {
                edit => $e->{edit} ,
                status => $status,
                message => $message,           
            } );
            # TODO: on error?
            redirect "/edit/$edit";
        } else {
            @mal = ( 'edit' => ($error = "edit not found") );
        }
    } else {
        @mal = ( 'edit' => ($error = "please provide edit ID") );
    }

    my $vars = { status => $status, edit => $edit, message => $message };
    $vars->{error} = $error if $error;
    $vars->{malformed} = \@mal;

    return $vars;
}

any ['get','post'] => '/done' => sub {
    my $vars = edit_done;
    # TODO: HTTP status
    return $vars;
};

any ['get','post'] => '/admin/done' => sub {
    template 'done', edit_done;
};

get '/admin' => sub {
    my $vars = { };
    # TODO: weitere Statistiken
    my $sql = 'SELECT iln, count(iln) AS "count", max(created) AS "latest" FROM changes GROUP BY iln ORDER BY count(iln) DESC';
    my $ilnstat = database->selectall_arrayref( $sql, { Slice => {} } );
    template 'admin', { ilnstat => $ilnstat };
};

any ['get','post'], '/admin/token' => sub {
    my $tokens = [ ];

    my $tk = new_token( map { $_ => param($_) } qw(dbkeys ilns tags) );
    if (param('add_token') and !$tk->{malformed}) {
        database->quick_insert('tokens', { 
            token => $tk->{access_token}, map { $_ => $tk->{$_} } qw(ilns dbkeys tags)
        } );
        $tk->{success} = "Token hinzugefügt";
        # TODO: Fehlerfall (z.B. token schon existent)
    }

    $tokens = [ database->quick_select('tokens',{}) ];

    template 'token', { tokens => $tokens, %$tk };
};

any ['get','post'], '/admin/backup' => sub {
    # TODO 
    template 'backup';
};


## REST API ####################################################################

set serializer => 'JSON';

get '/admin/token.json' => sub {
    my $token = [ database->quick_select('tokens',{}) ];
    { 'token' => $token };
};

resource 'edit' =>
    get    => \&get_edit,
    create => \&create_edit,
    delete => sub { status(503); { "error" => "Service Unavailable" }; },
    update => sub { status(503); { "error" => "Service Unavailable" }; };

prepare_serializer_for_format;

get "/edit.txt" => sub {
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

get "/edit.:format" => sub {
	{ changes => get_changes };
};

## Deprecated routes ###########################################################

get "/changes" => sub { redirect '/edit' };
get "/changes.txt" => sub { redirect '/edit.txt' };
get "/changes.json" => sub { redirect '/edit.json' };
get "/changes.xml" => sub { redirect '/edit.xml' };

## Initialize database on startup ##############################################

hook 'before' => sub {
    our $database_initialized;
    return if $database_initialized;
    $database_initialized = 1;

    my @sql = split '--', <<'SQL';
create table if not exists "changes" (
    edit    INTEGER PRIMARY KEY,
	record  NOT NULL,
	created DATETIME DEFAULT CURRENT_TIMESTAMP,
	deltags,
	addfields,
    ip,
	iln
);
--
create table if not exists "edits" (
    edit 	  INTEGER NOT NULL,
	timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
	status,
	message
);
--
create table if not exists "tokens" (
    token PRIMARY KEY,
    dbkeys,
    ilns,
    tags
);
SQL
	database->do($_) for @sql;
};

true;
