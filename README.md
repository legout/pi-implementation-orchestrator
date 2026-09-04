# pi-implementation-orchestrator

Plan features with the consolidated [`legout/skills`](https://github.com/legout/skills) planning stack, then execute the plans with isolated Pi workers, per-task test obligations, adaptive independent review, and orchestrator-owned integration.

## Architecture

```text
planning skills
  → ADRs, specifications, tickets, and plans
  → orchestrate-implementation
  → fresh workers in managed worktrees
  → focused validation and adaptive review
  → orchestrator-owned integration
  → separate publication authority
```

The repository ships: `package.json` (the native Pi manifest), `setup.sh` (dependency-free installer and project initializer), the `/setup-implementation-orchestrator` prompt, and shell tests. Runtime skills live in [`legout/skills`](https://github.com/legout/skills) and are installed by `setup.sh`. `pi-subagents` owns child lifecycle (fresh contexts, managed worktrees, missions, artifacts, review, recovery); `pi-intercom` is limited to named persistent read-only peers.

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

The prompt asks for the project and unresolved project choices. It previews the exact changes with `--dry-run`, obtains your explicit approval, and only then invokes `setup.sh` to install runtime and selected planning skills globally and create or update project documentation. Run the prompt again to modify an existing project's orchestrator configuration. Native package installation never runs setup, installs dependencies, or creates target-project files.

To update or remove the package:

```bash
pi update git:github.com/legout/pi-implementation-orchestrator
pi remove git:github.com/legout/pi-implementation-orchestrator
```

For a pinned tag or commit, append `@<ref>` to the Git source. A direct alternative is to clone this repository and run `./setup.sh --project /path/to/repo`; `./setup.sh --help` lists explicit choice flags, and `--dry-run` previews without touching anything.

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
| `orchestrate-implementation` | worker orchestration | Superpowers worktree patterns; carries Matt's `tdd` guidance for `new-test` tasks |
| `merge-worktree` | worktree integration | Superpowers `finishing-a-development-branch`; resolves conflicts inline (no `resolving-merge-conflicts` dependency) |
| `make-release` | release publication | — |

Packages: `pi install npm:pi-subagents`, `pi install npm:pi-intercom`.

### Not installed by default

Additional `legout/skills` entries you can add manually: `capture-project-vision`, `doc-coauthoring`, `simplify-code`, `review-codebase-architecture`. The original upstream packs (`mattpocock/skills`, `obra/superpowers`) are never installed — their workflows live on in the consolidated skills above. Whole-pack installation is never used.

## Workflows

- **Planning:** `shape-design` (idea → approved design or written spec; feasibility questions hand off to `prototype-question`) → `write-implementation-plan` (spec → executable, testable plan) → `orchestrate-implementation` executes the plan.
- **During execution:** workers apply `systematic-debugging` to failing checks and `verification-before-completion` before claiming done; the orchestrator supplies independent adaptive review.

### Ticket and plan inputs

Plans and tickets must reference their exact feature sources (ADR, specification, or issue). The orchestrator normalizes different plan formats with a read-only scout and never rewrites your planning documents.

## Worktree integration

The setup command installs [`merge-worktree`](https://github.com/legout/skills/tree/main/skills/merge-worktree). Use `/skill:merge-worktree` to integrate a registered worktree locally or through an automatically merged GitHub pull request. Local mode validates on an isolated integration branch before moving the target. Both modes default to merge commits, run project checks, regenerate conflicted lockfiles with their package manager, resolve remaining conflicts inline from source intent, and verify the pushed target. Pass `--clean-up` to remove the successfully merged source worktree automatically; otherwise the skill asks before removal. Branches are retained unless separately requested.

## Releases

The setup command installs [`make-release`](https://github.com/legout/skills/tree/main/skills/make-release). Use `/skill:make-release patch|minor|major` to version Python/uv or Node projects, finalize the changelog, build artifacts, commit and push, create a `v<version>` tag, and publish a GitHub Release. Add `--dry-run` for a mutation-free release plan; otherwise the exact plan requires approval before files change. Python releases may also publish to PyPI. On first use, the skill confirms the `[project].name` distribution and asks—with no default—between a GitHub workflow and local `uv publish`. GitHub publishing supports PyPI Trusted Publishing or a `PYPI_API_TOKEN` secret; local publishing uses `UV_PUBLISH_TOKEN`, not `.pypirc`.

Release validation is build-focused by default. Python artifacts also receive metadata checks and a fresh-environment post-publish smoke test. Repository-mandated checks still apply, and any failed build or publishing gate stops without rewriting remote history.

## Project documentation

`setup.sh --project` writes one managed block (between `<!-- pi-implementation-orchestrator:start/end -->` markers) into `AGENTS.md` or `CLAUDE.md` plus `docs/agents/issue-tracker.md` and `docs/agents/domain.md`. Everything outside the markers is preserved byte-for-byte. Source precedence inside a project:

```text
current owner decision → accepted ADR → approved specification
  → implementation plan → ticket → existing implementation
```

Work stops before implementation when authoritative sources conflict. Documentation map: `CONTEXT.md` (domain vocabulary), `docs/adr/` (decisions), `docs/agents/` (workflow configuration), `docs/specs/` or your tracker (feature behavior and acceptance), plans/tickets (execution entry points).

## Execution modes

- **`plan-only`** — normalize inputs, create manifest and task briefs, no source edits.
- **`supervised`** (default) — run workers, validation, review and fix cycles; pause before integration/publication.
- **`autonomous`** — same loop; cherry-pick accepted commits when clean; pause on conflicts, unresolved decisions, failed gates, push, merge, deploy, or release.

## Worker and reviewer contracts

Evidence is always mandatory; a new test is not. Every task declares exactly one test obligation during preflight:

- **`new-test`** — new behavior, bug regression, branching/state, parsing/validation, security, permissions, money, destructive data handling, concurrency, public contracts, or behavior without existing coverage (e.g. a new endpoint, a fixed off-by-one bug). Focused TDD is required only for `new-test` work: failing test → minimal implementation → passing test → refactor.
- **`existing-check`** — existing tests already exercise the affected behavior (e.g. a refactor inside covered seams). Add no redundant test; run and report the named focused checks.
- **`no-new-test`** — documentation, formatting, comments, static metadata, generated artifacts, typo correction, or another change where a new test proves little (e.g. a README edit). Run the smallest meaningful lint, parse, build, diff, or manual validation.

A worker may challenge its assigned obligation after inspection but must report why; it may never silently skip validation.

- **Workers:** sole writer in one managed worktree; one bounded brief per worker; report commit IDs, changed files, obligation, rationale, commands, results, and residual risks. No scope expansion, no cross-lane integration, no publication.
- **Review policy:** adaptive and orchestrator-owned — high-risk changes are reviewed immediately; low-risk changes may be batch-reviewed cumulatively (`lastReviewedSha..HEAD`) at a wave boundary. Alternatives: `strict` (immediate task review plus final review), `wave` (review completed waves plus final review), and `final-only` (explicit opt-in for prototypes or mechanical work).
- **Immediate-review triggers:** public API/schema/shared contract; security/auth/permissions/secrets; money/data-loss/migration; concurrency/distributed behavior; broad cross-cutting diff; weak or missing checks; worker uncertainty/scope expansion; integration conflict; a task whose contract will be consumed before the next wave review.
- **Cumulative review:** one reviewer covers the exact range `lastReviewedSha..HEAD`; after a clean verdict the boundary advances. One batch fix worker handles the accepted finding list, then the affected range is revalidated and re-reviewed. Every pending change is reviewed before integration or publication.
- **Independent reviewer:** fresh read-only context, reviews the exact diff range, classifies findings; the orchestrator (not workers or reviewers) owns acceptance and integration.

## Herdr visibility

Persistent peers (`architecture-peer`, `domain-peer`, `quality-peer`) run as explicitly named, read-only `pi-intercom` sessions in visible Herdr tabs. Native workers run headless through `pi-subagents`; optional inspector tabs attach read-only views. Peers never edit code, commit, integrate, or publish.

## Operations

- **Dry run:** `./setup.sh --project /path --dry-run` prints every command and preview; nothing is executed or written. The setup prompt always performs this preview before asking for approval.
- **Update / rerun:** rerunning setup replaces the one managed block and regenerates `docs/agents/` files idempotently; surrounding content survives. Ambiguous marker counts abort safely.
- **Worker fixes and recovery:** after review, a worker is resumed for fixes only when its managed worktree still exists and the child is resumable; otherwise a fresh fix worker starts in a new managed worktree from the exact original base and applies the durable prior handoff patch before accepted findings. The recovery boundary is durable handoff patch paths, not child session or cwd survival.
- **Uninstall:** remove the Pi package with `pi remove git:github.com/legout/pi-implementation-orchestrator`, remove the managed block from your instruction file, delete `docs/agents/`, and uninstall upstream skills with `npx skills remove <skill> --global --agent pi`.
- **Troubleshooting:** run with `--dry-run` first; check `pi install` output; see [pi docs](https://github.com/earendil-works/pi-coding-agent).

### Limitations

- No automatic resolution of semantic merge conflicts.
- No release or package publishing in the first version.
- Setup never authenticates GitHub, pushes, merges, or deploys.

## Tests

```bash
bash -n setup.sh tests/setup_test.sh
bash tests/setup_test.sh
```

Runs on every push and pull request via GitHub Actions.

## Attribution

- All planning and orchestration skills: [`legout/skills`](https://github.com/legout/skills) — consolidated from `obra/superpowers`, `mattpocock/skills`, and other MIT-licensed upstreams with pinned provenance in its `sources.json`; installed at runtime via [vercel-labs/skills](https://github.com/vercel-labs/skills) (Agent Skills CLI). This repository vendors nothing.
- Orchestration design: this repository. Both use the MIT license.

## License

[MIT](LICENSE) © 2026 Volker
