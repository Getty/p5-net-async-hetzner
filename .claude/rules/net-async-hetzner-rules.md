# Net-Async-Hetzner House Rules

Apply to every task in this repository unless explicitly overridden. Bias: caution over
speed on non-trivial work; use judgment on trivial tasks. Skill content is never restated
here: the skills are the source, the agents get them force-loaded via `briefing.skills`.
The async architecture, the transport seam, the `WWW::Hetzner` delegation and the mock test pattern live in
skill `net-async-hetzner-core`; Future/IO::Async idioms in `perl-io-async-future`; the `[@Author::GETTY]`
release and `dist.ini` conventions in `getty-perl-release-author-getty` and `perl-release-dist-ini` — don't
repeat that content.

## Engineering discipline

1. **Think before coding** — State assumptions, ask rather than guess, push back when a simpler approach
   exists, stop when confused; name what's unclear.
2. **Simplicity first** — Minimum code that solves the problem, nothing speculative.
3. **Surgical changes** — Touch only what you must; don't "improve" adjacent code, comments or formatting.
4. **Goal-driven execution** — Define success criteria, loop until verified; checkpoint after every
   significant step (done / verified / left).
5. **Surface conflicts, don't average them** — Contradicting patterns: pick one (more recent / more
   tested), explain why, flag the other. Don't blend.
6. **Read before you write** — Before new code, read the twin client, the transport seam and the
   wrapped `WWW::Hetzner::*` method you delegate to; the details live in `net-async-hetzner-core`.
7. **Tests verify intent, not just behavior** — Reproduce a bug before fixing it; leave a regression test
   behind. A test that can't fail when the logic changes is wrong.
8. **Match the codebase's conventions, even if you disagree** — Conformance > taste.
9. **Fail loud** — "Done" is wrong if anything was skipped silently. "Tests pass" is wrong if any were skipped.

## Delegation

If you can spawn subagents (orchestrating main agent): do NOT touch behavior-relevant code yourself — delegate to
`net-async-hetzner-worker`. Your lane: coordinate, inspect, plan, review diffs, run tests, edit non-behavioral docs.
When in doubt, delegate.

| Task | Agent |
|---|---|
| Implement / refactor / debug behavior-relevant code | `net-async-hetzner-worker` (default) |
| Write/extend tests | `net-async-hetzner-test-writer` |
| Commits, `Changes`, card → done, pre-release audit | `net-async-hetzner-release-manager` |

If you ARE a `net-async-hetzner-*` agent, the delegation lock does not apply to you — implement,
refactor, debug, and test per these rules.

Behavior-relevant = runtime behavior, the public API, the async transport seam (`_do_request`/`_http`), the
WWW::Hetzner delegation, the Future contract, IO::Async wiring, error propagation, tests. Pure prose docs, the changelog, and README are not.

**Only `net-async-hetzner-release-manager` commits.** A worker leaves a commit-ready tree and hands
its card to `review`; you then dispatch `net-async-hetzner-release-manager` to cut the commit and close it.

## Coordination — karr board (always in scope)

Ticket coordination is the orchestrating agent's job, so `karr` is always in scope — don't invoke the
`kanban-issues-karr-coordination` skill first, just use it. Git-native kanban; state lives in `refs/karr/*`; this repo has its own board.

- `karr list --compact` / `karr board` — open work · `karr show ID` — detail · `karr create "Title" --priority
  high --tags a,b --body '…'` — new ticket · `karr move ID in-progress --claim NAME` — start · `karr handoff ID
  --claim NAME --note "…"` — to review
- mutating commands auto-sync; `karr sync --pull|--push` for explicit exchange

A change that needs a different `_build_request`/`_parse_response` shape is owned by `WWW::Hetzner`: that is a
**ticket on `p5-www-hetzner`'s board**, never a silent cross-repo edit — do not touch the neighbour repo.

**Serialize board mutations when fanning out.** Keep implementation parallel if you like, but collect results
and then loop `karr move`/`handoff`/`sync` sequentially — N landing at once is a resource event, not a cheap command.

## Project-specific hazards

- **Cloud and Robot are twins — fix both or neither.** They share `_do_request` and the four verb methods
  almost verbatim, differing only in auth and the wrapped sync class. A fix applied to one and not the other
  passes that one's tests and leaves a silent bug in the sibling. Always check whether it belongs in both.
- **The delegation to `WWW::Hetzner` is the whole point.** Auth, JSON and error detection live in
  `_build_request`/`_parse_response`; error propagation depends on the parser *throwing* inside a `->then` so
  the Future fails. Hand-rolling any of that here silently diverges from the sync client — use the wrapped client.
- **Tests need `WWW::Hetzner` in `@INC`.** A bare `prove -lr t/` fails to load; always pass `-I../p5-www-hetzner/lib`.
  Tests must never hit the network — inject `Test::MockAsyncHTTP`.

## Release — never without permission, never alone

`dzil build` / `dzil test` / `prove -lr -I../p5-www-hetzner/lib t/` are fine anytime. `dzil release` and any
upload/tag/push are STRICTLY forbidden without the maintainer's explicit go-ahead — even if a plan or STATUS
document lists "release" as the next step. This distribution is **released together with `WWW::Hetzner`** (it reuses
that dist's private `_build_request`/`_parse_response`); the coupling is coordinated by a karr ticket, not by
releasing this side on its own. The local working-tree version is authoritative; a lagging CPAN version of either
dist is never a blocker and never a ticket. For anything heading toward release: stop and ask.

## Public issues — never act without instruction

`karr` is the internal agent board, churned freely. A public tracker (GitHub) carries real humans' issues, written
under the maintainer's account. Never act on a public issue on your own initiative — not even to read it. No
listing, viewing, commenting, editing, closing, or creating unless the user explicitly says to handle a specific issue.
