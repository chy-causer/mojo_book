package Photo;

use Mojo::Base 'Mojolicious';

sub site_dir
{
    state $site_dir = pop;
}

sub site_config
{
    state $site_config = pop;
}

sub startup {
    my $self = shift;

    $self->log->level("debug"); # (*@\label{_appendix_startup_debug}@*)

    my $site_config = $self->plugin("Config" => {file => '/opt/mojo_book/photo.config'}); # (*@\label{_appendix_startup_config}@*)

    $self->secrets([$$site_config{site_secret}]); # (*@\label{_appendix_startup_secrets}@*)

    # (*@\label{_appendix_startup_helpers}@*)
    $self->helper(site_dir => \&site_dir);
    $self->helper(site_config => \&site_config);
    $self->site_dir($$site_config{site_dir});
    $self->site_config($site_config);

    # (*@\label{_appendix_startup_accesslog}@*)
    $self->plugin(AccessLog => {log => "$$site_config{site_dir}/log/access.log", format => '%h %l %u %t "%r" %>s %b %D "%{Referer}i" "%{User-Agent}i"'});

    # (*@\label{_appendix_startup_hypnotoad}@*)
    my $listen = [];
    push(@{ $listen }, "http://$$site_config{hypnotoad_ip}:$$site_config{hypnotoad_port}") if $$site_config{hypnotoad_port};
    push(@{ $listen }, "https://$$site_config{hypnotoad_ip}:$$site_config{hypnotoad_tls}") if $$site_config{hypnotoad_tls};

    $self->config(hypnotoad => {listen => $listen, workers => $$site_config{hypnotoad_workers}, user => $$site_config{user}, group => $$site_config{group}, inactivity_timeout => 15, heartbeat_timeout => 15, heartbeat_interval => 15, accepts => 100});
    
    # Router
    # (*@\label{_appendix_startup_router}@*)
    my $r = $self->routes;

    # (*@\label{_appendix_startup_api}@*)
    my $api = $r->under (sub {
        my $self = shift;

        return($self->render(json => {status => "error", data => { message => "No JSON found" }})) unless $self->req->json;

        my $site_dir = $self->site_dir;
        my $username = $self->req->json->{username};
        my $api_key = $self->req->json->{api_key};

        unless ($username) {
            $self->render(json => {status => "error", data => { message => "No username found" }});

            return undef;
        }

        my $account = SiteCode::Account->new(username => $username);

        unless ($api_key) {
            $self->render(json => {status => "error", data => { message => "No API Key found" }});

            return undef;
        }

        unless ($api_key eq $account->key("api_key")) {
            $self->render(json => {status => "error", data => { message => "Credentials mis-match" }});

            return undef;
        }

        return 1;
    });
    
    # (*@\label{_appendix_startup_routes}@*)
    $r->get('/')->to(controller => 'Index', action => 'slash'); # (*@\label{_appendix_startup_slash_route}@*)
    $r->post('/save')->to(controller => 'Index', action => 'save');
    $r->post('/switch')->to(controller => 'Index', action => 'switch');
}

1;
