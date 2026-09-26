# Net::Async::Hetzner

Async Perl client for Hetzner's Cloud and Robot APIs, for use inside an IO::Async event
loop — every method returns a Future. It delegates request building, auth, JSON and error
handling to [WWW::Hetzner](https://github.com/Getty/p5-www-hetzner) (repo
`p5-www-hetzner`) and drives it over Net::Async::HTTP. The async architecture, the
transport seam and the mock-notifier test pattern are documented in the
`net-async-hetzner-core` skill — not here.

## Delegation

Delegate behavior-relevant code to the right agent instead of touching it yourself — the
principle, the delegation lock and the release rule are in
`.claude/rules/net-async-hetzner-rules.md`.

| Task | Agent |
|---|---|
| Implement / refactor / debug behavior-relevant code | `net-async-hetzner-worker` (default) |
| Write/extend tests | `net-async-hetzner-test-writer` |
| Commits, `Changes`, card → done, pre-release audit | `net-async-hetzner-release-manager` |

The agents carry their knowledge via `briefing.skills` (see `.claude/agents/`); the main
agent delegates rather than loading those skills itself. Skill sources live under
`.claude/skills/` — `net-async-hetzner-core` (this distribution), `perl-io-async-future`,
`getty-perl-release-author-getty`, `perl-release-dist-ini`, `kanban-issues-karr-coordination`.

Coordination runs on the repo's `karr` board (`karr board`). This distribution is released
**together with `WWW::Hetzner`** and never on its own; release is never run without the
maintainer's explicit go-ahead.

## Build & Test

```bash
dzil build
prove -lr -I../p5-www-hetzner/lib t/   # tests need WWW::Hetzner in @INC
```
