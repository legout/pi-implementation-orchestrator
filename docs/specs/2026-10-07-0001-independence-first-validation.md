# Independence-first validation obligations

- **Status:** approved
- **Approval:** owner approved the presented design in-chat on 2026-10-07, including all four settled decisions (F1 exception scope: bug-repro + characterization; one spec covering both repositories; F2 must-rule + reviewer failure modes; F3 guidance-level ladder). This specification records that approval and its exact scope.
- **Evidence:** `docs/research/2026-10-07-tdd-agentic-speed-research.md` (findings F1–F5).
- **Contract:** planning-contract v1; provenance: local `../skills` checkout (legout/skills).
- **Scope:** reframe the `new-test` validation obligation from test-first ordering to test independence; add a guidance-level cheapest-check ladder, a seam preference, and named reviewer failure modes for generated tests. Two repositories: this one and `legout/skills`.

## Behavior

### `new-test` obligation (canonical text)

> `new-test`: changed behavior lacks meaningful existing coverage and a named reachable failure would otherwise be unprotected. Add one focused test at the cheapest stable public seam. Expected values must be derived independently of the implementation under test — from the approved spec, acceptance criteria, or another oracle (an upstream contract, a real input/output pair, captured behavior) — never from reading the code under test. Ordering is the worker's choice, except: a bug fix requires a reproducing test that demonstrably fails before the fix lands, and a behavior-affecting refactor pins current behavior with a characterization test before mutation. Add further tests only for distinct material failure modes.

### Verification ladder (guidance, not a gate)

> When several checks would satisfy the obligation, prefer the cheapest stable one — types/lint/build, then an existing focused check, then a new focused test — and run the single focused check rather than the whole suite. State a deviation with a named reason; the ladder is guidance, not a gate.

### Seam preference

> Prefer the seam that would catch the named failure mode; when a unit seam and an integration seam cost the same, prefer the integration seam, and never mock the unit under test.

### Reviewer failure modes for generated tests

> Treat a generated test as a finding when it mirrors the implementation's structure, over-mocks (including mocking the unit under test), relaxes assertions to force green, or hardcodes expectations copied from implementation output; expected values must come from the spec, acceptance criteria, or an independent oracle.

## Touchpoints and exact changes

### This repository (pi-implementation-orchestrator)

1. **`setup.sh` — generated Agent-workflow obligation line** (`render_workflow_block`): replace
   `…; related tasks may share a validation unit, and focused TDD is required only for \`new-test\` work.`
   with
   `…; related tasks may share a validation unit. \`new-test\` means one focused test at the cheapest stable public seam with expected values derived independently of the implementation under test (spec, acceptance criteria, or another oracle); failing-test-first applies only to bug repros and behavior pinning before refactors. Prefer the cheapest stable check that satisfies the obligation — types/lint/build, then an existing focused check, then a new focused test.`
2. **`setup.sh` — review ground rules**: add after the "Test requests are findings" line:
   `- Generated tests are findings when they mirror the implementation's structure, over-mock, relax assertions to force green, or hardcode expectations copied from implementation output; expected values come from the spec, acceptance criteria, or an independent oracle — never from reading the code under test.`
3. **`setup.sh` — task-recap line**: replace `one behavior and, for \`new-test\`, one failing test first` with `one behavior and, for \`new-test\`, one focused test with independently derived expectations — failing-first only for bug repros and refactor pinning`.
4. **`README.md` — skills table row**: `carries Matt's \`tdd\` guidance for \`new-test\` validation units` → `carries independence-first focused-test guidance for \`new-test\` validation units`.
5. **`README.md` — `new-test` bullet** (Worker/reviewer contracts section): replace the `Focused TDD is required only for \`new-test\` work: failing test → minimal implementation → passing focused check.` sentence with the canonical obligation summary plus the ladder and seam sentences (compact forms from Behavior above).
6. **`docs/design.md`** — three spots: `carries the TDD/test-seam guidance` → `carries the independence-first focused-test guidance`; `The builtin \`worker\` gets TDD discipline through` → `The builtin \`worker\` gets validation discipline through`; the `new-test` obligation definition (§validation units) → canonical text from Behavior.
7. **`tests/setup_test.sh`**: update the two exact-string assertions (the `"TDD"` contains-check and the full obligation-line equality) to the new strings, and add a negative assertion that the generated block no longer contains `focused TDD is required` or `one failing test first`.

**Sibling repository (`legout/skills`)**

8. **`skills/workflow/orchestrate-implementation/SKILL.md`** — validation-units section: replace the `new-test` bullet with the canonical text; append the ladder, seam, and reviewer-failure-mode sentences after the existing "name the failure mode it covers" paragraph.
9. **`skills/workflow/orchestrate-implementation/references/manifest-and-briefs.md`**: `use the assigned focused obligation, one failing test first for new-test` → `use the assigned focused obligation: one focused test with independently derived expectations for \`new-test\`, failing-first only for bug repros and refactor pinning`; and the evidence bullet → `test-obligation evidence: the assigned obligation, named failure mode, commands, and results; for \`new-test\`, the focused test and its independently derived expectations; for bug repros and refactor pinning, failing test before and passing test after;`.
10. **`skills/workflow/orchestrate-implementation/references/pi-dispatch.md`**: `the embedded public-seam, behavior-first red/green contract` → `the embedded public-seam, independence-first test contract (failing-first only for bug repros and refactor pinning)`.
11. **`skills/workflow/write-implementation-plan/SKILL.md`**: `For \`new-test\`, show the red → minimal green → verification sequence.` → `For \`new-test\`, show the focused test, its independently derived expectation, and the verification command; show the failing-first sequence only for bug repros and behavior pinning before refactors.`

### Glossary (this repository, `CONTEXT.md`)

- **Characterization test**: a test pinning currently observed behavior before a change, derived from captured real behavior rather than intended design; it protects refactors, not the correctness of new intent.
- **Independent oracle**: a source of expected values — approved spec, acceptance criteria, upstream contract, or real input/output — that does not come from reading the implementation under test.

## Invariants

- Exactly three obligation classes (`new-test`, `existing-check`, `no-new-test`); names, count, assignment rules, and shared-unit rules unchanged.
- `existing-check` and `no-new-test` definitions unchanged.
- Risk-level → review-policy mapping unchanged; review rounds and disposition rules unchanged.
- Bug repros and characterization pinning retain failing-before → passing-after evidence.
- Setup safety model untouched: approval gates, byte preservation, path safety, publication gates.

## Migration

No flags, paths, or gates change. Existing projects keep their previously generated block until the next setup run; managed files whose rendered bytes changed are rewritten per existing byte-preservation rules, so installations converge on update. The sibling skill text and this repo's generated block ship in the same change window to bound drift.

## Acceptance criteria

- AC-1: A fresh `setup.sh` apply on a temporary project generates an Agent-workflow section containing the new obligation line and the new review-ground-rules line verbatim, and containing neither `focused TDD is required` nor `one failing test first`.
- AC-2: `tests/setup_test.sh` and `tests/setup_runner_test.sh` pass with the updated assertions.
- AC-3: In `legout/skills`, `skills/workflow` contains none of `red → minimal green`, `one failing test first`, `behavior-first red/green`, or `focused TDD is required` outside eval fixtures and history files.
- AC-4: `legout/skills` test suites (`skills_test.sh`, `orchestrator_handoff_test.sh`) pass.
- AC-5: `README.md` and `docs/design.md` state the new semantics; no document still claims a general test-first mandate for `new-test` work.
- AC-6: `CONTEXT.md` defines both glossary terms.
- AC-7: The combined diff touches only the enumerated touchpoints (generated text, docs, assertions, glossary).

## Non-goals

No fourth obligation class; no gated ladder; no changes to risk mapping, review rounds, planning-contract, spec pipeline, or Spec Kit–style machinery; no new dependencies.

## Capture checkpoint

Vocabulary: two terms captured in `CONTEXT.md` (above). Decisions: no ADR — the change is cheaply reversible text; the linked research note records the why. Behavior: this document is the approved source. Uncertainty: none material blocking planning.
