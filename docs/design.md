# Pi Implementation Orchestrator Design

## Goal

Publish a safe Pi installer and setup prompt for the planning and Pi-only implementation skills maintained in `legout/skills`. This package owns installation, project scaffolding, native role settings, and thin lifecycle shortcuts; the installed skills own execution.

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
  → Pi children through the selected host
  → focused validation and parent/reviewer checks
  → reviewed isolated candidate
  → separately authorized target integration and publication
```

Setup installs `pi-subagents` and `pi-intercom`; it does not install or configure Herdr, Paseo, or T3. The installed orchestration skill selects the Pi host: explicit/configured choices win, otherwise the verified current host. Native Pi children, fresh Herdr panes, Paseo's Pi provider, and T3's Pi driver are supported transports; T3 children remain read-only without supported isolated mutation binding. Intercom is optional messaging, not placement or lifecycle authority. New worktrees use the allocation host's `${XDG_STATE_HOME:-$HOME/.local/state}/worktrees/` root, with allocator-supported subdirectories and verified repository identities. Existing worktrees are not moved. Host configuration changes require separate approval before dispatch; setup only documents the placement policy. The exact model/thinking policy remains enforced by the skill's selected adapter; setup preserves its existing per-field model-setting behavior.

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

`--inspect` is a read-only, noninteractive report (never reads stdin, never installs, updates, or writes): canonical project path, detected existing configuration, field-level effective worker/reviewer model and thinking values with their sources, requested values, per-choice status with suggestions for unresolved choices, validation hazards, and a suggested preview command. Inspect, `--dry-run`, and apply share one validation path — malformed/reversed/duplicate managed markers, wrong-kind or unwritable destinations, invalid MCP JSON or conflicting Epiq entries, symlinked instruction/generated/MCP paths or ancestors, and missing `git`/`npx`/`pi`/`node` prerequisites all abort **before** any external install command runs. One explicit approval covers external installs/updates and all config/project writes; nothing mutates before it, declining or closed input aborts with zero side effects, and `--yes` is approval after validation, not a way to skip it. Symlinks are refused and named, never followed, unlinked, or replaced; the `--project` argument itself may resolve through a symlink to its canonical root.

External installs or updates run before config and project writes, with rendered outputs and the Epiq MCP merge staged in unique temporary files. A failed installer leaves config and project files unchanged. A failed updater may have partially changed its own dependency files, but managed config is not written; both report completed external steps and perform no destructive automatic rollback. After installation, the staged MCP config and each project output are atomically renamed into place. A write failure exits nonzero with a clear rerun instruction; earlier successful writes remain in place and a rerun deterministically converges. This is not a globally atomic transaction across package managers, and crash/power-loss durability is not promised.

Project choices can be made non-interactively with `--instruction-file auto|AGENTS.md|CLAUDE.md`, `--tracker auto|github|epiq|local|other`, `--tracker-description TEXT` (required for `other`), `--domain-layout auto|single|multi`, `--skill-scope auto|global|project`, role-specific model/thinking flags, and `--replace-custom` when explicitly approving replacement of custom generated-doc content. When unset, worker/reviewer default to `zai/glm-5.3`/`high` and `openai-codex/gpt-6.1-sol`/`high`; interactive setup asks for each field, showing its current effective value or the spec default. `--yes` skips missing model prompts; missing flags preserve settings. `inherit` resolves to the effective global value or spec default, not the parent model. Explicit choices change only selected fields; when project setup materializes a role object, it fills missing effective model/thinking values because Pi project overrides replace global objects wholesale. Unknown fields and global values remain unchanged unless explicitly selected. Selecting `epiq` installs `npm:pi-mcp-adapter` at the selected scope and merges the `epiq-mcp` stdio server into `.mcp.json` (project scope) or `~/.config/mcp/mcp.json` (global scope). The merge preserves other servers and refuses a conflicting existing `epiq` entry. Setup does not initialize an Epiq board or project. Global scope (the default) installs skills user-level and Pi packages globally; project scope installs skills into the project's agent directories and registers the Pi packages in the project's `.pi/settings.json` via `pi install --local`. Project scope requires `--project`. After project-scope installs, setup fills missing `model`/`thinking` fields in an existing partial role override from global settings; when explicit choices materialize a role override, missing fields use the effective global/default pair. This is necessary because project override objects replace global ones wholesale. Explicit project choices and unrelated fields remain unchanged, and every apply ends with an overview of the effective `worker`/`reviewer` models plus where to change them (project `.pi/settings.json`, global `~/.pi/agent/settings.json`, or `/subagents`). The script installs the selected skills from `legout/skills` for Pi and ensures `npm:pi-subagents` and `npm:pi-intercom` are installed through Pi. Existing generated or configuration-only artifact-map/tracker/layout content in the generated docs is reused without questions; custom content in those three managed files requires the explicit `--replace-custom` choice (interactive setup asks; `--yes` refuses without the flag), and setup never claims arbitrary other `project/agents/` content. External installs are not version-pinned; the runtime boundary documented here reflects the audited `pi-subagents` 0.66.0 behavior.

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
- `orchestrate-implementation` — worker/reviewer orchestration; carries the independence-first focused-test guidance for `new-test` validation units.
- `merge-worktree` — worktree integration; resolves conflicts inline from source intent.
- `make-release` — release publication.
- `planning-contract` — shared planning artifact and handoff contract (classification defaults, capture checkpoint, approval/readiness rules, missing-contract refusal) consumed by the planning skills above; installed explicitly alongside them because the skills CLI does not resolve dependencies.

Setup uses native `worker`/`reviewer` profiles shipped by `pi-subagents` and never creates or replaces agent definitions. Its model/thinking choices preserve unrelated settings. At runtime the skill verifies that selected profiles actually run Pi and that the host supports the role, shared-root placement, and exact resolved pair; other agent runtimes are not fallbacks. Additional `legout/skills` entries (`capture-project-vision`, `doc-coauthoring`, `simplify-code`, `review-codebase-architecture`) remain available but are not installed by default.

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
4. choose each worker/reviewer model and thinking field, with current effective values or the spec defaults shown; and
5. one approval covering the exact install commands, settings changes, managed block, and generated docs.

If one of `CLAUDE.md` or `AGENTS.md` already exists, update that file. If both exist, ask which is authoritative. Never overwrite surrounding user content.

Write or update one marked workflow block that documents:

- delegation of validation, review timing, committed-result handoffs, and patch-only recovery to the installed `orchestrate-implementation` skill;
- Pi-only host selection and executable-role preflight, including read-only T3 placement and optional intercom messaging;
- inline finding/security/test gates, parent disposition before repair, one fix pass plus one delta recheck, and a task/result reflection checkpoint;
- routing and authority rules (skill ownership, the shared `planning-contract` and artifact-map references, `supervised` preparation/review of an isolated candidate before the target-integration pause, explicit owner restrictions, one writer per worktree, and separate integration/publication authority);
- a layout-aware documentation map — single-context references canonical root `CONTEXT.md`; multi-context references per-context glossaries and an optional `CONTEXT-MAP.md` and never declares a root `CONTEXT.md` canonical;
- scoped authority (glossaries own terminology; ADRs own accepted architectural constraints; specifications own behavior; plans/tickets own execution decomposition; no scope silently overrides another); and
- stop-on-conflict behavior.

Create:

- `project/agents/artifacts.md`
- `project/agents/issue-tracker.md`
- `project/agents/domain.md`

When Epiq is selected, also merge its lazy stdio server into `.mcp.json` for project scope or `~/.config/mcp/mcp.json` for global scope. Existing MCP servers are preserved; conflicting `mcpServers.epiq` settings stop setup. Setup never initializes an Epiq board or project.

`project/agents/artifacts.md` is the protected project artifact mapping: declarative documentation recording the default destinations (`project/research/`, `project/adr/`, `project/specs/`, `project/plans/`, `project/tickets/`, workflow configuration in `project/agents/`) with links to the tracker and context-layout docs. The default artifact namespace is `project/`, separating delivery artifacts from product or library documentation under `docs/`; existing installations with legacy `docs/` artifact directories (`docs/agents/`, `docs/research/`, `docs/adr/`, `docs/specs/`, `docs/plans/`, `docs/tickets/`) keep that namespace automatically, and setup never migrates or duplicates artifacts between namespaces. Explicit project mappings recorded in it override the defaults. Setup never moves existing documents, fabricates glossaries/ADRs/placeholder folders, or infers a destination from a misplaced document; existing projects without a map receive one on the next approved rerun. Use `CONTEXT.md` plus `project/adr/` for single-context repositories. Offer multi-context only when monorepo signals exist (or it is configured explicitly). The complete managed block stays under roughly 850 words, including inline review ground rules; detailed procedures stay in the runtime skills.

Re-running setup updates the one managed block and regenerates the three managed docs idempotently (byte-identical for unchanged choices). Ambiguous or malformed managed blocks stop safely; custom content in the managed docs requires an explicit replace decision and is never silently overwritten.

## Execution contract ownership

The installed `orchestrate-implementation` skill owns intake readiness, host selection, decomposition, validation obligations, review timing, durable handoffs, candidate assembly, interruption, and cleanup. Setup's generated block routes to that skill rather than copying its policy menus, command recipes, or lifecycle state.

The generated contract defaults to `supervised`: implementation, validation, and review reach an isolated candidate before pausing for target integration. Explicit owner restrictions override that default. Target integration and publication retain separate authority; setup never performs either.

All child roles use Pi. Native profiles must be executable Pi roles; Herdr, Paseo, and T3 use the installed adapter's placement and capability checks. T3 is read-only while isolated child binding is unsupported. Shared-root placement and exact per-field model/thinking resolution remain binding; unsupported hosts, allocators, or pairs block rather than silently falling back.

Committed results retained under frozen refs are the ordinary handoff, even when a managed worker checkout disappears. Patch reconstruction is only a fallback for complete patch-only handoffs. Fixes normally descend from the previous result and receive one delta recheck; neither candidate assembly nor recovery resets that budget. The recipe and identity checks stay in the skill, not setup.

Keep review ground rules inline in the generated block so they reach the parent: findings need a named requirement/rule, change-caused or worsened defect, real reachability, material impact, and a proportionate response. Security/test requests pass the same evidence gates. The parent dispositions findings and owns acceptance; every fresh reviewer receives the full filled contract from the skill. No extra ledgers or sign-off artifacts are generated.

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
9. interactive choices generate the intended managed block and docs, with Pi-only host selection, skill-owned execution details, inline reviewer gates, and candidate review before the target-integration pause;
10. reruns are idempotent and produce byte-identical blocks across direct and flag-driven setup;
11. ambiguous or malformed managed blocks fail safely before any install;
12. existing instructions outside the managed block remain unchanged (bytes and file modes);
13. declines, EOF, missing prerequisites, wrong-kind paths, unwritable destinations, invalid/conflicting Epiq MCP config, and symlinked instruction/generated/MCP paths cause no installs and no writes;
14. Epiq is detected from existing tracker docs, installs `pi-mcp-adapter` only for the Epiq profile, and writes the selected project/global MCP target while preserving other servers;
15. `--inspect` is read-only: no stdin, no external installer calls, no filesystem changes;
16. install failures leave config and project files unchanged with a completed-steps report; injected later write failures exit nonzero with a rerun instruction and leave earlier successful writes in place;
17. interactive setup offers the specified worker/reviewer defaults when unset, preserves current values on decline, resolves project/global/default fields independently, and explicit model/thinking choices preserve unrelated settings;
18. update mode requires an existing selected-scope installation, uses update rather than install commands, skips missing/pinned dependencies, refuses cross-scope package ambiguity, and preserves files on dry-run, decline, or external failure;
19. `--migrate-namespace` previews and validates moves before approval, moves legacy directories only after external installs, preserves user content byte-for-byte, regenerates managed docs at the new namespace, refuses target collisions and symlinked paths, and converges on rerun after an interrupted migration; and
20. `bash -n` succeeds for each shell script individually.

`tests/setup_test.sh` runs every case in an independent shell process (`bash "$0" --case NAME`) so a failed assertion always fails the suite, and records stubbed argv plus cwd so the exact twelve-skill command, scope flags, and absence of unrelated external commands are asserted. `tests/setup_runner_test.sh` keeps the runner honest: it copies only the required tracked inputs into a temporary directory (isolated HOME/TMPDIR plus defensive outer `pi`/`npx` stubs, so no real installer runs), unregisters unrelated cases before `main` without changing the runner, proves the interactive-docs control passes, then mutates the copied `setup.sh` to omit the three generated docs during interactive setup and requires the copied suite to fail at that case. Synthetic probes verify that an early failing assertion followed by a passing command still fails a case, and that a failed case followed by a passing case still fails the suite. The full setup suite runs separately; these runner probes do not repeat it.

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
- execution-contract ownership and review/authority boundaries;
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
