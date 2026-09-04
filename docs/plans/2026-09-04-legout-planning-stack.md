# Implementation Plan: Consolidate on the legout/skills planning stack

## Header

- **Goal:** Remove the `mattpocock/skills` and `obra/superpowers` upstream dependencies from the installer and replace them with their consolidated clones from `legout/skills`, collapsing the three planning profiles (`matt`, `superpowers`, `both`) into one canonical stack.
- **Source specification:** `docs/design.md` (being amended by this plan); provenance evidence: `~/coding/libs/skills/sources.json` and per-skill attribution headers in `legout/skills`.
- **Architecture summary:** `setup.sh` installs one fixed skill set from `legout/skills` (plus `pi-subagents` + `pi-intercom`) and optionally initializes a project's instruction file and `docs/agents/`. The `--planning` flag and both upstream skill packs disappear. Installed set:

  | Skill | Absorbs / replaces |
  |---|---|
  | `shape-design` | superpowers `brainstorming`, matt `grilling`, matt `domain-modeling`, matt `to-spec` (architectural path produces the written spec) |
  | `write-implementation-plan` | superpowers `writing-plans`, matt `to-tickets` (plan tasks are the ticket decomposition) |
  | `prototype-question` | required companion: `shape-design`'s Spike path hands off to it |
  | `verification-before-completion` | new: clone of obra's verification discipline; matches mandatory-evidence model |
  | `systematic-debugging` | new: consolidates matt `diagnosing-bugs` + obra `systematic-debugging`; worker tool for failing checks |
  | `orchestrate-implementation` | already installed; absorbs matt `tdd`/`tests`/`mocking` as worker guidance |
  | `merge-worktree` | already installed; resolves conflicts inline — matt `resolving-merge-conflicts` dependency drops |
  | `make-release` | already installed |

  Not installed (available upstream if wanted): `capture-project-vision`, `doc-coauthoring`, `simplify-code`, `review-codebase-architecture`, and the unrelated legout catalog (visualization, writing, marimo, research, skill-authoring).
- **Constraints and non-goals:**
  - No changes to the `legout/skills` repository itself.
  - No vendoring; skills install at runtime via `npx skills add legout/skills` (latest `main`, no pinning — same as today).
  - No migration of users' already-installed global matt/superpowers skills; README documents manual removal.
  - Historical plans under `docs/superpowers/plans/` keep their content byte-for-byte; only the directory moves.
  - No CHANGELOG (repo has none); the breaking `--planning` removal is documented in README + design.
- **Technology/runtime assumptions:** bash installer, `npx skills` CLI, native Pi package manifest; tests are dependency-free shell with stubbed `pi`/`npx`/`gh`.
- **Acceptance criteria:**
  1. `setup.sh` accepts no `--planning` flag; unknown flags (including `--planning`) die with usage.
  2. One `npx skills add legout/skills` invocation installs exactly the 8 skills above with `--global --agent pi --yes --copy`.
  3. No `mattpocock` / `obra/superpowers` / profile references remain outside historical plan documents.
  4. `bash -n setup.sh tests/setup_test.sh && bash tests/setup_test.sh` passes.
- **Exact global validation commands:**

  ```bash
  bash -n setup.sh tests/setup_test.sh
  bash tests/setup_test.sh
  grep -rn 'mattpocock\|obra/superpowers\|superpowers\|--planning' --exclude-dir=.git . | grep -v '^./docs/plans/'
  ```

  (last command must output nothing)

## Tasks

### Task 1 — Installer surface: `setup.sh`, prompt, shell tests

Rewrite the installer to a single legout stack and update its test harness.

- **Files:** `setup.sh` (modify), `prompts/setup-implementation-orchestrator.md` (modify), `tests/setup_test.sh` (modify).
- **Interfaces consumed/produced:** CLI surface changes: `--planning matt|superpowers|both` removed; `PLANNING`, `SUPERPOWERS_SKILLS`, `MATT_PLANNING_SKILLS`, `MATT_REQUIRED_SKILLS` and both profile branches in `install_skills()` deleted. One install line remains:

  ```bash
  npx skills add legout/skills \
    --skill shape-design --skill write-implementation-plan --skill prototype-question \
    --skill verification-before-completion --skill systematic-debugging \
    --skill orchestrate-implementation --skill merge-worktree --skill make-release \
    --global --agent pi --yes --copy
  ```

  `usage()` loses the `--planning` token. Prompt step 2 drops profile resolution ("Resolve the requested planning profile …" → resolve only project path / skip-project).
- **Prerequisites:** none.
- **Behavior and edge cases:**
  - `--planning` now hits the existing `*) die "unknown flag"` branch — no special error text.
  - All other flags, dry-run, idempotence, marker handling, and project-init behavior unchanged.
  - Tests: delete `test_matt_profile` / `test_superpowers_profile` / both-profile and invalid-`--planning` cases; add assertions that the single legout line contains all 8 `--skill` flags, that `TEST_CALLS` contains neither `mattpocock/skills` nor `obra/superpowers`, and that `--planning matt` fails. Update every remaining `--planning matt` invocation in the suite to the new flagless form.
- **Test obligation:** `existing-check` — the rewritten shell suite exercises exactly this behavior; no new harness needed.
- **Exact commands and expected evidence:** `bash -n setup.sh tests/setup_test.sh && bash tests/setup_test.sh` → all tests pass, including the new legout-stack assertions.
- **Completion criterion:** suite green; `./setup.sh --skip-project --yes --dry-run` prints the single legout install line and nothing from the old upstreams.

### Task 2 — Documentation: `docs/design.md`, `README.md`

Make the spec and user docs describe the single legout stack.

- **Files:** `docs/design.md` (modify), `README.md` (modify).
- **Interfaces consumed/produced:** none (prose).
- **Prerequisites:** Task 1 (docs must match shipped behavior).
- **Behavior and edge cases:**
  - `design.md`: Goal loses "selected Superpowers and Matt Pocock planning workflows"; "Selected Upstream Skills" section replaced by the single 8-skill table with absorb mapping; "Upstream Installation" examples collapse to the one legout command; "Worktree Integration" drops the `resolving-merge-conflicts` sentence (merge-worktree resolves conflicts inline); Tests list items 3/5/6 (profiles, tdd, exclusions) rewritten for the single stack; Non-Goals drops "Replacing Superpowers or Matt planning methods" (now done deliberately); README section list loses "planning-profile skill tables".
  - `README.md`: tagline and "Planning profiles" table → one "Installed skills" table with the absorb mapping; "Workflows" section → `shape-design` → `write-implementation-plan` → `orchestrate-implementation`; "Worktree integration" drops the `resolving-merge-conflicts` mention; Exclusions section → replaced by "not installed by default" note; Attribution → legout/skills consolidates the upstreams (MIT), provenance in its `sources.json`; Uninstall keeps `npx skills remove` guidance; note the breaking `--planning` removal for existing users.
  - Keep the managed-block workflow text in `setup.sh` unchanged — it names no upstream skills.
- **Test obligation:** `no-new-test` — documentation only.
- **Exact commands and expected evidence:** stale-reference search — `grep -rn 'mattpocock\|obra/superpowers\|superpowers\|--planning' README.md docs/design.md` → no hits (except the deliberate breaking-change note wording, which must not reference install commands).
- **Completion criterion:** docs describe only the new stack; no dangling references.

### Task 3 — Plan-directory convention: `docs/superpowers/plans/` → `docs/plans/`

Drop the last superpowers-named path from the repository.

- **Files:** `git mv docs/superpowers docs/plans-tmp && git mv docs/plans-tmp/plans docs/plans && rmdir docs/plans-tmp` (or equivalent `git mv` sequence preserving history); the three existing plan files move unmodified.
- **Interfaces consumed/produced:** established plan location becomes `docs/plans/`; `design.md` Repository Layout gains the entry (amend in Task 2's design edit — cross-check at review).
- **Prerequisites:** none (independent of Tasks 1–2; sequence last to keep diffs clean).
- **Behavior and edge cases:** plan file contents unchanged (historical record); empty `docs/superpowers/` removed.
- **Test obligation:** `no-new-test` — directory rename.
- **Exact commands and expected evidence:** `ls docs/plans/` shows the three historical plans plus this one; `git log --follow docs/plans/2026-09-03-initial-release.md` retains history.
- **Completion criterion:** no `docs/superpowers` path remains; global validation grep (header) is clean.

## Quality gate

- **Requirement map:** remove matt upstream → Task 1+2; remove superpowers upstream → Task 1+2+3; single legout stack → Task 1; docs match → Task 2; acceptance criteria 1–4 → Tasks 1, 2, 3, suite.
- **Placeholder/interface check:** no TBD; the single install line is the only cross-task interface and is stated verbatim in Task 1 and referenced by Task 2.
- **Coherence:** each task leaves the repo testable (Task 1 keeps suite green; Tasks 2–3 are prose/rename).
- **Residual risks / manual checks:**
  - Users with existing global matt/superpowers skills keep them (harmless; README documents removal).
  - `npx skills add legout/skills` resolves latest `main`; a bad upstream commit affects fresh installs (pre-existing behavior, unchanged).
  - `merge-worktree` users previously relying on the installed `resolving-merge-conflicts` skill: legout's merge-worktree resolves conflicts inline — verified against its SKILL.md, no behavioral gap expected.
- **Handoff:** after approval, execute with `orchestrate-implementation` (or directly — three small sequential tasks, single writer, no worktrees needed).
