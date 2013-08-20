package GBV::App::Picamodbot;
#ABSTRACT: Picamodbot webservice

use v5.14;
use parent 'Plack::Component';
use Plack::Util::Accessor qw(root);

use Plack::Builder;
use Plack::Middleware::TemplateToolkit;

sub prepare_app {
    my $self = shift;

    my $core = builder {

        enable 'TemplateToolkit', 
            INCLUDE_PATH => $self->root;

        sub { [200,['Content-Type'=>'text/plain'],['Hello, Picamodbot!']]; };
    };

    $self->{app} = builder {

        enable 'Plack::Middleware::XForwardedFor',
            trust => ['127.0.0.1'];

        mount "/" => builder {

            enable 'Static',
                    path => qr{\.(css|js|png|gif|ico)$},
                    root => $self->root,
                    pass_through => 1;

            $core;
        }

    };
}

sub call {
    $_[0]->{app}->($_[1]);
}

1;
