package GBV::App::Picamodbot;
#ABSTRACT: Picamodbot webservice

use v5.14;
use parent 'Plack::Component';
use Plack::Util::Accessor qw(root queue);

use Plack::Builder;
use Plack::Middleware::TemplateToolkit;
use GBV::App::Picamodbot::Queue;

use JSON qw(to_json);

sub prepare_app {
    my $self = shift;

    $self->queue( GBV::App::Picamodbot::Queue->new );

    my $core = builder {
        enable 'Rewrite', rules => sub {
            $_ .= '.html' if $_ !~ qr{/$|\.html$};
            return;
        };
        enable 'TemplateToolkit', 
            INCLUDE_PATH => $self->root,
            PRE_PROCESS  => 'header.html',
            POST_PROCESS => 'footer.html';
        sub { [404,['Content-Type'=>'text/plain'],['Not found']] };
    };

    $self->{app} = builder {

        enable 'Plack::Middleware::XForwardedFor',
            trust => ['127.0.0.1'];

        enable 'JSONP';

        mount "/edit.json" => sub {
            my $json = to_json($self->queue->list);
            [200,['Content-Type'=>'application/json'],[$json]];
        };

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
