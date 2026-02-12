package Net::Async::Hetzner::Cloud;

# ABSTRACT: Async Hetzner Cloud API client for IO::Async

use strict;
use warnings;
use parent 'IO::Async::Notifier';

use Carp qw(croak);
use Future;
use URI;
use HTTP::Request;
use WWW::Hetzner::Cloud;
use WWW::Hetzner::HTTPResponse;

our $VERSION = '0.003';

sub configure {
    my ($self, %params) = @_;

    $self->{token}    = delete $params{token}    if exists $params{token};
    $self->{base_url} = delete $params{base_url} if exists $params{base_url};

    $self->SUPER::configure(%params);
}

sub token {
    my ($self) = @_;
    $self->{token} // $ENV{HETZNER_API_TOKEN}
        // croak "No Cloud API token configured.\n\n"
            . "Set token via:\n"
            . "  Environment: HETZNER_API_TOKEN\n"
            . "  Option:      token => \$token\n\n"
            . "Get token at: https://console.hetzner.cloud/ -> Select project -> Security -> API tokens\n";
}

sub base_url { $_[0]->{base_url} // 'https://api.hetzner.cloud/v1' }

# Internal: sync Cloud instance for request building and response parsing
sub _cloud {
    my ($self) = @_;
    $self->{_cloud} //= WWW::Hetzner::Cloud->new(
        token    => $self->token,
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
    my $cloud = $self->_cloud;
    my $req = $cloud->_build_request('GET', $path, %params);
    return $self->_do_request($req)->then(sub {
        my ($response) = @_;
        return Future->done($cloud->_parse_response($response, 'GET', $path));
    });
}

sub post {
    my ($self, $path, $data) = @_;
    my $cloud = $self->_cloud;
    my $req = $cloud->_build_request('POST', $path, body => $data);
    return $self->_do_request($req)->then(sub {
        my ($response) = @_;
        return Future->done($cloud->_parse_response($response, 'POST', $path));
    });
}

sub put {
    my ($self, $path, $data) = @_;
    my $cloud = $self->_cloud;
    my $req = $cloud->_build_request('PUT', $path, body => $data);
    return $self->_do_request($req)->then(sub {
        my ($response) = @_;
        return Future->done($cloud->_parse_response($response, 'PUT', $path));
    });
}

sub delete {
    my ($self, $path) = @_;
    my $cloud = $self->_cloud;
    my $req = $cloud->_build_request('DELETE', $path);
    return $self->_do_request($req)->then(sub {
        my ($response) = @_;
        return Future->done($cloud->_parse_response($response, 'DELETE', $path));
    });
}

1;

__END__

=encoding UTF-8

=head1 SYNOPSIS

    use IO::Async::Loop;
    use Net::Async::Hetzner::Cloud;

    my $loop = IO::Async::Loop->new;

    my $cloud = Net::Async::Hetzner::Cloud->new(
        token => $ENV{HETZNER_API_TOKEN},
    );
    $loop->add($cloud);

    # List servers
    my $data = $cloud->get('/servers')->get;
    for my $server (@{ $data->{servers} }) {
        printf "%s (%s)\n", $server->{name}, $server->{status};
    }

    # Create server (non-blocking)
    $cloud->post('/servers', {
        name        => 'my-server',
        server_type => 'cx22',
        image       => 'debian-12',
        location    => 'fsn1',
    })->then(sub {
        my ($data) = @_;
        print "Created: $data->{server}{id}\n";
        return Future->done;
    })->get;

    # Parallel requests
    my @futures = map {
        $cloud->get("/servers/$_")
    } @server_ids;

    my @results = Future->wait_all(@futures)->get;

=head1 DESCRIPTION

Async client for the Hetzner Cloud API built on L<IO::Async>. Extends
L<IO::Async::Notifier> and uses L<Net::Async::HTTP> for non-blocking
HTTP communication.

All methods return L<Future> objects. Request building and response
parsing are delegated to L<WWW::Hetzner::Cloud>.

=attr token

Hetzner Cloud API token. Falls back to C<HETZNER_API_TOKEN> environment
variable.

=attr base_url

Base URL for the Cloud API. Defaults to C<https://api.hetzner.cloud/v1>.

=method get($path, %params)

    my $f = $cloud->get('/servers', params => { label_selector => 'env=prod' });

Async GET request. Returns a L<Future> that resolves to the parsed JSON
response data.

=method post($path, \%body)

    my $f = $cloud->post('/servers', { name => 'test', ... });

Async POST request with JSON body.

=method put($path, \%body)

    my $f = $cloud->put('/servers/123', { name => 'renamed' });

Async PUT request with JSON body.

=method delete($path)

    my $f = $cloud->delete('/servers/123');

Async DELETE request.

=head1 SEE ALSO

L<Net::Async::Hetzner>, L<Net::Async::Hetzner::Robot>,
L<WWW::Hetzner::Cloud>, L<IO::Async>, L<Future>

=cut
