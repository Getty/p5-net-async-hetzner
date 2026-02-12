# Net-Async-Hetzner

Async Hetzner API clients for IO::Async. Built on top of
[WWW::Hetzner](https://github.com/Getty/p5-www-hetzner) for request building
and response parsing, with Net::Async::HTTP for non-blocking transport.

## Build & Test

```bash
dzil build
dzil test
prove -lv t/

# Tests need WWW::Hetzner in @INC:
prove -Ilib -I../p5-www-hetzner/lib t/

# Test coverage
PERL5OPT="-MDevel::Cover" prove -I../p5-www-hetzner/lib -l t/ && cover -report text
```

## Structure

```
lib/Net/Async/Hetzner.pm           # Umbrella module (docs only)
lib/Net/Async/Hetzner/Cloud.pm     # Async Cloud client (IO::Async::Notifier)
lib/Net/Async/Hetzner/Robot.pm     # Async Robot client (IO::Async::Notifier)
t/00-load.t                        # Module loading
t/cloud.t                          # Cloud API tests with MockAsyncHTTP
t/robot.t                          # Robot API tests with MockAsyncHTTP
```

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

Request flow:
1. `_build_request()` via sync WWW::Hetzner client - builds `HTTPRequest`
2. Convert to `HTTP::Request`, execute via `Net::Async::HTTP->do_request()` - returns Future
3. Convert `HTTP::Response` back to `HTTPResponse`, chain `_parse_response()` via `->then()`

All public methods (`get`, `post`, `put`, `delete`) return `Future` objects.

## Testing

Tests use a `Test::MockAsyncHTTP` notifier that replaces `Net::Async::HTTP`.
It extends `IO::Async::Notifier` and implements `do_request()` returning
`Future->done(HTTP::Response->new(...))`.

```perl
my $mock_http = Test::MockAsyncHTTP->new(
    responses => [{ status => 200, content => '{"servers":[]}' }],
);
my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test');
$cloud->{_http} = $mock_http;
$loop->add($cloud);
my $data = $cloud->get('/servers')->get;
```

The mock records all requests in `$mock_http->requests` for assertion.

## Tech

- **IO::Async** + **IO::Async::Notifier** for event loop integration
- **Net::Async::HTTP** for async HTTP
- **Future** for promises
- **WWW::Hetzner** for request/response logic (HTTPRequest, HTTPResponse, _build_request, _parse_response)
- **MIME::Base64** for Robot Basic Auth header
- **Dist::Zilla** with `[@Author::GETTY]`

## Related

- [WWW::Hetzner](https://github.com/Getty/p5-www-hetzner) - Sync Hetzner API client (provides IO architecture)
