#!/usr/bin/env perl

use 5.010;
use autodie;
use Cwd;

say "This script will initialize a deployment environment.";

my $pwd  = cwd;
my $user = getlogin;

die 'Expected to run in /home/$USER' unless $user and cwd eq "/home/$user";
die 'Expected to tun in an EMPTY account' if grep { $_ ne $0 } @dir;

# create bare git repository in ~/repository
system("git init --bare repository") and die;

my %scripts = map { chomp; $_ } split /---+\n/, join "", <DATA>;
while (my ($file, $content) = each %scripts) {
    say "creating $file as executable";
    open my $fh, '>', $file;
    print $fh $content;
    close $fh;
    chmod 0755, $file;
}

system("ln -s current/app/logs/ logs") unless -e "logs";
mkdir "data" unless -d "data";

__DATA__
repository/hooks/update
-----------------------
#!/bin/bash

refname="$1" 
oldrev="$2" 
newrev="$3" 
 
if [ -z "$refname" -o -z "$oldrev" -o -z "$newrev" ]; then 
    echo "Usage: $0 <ref> <oldrev> <newrev>" >&2 
    echo "  where <newrev> is relevant only" >&2
    exit 1 
fi 

# Any command that fails will cause the entire script to fail
set -e

export GIT_WORK_TREE=~/$newrev
export GIT_DIR=~/repository

cd
[ -d $GIT_WORK_TREE ] && echo "work tree $GIT_WORK_TREE already exists!" && exit 1

# reuse existing working tree for faster updates
# TODO: build from scratch if somehow required to do so!
if [ -d current ]; then
    rsync -a current/ $GIT_WORK_TREE
else
    mkdir $GIT_WORK_TREE
fi

echo "[UPDATE] Checking out $GIT_DIR in $GIT_WORK_TREE"
cd $GIT_WORK_TREE
git checkout -q -f $newrev

echo "[UPDATE] installing dependencies and testing"
cd app
carton install
perl Makefile.PL
carton exec -Ilib -- make test
carton exec -Ilib -- make clean

export PLACK_ENV=production
# TODO: test running with starman on testing port

echo "[UPDATE] new -> $GIT_WORK_TREE/app"
cd
rm -f new
ln -s $GIT_WORK_TREE new

echo "[UPDATE] revision $GIT_WORK_TREE installed at ~/new"

-----------------------------
repository/hooks/post-receive
-----------------------------
#!/bin/bash
set -e

cd
echo "[POST-RECEIVE] new => current"
if [ -d "new" ]; then
    rm current
    mv new current
else
    echo "[POST-RECEIVE] missing directory 'new'"
    exit 1
fi

PIDFILE=~/starman.pid

if [ -f $PIDFILE ]; then
    PID=`cat $PIDFILE`
    echo "[POST-RECEIVE] Gracefully restarting starman web server on port $PORT (pid $PID)"
    kill -HUP $PID
else
    ~/restart
    # TODO: cleanup old revisions
fi
-------
restart
-------
PIDFILE=~/starman.pid
PORT=6024 # TODO: read from config file

if [ -f $PIDFILE ]; then
    echo "[restart] killing old process"
    cat $PIDFILE | xargs kill
fi

cd current/app
echo "[RESTART] Starting starman as deamon on port $PORT (pid in $PIDFILE)"
export PLACK_ENV=production
carton exec -Ilib -- starman --port $PORT -D --pid $PIDFILE

