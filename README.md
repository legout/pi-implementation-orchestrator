# pi-implementation-orchestrator

Plan features with Superpowers or Matt Pocock skills, then execute the plans with isolated Pi TDD workers, independent reviewers, and orchestrator-owned integration.

## Architecture

```text
planning skills
  → ADRs, specifications, tickets, and plans
  → orchestrate-implementation
  → fresh TDD workers in managed worktrees
  → focused validation and independent review
  → orchestrator-owned integration
  → separate publication authority
```

The repository ships: `setup.sh` (dependency-free installer and project initializer), the packaged `orchestrate-implementation` skill, `prompts/init-orchestrator-project.md` (model-guided reconfiguration), and shell tests. `pi-subagents` owns child lifecycle (fresh contexts, managed worktrees, missions, artifacts, review, recovery); `pi-intercom` is limited to named persistent read-only peers.

## Prerequisites

- [`pi`](https://github.com/earendil-works/pi-coding-agent)
- Git
- Node.js / `npx` (for the Agent Skills CLI)
- GitHub CLI (`gh`) — only if you use GitHub Issues as your tracker

## Quick start

```bash
git clone https://github.com/legout/pi-implementation-orchestrator.git
cd pi-implementation-orchestrator
./setup.sh --planning both --project /path/to/repo
```

The installer installs selected planning skills globally for Pi, ensures `pi-subagents` and `pi-intercom`, installs this repository's `orchestrate-implementation` skill, and interactively initializes your project. `./setup.sh --help` shows all flags; `--dry-run` previews without touching anything.

## Planning profiles

Exact skills installed per profile:

| Skill | Source | `matt` | `superpowers` | `both` |
|---|---|---|---|---|
| `setup-matt-pocock-skills` | mattpocock/skills | ✅ | — | ✅ |
| `grilling` | mattpocock/skills | ✅ | — | ✅ |
| `domain-modeling` | mattpocock/skills | ✅ | — | ✅ |
| `grill-with-docs` | mattpocock/skills | ✅ | — | ✅ |
| `to-spec` | mattpocock/skills | ✅ | — | ✅ |
| `to-tickets` | mattpocock/skills | ✅ | — | ✅ |
| `tdd` | mattpocock/skills | ✅ | ✅ | ✅ |
| `brainstorming` | obra/superpowers | — | ✅ | ✅ |
| `writing-plans` | obra/superpowers | — | ✅ | ✅ |
| `orchestrate-implementation` | this repository | ✅ | ✅ | ✅ |

Packages for every profile: `pi install npm:pi-subagents`, `pi install npm:pi-intercom`.

### Exclusions (deliberate)

Never installed:

- Matt's `implement` and `code-review` — workers use TDD; the orchestrator supplies independent reviewers.
- Superpowers execution, review, worktree, and branch-finishing skills (`subagent-driven-development`, `executing-plans`, `requesting-code-review`, …) — the orchestrator owns those responsibilities.

Whole upstream packs are never installed; only the exact skills above.

## Workflows

- **Superpowers planning:** `brainstorming` → `writing-plans` → `orchestrate-implementation` executes the plan.
- **Matt planning:** `setup-matt-pocock-skills` → `grilling` / `domain-modeling` / `grill-with-docs` → `to-spec` → `to-tickets` → `orchestrate-implementation` executes the tickets.
- **Mixed:** use either planner per feature; both feed the same orchestrator.

### Ticket and plan inputs

Plans and tickets must reference their exact feature sources (ADR, specification, or issue). The orchestrator normalizes different plan formats with a read-only scout and never rewrites your planning documents.

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

- **TDD workers:** sole writer in one managed worktree; one bounded brief per worker; failing test → minimal implementation → passing test → refactor; report commit IDs, changed files, red/green evidence, validation results, and residual risks. No scope expansion, no cross-lane integration, no publication.
- **Independent reviewer:** fresh read-only context, reviews the exact task diff, classifies findings; the orchestrator (not workers or reviewers) owns acceptance and integration.

## Herdr visibility

Persistent peers (`architecture-peer`, `domain-peer`, `quality-peer`) run as explicitly named, read-only `pi-intercom` sessions in visible Herdr tabs. Native workers run headless through `pi-subagents`; optional inspector tabs attach read-only views. Peers never edit code, commit, integrate, or publish.

## Operations

- **Dry run:** `./setup.sh --planning both --project /path --dry-run` prints every command and preview; nothing is executed or written.
- **Update / rerun:** rerunning setup replaces the one managed block and regenerates `docs/agents/` files idempotently; surrounding content survives. Ambiguous marker counts abort safely.
- **Worker fixes and recovery:** after review, a worker is resumed for fixes only when its managed worktree still exists and the child is resumable; otherwise a fresh fix worker starts in a new managed worktree from the exact original base and applies the durable prior handoff patch before accepted findings. The recovery boundary is durable handoff patch paths, not child session or cwd survival.
- **Uninstall:** remove the managed block from your instruction file, delete `docs/agents/`, and uninstall skills with `npx skills remove <skill> --global --agent pi`.
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

- Planning skills: [obra/superpowers](https://github.com/obra/superpowers) and [mattpocock/skills](https://github.com/mattpocock/skills) — installed at runtime via [vercel-labs/skills](https://github.com/vercel-labs/skills) (Agent Skills CLI); upstream licenses apply to installed skills. This repository vendors nothing.
- Orchestration design and `orchestrate-implementation` skill: this repository, MIT license.

## License

[MIT](LICENSE) © 2026 Volker
