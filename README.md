# Net-Async-Hetzner

Async Hetzner API clients for IO::Async.

Built on [WWW::Hetzner](https://metacpan.org/pod/WWW::Hetzner) for request
building and response parsing, with [Net::Async::HTTP](https://metacpan.org/pod/Net::Async::HTTP)
for non-blocking transport. All methods return [Future](https://metacpan.org/pod/Future) objects.

## Installation

```bash
cpanm Net::Async::Hetzner
```

## Cloud API

```perl
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

# Create server
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
my @futures = map { $cloud->get("/servers/$_") } @server_ids;
Future->wait_all(@futures)->get;

# Delete
$cloud->delete("/servers/$id")->get;
```

## Robot API (Dedicated Servers)

```perl
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
```

## API Methods

All methods return [Future](https://metacpan.org/pod/Future) objects.

| Method | Description |
|--------|-------------|
| `get($path, %params)` | GET request, optional query params |
| `post($path, \%body)` | POST with JSON body |
| `put($path, \%body)` | PUT with JSON body |
| `delete($path)` | DELETE request |

Use `->get` to block until the Future resolves, or `->then(sub { ... })` for
non-blocking chaining.

## Architecture

```
Net::Async::Hetzner::Cloud          Net::Async::Hetzner::Robot
        |                                    |
        v                                    v
  IO::Async::Notifier              IO::Async::Notifier
        |                                    |
        +-----> Net::Async::HTTP <-----------+
        |       (async transport)            |
        v                                    v
  WWW::Hetzner::Cloud              WWW::Hetzner::Robot
  (_build_request /                (_build_request /
   _parse_response)                 _parse_response)
```

Request building and response parsing are delegated to the sync
[WWW::Hetzner](https://metacpan.org/pod/WWW::Hetzner) modules.
Only the HTTP transport is async.

## Development

```bash
# Run tests (needs WWW::Hetzner in @INC)
prove -I../p5-www-hetzner/lib -l t/

# Build
dzil build

# Release
dzil release
```

## See Also

- [WWW::Hetzner](https://metacpan.org/pod/WWW::Hetzner) - Sync Hetzner API client
- [IO::Async](https://metacpan.org/pod/IO::Async) - Async event framework
- [Future](https://metacpan.org/pod/Future) - Future/Promise implementation

## License

This is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

## Author

Torsten Raudssus <torsten@raudssus.de> ([GETTY](https://metacpan.org/author/GETTY))
