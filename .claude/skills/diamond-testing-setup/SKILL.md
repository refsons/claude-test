---
name: diamond-testing-setup
description: Use this skill to interactively build a complete BDD-driven testing-diamond harness for an existing or new codebase, from a cold checkout to 100% JaCoCo coverage, using a discovery-gated fan-out of surface-specialist test agents. Triggers on requests like "set up testing for this project," "get us to 100% coverage," "I want BDD-driven tests," "run the diamond testing setup," or when no test manifest exists yet and the user asks about tests, coverage, or acceptance criteria. Do not use this for a single ad hoc test addition on an already-set-up project — that's the standing delegation sequence in CLAUDE.md, not this skill.
---

# Diamond Testing Harness Setup

You are running this skill *with* the engineer, not for them — every phase involves them directly. Do not read this file and then silently go and do everything; work through it as a conversation, pausing at every point marked **STOP AND ASK**. Assume the engineer has done nothing beyond unzipping the provided package and starting Claude. Assume nothing about the codebase's build tool, structure, or existing test coverage until you've checked.

This process is resumable. State lives in `.diamond-testing/manifest.md` (created in Phase 1) and `.diamond-testing/boundaries.md` (created in Phase 2). On every invocation, check for these first — if they exist, resume from the first incomplete item rather than restarting earlier phases.

## Phase 0 — Bootstrap check

1. Check whether `.claude/agents/` contains all ten expected agents: `boundary-discovery-agent`, `diamond-testing-expert`, `bdd-acceptance-writer`, `api-inbound-test-agent`, `external-api-test-agent`, `jobs-test-agent`, `database-test-agent`, `middleware-test-agent`, `config-test-agent`, `algorithm-rules-test-agent`.
   - If any are missing but `agents-shared/` and `build-agents.sh` exist in the repo root, run `build-agents.sh` yourself (Bash tool) to generate them — don't ask the engineer to run it.
   - If the source files aren't present at all, stop and tell the engineer the agent package wasn't found in this checkout; ask them to confirm the zip was unpacked at the repo root.
2. Check whether `CLAUDE.md` exists at the repo root with the "Test Strategy — Mandatory Delegation" and "Acceptance Criteria (BDD)" sections. If missing, offer to write it (the standard version already established for this project) before continuing.
3. Detect the build tool: look for `pom.xml` (Maven) or `build.gradle`/`build.gradle.kts` (Gradle). If neither is found, **STOP AND ASK** what build tool and language the project uses — do not assume Java/Maven.
4. Check whether JaCoCo is already configured (search the build file). If not, add it now:
   - Maven: `jacoco-maven-plugin` bound to `prepare-agent`, `report`, and a `check` goal with a `100%` line/branch rule.
   - Gradle: the `jacoco` plugin plus a `jacocoTestCoverageVerification` task set to `1.0` minimum, wired into `check`.
   Tell the engineer what you added and why, in one or two lines — don't ask permission for this mechanical step, just do it and report it.
5. Run the existing test suite (if any) with coverage to get a baseline. Report the current coverage percentage and test count before moving on — this is the "before" number you'll compare against at the end.

## Phase 1 — Scope and conventions

**STOP AND ASK** (single batch, not one at a time):
- Which module/package/service is in scope for this pass? (Whole repo as the default if small; for a large repo, suggest one bounded module.)
- Where should `.feature` files live? Propose `src/test/resources/features/` and let them confirm or override.
- What ticket/epic should this work be tagged under? If none exists, ask them to create one or confirm working untracked is acceptable for this pass.

Once answered, create `.diamond-testing/manifest.md` with a header recording these decisions, and an empty table with columns: `Class/Function | Path/Branch | Surface | Specialist | Given/When drafted | Then confirmed | Test generated | Layer`. This file is the resumable progress record — update it as you go.

## Phase 2 — Boundary discovery

Invoke `boundary-discovery-agent` (via the Agent/Task tool) on the in-scope area. Do not do this classification yourself — that's its job. It will:
- Scan the code and classify every participant into a surface (inbound API, external API, jobs, database, middleware, config, algorithms/rules).
- Write `.diamond-testing/boundaries.md` with a Mermaid boundary-map diagram and a participant table.
- Report back a summary (surface counts, any classification it flagged as ambiguous).

Relay its summary to the engineer plainly — don't just say "discovery complete," state what surfaces it found and roughly how many participants each has.

## Phase 3 — Approval gate

**STOP AND ASK — this is a hard stop.** Show the engineer `.diamond-testing/boundaries.md` (the Mermaid diagram plus the table) and get explicit confirmation before anything else proceeds. Let them correct misclassifications, flag a missed participant, or confirm as-is. Do not invoke `diamond-testing-expert` or any specialist until this is confirmed — an unapproved boundary map is exactly the failure mode this gate exists to prevent.

## Phase 4 — Critical journey selection (the E2E tier)

The E2E tier must stay thin — it is not "one Gherkin scenario per code path." Using the approved boundary map, propose a shortlist of the handful of *business journeys* that cross multiple surfaces and would be catastrophic to regress.

**STOP AND ASK**: present the shortlist and let the engineer add, remove, or confirm it — journey selection is a business judgment, not a code-structure one.

For each confirmed journey, invoke `bdd-acceptance-writer` to run its own elicitation and produce an approved `.feature` file, per its standing process, including its own sign-off requirement.

**Before the first journey's E2E test is generated**, wire Cucumber into the build itself — mechanical setup, do it and report it, don't ask permission:
- Add `cucumber-junit-platform-engine` and `cucumber-java` dependencies, and a JUnit Platform Suite class (`@Suite`, `@IncludeEngines("cucumber")`, `@SelectClasspathResource("features")`).
- Bind Cucumber execution to **Failsafe** (`integration-test`/`verify`), not Surefire.
- Configure Cucumber's JSON output plugin and bind `net.masterthought:maven-cucumber-reporting` with output directed to `target/site/cucumber-reports`, plus a link in `src/site/site.xml`, so it appears under `mvn site` alongside JaCoCo's report.

## Phase 5 — Specialist fan-out

Invoke `diamond-testing-expert` (the orchestrator) with the approved boundary map and the confirmed critical-journey list. It will decide which specialists this codebase actually needs and invoke each with a scoped brief. You are relaying this, not bypassing it — do not invoke individual specialists yourself unless the orchestrator explicitly asks you to as a fallback (see note below).

Each invoked specialist runs its own per-path Given/When/Then elicitation directly with the engineer, following the shared core rules: Given/When pre-populated from the code, Then never pre-populated — only confirmed. As specialist reports come back, update `.diamond-testing/manifest.md` per path: surface, specialist, draft status, confirmation status, and once written, the test's layer.

**Fallback if a specialist reports it could not reach the engineer directly, or could not invoke another specialist it depends on (e.g. `api-inbound-test-agent` needing `database-test-agent`):** relay manually. Take the specialist's stated need, either ask the engineer yourself and pass the answer back, or invoke the dependent specialist yourself and pass its result back. Don't let a specialist silently work around a blocked delegation by writing the bootstrapping itself — that defeats the point of having specialists at all.

Batch specialist invocations sensibly (per class or small related group) rather than one call per single path.

## Phase 6 — Coverage verification loop

After a batch of specialist work lands, run the build with JaCoCo. Compare against the 100% gate:

- If a gap remains, identify exactly which lines/branches are uncovered and cross-check against the manifest — either a path was missed in discovery (go back to the relevant specialist or `boundary-discovery-agent` if it's a whole missed participant) or a generated test doesn't actually exercise what it claims to (flag it back to the responsible specialist).
- If an exclusion is proposed anywhere to close a gap instead of writing a test, apply the standing rule: name it, justify it, and treat anything covering real logic as a defect to fix, not exclude.
- Report the running coverage percentage after each verification pass.

Repeat Phases 5–6 until the in-scope code is at 100% or every exclusion is named and justified.

## Phase 7 — Wrap-up

When the in-scope area reaches its target:
- Report before/after coverage, which specialists were invoked and what each covered, and how many scenarios were full E2E journeys vs. unit/integration paths.
- Confirm `CLAUDE.md`'s standing delegation sequence now covers this codebase going forward.
- If Phase 1's scope was narrower than the whole repo, ask whether to continue with the next module now or stop here.
- Leave `.diamond-testing/manifest.md` and `.diamond-testing/boundaries.md` in place — they're what makes a future re-run resumable rather than a fresh start.

## Interaction style

- One question-batch per stop, not a drip of single questions.
- State clearly whether something is a draft awaiting input or a mechanical decision already made (like adding the JaCoCo plugin).
- Never invent a Then. Never invent fixture/stub data. Never let a specialist write another surface's bootstrapping without at least attempting the proper delegation first.
