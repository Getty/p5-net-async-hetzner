package Net::Async::Hetzner::Base;

# ABSTRACT: Shared async transport base for the Hetzner API clients

use strict;
use warnings;
use parent 'IO::Async::Notifier';

use Carp qw(croak);
use Future;
use URI;
use HTTP::Request;
use Net::Async::HTTP;
use WWW::Hetzner::HTTPResponse;

our $VERSION = '0.004';

sub configure {
    my ($self, %params) = @_;

    $self->{base_url} = delete $params{base_url} if exists $params{base_url};
    $self->{timeout}  = delete $params{timeout}  if exists $params{timeout};
    # cached sync client holds the old credentials/URL
    delete $self->{_sync};

    $self->SUPER::configure(%params);
}

sub base_url { $_[0]->{base_url} // $_[0]->_default_base_url }

sub timeout { $_[0]->{timeout} // 30 }

sub _default_base_url { croak ref($_[0]) . " must implement _default_base_url" }

sub _new_sync { croak ref($_[0]) . " must implement _new_sync" }

# Subclasses croak here when credentials are missing
sub _check_auth { }

# Internal: sync client for request building and response parsing
sub _sync {
    my ($self) = @_;
    $self->{_sync} //= $self->_new_sync;
}

# Internal: Net::Async::HTTP instance
sub _http {
    my ($self) = @_;
    unless ($self->{_http}) {
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

    # timeout 0 means none: Net::Async::HTTP would fire a 0s timer otherwise
    my $timeout = $self->timeout;
    return $self->_http->do_request(
        request => $http_req,
        ($timeout ? (timeout => $timeout) : ()),
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

sub _request {
    my ($self, $method, $path, @build_args) = @_;
    $self->_check_auth;
    my $sync = $self->_sync;
    my $req = $sync->_build_request($method, $path, @build_args);
    return $self->_do_request($req)->then(sub {
        my ($response) = @_;
        return Future->done($sync->_parse_response($response, $method, $path));
    });
}

sub get {
    my ($self, $path, %params) = @_;
    return $self->_request('GET', $path, %params);
}

sub post {
    my ($self, $path, $data) = @_;
    return $self->_request('POST', $path, body => $data);
}

sub put {
    my ($self, $path, $data) = @_;
    return $self->_request('PUT', $path, body => $data);
}

sub delete {
    my ($self, $path) = @_;
    return $self->_request('DELETE', $path);
}

1;

__END__

=encoding UTF-8

=head1 SYNOPSIS

    package Net::Async::Hetzner::Example;
    use parent 'Net::Async::Hetzner::Base';

    sub _default_base_url { 'https://api.example/v1' }
    sub _new_sync { WWW::Hetzner::Example->new(base_url => $_[0]->base_url) }

=head1 DESCRIPTION

Transport shared by L<Net::Async::Hetzner::Cloud>,
L<Net::Async::Hetzner::Robot> and L<Net::Async::Hetzner::Storage>. Extends
L<IO::Async::Notifier> and drives the request a wrapped WWW::Hetzner client
builds over L<Net::Async::HTTP>; the same client parses the response, so
authentication, JSON handling and API errors behave like the sync client.

A subclass implements C<_default_base_url> and C<_new_sync> (returns the
WWW::Hetzner client, built from its own credentials), may override
C<_check_auth> to croak early when credentials are missing, and handles its
own credential parameters in C<configure> before calling the parent.

=attr base_url

Base URL of the API. Defaults to the subclass's C<_default_base_url>.

=attr timeout

Seconds after which a request fails its Future with C<timeout> (default 30,
like L<WWW::Hetzner::LWPIO>). C<0> disables the timeout.

=head1 ERRORS

A non-2xx response fails the Future with a L<WWW::Hetzner::Error> object,
the same one the sync client throws. It carries C<status> (HTTP status),
C<code> (the API's error code, if any), C<api_message> (the API's message,
if any) and C<message> (the full text). Stringified it reads
C<Hetzner API error: E<lt>messageE<gt> (E<lt>statusE<gt> E<lt>codeE<gt>)>, so
matching the text keeps working:

    $client->get('/servers/999')->on_fail(sub {
        my ($error) = @_;
        warn "not found" if ref $error && $error->status == 404;
    });

Failures that are not API errors, such as a timeout, are not this object.

=method get($path, %params)

    my $f = $client->get('/servers', params => { label_selector => 'env=prod' });

Async GET request. Returns a L<Future> that resolves to the parsed response
data.

=method post($path, \%body)

Async POST request. Returns a L<Future>.

=method put($path, \%body)

Async PUT request. Returns a L<Future>.

=method delete($path)

Async DELETE request. Returns a L<Future>.

=head1 SEE ALSO

L<Net::Async::Hetzner>, L<WWW::Hetzner::Role::HTTP>, L<IO::Async>, L<Future>

=cut
