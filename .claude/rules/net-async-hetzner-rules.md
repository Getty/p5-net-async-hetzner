# Net-Async-Hetzner House Rules

The shared house rules come from skilletor — bundle `getty-cpan-dist@getty`: engineering
discipline, the delegation lock, the publish gate, karr coordination, CPAN release. They load
as `.claude/rules/.local.*.md`; if they are missing, run `skilletor sync` and publish nothing
until they load. This file adds what is true only here, and wins where it differs.

## What this repo is

Async Hetzner API clients for IO::Async, delegating to `WWW::Hetzner` (repo `p5-www-hetzner`).
Read first: the shared transport in `Net::Async::Hetzner::Base`, the sibling clients and the
wrapped `WWW::Hetzner::*` method you delegate to; details in `net-async-hetzner-core`.

## Agent team

| Task | Agent |
|---|---|
| Implement / refactor / debug behavior-relevant code | `net-async-hetzner-worker` (default) |
| Write/extend tests | `net-async-hetzner-test-writer` |
| Commits, `Changes`, card → done, pre-release audit | `net-async-hetzner-release-manager` |
| Read-only research, audit, gap analysis | `net-async-hetzner-worker` ("read-only, change nothing") |

Behavior-relevant = runtime behavior, the public API, the async transport seam
(`_do_request`/`_http`), the WWW::Hetzner delegation, the Future contract, IO::Async wiring,
error propagation, tests. Pure prose docs, the changelog and README are not.

## Release — together with WWW::Hetzner, never alone

Test command: `prove -lr -I../p5-www-hetzner/lib t/`. This distribution reuses
`WWW::Hetzner`'s private `_build_request`/`_parse_response` and is released together with it;
the coupling is coordinated by a karr ticket, not by releasing this side on its own. A change
that needs a different `_build_request`/`_parse_response` shape is a ticket on
`p5-www-hetzner`'s board.

## Hazards

- **Cloud, Robot and Storage share one transport — fix it where it lives.** `_do_request` and
  the verb methods sit in `Net::Async::Hetzner::Base`; the clients differ only in auth and the
  wrapped sync class. A fix patched into one client passes that client's tests and leaves the
  siblings broken. Check whether it belongs in `Base`.
- **The delegation to `WWW::Hetzner` is the whole point.** Auth, JSON and error detection live
  in `_build_request`/`_parse_response`; error propagation depends on the parser *throwing*
  inside a `->then` so the Future fails. Hand-rolling any of that here silently diverges from
  the sync client — use the wrapped client.
- **Tests need `WWW::Hetzner` in `@INC`.** A bare `prove -lr t/` fails to load; always pass
  `-I../p5-www-hetzner/lib`. Tests never hit the network — inject `Test::MockAsyncHTTP`.

## Perl / async specifics — reference, don't restate

The async architecture, the transport seam and the mock test pattern live in
`net-async-hetzner-core`; Future/IO::Async idioms in `perl-io-async-future`; release and
`dist.ini` conventions in `getty-perl-release-author-getty` and `perl-release-dist-ini`.
