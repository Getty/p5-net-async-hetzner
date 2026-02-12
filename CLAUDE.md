# Net-Async-Hetzner

Async Hetzner API clients for IO::Async.

## Build & Test

```bash
dzil build
dzil test
prove -lv t/
# Tests need WWW::Hetzner in @INC:
prove -Ilib -I../p5-www-hetzner/lib t/
```

## Structure

```
lib/Net/Async/Hetzner.pm           # Umbrella module
lib/Net/Async/Hetzner/Cloud.pm     # Async Cloud client (IO::Async::Notifier)
lib/Net/Async/Hetzner/Robot.pm     # Async Robot client (IO::Async::Notifier)
```

## Architecture

- Extends `IO::Async::Notifier`, uses `Net::Async::HTTP` for async transport
- Delegates request building (`_build_request`) and response parsing (`_parse_response`) to sync `WWW::Hetzner::Cloud` / `WWW::Hetzner::Robot`
- All public methods (`get`, `post`, `put`, `delete`) return `Future` objects
- Tests use a `Test::MockAsyncHTTP` notifier to mock `Net::Async::HTTP`

## Tech

- **IO::Async** + **IO::Async::Notifier** for event loop integration
- **Net::Async::HTTP** for async HTTP
- **Future** for promises
- **WWW::Hetzner** for request/response logic
- **Dist::Zilla** with `[@Author::GETTY]`
