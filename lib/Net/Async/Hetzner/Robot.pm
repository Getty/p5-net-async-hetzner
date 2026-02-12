package Net::Async::Hetzner::Robot;

# ABSTRACT: Async Hetzner Robot API client for IO::Async

use strict;
use warnings;
use parent 'IO::Async::Notifier';

use Carp qw(croak);
use Future;
use URI;
use HTTP::Request;
use WWW::Hetzner::Robot;
use WWW::Hetzner::HTTPResponse;

our $VERSION = '0.001';

sub configure {
    my ($self, %params) = @_;

    $self->{user}     = delete $params{user}     if exists $params{user};
    $self->{password} = delete $params{password} if exists $params{password};
    $self->{base_url} = delete $params{base_url} if exists $params{base_url};

    $self->SUPER::configure(%params);
}

sub user {
    my ($self) = @_;
    $self->{user} // $ENV{HETZNER_ROBOT_USER};
}

sub password {
    my ($self) = @_;
    $self->{password} // $ENV{HETZNER_ROBOT_PASSWORD};
}

sub _check_auth {
    my ($self) = @_;
    unless ($self->user && $self->password) {
        croak "No Robot credentials configured.\n\n"
            . "Set credentials via:\n"
            . "  Environment: HETZNER_ROBOT_USER and HETZNER_ROBOT_PASSWORD\n"
            . "  Options:     user => \$user, password => \$password\n\n"
            . "Get credentials at: https://robot.hetzner.com/preferences/index\n";
    }
}

sub base_url { $_[0]->{base_url} // 'https://robot-ws.your-server.de' }

# Internal: sync Robot instance for request building and response parsing
sub _robot {
    my ($self) = @_;
    $self->{_robot} //= WWW::Hetzner::Robot->new(
        user     => $self->user,
        password => $self->password,
        base_url => $self->base_url,
    );
}

# Internal: Net::Async::HTTP instance
sub _http {
    my ($self) = @_;
    unless ($self->{_http}) {
        require Net::Async::HTTP;
        $self->{_http} = Net::Async::HTTP->new(
            user_agent => 'Net-Async-Hetzner/' . $VERSION,
            max_connections_per_host => 0,
        );
    }
    return $self->{_http};
}

sub _add_to_loop {
    my ($self, $loop) = @_;
    $self->add_child($self->_http);
}

# ============================================================================
# ASYNC HTTP TRANSPORT
# ============================================================================

sub _do_request {
    my ($self, $req) = @_;

    my $uri = URI->new($req->url);

    my $http_req = HTTP::Request->new($req->method => $uri);
    my $headers = $req->headers;
    for my $key (keys %$headers) {
        $http_req->header($key => $headers->{$key});
    }
    $http_req->content($req->content) if $req->has_content;

    return $self->_http->do_request(
        request => $http_req,
    )->then(sub {
        my ($response) = @_;
        return Future->done(WWW::Hetzner::HTTPResponse->new(
            status  => $response->code,
            content => $response->decoded_content // $response->content // '',
        ));
    });
}

# ============================================================================
# ASYNC API METHODS - all return Futures
# ============================================================================

sub get {
    my ($self, $path, %params) = @_;
    my $robot = $self->_robot;
    my $req = $robot->_build_request('GET', $path, %params);
    return $self->_do_request($req)->then(sub {
        my ($response) = @_;
        return Future->done($robot->_parse_response($response, 'GET', $path));
    });
}

sub post {
    my ($self, $path, $data) = @_;
    my $robot = $self->_robot;
    my $req = $robot->_build_request('POST', $path, body => $data);
    return $self->_do_request($req)->then(sub {
        my ($response) = @_;
        return Future->done($robot->_parse_response($response, 'POST', $path));
    });
}

sub put {
    my ($self, $path, $data) = @_;
    my $robot = $self->_robot;
    my $req = $robot->_build_request('PUT', $path, body => $data);
    return $self->_do_request($req)->then(sub {
        my ($response) = @_;
        return Future->done($robot->_parse_response($response, 'PUT', $path));
    });
}

sub delete {
    my ($self, $path) = @_;
    my $robot = $self->_robot;
    my $req = $robot->_build_request('DELETE', $path);
    return $self->_do_request($req)->then(sub {
        my ($response) = @_;
        return Future->done($robot->_parse_response($response, 'DELETE', $path));
    });
}

1;

__END__

=encoding UTF-8

=head1 SYNOPSIS

    use IO::Async::Loop;
    use Net::Async::Hetzner::Robot;

    my $loop = IO::Async::Loop->new;

    my $robot = Net::Async::Hetzner::Robot->new(
        user     => $ENV{HETZNER_ROBOT_USER},
        password => $ENV{HETZNER_ROBOT_PASSWORD},
    );
    $loop->add($robot);

    # List dedicated servers
    my $servers = $robot->get('/server')->get;

    # Get specific server
    my $data = $robot->get('/server/123456')->get;
    print $data->{server}{server_name}, "\n";

=head1 DESCRIPTION

Async client for the Hetzner Robot API (dedicated servers) built on
L<IO::Async>. Extends L<IO::Async::Notifier> and uses L<Net::Async::HTTP>
for non-blocking HTTP communication.

All methods return L<Future> objects. Request building and response
parsing are delegated to L<WWW::Hetzner::Robot>.

=attr user

Robot webservice username. Falls back to C<HETZNER_ROBOT_USER> environment
variable.

=attr password

Robot webservice password. Falls back to C<HETZNER_ROBOT_PASSWORD>
environment variable.

=attr base_url

Base URL for the Robot API. Defaults to C<https://robot-ws.your-server.de>.

=method get($path, %params)

Async GET request. Returns a L<Future>.

=method post($path, \%body)

Async POST request with JSON body. Returns a L<Future>.

=method put($path, \%body)

Async PUT request with JSON body. Returns a L<Future>.

=method delete($path)

Async DELETE request. Returns a L<Future>.

=head1 SEE ALSO

L<Net::Async::Hetzner>, L<Net::Async::Hetzner::Cloud>,
L<WWW::Hetzner::Robot>, L<IO::Async>, L<Future>

=cut
