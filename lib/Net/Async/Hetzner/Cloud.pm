package Net::Async::Hetzner::Cloud;

# ABSTRACT: Async Hetzner Cloud API client for IO::Async

use strict;
use warnings;
use parent 'Net::Async::Hetzner::Base';

use Carp qw(croak);
use WWW::Hetzner::Cloud;

our $VERSION = '0.004';

sub configure {
    my ($self, %params) = @_;

    $self->{token} = delete $params{token} if exists $params{token};

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

sub _default_base_url { 'https://api.hetzner.cloud/v1' }

# Internal: sync Cloud instance for request building and response parsing
sub _new_sync {
    my ($self) = @_;
    WWW::Hetzner::Cloud->new(
        token    => $self->token,
        base_url => $self->base_url,
    );
}

sub _cloud { $_[0]->_sync }

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
variable. Requests croak if no token is available.

=attr base_url

Base URL for the Cloud API. Defaults to C<https://api.hetzner.cloud/v1>.

=attr timeout

Seconds after which a request fails its Future with C<timeout> (default 30,
like L<WWW::Hetzner::LWPIO>). C<0> disables the timeout.

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
