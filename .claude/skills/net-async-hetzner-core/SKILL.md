---
name: net-async-hetzner-core
description: "Architecture, vocabulary and invariants of the Net::Async::Hetzner distribution — the async IO::Async client for Hetzner's Cloud and Robot APIs that delegates request building and response parsing to WWW::Hetzner and drives them over Net::Async::HTTP, every method returning a Future. Load when implementing, refactoring, testing or documenting anything in p5-net-async-hetzner."
user-invocable: false
allowed-tools: Read, Grep, Glob
model: sonnet
---

# Net::Async::Hetzner — async Hetzner API client

Async Perl client for Hetzner's two APIs, for use inside an L<IO::Async> event loop.
Every public method returns a L<Future>. It is the **async sibling** of `WWW::Hetzner`
(repo `p5-www-hetzner`): it does **not** re-implement request building, authentication,
JSON handling or error detection — it borrows all of that from the sync distribution and
supplies only a non-blocking transport.

- **Cloud** (`Net::Async::Hetzner::Cloud`) — bearer-token auth, base
  `https://api.hetzner.cloud/v1`.
- **Robot** (`Net::Async::Hetzner::Robot`) — HTTP Basic auth (user/password), base
  `https://robot-ws.your-server.de`.

The two client classes are near-identical twins; the only real differences are the auth
inputs (`token` vs `user`/`password`) and which sync class they wrap. Keep them in
lockstep — a fix to one almost always applies to the other.

## Tech baseline

- **`parent 'IO::Async::Notifier'`** — plain Perl OO, **no Moo** in this distribution
  (the sync side uses Moo; this side does not). `configure` unpacks the client's own
  params and delegates the rest to `SUPER::configure`.
- **Net::Async::HTTP** — the async transport, lazily built in `_http`, added to the loop
  as a child notifier in `_add_to_loop` via `add_child`.
- **Future** — every `get`/`post`/`put`/`delete` returns one; a `->then` chain converts
  the HTTP response and runs the sync parser.
- **WWW::Hetzner::Cloud / ::Robot** — the wrapped sync clients, built lazily in `_cloud`
  / `_robot`, used purely for `_build_request` and `_parse_response`.
- **HTTP::Request / URI** — used to translate the transport-independent request into what
  Net::Async::HTTP wants; **WWW::Hetzner::HTTPResponse** wraps the reply back.
- **Dist::Zilla** with `[@Author::GETTY]`; POD lives in `__END__` with `=attr`/`=method`.

## Module layout

```
lib/Net/Async/Hetzner.pm         # umbrella / docs only (ABSTRACT + SYNOPSIS)
lib/Net/Async/Hetzner/Cloud.pm   # async Cloud client  (IO::Async::Notifier, bearer auth)
lib/Net/Async/Hetzner/Robot.pm   # async Robot client  (IO::Async::Notifier, basic auth)
t/00-load.t                      # module loading
t/cloud.t                        # Cloud tests, in-file Test::MockAsyncHTTP notifier
t/robot.t                        # Robot tests, same mock pattern
```

There are no per-resource classes here — unlike the sync distribution's Cloud
`API::*`/entity/CLI mesh, this client exposes only the four verb methods over raw paths.
The resource surface, entity shapes and the request/response contract are documented in
the sync side; do not restate them here.

## The transport seam — how a call flows

The single mechanism, identical in both clients (`_do_request`):

1. `$cloud->get('/servers')` builds the request through the **wrapped sync client**:
   `$self->_cloud->_build_request('GET', $path, %params)` → a `WWW::Hetzner::HTTPRequest`
   (method, url, headers incl. auth, content). POST/PUT pass the payload as `body => $data`.
2. `_do_request($req)` converts that to an `HTTP::Request` (URI, copy each header, set
   content if `$req->has_content`), calls `$self->_http->do_request(request => ...)`,
   and `->then`-maps the `HTTP::Response` into a `WWW::Hetzner::HTTPResponse`
   (`status` = `code`, `content` = `decoded_content // content // ''`).
3. The verb method chains `->then(sub { Future->done($cloud->_parse_response($response,
   $METHOD, $path)) })` — the sync parser decodes JSON and, on an API error, **throws**;
   because it throws inside a `then` block the Future ends up **failed**, which is how
   error propagation works (see `t/cloud.t` "async error handling").

Invariants that must not drift:

- **All auth, JSON encode/decode and error detection belong to the wrapped sync client.**
  Never hand-build an auth header, parse JSON, or check status codes in this distribution —
  route it through `_build_request` / `_parse_response`. Reimplementing any of that here
  silently diverges from the sync client and the shared contract.
- **`_build_request` / `_parse_response` are the shared contract with `WWW::Hetzner`.**
  Their shape is owned upstream. If a change here needs a different shape, that is a
  cross-repo change: file a karr ticket on `p5-www-hetzner`'s board, do not work around it
  locally.
- **`_http` is injectable and that is the test seam.** Tests replace `$self->{_http}`
  with a mock notifier before `$loop->add`. Keep `_http` a lazy accessor reading
  `$self->{_http}` so injection keeps working.

## Testing — mock the async transport, no live calls

Tests never hit the network. Each test file defines an in-file **`Test::MockAsyncHTTP`**
notifier (`parent 'IO::Async::Notifier'`) that stands in for Net::Async::HTTP:

- It implements `do_request(%args)`, pushes `\%args` onto `->requests` (so assertions can
  inspect the real `HTTP::Request` at `->requests->[i]{request}`), and returns
  `Future->done(HTTP::Response->new($status, ...))` built from a queued `responses` list
  (indexed per call, falling back to `responses[0]`).
- Wire it in by assigning `$client->{_http} = $mock_http` **before** `$loop->add($client)`,
  then call verbs and `->get` the Future synchronously.

```perl
my $mock_http = Test::MockAsyncHTTP->new(
    responses => [{ status => 200, content => '{"servers":[]}' }],
);
my $cloud = Net::Async::Hetzner::Cloud->new(token => 'test');
$cloud->{_http} = $mock_http;
$loop->add($cloud);
my $data = $cloud->get('/servers')->get;
is $mock_http->requests->[0]{request}->header('Authorization'), 'Bearer test';
```

Assert on the outgoing request (method, URI/path, auth header, body JSON) via the recorded
`requests`, and on parsing via the resolved data. For an API error, queue a non-2xx
`status` with an `{"error":{"message":...}}` body and assert the Future `is_failed` with
the message in `->failure` — the failure comes from the sync parser throwing.

Run the suite: tests need `WWW::Hetzner` in `@INC` and this dist's `lib`:
`prove -lr -I../p5-www-hetzner/lib t/` (recursive; keeps working if subdir tests are added).

## Release coupling — never released alone

`Net::Async::Hetzner` depends on `WWW::Hetzner` at runtime and reuses its private
`_build_request`/`_parse_response`. A contract change spans both distributions, so they
are released together, coordinated on `p5-www-hetzner`'s board via a karr ticket. The
local working-tree state is authoritative; a lagging CPAN version of either side is never
a blocker and never a ticket.

## Related

- `p5-www-hetzner` — `WWW::Hetzner`, the sync client that owns request building, auth,
  JSON and error handling (skill `www-hetzner-core` in that repo documents the resource
  mesh and the request/response contract this client consumes).
