# Project Instructions

## First Session on This Codebase

If `.diamond-testing/manifest.md` does not exist yet, the BDD-driven diamond testing harness has not been set up for this codebase. Proactively offer to run the `diamond-testing-setup` skill before doing anything else test-related — do not wait for the engineer to ask, and do not explain the process in prose; the skill itself walks them through it interactively. This applies whether they've just unzipped a fresh checkout or are opening an established repo for the first time in this project's history.

## Acceptance Criteria (BDD) — Mandatory for User-Facing Behavior

Before writing code for anything with a business-visible outcome (a new feature, a changed rule, a new endpoint's observable behavior — not internal refactors), invoke the `bdd-acceptance-writer` subagent to elicit and draft Gherkin `Given/When/Then` acceptance criteria, and get them confirmed with the user (standing in for the product owner) before implementation proceeds.

- Do not write the acceptance criteria yourself. Do not let `diamond-testing-expert` invent them either — its E2E tier is required to be sourced from these approved scenarios, not from its own judgment (see below).
- The output is a `.feature` file, saved under the project's convention (default `src/test/resources/features/`), tagged with the relevant ticket/story ID.
- If a task has no ticket ID, ask for one rather than proceeding untracked.
- A scenario is not acceptance criteria until the user has explicitly confirmed it — a drafted-but-unconfirmed scenario blocks the E2E tier, not just the plan.

## Test Strategy — Mandatory Delegation

This project follows the **testing diamond** approach exclusively, via a discovery-gated, multi-specialist architecture — not one agent writing everything. You do not design, write, or approve tests directly.

### The agent roster

- `boundary-discovery-agent` — scans the codebase, classifies every test surface and participant, produces `.diamond-testing/boundaries.md` (a Mermaid boundary map + participant table). Runs first, always. Writes nothing else.
- `diamond-testing-expert` — the top-level orchestrator. Takes the *approved* boundary map, decides which specialists this codebase actually needs, scopes each one's brief, enforces the shared diamond principles, and runs the final JaCoCo gate. Does not write test code itself.
- `bdd-acceptance-writer` — elicits and confirms Gherkin acceptance criteria for critical business journeys (the E2E tier). Unchanged from before.
- Specialists, invoked by `diamond-testing-expert` only for surfaces the boundary map confirms are present: `api-inbound-test-agent`, `external-api-test-agent`, `jobs-test-agent`, `database-test-agent`, `middleware-test-agent`, `config-test-agent`, `algorithm-rules-test-agent`.

### The mandatory sequence

1. **Discovery, always first.** Invoke `boundary-discovery-agent` before any test-creator agent runs, for any codebase or module not yet covered by an approved boundary map.
2. **Approval gate.** Present `.diamond-testing/boundaries.md` to the user and get explicit confirmation before anything proceeds. This is a hard stop — do not let `diamond-testing-expert` start spinning up specialists on an unapproved map.
3. **Fan-out.** Once approved, `diamond-testing-expert` decides which specialists are needed and invokes them with scoped briefs.
4. **Delegation, not duplication.** No specialist writes another surface's bootstrapping. `database-test-agent` is the single owner of data setup/teardown; `external-api-test-agent` is the single owner of outbound stubs/fixtures per dependency. A specialist that needs either must call that agent, not hand-roll its own copy — you should reject and send back any specialist output that skips this.
5. **E2E stays gated on approved Gherkin**, as before: `diamond-testing-expert` will not let a specialist write an E2E test without a `bdd-acceptance-writer`-approved `.feature` file behind it.

### When to invoke the sequence

Run it automatically, without being asked, whenever:

- You write a new class, function, endpoint, consumer, or module not yet covered by an approved boundary map.
- You modify the logic, signature, or I/O behavior of existing code (not pure formatting/comment changes).
- You are asked to "add tests," "write a test," "cover this," "set up testing," or similar.
- A PR or task is about to be considered complete and no test plan has yet been produced for the code touched in it.

Do not skip discovery because the change "looks simple" — classification of what's simple is `boundary-discovery-agent`'s and the relevant specialist's job, not yours.

### Sourcing input and response data

No agent invents fixture data. When a specialist determines data is needed and none exists:

1. **Check for an existing contract or fixture first** via the owning specialist (`database-test-agent` for data setup, `external-api-test-agent` for outbound stubs) — never let two specialists maintain separate fixtures for the same dependency.
2. **If none exists, ask the user** for the exact data needed — field names, types, a sample real response, error formats, or which OpenAPI/Avro/Pact source to pull from. Ask a single, specific question per missing piece.
3. **Do not proceed on a guess.** If the user is unavailable, stop and report what's blocked, rather than filling the gap with assumed data.

### Non-negotiables (shared across every agent in the roster)

- Reach code through real program flow — the actual entry point for the surface — not direct class/method instantiation, except for pure algorithm/rules logic where direct invocation is correct.
- No mocking frameworks or interaction-verifying test doubles, ever — stubs and real/embedded dependencies only.
- JaCoCo coverage wired on every run; 100% line and branch coverage is the CI gate.
- Any coverage exclusion must be named and justified; an exclusion that hides untested logic is treated as a defect, not accepted silently.
- Given/When/Then is the acceptance-criteria format at every tier, not just E2E — a Then is never invented, only confirmed.

### Operational note on delegation

`database-test-agent` and `external-api-test-agent` calls from other specialists rely on nested subagent invocation (the `Agent` tool), which requires it to actually work in this environment. If a specialist reports it could not invoke another specialist directly, fall back to relaying manually: have the calling specialist state exactly what it needs, invoke the owning specialist yourself with that request, and pass the result back. Don't let a specialist silently write another surface's bootstrapping just because direct delegation failed.
