This application is used to collect change requests in PICA+ records.

# Prerequisites

1. A Unix based operating system (Ubunutu recommended). On Windows you 
   should better install a virtual machine with Ubuntu.

2. Perl (at least version 5.10.1). Check its version with `perl -v`.

3. Git for version control. Install with `sudo apt-get install git-core`.

4. Some development tools and header files

       sudo apt-get install build-essential libexpat1-dev libssl-dev

5. Cpanminus and Carton for managing Perl dependencies.

       wget -O - http://cpanmin.us | sudo perl - --self-upgrade
       sudo cpanm Carton`

6. For optional support of HTTPS you need to install LWP::Protocol::https,
   which requires Net::SSLeay. You can install it as root:

       sudo apt-get install libnet-ssleay-perl
       sudo cpanm LWP::Protocol::https


# Installation at several PaaS cloud providers

## Installation at dotCloud

To deploy this application on your [dotCloud] account:

    dotcloud push picamodbot

## Installation at OpenShift

See L<https://openshift.redhat.com/app/> (not tested yet)


# Installation at your own production server

1. Choose a server to install at. A clean Ubuntu is recommended.

2. Install prerequisites as listed above.

3. Add a dedicated user account to run the application as (replace $USER).

       sudo adduser $USER 

4. Log in as this user, copy `init-production.pl` to the 
   home directory, and run it to initialize the deployment environment:

       ~/init-production.pl

5. Switch to your development machine and add the new home directory
   at the server as git remote (replace $USER and $SERVER):

       git remote add prod $USER@$SERVER:~/repository

6. Push the current version to the master, whenever needed

       git push prod master


# TODO

- Installing a selected version at production is not documented yet.
- You must also install an init script
- 

# Configuration

Main configuration is located in `config.yml`. Additional configuration
settings are located in the `environments` directory. In particular
this includes location of the database and access to the admin interface.

- `development.yml` for local development and testing:
  Admin access is restricted to localhost.

- `deployment.yml` for installation at [dotCloud]:
  Database is persistent across deployments and admin access is public.
 
- `production.yml` for production installation at VZG.
  Admin access is restricted to specific IPs

# Credits

This application is based on [Dancer], [PICA::Record], and [TemplateToolkit]
among other Open Source components. The user interface (HTML+CSS+JavaScript) 
is build with [Bootstrap], [jQuery], and [picatextarea] (based
on [CodeMirror]), that are included in this repository.

[dotCloud]: http://dotcloud.com/
[Dancer]: http://perldancer.org
[PICA::Record]: http://search.cpan.org/dist/PICA-Record/
[TemplateToolkit]: http://template-toolkit.org/
[Bootstrap]: http://twitter.github.com/bootstrap/
[jQUery]: http://jquery.com
[picatextarea]: http://gbv.github.com/picatextarea/
[CodeMirror]: http://codemirror.net/
