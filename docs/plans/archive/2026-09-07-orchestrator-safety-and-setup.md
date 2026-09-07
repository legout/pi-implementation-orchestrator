# Implementation plan: safe, faster orchestrator setup

> **Archived plan — implemented.** Setup safety, inspect/dry-run/apply validation, bounded prompt flow, generated routing, and documentation landed in the installer history. Native lifecycle acceptance is tracked separately in the active plan. The original unchecked ledger is retained for traceability.

## Status and scope

**Archived implementation record.** This file records the owner's request to fix review findings 1–8, reduce agentic setup overhead, and consider stronger generated instructions. It does not authorize installs, publication, or changes to a user's existing projects.

- **Goal:** make direct and prompt-driven setup share one safe deterministic path, restore trustworthy tests, and give projects concise routing/safety instructions.
- **Source requirements:** the owner's follow-up to the September 7 critical review; numbered acceptance criteria below preserve that request for a fresh implementer. Existing architectural baseline: [../../design.md](../../design.md), whose stale claims were corrected rather than treated as overriding the owner.
- **Reviewed baseline:** `pi-implementation-orchestrator` main at `5a69c07`; sibling `../skills` main at `75db0c4`. Recheck both before implementation; do not reset either repository to these commits.
- **Companion plan:** [skill lifecycle and handoff fixes](2026-09-07-orchestrator-skill-contracts.md) owns runtime-skill changes in `../skills`, including findings 4–6. Both plans together cover all eight findings.
- **Ownership:** this repository remains prompt/setup-only. Runtime skills and their tests remain in `legout/skills`. No new Pi extension, execution engine, vendored skill copies, or production dependency.
- **Runtime:** retain macOS Bash 3.2 and Linux Bash compatibility; Git, Pi, and Node/npx remain prerequisites. Do not introduce Bash 4-only constructs.

## Acceptance criteria and task map

- **A1 / finding 1:** no skills, packages, settings, or project files change before approval, including when direct setup is declined or input closes. `--yes` is explicit approval, not permission to skip validation. Tasks 2–3.
- **A2 / finding 2:** inspect/dry-run/apply use the same path and managed-block validation; invalid destinations fail before external install calls. A project-write failure exits nonzero with a clear rerun instruction; earlier successful writes remain in place and rerun converges deterministically. Task 2.
- **A3 / finding 3:** every failed assertion makes the shell suite fail. The formerly false-green missing-docs mutation is detected. Task 1.
- **A4 / finding 4:** review, fixes, recovery, and candidate assembly work after worker worktrees/branches disappear and parent HEAD advances. Companion Tasks S1–S2.
- **A5 / finding 5:** selecting a prototype variant does not authorize production implementation. Companion Task S3.
- **A6 / finding 6:** multi-context setup and domain-modeling agree on discovery; no root glossary is silently created for configured multi-context projects. Task 4 and companion Task S3.
- **A7 / finding 7:** setup never silently replaces an instruction symlink or follows a generated-output ancestor outside its validated boundary. Task 2.
- **A8 / finding 8:** current README/design describe the actual review, merge, release, and safe uninstall contracts. Task 5.
- **A9 / faster setup:** deterministic discovery belongs in the script; the prompt does not inspect each project file, load planning skills, dispatch agents, or read help on the normal path. Unresolved choices are collected together, followed by one exact preview and one approval. Task 3.
- **A10 / generated instructions:** include stable routing, ownership, evidence, and authority rules; link to detailed configuration and installed skills instead of copying their procedures. Task 4.

## Proposed choices

### Faster setup without another runtime

Add a read-only, noninteractive `--inspect` mode to `setup.sh`. It returns a bounded text report: canonical project path, existing configuration, candidate instruction files, suggested choice values, unresolved/conflicting choices, symlink/path hazards, and the invocation template for preview. Plain text is sufficient; no JSON protocol or persisted setup state is needed.

The prompt becomes:

1. Locate this package once from already-known context or `pi list`; ask for its path if ambiguous. Never use an unrelated project's `./setup.sh` merely because it exists.
2. Run the package script with `--inspect` and the supplied project or explicit `--skip-project`. If the target itself is missing, ask for it first.
3. Ask all unresolved choices together. Reuse explicit request values and unambiguous existing configuration; do not guess through contradictory files.
4. Run `--dry-run` with fully resolved explicit flags, show its output, and request approval.
5. Apply the identical choices with `--yes`; report actual outcome.

Normal bound **after package/target resolution:** three script executions (inspect, preview, apply), at most one grouped choice round, and one approval. A changed choice requires another preview; invalid inputs and failures are legitimate exceptions. Fully specified requests can skip inspect and use preview/apply directly. Measure tool calls and interview rounds, not a promised wall-clock reduction: network installation still has its own cost.

Keep native package loading passive. Do not rely on unsupported prompt interpolation or hide shell execution in package-install hooks. Do not run `pi list`, read help, or perform project-file reconnaissance repeatedly in the same setup request.

### Symlink policy: fail safely, rather than inventing link ownership

For this fix, **refuse symlinked instruction/generated output files and symlinked ancestors below the canonical project root**, before any install or write. Name the offending path and explain that it has not been modified. Let the owner select a regular authoritative file or explicitly resolve their link arrangement outside setup. Never automatically unlink or rewrite the link target.

The project argument itself may resolve through a symlink to its canonical root. This is different from allowing output paths to escape that root. Preserving arbitrary output symlinks can be a separately approved enhancement; refusal is the smallest safe behavior now.

### More AGENTS.md content: yes, but only stable rules

Add a short routing/authority subsection to the existing managed block, not the complete skill catalog or runtime API examples. Preserve its current test obligations and source precedence. Suggested added wording:

```markdown
### Routing and authority

- Read `docs/agents/issue-tracker.md` and `docs/agents/domain.md` when their scope applies; preserve established project conventions.
- Use `shape-design` for unresolved behavior/design choices; use `write-implementation-plan` for approved multi-step work; use `orchestrate-implementation` to execute approved work. Do not turn a trivial edit into a planning exercise.
- Default orchestrated execution to `supervised`: workers may implement and validate, but candidate assembly/integration and publication retain their explicit approval gates.
- Keep one writer per worktree. Use `pi-subagents` for spawned-child lifecycle; named persistent `pi-intercom` peers are read-only advisors, not workers or schedulers.
- Use `systematic-debugging` for unexpected failures and `verification-before-completion` before success claims; match evidence to the exact change and report skipped checks.
- Use `merge-worktree` for target integration and `make-release` for releases. Local integration does not authorize pushing; opening a PR does not authorize merging; release/publication requires its own approved plan.
- Stop on conflicting authoritative sources, unclear ownership, failed required gates, or missing required tooling. Never silently switch execution modes to bypass a blocker.
```

Render the documentation map by domain layout: single-context references root `CONTEXT.md`; multi-context references `docs/agents/domain.md`, package/context glossaries, and `CONTEXT-MAP.md` when present. Do not generate fictional contexts, acceptance commands, project architecture, credentials, model names, or copies of lifecycle/recovery instructions. Do not overwrite user text outside the managed markers.

## Execution order and ownership

One writer owns installer/prompt/test changes in this checkout: **Task 1 → Task 2 → Task 3 → Task 4 → Task 5**. The companion skills lane may proceed independently, but Task 4 and companion S3 share the domain-discovery contract defined here and must be reviewed together. Integration/documentation acceptance waits for both lanes.

Do not dogfood the known-broken orchestration lifecycle before companion S1–S2 establish a working recipe. Use one explicitly assigned writer per repository or retain a directly supervised single writer; never invent a runtime fallback after a failed lane.

## Task 1 — Make the test runner fail honestly

**Files:** modify `tests/setup_test.sh`; add `tests/setup_runner_test.sh`; update `.github/workflows/test.yml`.

**Obligation:** `new-test` — the current runner masks real assertion failures. No prerequisites.

- [ ] Red: add an isolated mutation probe that copies only required tracked inputs into a temporary directory, stubs external commands, and omits both generated docs only during interactive setup. Assert that the copied suite fails. It currently exits zero.
- [ ] Make all assertions explicit (`... || fail ...`) or invoke test cases in genuinely independent shell processes. Do not assume `(set -e; "$t")` inside a conditional fixes Bash suppression.
- [ ] Verify an early failing assertion followed by a passing command still fails the case. Keep the runner mutation probe as a regression check without invoking itself recursively.
- [ ] Record stubbed argv and cwd accurately. Assert exactly the eleven selected skills, one skills-install invocation, correct global/project scope, and no unrelated external commands.
- [ ] Syntax-check each shell file separately: `bash -n a.sh b.sh` parses only the first script; it is not a batch check.
- [ ] Green: `bash tests/setup_runner_test.sh && bash tests/setup_test.sh`; both pass while the deliberately broken copy exits nonzero.

**Done:** a missing generated doc cannot yield a green suite, tests use isolated HOME/projects, and no real installer runs.

## Task 2 — Unify validation, approval, and safe writes

**Files:** modify `setup.sh`, `tests/setup_test.sh`. Depends on Task 1.

**Interfaces:** existing flags retain meaning; approval covers both dependency installation and project configuration. Dry-run never invokes installers or creates temp/output files. The later inspect mode will reuse this validation.

**Obligation:** `new-test` — mutation ordering, refusal, and recovery behavior.

- [ ] Red: cover declined confirmation/EOF with zero stub calls; malformed/reversed/duplicate markers in dry-run and apply; missing flag operands; `docs` or an output path being a regular file/directory of the wrong kind; unwritable destinations; dangling/file/ancestor symlinks; paths containing spaces; and project/global scope.
- [ ] Resolve arguments and all choices, canonicalize the project, validate every output and ancestor, render the complete command/file preview, then approve once. Perform no installation while collecting choices.
- [ ] Treat `--yes` as approval after validation. Without it, EOF fails closed rather than accepting unresolved choices. Check required executables before mutation; dry-run may describe missing install prerequisites without invoking them, but must report them explicitly.
- [ ] Preserve outside-marker bytes and existing regular-file permissions. Apply the stated symlink refusal policy consistently to inspect, preview, and apply.
- [ ] After approval, stage rendered files in a safe unique temporary location. Install dependencies before replacing project documentation. On install failure, leave project docs unchanged and report which external steps already succeeded; do not attempt a destructive automatic uninstall.
- [ ] For each project output, write a same-directory temporary file and rename it into place. If a later write fails, exit nonzero with a clear rerun instruction; do not attempt a backup ledger, rollback, quarantine, or automatic cleanup of earlier writes. Do not promise a globally atomic transaction across package managers or crash-proof multi-file commits.
- [ ] Recheck output paths and ancestors before each write and refuse symlinks. Always validate again on apply, not just on a preceding dry-run.
- [ ] Green: `bash tests/setup_test.sh && bash tests/setup_runner_test.sh`. Include injected installer and later-write failures, asserting prior writes remain and the failure instructs the user to rerun.

**Done:** malformed configuration, refusal, and symlinks cause no installs; a write failure is explicit and rerunning converges without hidden recovery machinery.

## Task 3 — Collapse prompt-driven setup into a bounded interaction

**Files:** modify `setup.sh`, `prompts/setup-implementation-orchestrator.md`, `tests/setup_test.sh`. Depends on Task 2.

**Interfaces:** add `--inspect` as a read-only mode, incompatible with `--dry-run`/`--yes`; it uses the existing project/choice flags and never reads stdin. It reports unresolved choices instead of silently selecting defaults. Existing CLI interactive setup remains available.

**Obligation:** `new-test` — new mode and explicit decision routing.

- [ ] Red: test inspect with new/existing projects, no stdin, all explicit values, existing tracker/layout docs, both instruction files, ambiguous/malformed configuration, project/skip-project modes, and symlink hazards. Hash the fixture tree and verify zero external invocations/filesystem changes.
- [ ] Reuse current format renderers/validators. Read recognized existing tracker/layout configuration; treat unrecognized custom content as requiring a choice, not disposable defaults. Report scope evidence from project settings/skill directories without silently changing global/project scope.
- [ ] Update the prompt to the five-step recipe above. Remove mandatory help reads, file-by-file agentic inspection, setup-related subagents, and planning-skill detours. Keep package-path verification and exact approval.
- [ ] Existing generated docs are fully managed today: preview replacement clearly, preserve unrecognized custom content by stopping for a decision, and never describe arbitrary existing `docs/agents/` contents as automatically owned.
- [ ] Green: `bash tests/setup_test.sh`; manual prompt exercise in an isolated disposable project verifies the stated call/round bound, both the full-argument fast path and unresolved-choice path, and no mutation before approval. Use stubs for installs during the exercise; do not install into the user's real environment.

**Done:** normal setup is inspection/choices → preview/approval → apply, with no repeated discovery/help/reconnaissance loop. Record observed tool calls and any exceptions.

## Task 4 — Generate concise routing rules and consistent domain configuration

**Files:** modify `setup.sh`, `tests/setup_test.sh`. Depends on Tasks 2–3 and the agreed companion S3 domain contract.

**Interfaces:** `docs/agents/domain.md` remains the explicit layout declaration; `CONTEXT-MAP.md` is an optional map of real contexts, not mandatory boilerplate. The companion domain skill reads the layout declaration before falling back to old discovery rules.

**Obligation:** `new-test` — generated content affects agent routing and context ownership.

- [ ] Red: assert the multi-context block does not declare root `CONTEXT.md` canonical; single-context output still does. Existing context maps and glossaries remain byte-for-byte unchanged.
- [ ] Add the proposed routing/authority subsection and layout-aware documentation map. Keep the complete managed block under roughly 500 words, including existing policies; avoid duplicating skill procedures.
- [ ] In multi-context domain docs, explain where context glossaries live, how an existing map is consumed, and that missing/ambiguous context ownership requires inspection/clarification—not creation of a global glossary.
- [ ] Require identical rendered blocks across direct and prompt-driven setup and byte-identical reruns for unchanged choices.
- [ ] Green: `bash tests/setup_test.sh`; review paired single/multi previews alongside companion S3 fixtures for consistency.

**Done:** generated instructions improve routing and authority without becoming a second skill implementation or inventing project-specific facts.

## Task 5 — Align public documentation and final verification

**Files:** modify `README.md`, `docs/design.md`, `.github/workflows/test.yml` as needed. Depends on Tasks 1–4 and companion S1–S3.

**Obligation:** `no-new-test` for prose; `existing-check` for wiring established test commands.

- [ ] Explain inspect, direct approval, the faster prompt path, safe symlink refusal, preflight failures, and install-before-write ordering; document rerun convergence instead of rollback recovery.
- [ ] Document branch-scoped/reconstructed review evidence and the registered candidate handoff, not ambiguous parent `HEAD` or guaranteed worker-worktree survival.
- [ ] Align merge/release descriptions with current skills: local means no push; PR opening is not merge approval; release checks include repository-required checks. Remove obsolete no-release and automatic-merge claims.
- [ ] Fix current skill hyperlinks for the nested `skills/workflow/<name>/` layout. Bring active install examples up to the full eleven-skill set. Leave historical plans unchanged.
- [ ] Replace “delete docs/agents/” uninstall advice with removal of the exact managed block and only unchanged generated files confirmed as owned. Preserve other documents, modified files, shared skills, and shared Pi packages. Show global/project scope correctly; no new uninstall engine in this slice.
- [ ] Document the actual verified Pi-subagents version/capabilities from companion S2 and that external installs are not reproducibly pinned. Do not silently pin the old skills SHA, which would omit these fixes; dependency version pinning is a separate release-policy decision.
- [ ] Run the full validation commands below and review final diffs in both repositories. Report separately any optional/live checks not performed.

**Done:** active docs match shipped behavior, all eight findings have closure evidence, and the new prompt/instruction behavior is demonstrated.

## Global validation

From this repository:

```bash
for f in setup.sh tests/setup_test.sh tests/setup_runner_test.sh; do bash -n "$f" || exit; done
bash tests/setup_test.sh
bash tests/setup_runner_test.sh
node -e 'const p=require("./package.json"); if (!p.pi.prompts.includes("./prompts") || p.pi.skills) process.exit(1)'
git diff --check
```

From the sibling skills repository, run the companion plan's checks, then:

```bash
(cd ../skills && bash tests/skills_test.sh && bash tests/orchestrator_handoff_test.sh && git diff --check)
```

Additionally run installer suites on macOS's `/bin/bash` and Linux Bash. Review stale phrases in `README.md`/`docs/design.md` and modified skill references; do not fail historical plans for accurately recording earlier behavior. Static checks must not be reported as live skill execution evidence.

## Risks and handoff

- CLI invocations and LLM skills remain separate approval surfaces: speed improvements remove redundant discovery, never confirmation.
- Multi-file filesystem replacement and external installs are not one atomic transaction. A failed write may leave earlier outputs updated; rerun setup to converge. Crash/power-loss durability is not promised.
- Symlink refusal deliberately trades convenience for a safe, bounded fix; linked instruction setups need an explicit owner choice.
- Agent behavior is not proven by keyword tests alone. Companion S2 includes a live native lifecycle acceptance exercise with exact runtime evidence.
- Publish/merge/install changes only with separate authorization. Coordinate the skills release before advertising its behavior as available through this installer's unpinned remote installation.
- **Handoff:** present both plans for approval, then execute their bounded tasks with one writer per repository and independent review of safety/lifecycle changes.
