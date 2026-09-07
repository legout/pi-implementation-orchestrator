# pi-implementation-orchestrator

Plan features with the consolidated [`legout/skills`](https://github.com/legout/skills) planning stack, then execute the plans with a preconfigured `implementer`, per-task test obligations, adaptive `code-reviewer` review, and orchestrator-owned integration.

## Architecture

```text
planning skills
  → ADRs, specifications, tickets, and plans
  → orchestrate-implementation
  → preconfigured `implementer` in managed worktrees
  → focused validation
  → fresh `code-reviewer` review
  → orchestrator-owned integration
  → separate publication authority
```

The repository ships: `package.json` (the native Pi manifest), `setup.sh` (the safety-gated installer and project initializer), the `/setup-implementation-orchestrator` prompt, and isolated shell tests. Runtime skills live in [`legout/skills`](https://github.com/legout/skills) and are installed by `setup.sh`. `pi-subagents` owns child lifecycle (fresh contexts, managed worktrees, missions, artifacts, review, recovery); `pi-intercom` is limited to named persistent read-only peers.

## Prerequisites

- [`pi`](https://github.com/earendil-works/pi-coding-agent)
- Git
- Node.js / `npx` (for the Agent Skills CLI)
- GitHub CLI (`gh`) — only if you use GitHub Issues as your tracker

## Quick start

Install the native Pi package (resource loading is passive):

```bash
pi install git:github.com/legout/pi-implementation-orchestrator
```

Then use the setup prompt to set up a new project or update an existing one:

```text
/setup-implementation-orchestrator
```

The prompt is bounded: after locating the package it performs at most three script executions — a read-only `--inspect` report when the request does not already supply every choice and custom-content decision explicitly, one `--dry-run` preview, and one apply with `--yes` — plus at most one grouped round of unresolved questions and one explicit approval. It never edits project files or installs skills itself; nothing is installed or written before your approval. Run the prompt again to modify an existing project's orchestrator configuration. Native package installation never runs setup, installs dependencies, or creates target-project files.

To update or remove the package:

```bash
pi update git:github.com/legout/pi-implementation-orchestrator
pi remove git:github.com/legout/pi-implementation-orchestrator
```

For a pinned tag or commit, append `@<ref>` to the Git source. A direct alternative is to clone this repository and run `./setup.sh --project /path/to/repo`; `./setup.sh --help` lists explicit choice flags, `./setup.sh --project /path --inspect` reports detected configuration, unresolved choices, and hazards without side effects, and `--dry-run` previews the exact commands and resulting files without touching anything.

> **Breaking change:** the `--planning matt|superpowers|both` flag was removed. Setup now installs one consolidated planning stack from `legout/skills`; older commands fail with "unknown flag". Remove `--planning <profile>` from saved commands.

## Installed skills

`setup.sh` installs exactly this set from `legout/skills` (one invocation, global, Pi agent):

| Skill | Role | Consolidates / replaces |
|---|---|---|
| `research` | pre-planning investigation against primary sources, findings filed as Markdown | Matt's `research` |
| `shape-design` | idea shaping and design approval | Superpowers `brainstorming`, Matt's `to-spec`; delegates stress-tests to `grilling` and glossary/ADR work to `domain-modeling` |
| `grilling` | explicit stress-testing of plans, decisions, ideas | Matt's `grilling`, `grill-me`, `grill-with-docs` |
| `domain-modeling` | CONTEXT.md glossary and ADR workflows | Matt's `domain-modeling` (full workflow, with format references) |
| `write-implementation-plan` | executable implementation plans | Superpowers `writing-plans`, Matt's `to-tickets` |
| `prototype-question` | disposable feasibility spikes | hands off from `shape-design`'s Spike path |
| `verification-before-completion` | evidence-before-claims discipline | Superpowers `verification-before-completion` |
| `systematic-debugging` | reproduction and root-cause method | Matt's `diagnosing-bugs`, Superpowers `systematic-debugging` |
| `orchestrate-implementation` | implementer/code-reviewer orchestration | Superpowers worktree patterns; carries Matt's `tdd` guidance for `new-test` tasks |
| `merge-worktree` | worktree integration | Superpowers `finishing-a-development-branch`; resolves conflicts inline (no `resolving-merge-conflicts` dependency) |
| `make-release` | release publication | — |

Packages: `pi install npm:pi-subagents`, `pi install npm:pi-intercom`.

Skills and packages install **globally** (user-level) by default. Choose **project** scope to install skills into the project's agent directories and register the Pi packages in the project's `.pi/settings.json` instead: `./setup.sh --project /path --skill-scope project` (non-interactive) or answer the scope question when prompted. Project scope requires `--project`; it cannot be combined with `--skip-project`.

### Not installed by default

Additional `legout/skills` entries you can add manually: `capture-project-vision`, `doc-coauthoring`, `simplify-code`, `review-codebase-architecture`. The original upstream packs (`mattpocock/skills`, `obra/superpowers`) are never installed — their workflows live on in the consolidated skills above. Whole-pack installation is never used.

## Workflows

- **Planning:** `shape-design` (idea → approved design or written spec; feasibility questions hand off to `prototype-question`) → `write-implementation-plan` (spec → executable, testable plan) → `orchestrate-implementation` executes the plan.
- **During execution:** `implementer` applies `systematic-debugging` to failing checks and `verification-before-completion` before claiming done; the orchestrator supplies independent `code-reviewer` review.

### Ticket and plan inputs

Plans and tickets must reference their exact feature sources (ADR, specification, or issue). The orchestrator normalizes different plan formats with a read-only scout and never rewrites your planning documents.

## Worktree integration

The setup command installs [`merge-worktree`](https://github.com/legout/skills/tree/main/skills/workflow/merge-worktree). Use `/skill:merge-worktree` to integrate a registered worktree locally or through a GitHub pull request. **Local mode validates on an isolated integration branch and never pushes.** PR mode pushes the source branch and opens a PR — **opening a PR never authorizes merging it**; merging after required checks is a separate, explicitly authorized action. Both modes default to merge commits, run project checks, regenerate conflicted generated files (for example lockfiles) with their owning tool, resolve remaining conflicts inline from source intent, and never force-push. Pass `--clean-up` to remove the successfully merged source worktree automatically; otherwise the skill asks before removal. Branches are retained unless separately requested.

## Releases

The setup command installs [`make-release`](https://github.com/legout/skills/tree/main/skills/workflow/make-release). Use `/skill:make-release patch|minor|major` to version Python/uv or Node projects, finalize the changelog, build artifacts, commit and push, create a `v<version>` tag, and publish a GitHub Release. Add `--dry-run` for a mutation-free release plan; otherwise the exact plan requires approval before files change. Python releases may also publish to PyPI. On first use, the skill confirms the `[project].name` distribution and asks—with no default—between a GitHub workflow and local `uv publish`. GitHub publishing supports PyPI Trusted Publishing or a `PYPI_API_TOKEN` secret; local publishing uses `UV_PUBLISH_TOKEN`, not `.pypirc`.

Release validation is build-focused by default. Python artifacts also receive metadata checks and a fresh-environment post-publish smoke test. Repository-mandated checks still apply, and any failed build or publishing gate stops without rewriting remote history.

## Project documentation

`setup.sh --project` writes one managed block (between `<!-- pi-implementation-orchestrator:start/end -->` markers) into `AGENTS.md` or `CLAUDE.md` plus `docs/agents/issue-tracker.md` and `docs/agents/domain.md`. Everything outside the markers is preserved byte-for-byte. The block records the test-obligation and adaptive-review policies, source precedence, and a **Routing and authority** section (which skill resolves which kind of decision, the `supervised` default with explicit approval gates for candidate assembly/integration/publication, one writer per worktree, evidence discipline, and merge/release authority), followed by a layout-aware documentation map: single-context repositories get a canonical root `CONTEXT.md`; multi-context repositories get per-context glossaries plus an optional `CONTEXT-MAP.md` and never declare a root `CONTEXT.md` canonical. The generated block stays under roughly 500 words and links to project docs instead of duplicating skill procedures.

Source precedence inside a project:

```text
current owner decision → accepted ADR → approved specification
  → implementation plan → ticket → existing implementation
```

Work stops before implementation when authoritative sources conflict. Documentation map: `CONTEXT.md` (domain vocabulary), `docs/adr/` (decisions), `docs/agents/` (workflow configuration), `docs/specs/` or your tracker (feature behavior and acceptance), plans/tickets (execution entry points).

## Execution modes

- **`plan-only`** — normalize inputs, create manifest and task briefs, no source edits.
- **`supervised`** (default) — run the implementer, validation, review and fix cycles; pause before integration/publication.
- **`autonomous`** — same loop; cherry-pick accepted commits when clean; pause on conflicts, unresolved decisions, failed gates, push, merge, deploy, or release.

## Implementer and code-reviewer contracts

The orchestrator consumes existing Pi subagent profiles; setup does not create or override user models or agent definitions. Prefer the preconfigured `implementer` for implementation and `code-reviewer` for independent review. If either profile is unavailable, stop and get owner approval before using builtin `worker` or `reviewer`, then record the resolved names in the run manifest. Before dispatch, confirm the selected profiles with `subagent({ action: "list", capabilities: true })` and verify their tool permissions match the role.

Evidence is always mandatory; a new test is not. Every task declares exactly one test obligation during preflight:

- **`new-test`** — new behavior, bug regression, branching/state, parsing/validation, security, permissions, money, destructive data handling, concurrency, public contracts, or behavior without existing coverage (e.g. a new endpoint, a fixed off-by-one bug). Focused TDD is required only for `new-test` work: failing test → minimal implementation → passing test → refactor.
- **`existing-check`** — existing tests already exercise the affected behavior (e.g. a refactor inside covered seams). Add no redundant test; run and report the named focused checks.
- **`no-new-test`** — documentation, formatting, comments, static metadata, generated artifacts, typo correction, or another change where a new test proves little (e.g. a README edit). Run the smallest meaningful lint, parse, build, diff, or manual validation.

An implementer may challenge its assigned obligation after inspection but must report why; it may never silently skip validation.

- **Implementer:** sole writer in one managed worktree; one bounded brief per run; report commit IDs, changed files, obligation, rationale, commands, results, and residual risks. No scope expansion, cross-lane integration, or publication.
- **Review policy:** adaptive and orchestrator-owned — high-risk changes are reviewed immediately; low-risk changes may be batch-reviewed cumulatively from a `lastReviewedSha` boundary to the pinned tip of the reviewed branch at a wave boundary. Alternatives: `strict` (immediate task review plus final review), `wave` (review completed waves plus final review), and `final-only` (explicit opt-in for prototypes or mechanical work).
- **Immediate-review triggers:** public API/schema/shared contract; security/auth/permissions/secrets; money/data-loss/migration; concurrency/distributed behavior; broad cross-cutting diff; weak or missing checks; implementer uncertainty/scope expansion; integration conflict; a task whose contract will be consumed before the next wave review.
- **Cumulative review:** one `code-reviewer` covers the exact branch-scoped range from `lastReviewedSha` to the pinned reviewed-branch tip; after a clean verdict the boundary advances. One batch fix `implementer` handles the accepted finding list, then the affected range is revalidated and re-reviewed. Every pending change is reviewed before integration or publication.
- **Independent code-reviewer:** fresh read-only context, reviews the exact diff range, classifies findings; the orchestrator (not implementer or code-reviewer) owns acceptance and integration.

## Herdr visibility

Persistent peers (`architecture-peer`, `domain-peer`, `quality-peer`) run as explicitly named, read-only `pi-intercom` sessions in visible Herdr tabs. The `implementer` runs headless through `pi-subagents`; `code-reviewer` is a fresh read-only child; optional inspector tabs attach read-only views. Peers never edit code, commit, integrate, or publish.

## Operations

### Setup safety model

- **Approval gates everything.** One approval covers both the external installs (`npx skills add legout/skills`, `pi install npm:pi-subagents`, `pi install npm:pi-intercom`) and the project-file writes. Nothing is installed and no project file changes before that approval — declining, or closing input before a question or approval is answered, aborts with zero side effects. `--yes` is noninteractive approval **after** validation; it never skips validation or the preview.
- **Inspect is read-only.** `--inspect` (incompatible with `--dry-run`/`--yes`, never reads stdin) reports the canonical project path, detected existing configuration, per-choice status (explicit / detected / unresolved with a suggestion), custom generated-doc replacement decisions, validation hazards, and a suggested preview command. The setup prompt uses it once; project requests skip it only when the custom generated-doc replacement decision is explicit too.
- **Shared preflight validation.** Inspect, dry-run, and apply all run the same checks before any install: malformed, reversed, or duplicate managed markers; instruction/output paths of the wrong kind (for example `docs` existing as a regular file); unwritable destinations; and missing `git`/`npx`/`pi`/`node` prerequisites (reported in inspect/preview, enforced on apply). All of these fail **before** any external command runs.
- **Symlinks are refused, never followed.** A symlinked instruction file, generated doc, or symlinked ancestor directory below the canonical project root aborts setup, naming the offending path; nothing is modified, unlinked, or replaced. Resolve such links yourself outside setup. The `--project` argument itself may resolve through a symlink to its canonical root.
- **Install-before-write ordering.** After approval, rendered outputs are staged in a unique temporary directory and external installs run **before** any project write. If an install fails, project files are untouched, the already-completed external steps are reported, and no destructive automatic uninstall is attempted. Each project output is then rendered to a same-directory temporary file and renamed into place. A write failure exits nonzero with a clear rerun instruction; earlier successful writes remain in place, and rerunning deterministically converges. Multi-file replacement and external installs are not one atomic transaction, and crash/power-loss durability is not promised.
- **Generated docs are managed.** `docs/agents/issue-tracker.md` and `docs/agents/domain.md` are owned only when they match generated/configuration-only content: unchanged choices regenerate them byte-identically, while custom content is never silently overwritten. Interactive setup asks; `--replace-custom` records the explicit replacement choice for preview/apply; `--yes` refuses without that flag. Setup never claims arbitrary other `docs/agents/` files.

### Day-to-day operations

- **Inspect:** `./setup.sh --project /path --inspect` — read-only report as described above.
- **Dry run:** `./setup.sh --project /path --dry-run` prints every command and the complete resulting files; nothing is executed or written. The setup prompt always performs this preview before asking for approval.
- **Update / rerun:** rerunning setup replaces the one managed block and regenerates the two managed docs idempotently; surrounding content survives. After a partial write failure, rerun setup to converge. Ambiguous or malformed markers abort safely before any install.
- **Implementer fixes and recovery:** review evidence is branch-scoped — a verdict applies to an exact reviewed range from a pinned boundary to the reviewed branch tip, never to a moved parent `HEAD`. When an implementation worktree or branch no longer exists, the durable handoff patch is replayed in a parent-owned review worktree at the pinned lane base to reconstruct and review the exact tree; fixes start from the same base with the prior patch applied; accepted lanes are assembled into an explicitly registered candidate branch that is handed to `merge-worktree` for integration. The recovery boundary is durable patch paths and pinned refs, not child-session or worktree survival. The detailed lifecycle is owned by `orchestrate-implementation` in [`legout/skills`](https://github.com/legout/skills); the hardening of that lifecycle (pinned bases, reconstructed review, registered candidates) is specified in this repository's current plans and is not yet released in the skills repository.
- **Safe uninstall:** remove the Pi package with `pi remove git:github.com/legout/pi-implementation-orchestrator`; delete the managed block between the `pi-implementation-orchestrator:start/end` markers from your instruction file (keep everything else in that file); remove `docs/agents/issue-tracker.md` and `docs/agents/domain.md` **only after confirming they still match the generated content and contain none of your edits** — keep any other documents under `docs/agents/`, modified files, and anything you own. Shared skills and Pi packages are unaffected by removing this package; remove them separately only if you want to (for example `npx skills remove <skill> --global --agent pi` for globally installed skills).
- **Troubleshooting:** run with `--inspect` and `--dry-run` first; a refusal naming a symlink or a malformed marker is a preflight stop, not a failure to clean up; check `pi install` output; see [pi docs](https://github.com/earendil-works/pi-coding-agent).

### Limitations

- No automatic resolution of semantic merge conflicts.
- Setup never authenticates GitHub, pushes, merges, or deploys.
- External installs are not reproducibly pinned: `npx skills add legout/skills` and `pi install npm:pi-*` fetch current remote state at install time. The runtime boundary described here reflects the audited `pi-subagents` 0.66.0 behavior (managed implementer worktrees may be removed on completion); live re-verification and pinning are tracked with the [`legout/skills`](https://github.com/legout/skills) release.

## Tests

```bash
# `bash -n a.sh b.sh` parses only the first script; check each file.
for f in setup.sh tests/setup_test.sh tests/setup_runner_test.sh; do
  bash -n "$f" || exit 1
done
bash tests/setup_test.sh
bash tests/setup_runner_test.sh
node -e 'const p=require("./package.json"); \
  if (!p.pi.prompts.includes("./prompts") || p.pi.skills) process.exit(1)'
git diff --check
```

`tests/setup_test.sh` runs every case in an independent shell process so a failed assertion always fails the suite; `tests/setup_runner_test.sh` mutation-probes that runner (a copy of `setup.sh` that omits the generated docs during interactive setup must fail the copied suite) and never invokes a real installer. Both suites run on every push and pull request via GitHub Actions.

## Attribution

- All planning and orchestration skills: [`legout/skills`](https://github.com/legout/skills) — consolidated from `obra/superpowers`, `mattpocock/skills`, and other MIT-licensed upstreams with pinned provenance in its `sources.json`; installed at runtime via [vercel-labs/skills](https://github.com/vercel-labs/skills) (Agent Skills CLI). This repository vendors nothing.
- Orchestration design: this repository. Both use the MIT license.

## License

[MIT](LICENSE) © 2026 Volker
