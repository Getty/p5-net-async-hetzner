package Net::Async::Hetzner::Storage;

# ABSTRACT: Async Hetzner Storage Box API client for IO::Async

use strict;
use warnings;
use parent 'Net::Async::Hetzner::Base';

use Carp qw(croak);
use WWW::Hetzner::Storage;

our $VERSION = '0.004';

sub configure {
    my ($self, %params) = @_;

    $self->{token} = delete $params{token} if exists $params{token};

    $self->SUPER::configure(%params);
}

sub token {
    my ($self) = @_;
    $self->{token} // $ENV{HETZNER_API_TOKEN};
}

sub _check_auth {
    my ($self) = @_;
    unless ($self->token) {
        croak "No Storage API token configured.\n\n"
            . "Set token via:\n"
            . "  Environment: HETZNER_API_TOKEN\n"
            . "  Option:      token => \$token\n\n"
            . "Get token at: https://console.hetzner.cloud/ -> Select project -> Security -> API tokens\n";
    }
}

sub _default_base_url { 'https://api.hetzner.com/v1' }

# Internal: sync Storage instance for request building and response parsing
sub _new_sync {
    my ($self) = @_;
    WWW::Hetzner::Storage->new(
        token    => $self->token,
        base_url => $self->base_url,
    );
}

1;

__END__

=encoding UTF-8

=head1 SYNOPSIS

    use IO::Async::Loop;
    use Net::Async::Hetzner::Storage;

    my $loop = IO::Async::Loop->new;

    my $storage = Net::Async::Hetzner::Storage->new(
        token => $ENV{HETZNER_API_TOKEN},
    );
    $loop->add($storage);

    # List Storage Boxes
    my $data = $storage->get('/storage_boxes')->get;
    for my $box (@{ $data->{storage_boxes} }) {
        printf "%s (%s)\n", $box->{name}, $box->{status};
    }

=head1 DESCRIPTION

Async client for the Hetzner Storage Box API (C<api.hetzner.com>) built on
L<IO::Async>. Extends L<Net::Async::Hetzner::Base>, which provides the
L<Net::Async::HTTP> transport and the C<get>/C<post>/C<put>/C<delete>
methods; they all return L<Future> objects. Request building and response
parsing are delegated to L<WWW::Hetzner::Storage>.

=attr token

Hetzner API token. Falls back to C<HETZNER_API_TOKEN> environment variable.
Requests croak if no token is available.

=attr base_url

Base URL for the Storage Box API. Defaults to C<https://api.hetzner.com/v1>.

=attr timeout

Seconds after which a request fails its Future with C<timeout> (default 30).
C<0> disables the timeout.

=head1 SEE ALSO

L<Net::Async::Hetzner>, L<Net::Async::Hetzner::Base>,
L<WWW::Hetzner::Storage>, L<IO::Async>, L<Future>

=cut
