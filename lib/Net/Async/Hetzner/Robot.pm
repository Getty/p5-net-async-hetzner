package Net::Async::Hetzner::Robot;

# ABSTRACT: Async Hetzner Robot API client for IO::Async

use strict;
use warnings;
use parent 'Net::Async::Hetzner::Base';

use Carp qw(croak);
use WWW::Hetzner::Robot;

our $VERSION = '0.004';

sub configure {
    my ($self, %params) = @_;

    $self->{user}     = delete $params{user}     if exists $params{user};
    $self->{password} = delete $params{password} if exists $params{password};

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

sub _default_base_url { 'https://robot-ws.your-server.de' }

# Internal: sync Robot instance for request building and response parsing
sub _new_sync {
    my ($self) = @_;
    WWW::Hetzner::Robot->new(
        user     => $self->user,
        password => $self->password,
        base_url => $self->base_url,
    );
}

sub _robot { $_[0]->_sync }

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

=attr timeout

Seconds after which a request fails its Future with C<timeout> (default 30,
like L<WWW::Hetzner::LWPIO>). C<0> disables the timeout.

=method get($path, %params)

Async GET request. Croaks if no credentials are configured. Returns a L<Future>.

=method post($path, \%body)

Async POST request. The body is sent form-encoded (as the Robot API expects). Croaks
if no credentials are configured. Returns a L<Future>.

=method put($path, \%body)

Async PUT request, form-encoded like C<post>. Returns a L<Future>.

=method delete($path)

Async DELETE request. Returns a L<Future>.

=head1 SEE ALSO

L<Net::Async::Hetzner>, L<Net::Async::Hetzner::Cloud>,
L<WWW::Hetzner::Robot>, L<IO::Async>, L<Future>

=cut
