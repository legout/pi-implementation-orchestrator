# Plan: independence-first validation obligations

- **Goal:** land the approved specification's text changes across both repositories with their checks, in one review boundary.
- **Source:** `docs/specs/2026-10-07-0001-independence-first-validation.md` (status: approved; owner approved design and written spec in-chat 2026-10-07; scope = F1–F4, both repos).
- **Capture checkpoint:** vocabulary captured (`CONTEXT.md`: characterization test, independent oracle — already on disk); no ADR (cheaply reversible; research note `docs/research/2026-10-07-tdd-agentic-speed-research.md` records why); behavior source = the spec; no open uncertainty. Contract: planning-contract v1; provenance: local `../skills` checkout (legout/skills).
- **Constraints for sequencing:** canonical texts are quoted verbatim in the spec — workers copy them, never re-derive or paraphrase. Expected assertion strings come from the spec, not from running `setup.sh` and copying its output (that would violate the independence rule this change installs). Non-goals per spec: no fourth class, no gate, no risk-mapping or lifecycle changes.
- **Assumptions:** Bash + existing suites; no new dependencies; sibling repo is the local `../skills` checkout on its current branch.
- **Requirement map:** AC-1, AC-2 → T1; AC-5, AC-6 → T2; AC-3, AC-4 → T3; AC-7 → candidate review at integration.

## Task 1 — Generated contract text and its assertions (this repo)

Files: `tests/setup_test.sh`, `setup.sh` (three spots in `render_workflow_block` and the review-ground-rules section).

1. Update `tests/setup_test.sh` first: replace the `"TDD"` contains-assertion and the exact obligation-line assertion with the spec's new strings (touchpoint 7, including the negative assertions for `focused TDD is required` and `one failing test first`).
2. Run `bash tests/setup_test.sh`; confirm the new assertions fail against the current `setup.sh` output (red — expected-string mismatch is the evidence, expectations derived from the spec).
3. Apply touchpoints 1–3 to `setup.sh`: the obligation line, the added review-ground-rules line, the task-recap line.
4. Run `bash tests/setup_test.sh` and `bash tests/setup_runner_test.sh`; both green. `bash -n setup.sh`.

Validation unit V1 — obligation `new-test` at an existing seam: the updated exact-string assertions are the focused test; failure mode covered: generated AGENTS.md deviating from the approved canonical text (AC-1, AC-2). Expected strings are derived from the spec, not the implementation.

Completion: both suites green with the new assertions; a temporary-project apply shows the new workflow block and none of the retired phrases.

## Task 2 — This repo's documentation (this repo)

Files: `README.md` (skills-table row; `new-test` bullet), `docs/design.md` (three spots), `CHANGELOG.md` (Unreleased entry).

1. Apply touchpoints 4–6 verbatim from the spec.
2. Add a `CHANGELOG.md` Unreleased entry summarizing the obligation reframe (one entry, both repos noted; sibling details reference T3's entry).
3. Verify AC-6 (`CONTEXT.md` terms present — already landed at shaping; confirm) and AC-5: `grep -rn 'focused TDD is required\|failing test → minimal implementation\|red → minimal green' README.md docs/design.md` returns nothing.

Validation unit V2 — obligation `no-new-test` (documentation): the grep is the smoke check; failure mode: stale ordering claims surviving in docs (AC-5). No new test.

Completion: grep clean; markdown renders (existing review tooling).

## Task 3 — Sibling skill texts (legout/skills)

Files: `skills/workflow/orchestrate-implementation/SKILL.md`, `skills/workflow/orchestrate-implementation/references/manifest-and-briefs.md` (two spots), `skills/workflow/orchestrate-implementation/references/pi-dispatch.md`, `skills/workflow/write-implementation-plan/SKILL.md`, `CHANGELOG.md` (Unreleased).

1. Apply touchpoints 8–11 verbatim from the spec.
2. Add a sibling `CHANGELOG.md` Unreleased entry (catalog-wide convention; describe the obligation reframe and the two failing-first exceptions).
3. Verify AC-3: `grep -rn 'red → minimal green\|one failing test first\|behavior-first red/green\|focused TDD is required' skills/workflow/ --include='*.md'` returns nothing outside eval fixtures and history.
4. Run the sibling suites: `bash tests/skills_test.sh` and `bash tests/orchestrator_handoff_test.sh` (AC-4).

Validation unit V3 — obligation `existing-check`: the sibling suites are the runnable check; the grep names the failure mode (retired ordering phrases surviving in skill texts, AC-3). No new test.

Completion: grep clean, both suites green.

## Sequencing and review

T1 → T2 are same-repo but touch disjoint files (parallel-safe); T3 is a separate repo (parallel-safe). One candidate review at integration covering V1–V3 against the spec's touchpoint list (AC-7): the reviewer verifies each canonical string landed verbatim and the diff touches nothing else. One fix pass, one delta recheck, then integrate. Publication (commits/push/tags) stays a separate owner approval per house rules.

Residual risks: none beyond the suites; the only manual check is the candidate review above.
