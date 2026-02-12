package Net::Async::Hetzner;

# ABSTRACT: Async Hetzner API clients for IO::Async

use strict;
use warnings;

our $VERSION = '0.002';

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

    # Future-based API - all methods return Futures
    my $servers = $cloud->get('/servers')->get;

    $cloud->post('/servers', {
        name        => 'my-server',
        server_type => 'cx22',
        image       => 'debian-12',
        location    => 'fsn1',
    })->then(sub {
        my ($data) = @_;
        print "Created: $data->{server}{name}\n";
        return Future->done;
    })->get;

    # Robot API
    use Net::Async::Hetzner::Robot;

    my $robot = Net::Async::Hetzner::Robot->new(
        user     => $ENV{HETZNER_ROBOT_USER},
        password => $ENV{HETZNER_ROBOT_PASSWORD},
    );
    $loop->add($robot);

    my $servers = $robot->get('/server')->get;

=head1 DESCRIPTION

C<Net::Async::Hetzner> provides async clients for Hetzner APIs built on
L<IO::Async>. All HTTP methods return L<Future> objects for non-blocking
operation.

Request building, authentication, and response parsing are delegated to
L<WWW::Hetzner>, so the same JSON handling, error messages, and logging
are available.

=head2 Available Clients

=over 4

=item * L<Net::Async::Hetzner::Cloud> - Hetzner Cloud API (servers, volumes, DNS, etc.)

=item * L<Net::Async::Hetzner::Robot> - Hetzner Robot API (dedicated servers)

=back

=head1 SEE ALSO

L<Net::Async::Hetzner::Cloud>, L<Net::Async::Hetzner::Robot>,
L<WWW::Hetzner>, L<IO::Async>, L<Future>

=cut
