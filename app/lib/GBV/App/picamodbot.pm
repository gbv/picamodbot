package GBV::App::picamodbot;

use 5.010;
use strict;
use warnings;

use Dancer ':syntax';
use PICA::Record;
use Dancer::Plugin::Database;
use Dancer::Plugin::REST;
use LWP::Simple qw();
use YAML;

use GBV::PICA::Edit;
use Try::Tiny;

our $VERSION = '0.1';

my %PARAM = (
	record	  => qr{[a-z]([a-z0-9-]?[a-z0-9])*:ppn:\d+[0-9Xx]},
	deltags   => qr{[01]\d\d[A-Z@](/\d\d)?(,[01]\d\d[A-Z@](/\d\d)?)*},
	addfields => qr{.*},
	iln 	  => qr{\d*},
);

my $ACCESS_TOKENS = { };

# TODO: load access
sub load_tokens {
    my $file; # TODO
    eval { $ACCESS_TOKENS = YAML::LoadFile($file) } if -f $file;
    return unless $ACCESS_TOKENS;

    # TODO: change ... to ...
}

# Returns a GBV::PICA::Edit created from request params and enriched
# with `malformed` and `error` field.
sub checked_edit {
	my $edit = new_edit(
		map { $_ => param($_) // '' } qw(record deltags addfields iln eln),
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

    return ( $edits->{status}, $edits->{timestamp}, $edits->{message} );
    
#    use Data::Dumper;
#print STDERR Dumper($edits);    
#    my $status = $id;
}

sub get_changes {
	my $changes = [ database->quick_select("changes", { }) ]; 
	foreach my $i ( 0..(@$changes-1) ) {
        my $edit = $changes->[$i];
		my $pica = $edit->{addfields} or next;
		$pica = PICA::Record->new($pica);
		$edit->{addtags} = "$pica"; # TODO: get tags only
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

get '/' => sub {
    template 'index', { };
};

get qr{^/edit/?} => sub {
	template 'changes', {
		title 	=> 'Änderungen',
		changes => get_changes,
	};
};

get '/webapi' => sub {
    template 'webapi', checked_edit;
};

sub get_edit {
    my $id = shift // param('id');
    # TODO: weitere Anfrage-Parameter
    my $edit = database->quick_select( 'changes', { edit => $id } );
    if ($edit and $edit->{edit}) {
        ($edit->{status},$edit->{timestamp},$edit->{message}) = get_status( $edit->{edit} );
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

sub update_edit {
    # status(403); # Forbidden
    status(503);
    return { "error" => "Service Unavailable" };
};

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

post '/webapi' => sub {
	my $edit = checked_edit;
	if (param('preview')) {
		template 'webapi', $edit;
	} else {
		store_edit($edit);
		template 'webapi', $edit;
	}
};

get qr{/edit/([^./]+)(\.html)?$} => sub {
    my ($id) = splat;
    my $edit = get_edit($id);
    if (!$edit->{edit}) {
        status(404);
        $edit->{title} = "Änderung nicht gefunden";
    }
use Data::Dumper;
print debug(Dumper($edit));
        # TODO: check!

    template 'edit' => $edit;
};


## REST API ####################################################################

set serializer => 'JSON';

resource 'edit' =>
    get    => \&get_edit,
    create => \&create_edit,
    delete => sub {
        status(503);
        return { "error" => "Service Unavailable" };
    },
    update => \&update_edit; # TODO: auch über eine andere URL

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
};

true;
