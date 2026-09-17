# Pi Implementation Orchestrator Design

## Goal

Publish a safe Pi installer and setup prompt for implementation-orchestration and planning skills maintained in `legout/skills`, using the builtin pi-subagents `worker`/`reviewer` pair with risk-based validation and proportional review, optional persistent intercom peers, and interactive project setup.

## Repository

- Local path: `~/coding/libs/pi-implementation-orchestrator`
- GitHub target: `legout/pi-implementation-orchestrator`
- Visibility: public
- License: MIT
- Default branch: `main`

## Architecture

The repository owns the native Pi manifest, setup prompt, installer, tests, and documentation. Runtime skills are maintained in `legout/skills`; upstream planning skills are not vendored.

Native package installation is passive: Pi loads the declared `prompts/` resource from `package.json` and does not execute `setup.sh`. Project configuration and dependency installation happen only after an explicit `/setup-implementation-orchestrator` prompt invocation (or direct `setup.sh` use) and user approval.

```text
planning skills
  → ADRs, specifications, tickets, and plans
  → orchestrate-implementation
  → builtin `worker` in managed worktrees
  → focused validation
  → proportional parent/reviewer checks
  → orchestrator-owned integration
  → separate publication authority
```

`pi-subagents` owns child lifecycle, worktrees, mission state, artifacts, review, and recovery. `pi-intercom` is limited to explicitly named persistent read-only advisors and visible cross-project peers.

## Repository Layout

```text
pi-implementation-orchestrator/
├── .github/workflows/test.yml
├── README.md
├── LICENSE
├── package.json                 # native Pi package manifest
├── setup.sh                     # explicit dependency/project setup
├── prompts/          # setup-implementation-orchestrator + lifecycle shortcuts
│   # research, shape, plan, implement, integrate, release — thin skill
│   # force-loaders; the skills stay the single source of procedure
├── tests/setup_test.sh
├── tests/setup_runner_test.sh
└── docs/design.md

Implementation plans live in `docs/plans/` (date-prefixed Markdown).
```

## Installation Scope

Install the repository as a native Git-backed Pi package:

```bash
pi install git:github.com/legout/pi-implementation-orchestrator
```

The manifest declares `./prompts`. This install is passive and must not execute setup, install skills or npm packages, or create files in a target project. `pi update git:github.com/legout/pi-implementation-orchestrator` updates it and `pi remove git:github.com/legout/pi-implementation-orchestrator` removes it. Append `@<tag-or-commit>` to pin a Git ref. Explicit setup additionally copies every `prompts/*.md` template into the scope-selected prompt directory (`~/.pi/agent/prompts/` for global scope, the project's `.pi/prompts/` for project scope) so the commands exist even without the package installed; copies are validated (destination kind, writability, no symlinked prompt files) in the shared preflight and are idempotent on rerun.

After installation, invoke `/setup-implementation-orchestrator`. That prompt locates the package's `setup.sh`, asks only unresolved choices, runs one dry-run preview, obtains explicit approval, and invokes the same command once with `--yes` to mutate state. It never edits projects itself.

Direct setup remains available from a checkout:

```bash
./setup.sh --project /path/to/repo
./setup.sh --skip-project
./setup.sh --project /path/to/repo --inspect
./setup.sh --project /path/to/repo --dry-run
./setup.sh --project /path/to/repo --update --dry-run
```

`--update` is a separate operation, not an alias for setup rerun. It requires evidence of an existing installation at the selected scope, reads only local skill-lock and Pi settings metadata before approval, and builds a bounded update plan. Source-owned installed skills use `npx skills update`; installed unpinned Pi packages use `pi update`. Missing and pinned dependencies are reported but never installed, source-conflicting skills are refused, and duplicate global/project Pi package identities are refused because Pi's package updater cannot isolate one scope. Managed prompt/project outputs are still rendered so releases can add or change owned files, but byte-identical targets are not rewritten. The Pi prompt maps `update`, `upgrade`, or `--update` in its additional input to this flag. This operation updates the managed stack using the current package version; updating the orchestrator package itself remains the separate `pi update git:github.com/legout/pi-implementation-orchestrator` command.

`--migrate-namespace` explicitly moves a legacy `docs/` artifact installation to `project/`. Targets are validated before approval: a target that already exists with its source present is refused, symlinked legacy directories are refused, and the namespace root must be a writable directory or creatable. The preview lists every move; the apply phase runs external installs first, then moves each legacy directory with `git mv` when tracked (plain `mv` otherwise), then stages and writes so the managed docs and instruction-file block regenerate at the new namespace (the flag is the owner approval for that regeneration; user content is preserved byte-for-byte). An interrupted migration converges on rerun because completed moves disappear from the plan. Everything else under `docs/` is untouched.

`--bin-link` creates `~/.local/bin/pi-orchestrator-init` as a symlink to the running package's `setup.sh` after approval. Only the pi-managed clone under `~/.pi/agent/git/` has a path that survives `pi update`, so the flag is refused from a checkout or extracted tarball; an existing regular file or foreign symlink at the target is never overwritten, and reruns are no-ops. A warning is printed when `~/.local/bin` is not on `PATH`; `pi remove` deletes the clone and leaves a dangling link.

`--inspect` is a read-only, noninteractive report (never reads stdin, never installs, updates, or writes): canonical project path, detected existing configuration, current and requested worker/reviewer model settings, per-choice status with suggestions for unresolved choices, validation hazards, and a suggested preview command. Inspect, `--dry-run`, and apply share one validation path — malformed/reversed/duplicate managed markers, wrong-kind or unwritable destinations, invalid MCP JSON or conflicting Epiq entries, symlinked instruction/generated/MCP paths or ancestors, and missing `git`/`npx`/`pi`/`node` prerequisites all abort **before** any external install command runs. One explicit approval covers external installs/updates and all config/project writes; nothing mutates before it, declining or closed input aborts with zero side effects, and `--yes` is approval after validation, not a way to skip it. Symlinks are refused and named, never followed, unlinked, or replaced; the `--project` argument itself may resolve through a symlink to its canonical root.

External installs or updates run before config and project writes, with rendered outputs and the Epiq MCP merge staged in unique temporary files. A failed installer leaves config and project files unchanged. A failed updater may have partially changed its own dependency files, but managed config is not written; both report completed external steps and perform no destructive automatic rollback. After installation, the staged MCP config and each project output are atomically renamed into place. A write failure exits nonzero with a clear rerun instruction; earlier successful writes remain in place and a rerun deterministically converges. This is not a globally atomic transaction across package managers, and crash/power-loss durability is not promised.

Project choices can be made non-interactively with `--instruction-file auto|AGENTS.md|CLAUDE.md`, `--tracker auto|github|epiq|local|other`, `--tracker-description TEXT` (required for `other`), `--domain-layout auto|single|multi`, `--skill-scope auto|global|project`, role-specific model/thinking flags, and `--replace-custom` when explicitly approving replacement of custom generated-doc content. Model choices are `keep` (default), `inherit`, or `provider/model`; thinking choices are `keep`, `inherit`, or a Pi thinking level. Explicit choices mutate only selected fields in the scope's settings file; global overrides are preserved by default. Selecting `epiq` installs `npm:pi-mcp-adapter` at the selected scope and merges the `epiq-mcp` stdio server into `.mcp.json` (project scope) or `~/.config/mcp/mcp.json` (global scope). The merge preserves other servers and refuses a conflicting existing `epiq` entry. Setup does not initialize an Epiq board or project. Global scope (the default) installs skills user-level and Pi packages globally; project scope installs skills into the project's agent directories and registers the Pi packages in the project's `.pi/settings.json` via `pi install --local`. Project scope requires `--project`. After project-scope installs, setup fills missing `model`/`thinking` fields in the project's `subagents.agentOverrides` from the global settings (project override objects replace global ones wholesale) without overwriting explicit project choices, and every apply ends with an overview of the effective `worker`/`reviewer` models plus where to change them (project `.pi/settings.json`, global `~/.pi/agent/settings.json`, or `/subagents`). The script installs the selected skills from `legout/skills` for Pi and ensures `npm:pi-subagents` and `npm:pi-intercom` are installed through Pi. Existing generated or configuration-only artifact-map/tracker/layout content in the generated docs is reused without questions; custom content in those three managed files requires the explicit `--replace-custom` choice (interactive setup asks; `--yes` refuses without the flag), and setup never claims arbitrary other `project/agents/` content. External installs are not version-pinned; the runtime boundary documented here reflects the audited `pi-subagents` 0.66.0 behavior.

## Selected Skills

Install exactly this set from `legout/skills`; no other upstream skill repositories:

- `research` — pre-planning investigation against primary sources, captured as Markdown in the repository.
- `shape-design` — idea shaping and design approval (combines Superpowers brainstorming with selected grilling/domain-modeling techniques; covers Matt's to-spec via its architectural path).
- `grilling` — explicit stress-tests of plans, decisions, and ideas (combines Matt's grilling/grill-me/grill-with-docs); `shape-design` invokes it only on explicit request.
- `domain-modeling` — CONTEXT.md glossary and ADR recording with file-format references; `shape-design` invokes it when the glossary changes or an ADR is recorded.
- `write-implementation-plan` — executable implementation plans (consolidates Superpowers writing-plans and Matt's to-tickets decomposition).
- `prototype-question` — disposable spikes; `shape-design` hands feasibility questions to it.
- `verification-before-completion` — evidence-before-claims discipline for the implementer.
- `systematic-debugging` — reproduction and root-cause method for failing checks.
- `orchestrate-implementation` — worker/reviewer orchestration; carries the TDD/test-seam guidance for `new-test` validation units.
- `merge-worktree` — worktree integration; resolves conflicts inline from source intent.
- `make-release` — release publication.
- `planning-contract` — shared planning artifact and handoff contract (classification defaults, capture checkpoint, approval/readiness rules, missing-contract refusal) consumed by the planning skills above; installed explicitly alongside them because the skills CLI does not resolve dependencies.

The builtin `worker` gets TDD discipline through `orchestrate-implementation`; when the selected review policy requires it, the orchestrator supplies a fresh read-only builtin `reviewer`. Setup uses the profiles shipped by `pi-subagents` and never creates or replaces their definitions. Optional setup choices update only selected `model`/`thinking` fields while preserving tool configuration, other agents, and unknown keys. Confirm both are executable before dispatch and record the resolved names in the run manifest. Additional `legout/skills` entries (`capture-project-vision`, `doc-coauthoring`, `simplify-code`, `review-codebase-architecture`) are available but not installed by default.

## Upstream Installation

Use the standard Agent Skills CLI with explicit skill names, global scope, and Pi as the target agent. Do not use whole-pack installation. All skills come from one repository in one invocation:

```bash
npx skills add legout/skills \
  --skill research \
  --skill shape-design \
  --skill grilling \
  --skill domain-modeling \
  --skill write-implementation-plan \
  --skill prototype-question \
  --skill verification-before-completion \
  --skill systematic-debugging \
  --skill orchestrate-implementation \
  --skill merge-worktree \
  --skill make-release \
  --skill planning-contract \
  --global --agent pi --yes --copy
```

The setup script reports installed, skipped, and already-present components. It does not authenticate GitHub, overwrite modified skills silently, or install unrelated upstream skills.

## Worktree Integration

The externally maintained [`merge-worktree`](https://github.com/legout/skills/tree/main/skills/workflow/merge-worktree) skill integrates a registered source worktree either locally or through GitHub. Local mode first merges and validates on an isolated temporary integration branch, then fast-forwards the unchanged target to the verified merge commit and **never pushes**. PR mode pushes the source branch and opens a pull request; **opening a PR never authorizes merging it** — merge-after-checks is a separate, explicitly authorized action that watches required checks and never bypasses branch protection. Both modes default to merge commits, validate before and after integration, never force-push, and resolve conflicts inline from source intent (regenerating conflicted generated files with their owning tool) before checks resume.

Cleanup is a post-success operation. `--clean-up` removes and prunes the source worktree automatically; without the flag the skill asks. It never removes a dirty or unmerged worktree and does not delete branches unless separately requested.

## Release Publishing

The externally maintained [`make-release`](https://github.com/legout/skills/tree/main/skills/workflow/make-release) skill supports explicit patch, minor, and major releases for Python/uv and Node packages. It previews the complete release plan and requires approval before the first mutation (`--dry-run` stops at the preview). It updates the canonical manifest and lockfile, verifies the finalized changelog against actual commits, performs build-focused validation, creates `chore(release): <version>`, pushes the default branch, creates and verifies an immutable `v<version>` tag, and publishes a GitHub Release.

Python releases optionally publish to PyPI. The first publishing run confirms `[project].name` and requires an explicit choice between a GitHub workflow and local `uv publish`. GitHub publishing supports either Trusted Publishing with `id-token: write` or a `PYPI_API_TOKEN` repository secret. Local publishing uses a securely supplied `UV_PUBLISH_TOKEN`; `.pypirc` is not created because uv does not consume it. Python artifacts receive metadata validation before publication and a fresh-environment consumer smoke check afterward. Failed remote steps are reported as partial state and never repaired by rewriting history.

## Single Setup Prompt for New and Existing Projects

`prompts/setup-implementation-orchestrator.md` is the user-facing command for both new-project setup and existing-project reconfiguration. It accepts an optional project argument; missing inputs are requested rather than guessed. The prompt is bounded: after locating the package (its own `./setup.sh` when this is the checkout, otherwise one `pi list`) it performs at most three script executions — `--inspect` when the request is not already fully explicit, including its custom-content replacement and model decisions, one `--dry-run` preview, one apply with `--yes` — plus at most one read-only `pi --list-models` query, one grouped round of unresolved questions, and one explicit approval. A project request skips inspect only when its custom generated-doc replacement decision is explicit too. It performs no file-by-file project reconnaissance, no help reads, no planning-skill detours, and no setup subagents; discovery is deterministic inside `setup.sh`. The dry-run output is shown verbatim for approval before any mutation, and a changed choice restarts the preview. Setup is always delegated to `setup.sh`, so direct and prompt-driven setup share validation, rendering, idempotence, and safety behavior and produce identical blocks. Re-run the same prompt to modify an existing project's orchestrator configuration.

When `--project` is supplied, setup resolves only genuinely unresolved choices; explicit flags and unambiguous existing configuration (for example a recognized `Tracker: …` line or `Layout: …` line in the generated docs) are reused. With `--skip-project`, `--tracker epiq` is also accepted for a global Epiq MCP setup:

1. choose `CLAUDE.md` or `AGENTS.md` when neither or both exist;
2. choose GitHub Issues, Epiq, local Markdown, or another tracker when no recognized tracker doc exists;
3. choose single-context or multi-context domain documentation when monorepo signals exist and no recognized layout doc exists;
4. optionally keep, inherit, or explicitly select the builtin worker/reviewer model and thinking fields; and
5. one approval covering the exact install commands, settings changes, managed block, and generated docs.

If one of `CLAUDE.md` or `AGENTS.md` already exists, update that file. If both exist, ask which is authoritative. Never overwrite surrounding user content.

Write or update one marked workflow block that documents:

- risk-based validation-unit obligations (`new-test`, `existing-check`, `no-new-test`);
- builtin `worker` and `reviewer` routing, with executable-profile preflight;
- adaptive orchestrator-owned review with inline finding/security/test gates, parent disposition before repair, one fix pass plus one delta recheck, and a task/result reflection checkpoint;
- routing and authority rules (which skill handles which decision — including loading the shared `planning-contract` skill and the `project/agents/artifacts.md` mapping — `supervised` default with explicit integration/publication gates, one writer per worktree, evidence discipline, merge/release authority);
- a layout-aware documentation map — single-context references canonical root `CONTEXT.md`; multi-context references per-context glossaries and an optional `CONTEXT-MAP.md` and never declares a root `CONTEXT.md` canonical;
- scoped authority (glossaries own terminology; ADRs own accepted architectural constraints; specifications own behavior; plans/tickets own execution decomposition; no scope silently overrides another); and
- stop-on-conflict behavior.

Create:

- `project/agents/artifacts.md`
- `project/agents/issue-tracker.md`
- `project/agents/domain.md`

When Epiq is selected, also merge its lazy stdio server into `.mcp.json` for project scope or `~/.config/mcp/mcp.json` for global scope. Existing MCP servers are preserved; conflicting `mcpServers.epiq` settings stop setup. Setup never initializes an Epiq board or project.

`project/agents/artifacts.md` is the protected project artifact mapping: declarative documentation recording the default destinations (`project/research/`, `project/adr/`, `project/specs/`, `project/plans/`, `project/tickets/`, workflow configuration in `project/agents/`) with links to the tracker and context-layout docs. The default artifact namespace is `project/`, separating delivery artifacts from product or library documentation under `docs/`; existing installations with legacy `docs/` artifact directories (`docs/agents/`, `docs/research/`, `docs/adr/`, `docs/specs/`, `docs/plans/`, `docs/tickets/`) keep that namespace automatically, and setup never migrates or duplicates artifacts between namespaces. Explicit project mappings recorded in it override the defaults. Setup never moves existing documents, fabricates glossaries/ADRs/placeholder folders, or infers a destination from a misplaced document; existing projects without a map receive one on the next approved rerun. Use `CONTEXT.md` plus `project/adr/` for single-context repositories. Offer multi-context only when monorepo signals exist (or it is configured explicitly). The complete managed block stays under roughly 700 words, including inline review ground rules; detailed procedures stay in the runtime skills.

Re-running setup updates the one managed block and regenerates the three managed docs idempotently (byte-identical for unchanged choices). Ambiguous or malformed managed blocks stop safely; custom content in the managed docs requires an explicit replace decision and is never silently overwritten.

## Test obligations and review policy

Validation evidence is mandatory; a new test is not. During preflight each validation unit receives exactly one obligation, and related tasks may share a validation unit:

- `new-test`: changed behavior lacks meaningful existing coverage and a named reachable failure would otherwise be unprotected. Follow the TDD guidance carried by `orchestrate-implementation` and require failing-test, minimal-implementation, and passing-check evidence.
- `existing-check`: an existing focused check already exercises the affected behavior. Run and report that check without adding redundant tests.
- `no-new-test`: a new test would prove little, including documentation, formatting, comments, static metadata, generated artifacts, mechanical changes, or behavior-neutral refactoring. Run the smallest meaningful parse, build, smoke check, or diff inspection.

The review policy is chosen per run and defaults to `adaptive`:

- `adaptive` (default): parent diff inspection for low-risk work, one candidate review for normal-risk work, and immediate plus candidate review for high-risk or dependency-defining work.
- `strict`: immediate task review plus final review.
- `final-only`: one independent candidate review, with no task or wave reviews.
- `parent-only`: parent diff inspection plus focused checks; use for low-risk changes only.

Immediate-review triggers: public API/schema/shared contract; security/auth/permissions/secrets; money/data-loss/migration; concurrency/distributed behavior; broad cross-cutting diff; weak or missing checks; implementer uncertainty/scope expansion; integration conflict; a task whose contract will be consumed before the next wave review.

At a wave boundary, independently review only high-risk lanes and dependency-defining contracts needed by the next wave. Defer normal-risk review until the candidate is assembled; low-risk lanes receive parent inspection. Verify the exact candidate range after accepted lanes are assembled, using prior evidence only after checking correspondence. Review unreviewed code and integration effects, never reopen settled findings. One fix pass and one delta recheck is the limit, not a renewable default; unresolved blockers go to the human, never round three.

Every fresh reviewer dispatch carries the complete contract inline: approved criteria, named written conventions, actual callers/inputs/environment, five finding gates (named requirement/rule, change-caused or worsened, reachable, material, proportionate), realistic security-boundary gating, named test scenarios, and a finite `pass`/`fix-first` verdict. Untouched security boundaries get `security: n/a`; missing security facts remain `unverified`. The parent rejects failed gates, authorizes small in-scope fixes, or hands large/out-of-scope work to the human before any repair. Written conventions still bind, taste and coverage targets do not. Existing reports hold the task/result comparison (`accept / fix / hand back / ask`); no extra ledgers, lifecycles, or sign-offs.

Review evidence is branch-scoped, not parent-`HEAD`-scoped, and never assumes implementer-worktree survival: verdicts bind to the exact reviewed branch range; when an implementation worktree/branch disappears, the durable handoff patch is replayed at the pinned lane base inside a parent-owned review worktree to reconstruct and review the exact tree; fixes restart from that base with the prior patch applied, preserving the prior materialized review ref/SHA. Full replacement patches reconstruct from the pinned base, but the one recheck compares the two materialized endpoints directly and only checks the fix and affected behavior; transport never resets the correction budget. Accepted lanes are assembled into an explicitly registered candidate branch handed to `merge-worktree`. This lifecycle contract is owned by `orchestrate-implementation` in the current `legout/skills` catalog.

## Safety

- No skill, package, setting, or config/project-file mutation before one explicit approval covering installs and config/project writes; declining or closed input aborts with zero side effects (`--yes` approves after validation, never skipping it). Existing global worker/reviewer overrides remain unchanged unless an explicit non-`keep` choice requests a field update.
- Support `--inspect` (read-only, no stdin) and `--dry-run` without filesystem or package mutations; inspect/preview/apply share one validation path.
- Validate project paths, marker well-formedness, destination kinds, writability, and Epiq MCP JSON/conflicts before any install command runs; report missing `git`/`npx`/`pi`/`node` prerequisites in inspect/preview and enforce them on apply.
- Refuse symlinked instruction/generated/MCP paths and their configured ancestors, naming the offending path; never follow, unlink, or replace them. The `--project` argument itself may resolve through a symlink.
- Preserve existing instructions outside the managed block, byte-for-byte, including file modes.
- Refuse ambiguous or malformed managed blocks.
- Stage rendered outputs and the Epiq MCP merge in unique temporary files; run external installs before config/project writes; on install failure leave config and project files unchanged and report completed external steps without destructive automatic uninstall.
- Replace each project file by writing a same-directory temporary file and renaming it into place; if a write fails, exit nonzero with a clear rerun instruction and leave earlier successful writes in place for deterministic convergence.
- Never install whole upstream skill collections.
- Never install competing implementation or review workflows.
- Never push, merge, deploy, or release during setup.

## Tests

Use isolated shell tests with temporary HOME and project directories. Stub `pi`, `npx`, and `gh` so tests cannot alter the real machine.

Verify:

1. `package.json` parses and declares only the setup prompt;
2. the setup prompt requires a dry-run and approval before `--yes`;
3. the installer invokes exactly one `legout/skills` installation with the full selected skill set;
4. all runtime skills are installed from `legout/skills`;
5. the removed `--planning` flag is rejected as an unknown flag;
6. no other upstream skill repository (`mattpocock/skills`, `obra/superpowers`) appears in install commands;
7. explicit project-choice flags bypass prompts and validate values;
8. dry-run performs no package or project writes;
9. interactive choices generate the intended managed block and docs;
10. reruns are idempotent and produce byte-identical blocks across direct and flag-driven setup;
11. ambiguous or malformed managed blocks fail safely before any install;
12. existing instructions outside the managed block remain unchanged (bytes and file modes);
13. declines, EOF, missing prerequisites, wrong-kind paths, unwritable destinations, invalid/conflicting Epiq MCP config, and symlinked instruction/generated/MCP paths cause no installs and no writes;
14. Epiq is detected from existing tracker docs, installs `pi-mcp-adapter` only for the Epiq profile, and writes the selected project/global MCP target while preserving other servers;
15. `--inspect` is read-only: no stdin, no external installer calls, no filesystem changes;
16. install failures leave config and project files unchanged with a completed-steps report; injected later write failures exit nonzero with a rerun instruction and leave earlier successful writes in place;
17. default global setup preserves existing worker/reviewer overrides, while explicit model/thinking choices update only selected fields in the selected scope;
18. update mode requires an existing selected-scope installation, uses update rather than install commands, skips missing/pinned dependencies, refuses cross-scope package ambiguity, and preserves files on dry-run, decline, or external failure;
19. `--migrate-namespace` previews and validates moves before approval, moves legacy directories only after external installs, preserves user content byte-for-byte, regenerates managed docs at the new namespace, refuses target collisions and symlinked paths, and converges on rerun after an interrupted migration; and
20. `bash -n` succeeds for each shell script individually.

`tests/setup_test.sh` runs every case in an independent shell process (`bash "$0" --case NAME`) so a failed assertion always fails the suite, and records stubbed argv plus cwd so the exact twelve-skill command, scope flags, and absence of unrelated external commands are asserted. `tests/setup_runner_test.sh` keeps the runner honest: it copies only the required tracked inputs into a temporary directory (isolated HOME/TMPDIR plus defensive outer `pi`/`npx` stubs, so no real installer runs), proves the unmutated copy passes, then mutates the copied `setup.sh` to omit the three generated docs during interactive setup and requires the copied suite to fail at the interactive-docs case; it also verifies that an early failing assertion followed by a passing command still fails a case.

In addition to the shell suites, parse `package.json` with Node, run `git diff --check`, and install the package in an isolated temporary `PI_CODING_AGENT_DIR`. Runtime skill contract tests belong in `legout/skills`. The isolated install must list the package while leaving a separate target project unchanged; installation itself must not invoke `setup.sh`.

GitHub Actions syntax-checks each script individually and runs both shell suites on pushes and pull requests on Ubuntu and macOS.

## README

The root README is short but comprehensive. It includes:

- purpose and architecture;
- prerequisites;
- quick start;
- installed-skills table with consolidation mapping;
- the planning-to-orchestration workflow;
- ticket/plan input behavior;
- project documentation scope and precedence;
- execution modes;
- test obligations and adaptive review boundaries;
- Herdr visibility options;
- dry-run, updates, uninstall, and troubleshooting;
- limitations; and
- upstream attribution and licenses.

## Publication

After implementation, tests, and independent review pass:

1. create public GitHub repository `legout/pi-implementation-orchestrator`;
2. add it as `origin`;
3. push `main`;
4. verify the repository URL and default branch; and
5. report the exact installation command using the published repository.

## Non-Goals

- Vendoring complete upstream skill repositories.
- Installing other upstream skill packs (`mattpocock/skills`, `obra/superpowers`) — their workflows are consolidated in `legout/skills`.
- Running all implementers and reviewers as interactive Herdr sessions.
- Automatically resolving semantic merge conflicts.
- Version-pinning external installs (`npx skills add`, `pi install`) — a separate release-policy decision.
- An uninstall engine: safe uninstall is documented manual removal of the exact managed block and only generated files confirmed unchanged; setup itself never deletes project documentation.
