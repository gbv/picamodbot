This application is used to collect change requests in PICA+ records.

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

# Installation

To deploy this application on your [dotCloud] account:

    dotcloud push picamodbot

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
