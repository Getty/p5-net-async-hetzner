# Net::Async::Hetzner House Rules

Apply to every task in this repository unless explicitly overridden. Bias: caution over
speed on non-trivial work; use judgment on trivial tasks. Loaded automatically at launch
(same priority as `CLAUDE.md`). Subagents get their discipline from the skills force-loaded
via `briefing.skills` — this file is for the orchestrating agent.

## Engineering discipline

1. **Think before coding** — State assumptions. When uncertain, ask rather than guess.
   Push back when a simpler approach exists. Stop when confused; name what's unclear.
2. **Simplicity first** — Minimum code that solves the problem. Nothing speculative.
3. **Surgical changes** — Touch only what you must. Don't "improve" adjacent code,
   comments, or formatting. Match existing style.
4. **Goal-driven execution** — Define success criteria, loop until verified.
5. **Surface conflicts, don't average them** — Contradicting patterns: pick one (more
   recent / more tested), explain why, flag the other. Don't blend.
6. **Read before you write** — Before new code, read the twin client (Cloud ↔ Robot are
   near-identical), the `_do_request`/`_http` transport seam, and the wrapped
   `WWW::Hetzner::*` method you delegate to. "Looks orthogonal" is dangerous.
7. **Tests verify intent, not just behavior** — Reproduce a bug before fixing it; leave a
   regression test behind. A test that can't fail when the logic changes is wrong.
8. **Checkpoint after every significant step** — Summarize: done / verified / left.
9. **Match the codebase's conventions, even if you disagree** — Conformance > taste.
10. **Fail loud** — "Done" is wrong if anything was skipped silently. "Tests pass" is
    wrong if any were skipped.

## Delegation

This rule depends on whether the Agent/Task tool is available to you.

- **You can spawn subagents** (orchestrating main agent): Do NOT touch behavior-relevant
  code yourself — delegate to `net-async-hetzner-worker`. Your lane: coordinate, inspect,
  plan, review diffs, run tests, manage git, edit non-behavioral docs. When in doubt,
  delegate. Why: only the `net-async-hetzner-*` agents get their skills force-loaded via
  `briefing.skills`; you get no briefing and would touch internals with too little context.
  Specialist lanes:

  | Task | Agent |
  |---|---|
  | Implement / refactor / debug behavior-relevant code | `net-async-hetzner-worker` (default) |
  | Write/extend tests | `net-async-hetzner-test-writer` |
  | Pre-release audit | `net-async-hetzner-release-checker` |

- **You cannot spawn subagents** (you ARE a `net-async-hetzner-*` agent): The delegation
  lock does not apply to you — implement, refactor, debug, and test per these rules.

Behavior-relevant = runtime behavior, the public API, the async transport seam
(`_do_request`/`_http`), the WWW::Hetzner delegation, the Future contract, IO::Async
wiring, error propagation, tests. Pure prose docs, the changelog, and README are not.

## Coordination — karr board (always in scope)

Ticket coordination is the orchestrating agent's job, so `karr` is always in scope — don't
invoke the `kanban-issues-karr-cli` skill first, just use it. Git-native kanban; state
lives in `refs/karr/*`; this repo has its own board.

- `karr list --compact` / `karr board` — open work · `karr show ID` — detail
- `karr create "Title" --priority high --tags a,b --body '…'` — new ticket
- `karr move ID in-progress --claim NAME` — start · `karr handoff ID --claim NAME --note "…"` — to review
- mutating commands auto-sync; `karr sync --pull|--push` for explicit exchange

A change that needs a different `_build_request`/`_parse_response` shape is owned by
`WWW::Hetzner`: that is a **ticket on `p5-www-hetzner`'s board**, never a silent cross-repo
edit — do not touch the neighbour repo. Full command surface: skill `kanban-issues-karr-cli`.

**Serialize board mutations when fanning out.** Keep implementation parallel if you like,
but collect results and then loop `karr move`/`handoff`/`sync` sequentially — N landing at
once is a resource event, not a cheap command.

## Release — never without permission, never alone

`dzil build` / `dzil test` / `prove -lr -I../p5-www-hetzner/lib t/` are fine anytime.
`dzil release` and any upload/tag/push are STRICTLY forbidden without the maintainer's
explicit go-ahead — even if a plan or STATUS document lists "release" as the next step.
This distribution is **released together with `WWW::Hetzner`** (it reuses that dist's
private `_build_request`/`_parse_response`); the coupling is coordinated by a karr ticket,
not by releasing this side on its own. The local working-tree version is authoritative; a
lagging CPAN version of either dist is never a blocker and never a ticket. For anything
heading toward release: stop and ask.

## Project-specific hazards

- **Cloud and Robot are twins — fix both or neither.** They share `_do_request` and the
  four verb methods almost verbatim, differing only in auth and the wrapped sync class. A
  fix applied to one and not the other passes that one's tests and leaves a silent bug in
  the sibling. Always check whether the change belongs in both.
- **The delegation to `WWW::Hetzner` is the whole point.** Auth, JSON, and error detection
  live in `_build_request`/`_parse_response`; error propagation depends on the parser
  *throwing* inside a `->then` so the Future fails. Hand-rolling any of that here looks
  correct in isolation and silently diverges from the sync client — route everything
  through the wrapped client.
- **Tests need `WWW::Hetzner` in `@INC`.** A bare `prove -lr t/` fails to load; always pass
  `-I../p5-www-hetzner/lib`. Tests must never hit the network — inject `Test::MockAsyncHTTP`.

## Perl / async / release specifics — reference, don't restate

The async architecture, the transport seam, the WWW::Hetzner delegation and the mock test
pattern live in skill `net-async-hetzner-core`; Future/IO::Async idioms in
`perl-io-async-future`; the `[@Author::GETTY]` release and `dist.ini` conventions in
`getty-perl-release-author-getty` and `perl-release-dist-ini` (all force-loaded for
`net-async-hetzner-*` agents). Do not duplicate that content here.
