package GBV::App::picamodbot;
#ABSTRACT: Hauptmodul der Webkomponente von picamodbot 

use 5.010;
use strict;
use warnings;

# TODO: simplify, by combining database tables

use Dancer ':syntax';
use PICA::Record;
use Dancer::Plugin::Database;
use Dancer::Plugin::REST;
#use Dancer::Plugin::Feed;
use LWP::Simple qw();
use JSON::Any;
use DateTime::Format::RFC3339;
use POSIX;

use Try::Tiny;

# local libraries
use Edit;
use Token;

use Net::IP::AddrRanges;
my $admin_ips;

sub address {
    my $address = config->{behind_proxy} ? 
        ( request->forwarded_for_address || request->env->{HTTP_X_FORWARDED_FOR} )
    : 0;
    return $address || request->address;
}

# check whether user is admin
sub is_admin {
    my $c = config->{admin} or return;

    # See also Plack::Middleware::IPAddressFilter
    if (!$admin_ips) {
        $admin_ips = Net::IP::AddrRanges->new;
        my @ips = ref $c->{ips} ? @{$c->{ips}} : ($c->{ips});
        foreach (@ips) {
            $admin_ips->add( $_ eq 'all' ? '255/0' : $_ )
        }
    }

    return $admin_ips->find( address || '127.0.0.1' );
}

# Returns an edit created from request params and enriched
# with `malformed` and `error` field.
sub checked_edit {
	my $edit = new_edit(
		map { $_ => (param($_) // '') } qw(record deltags addfields iln eln),
        ip => address,
	);

    return $edit if $edit->{error};

    try {
        validate_edit( $edit, config->{unapi} );
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

sub get_queue {
    my $changes = get_changes;
    return [ grep { $_->{status} == 0 } @$changes ];
}

sub get_edit {
    my $id = shift // param('id');
    my $edit = database->quick_select( 'changes', { edit => $id } );
    if ($edit and $edit->{edit}) {
        my $attempts = [ 
            database->quick_select( 'edits', { edit => $id }, { order_by => { desc => 'timestamp' } } ) 
        ];
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

hook 'before_template_render' => sub {
    my $vars = shift;
    # $vars->{environment} = config->{environment};

    $vars->{is_admin} = is_admin;
    $vars->{address}  = address;
};

get '/' => sub {
    template 'index', { };
};

get '/about' => sub {
    template 'about';
};

hook 'before' => sub {
    debug(request->path);
    if (request->path =~ qr{^/(done|admin)} and !is_admin) {
        status '401';
        header 'Content-Type' => 'application/json';
        halt '{ "error" : "Access denied" }';
    }
};

get qr{^/edit/?} => sub {
    my $changes = get_changes;
    my $status  = param('status') // -99;
    if ($status >= -1 and $status <= 2) {
        $changes = [ grep { $_->{status} == $status } @$changes ];
    }
    template 'edit-list', { changes => $changes, status => $status };
};

get '/webapi' => sub {
    template 'webapi', checked_edit;
};

post '/webapi' => sub {
	my $edit = checked_edit;
	if (param('result')) {
		template 'webapi', $edit;
	} else {
		store_edit($edit);
		redirect '/edit/'.$edit->{edit};
	}
};

get qr{/edit/([^./]+).check$} => sub {
    my ($id) = splat;
    my $edit = get_edit($id);

    if (! $edit->{status} ) {
        get_result($id);
    }

    redirect "/edit/$id";
};

get qr{/edit/([^./]+)(\.html)?$} => sub {
    my ($id) = splat;
    my $edit = get_edit($id);
    if (!$edit->{edit}) {
        status(404);
        $edit->{title} = "Änderung nicht gefunden";
    } else {
        validate_edit( $edit, config->{unapi} );
        $edit->{json} = JSON::Any->new(pretty =>1)->encode( $edit );
    }
    template 'edit' => $edit;
};

# Falls keine Bearbeitungs-ID angegeben
get '/result' => sub {
    redirect '/edit';
};

get qr{/result/([^./]+)(\.html)?$} => sub {
    my ($id) = splat;
    my $edit = get_result($id) || do {
        status(404);
        { title => "Änderung nicht gefunden" };
    };
    template 'result' => $edit;
};

get qr{/result/([^./]+)\.(normpp|pp)$} => sub {
    my ($id, $format) = splat;
    my $edit = get_result($id);

    content_type('text/plain; charset=utf-8');

    if (!$edit->{edit}) {
        status(404);
        return "not found";
    }

    return $format eq 'normpp' ? $edit->{after}->normalized : $edit->{after}->string;
};

sub get_result {
    my $id = shift; # edit id

    my $edit = get_edit($id) or return;
    result_edit( $edit );
    return $edit;
}

sub result_edit {
    my $edit = shift;

    my $url = config->{unapi}.'id='.$edit->{record}.'&format=pp';
    my $pica = eval { 
        PICA::Record->new( LWP::Simple::get( $url ) ); 
    };
    if (!$pica) {
        #$self->{malformed}->{record} //= "not found";
        #croak "Failed to get PICA+ record";
        #TODO: some error message?
    } else {
        $edit->{before} = $pica;
        $edit->{after}  = modify_record( $edit, $pica ); 

        # check_whether_edit_done;
        if ( $edit->{before}->as_string eq $edit->{after}->as_string ) {
            info ("Edit ".$edit->{edit}." already done");
            mark_edit_as_done($edit->{edit}, 1, "detected that edit is done");
        }
    }
}

sub mark_edit_as_done {
    my ($id, $status, $message) = @_;

    database->quick_update('edits', { edit => $id },
        {
          status => $status,
          message => $message,           
        } );
    redirect "/edit/$id";
}

sub edit_done {
    my $edit    = param('edit') // '';
    my $status  = 1*(param('status') || 0);
    my $message = param('message') // '';

    ($edit, $status, $message) = @_ if @_;

    my $error;
    my %mal;

    if ( $status !~ /^(-1|0|1|2)$/ ) {
        $error = "unknown status";
    } elsif ( !$status ) {
        # ignore
    } elsif ( $edit =~ /^\d+$/ ) {
        my $e = get_edit($edit);
        if ($e->{edit}) {
            database->quick_insert('edits', {
                edit => $e->{edit},# }, {
                status => $status,
                message => $message,           
            } );
            # TODO: on error?
            redirect "/edit/$edit";
        } else {
            %mal = ( 'edit' => ($error = "edit not found") );
        }
    } else {
        %mal = ( 'edit' => ($error = "please provide edit ID") );
    }

    my $vars = { status => $status, edit => $edit, message => $message };
    $vars->{error} = $error if $error;
    $vars->{malformed} = \%mal;

    return $vars;
}

## admin methods: TODO: auth

any ['get','post'] => '/done' => sub {
    my $vars = edit_done;
    # TODO: HTTP status
    return $vars;
};

any ['get','post'] => '/admin/done' => sub {
    template 'done', edit_done;
};

get '/admin' => sub {
    template 'admin';
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

get '/admin/stats' => sub {
    my $vars = { };

    # TODO: weitere Statistiken
    my $sql = 'SELECT iln, count(iln) AS "count", max(created) AS "latest" FROM changes GROUP BY iln ORDER BY count(iln) DESC';
    my $ilnstat = database->selectall_arrayref( $sql, { Slice => {} } );

    template 'admin-stats', { ilnstat => $ilnstat };
};

## REST API ####################################################################

set serializer => 'JSON';

resource 'edit' =>
    get    => \&get_edit,
    create => \&create_edit,
    delete => sub { status(503); { "error" => "Service Unavailable" }; },
    update => sub { status(503); { "error" => "Service Unavailable" }; };

prepare_serializer_for_format;

get "/edit.json" => sub {
	{ changes => get_changes };
};

get "/queue.json" => sub {
	{ changes => get_queue };
};

sub sqlite3_timestamp_to_rfc3339 {
    my $timestamp = shift;

    my $m = strftime("%z", localtime);
    $m =~ s/^\+(..)(..)$/+$1:$2/;
    $m = $timestamp . $m;
    $m =~ s/ /T/;

    $timestamp = eval { DateTime::Format::RFC3339->new->parse_datetime($m); };

    return $timestamp;
}

=head1
sub make_feed {
    my $changes = shift;
    my $title = 'Änderungen'; # TODO: fix this at another place
    utf8::decode($title); 
    my $feed = create_atom_feed ( 
        title => $title,
        entries => [ 
            map { 
                { 
                    title    => $_->{record},
                    issued   => sqlite3_timestamp_to_rfc3339($_->{created}),
                    modified => sqlite3_timestamp_to_rfc3339($_->{timestamp}),
                    link     => request->uri_base . '/edit/' . $_->{edit},
                    # TODO: alternate links
# TODO: informationen wie auf der HTML-Seite
#                    summary =>
#                   content => (type=xhtml?)
                } 
            } @$changes
        ]
    );
    my $relbase = "http://purl.org/ontology/gbv";
    $feed =~ s{<link rel="alternate" href="([^"]+)/edit/(\d+)" type="text/html"/>}
   {<link rel="alternate" href="$1/edit/$2" type="text/html"/>    
    <link rel="$relbase/result-normpp" href="$1/result/$2.normpp" type="text/plain"/>
    <link rel="$relbase/result-pp" href="$1/result/$2.pp" type="text/plain"/>}g;
    return $feed;
}

# Atom Feed (TODO: add paging)
get "/edit.xml" => sub {
    make_feed( get_changes );
};

get "/queue.xml" => sub {
    make_feed( get_queue );
};
=cut

## Deprecated routes ###########################################################

get "/changes" => sub { redirect '/edit' };
get "/changes.json" => sub { redirect '/edit.json' };
get "/changes.xml" => sub { redirect '/edit.xml' };

get "/queue" => sub { redirect '/edit?status=0' };
get "/queue.json" => sub { redirect '/edit.json?status=0' };
get "/queue.xml" => sub { redirect '/edit.xml?status=0' };


## Initialize database on startup ##############################################

hook 'before' => sub {
    our $database_initialized;
    return if $database_initialized;
    $database_initialized = 1;

    debug 'Initializing database';
    debug 'Environment is: ' . config->{environment};

    database->do($_) for split '--', <<'SQL';
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
};

set behind_proxy => 1 if config->{behind_proxy};

true;
