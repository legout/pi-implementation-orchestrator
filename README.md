# pi-implementation-orchestrator

Plan features with the consolidated [`legout/skills`](https://github.com/legout/skills) planning stack, then execute the plans with builtin pi-subagents `worker` and `reviewer` profiles, risk-based validation obligations, proportional review, and orchestrator-owned integration.

## Architecture

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

The repository ships: `package.json` (the native Pi manifest), `setup.sh` (the safety-gated installer and project initializer), the `/setup-implementation-orchestrator` prompt, the lifecycle prompts (`/research`, `/shape`, `/plan`, `/implement`, `/integrate`, `/release`), and isolated shell tests. Runtime skills live in [`legout/skills`](https://github.com/legout/skills) and are installed by `setup.sh`. `pi-subagents` owns child lifecycle (fresh contexts, managed worktrees, missions, artifacts, review, recovery); `pi-intercom` is limited to named persistent read-only peers.

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
| `orchestrate-implementation` | worker/reviewer orchestration | Superpowers worktree patterns; carries Matt's `tdd` guidance for `new-test` validation units |
| `merge-worktree` | worktree integration | Superpowers `finishing-a-development-branch`; resolves conflicts inline (no `resolving-merge-conflicts` dependency) |
| `make-release` | release publication | — |
| `planning-contract` | shared planning artifact and handoff contract (classification defaults, capture checkpoint, approval/readiness rules) consumed by the other planning skills | — (locally authored in `legout/skills`; installed explicitly alongside its consumers) |

Packages: `pi install npm:pi-subagents`, `pi install npm:pi-intercom`. Selecting Epiq additionally installs `pi-mcp-adapter` and configures the standard MCP file: `.mcp.json` for project scope or `~/.config/mcp/mcp.json` for global scope. Existing `mcpServers` entries are preserved; a conflicting existing `epiq` entry stops setup instead of being overwritten. Setup never initializes an Epiq board or project.

Skills and packages install **globally** (user-level) by default. Choose **project** scope to install skills into the project's agent directories and register the Pi packages in the project's `.pi/settings.json` instead: `./setup.sh --project /path --skill-scope project` (non-interactive) or answer the scope question when prompted. Project scope requires `--project`; it cannot be combined with `--skip-project`. The selected scope also decides where setup copies the package's prompt commands (`setup-implementation-orchestrator`, `research`, `shape`, `plan`, `implement`, `integrate`, `release`): global scope installs them into `~/.pi/agent/prompts/`, project scope into the project's `.pi/prompts/`. Copies are idempotent — rerunning setup refreshes them — and the Pi package's own `prompts/` manifest keeps working alongside. Project scope also fills missing `model`/`thinking` fields in the project's `subagents.agentOverrides` from the global `~/.pi/agent/settings.json` (a project override object replaces its global counterpart wholesale, so a bare `{"tools":"inherit"}` entry would otherwise shadow the configured model); explicit project choices are never overwritten. Every apply ends with an overview of the effective `worker` and `reviewer` models and where to change them (project `.pi/settings.json`, global `~/.pi/agent/settings.json`, or `/subagents` inside pi).

For Epiq, the generated tracker guidance routes board work through `epiq_*` MCP tools and explicit `epiq_sync`; setup never initializes the board or project. The orchestrator skill's Epiq route must be loaded before making board changes.

### Not installed by default

Additional `legout/skills` entries you can add manually: `capture-project-vision`, `doc-coauthoring`, `simplify-code`, `review-codebase-architecture`. The original upstream packs (`mattpocock/skills`, `obra/superpowers`) are never installed — their workflows live on in the consolidated skills above. Whole-pack installation is never used.

## Workflows

You drive intent and approvals; the skills carry the mechanics. Three layers make that work: the generated `AGENTS.md` block routes each request to the right skill, installed skill descriptions auto-load the matching skill when your request fits (no `/skill:` call needed — that just forces it), and each `SKILL.md` holds the actual procedure. You never need to know the workflow internals — phrase the intent and answer the approval gates. Each lifecycle step also has a prompt shortcut: `/research <question>`, `/shape <feature>`, `/plan <spec>`, `/implement`, `/integrate`, `/release`. A shortcut only force-loads the matching skill and passes your arguments through — the skill stays the single source of procedure; if the skill is missing, the shortcut points to `/setup-implementation-orchestrator` instead of improvising. Setup copies these commands into the selected scope's prompt directory, so they also work when the Pi package itself is not installed.

A typical feature lifecycle:

1. **Shape:** "Shape the design for X — ask me the open questions." `shape-design` interviews you, then runs its capture checkpoint: resolved terms go to the owning glossary (`CONTEXT.md` is created lazily only when the first term is actually resolved — "no new terms" is a valid outcome), and only qualifying decisions (costly to reverse, surprising, made among real alternatives) earn an ADR. Feasibility questions hand off to `prototype-question`; durable findings land in `docs/research/` as evidence, never as authorization. After your approval, behavior and acceptance are written to `docs/specs/`.
2. **Plan:** "Write the implementation plan for the approved spec." `write-implementation-plan` produces the smallest executable map — tracer-bullet slices with files, interfaces, dependencies, validation obligations, and evidence. You approve it.
3. **Implement:** "Implement the plan." `orchestrate-implementation` checks readiness first: an approved behavioral source is mandatory, and research alone or a draft spec refuses and routes back to shaping. It then dispatches one builtin `worker` per lane in managed worktrees and applies proportional validation and review.
4. **Integrate:** "Merge the candidate." `merge-worktree` runs local integration; pushing and publication stay separate approvals.

A bounded change collapses this: an approved issue with acceptance criteria goes straight to step 3 — no spec, plan, or tickets.

- **During execution:** the builtin `worker` applies the assigned debugging and verification discipline; the orchestrator supplies a fresh builtin `reviewer` when the selected policy requires independent review.

### Typical runs

**Greenfield — brand-new project, first feature:**

```text
pi install git:github.com/legout/pi-implementation-orchestrator   # once per machine
git init my-project && cd my-project
/setup-implementation-orchestrator    # inspect → choices → dry-run preview → approval
/research <open technical questions>  # optional; findings land in docs/research/
/shape <first feature>                # interviews → capture checkpoint → spec in docs/specs/
/plan <approved spec>                 # tracer-bullet slices in docs/plans/; you approve it
/implement                            # readiness check → worker worktrees → pause before integration
/integrate                            # local merge on an isolated branch; never pushes
/release patch                        # approved release plan → tag + GitHub Release
```

On a fresh repository expect the single-context layout: `CONTEXT.md` appears lazily when shaping resolves the first domain term, and ADRs come only from genuinely costly decisions. Repeat `/shape → /plan → /implement → /integrate` per feature; the installed stack and managed block stay.

**Brownfield — existing repository:**

```text
cd existing-repo
/setup-implementation-orchestrator    # detects existing config/docs; preserves everything outside the markers byte-for-byte
# bounded change — an approved issue with acceptance criteria:
/implement <issue>                    # straight to lanes; no spec, plan, or tickets
# larger feature:
/research <how the current code handles X>
/shape <feature>                      # reconciles with existing glossaries/ADRs; conflicts stop work
/plan <approved spec>
/implement
/integrate                            # /release when you are ready to publish
```

Setup maps what already exists — glossaries, tracker, multi-context layouts — instead of moving or fabricating documents. Existing `AGENTS.md`/`CLAUDE.md` content survives untouched around the managed block, and authoritative-source conflicts stop before implementation.

### Plans vs. tickets

Plans and tickets must reference their exact feature sources (ADR, specification, or issue). The orchestrator normalizes different plan formats with a read-only scout and never rewrites your planning documents.

Tickets are optional. The plan's tasks already are the execution units — converting them to tickets would create a second, drifting copy of the same task bodies, and the planning contract forbids duplicate editable task definitions. Create tickets only when coordination must outlive the current conversation: multi-session work, team visibility in GitHub Issues, Epiq board visibility, an established tracker convention, or an explicit request. One decision rule: *will someone — including future-you — need to find this task outside this conversation?* No → plan only. Yes → tickets own the canonical task bodies and the plan becomes a thin overview linking them. The tracker setup in `docs/agents/issue-tracker.md` only declares which tracker exists; it never mandates creating tickets or initializing an Epiq board.

### Sequential vs. parallel execution

Parallelism comes from the dependency graph and write ownership, not from tickets — distinct ticket files alone never justify parallel writers. Tasks run in parallel managed worktrees only when all three hold: dependencies satisfied, stable consumed interfaces, and non-conflicting file ownership. Plan for it by separating write targets and defining the contract task first (schema → API and CLI in parallel → integration). Sequential execution is the right default when lanes share files, interfaces are still moving, or the feature is small.

## Worktree integration

The setup command installs [`merge-worktree`](https://github.com/legout/skills/tree/main/skills/workflow/merge-worktree). Use `/skill:merge-worktree` to integrate a registered worktree locally or through a GitHub pull request. **Local mode validates on an isolated integration branch and never pushes.** PR mode pushes the source branch and opens a PR — **opening a PR never authorizes merging it**; merging after required checks is a separate, explicitly authorized action. Both modes default to merge commits, run project checks, regenerate conflicted generated files (for example lockfiles) with their owning tool, resolve remaining conflicts inline from source intent, and never force-push. Pass `--clean-up` to remove the successfully merged source worktree automatically; otherwise the skill asks before removal. Branches are retained unless separately requested.

## Releases

The setup command installs [`make-release`](https://github.com/legout/skills/tree/main/skills/workflow/make-release). Use `/skill:make-release patch|minor|major` to version Python/uv or Node projects, finalize the changelog, build artifacts, commit and push, create a `v<version>` tag, and publish a GitHub Release. Add `--dry-run` for a mutation-free release plan; otherwise the exact plan requires approval before files change. Python releases may also publish to PyPI. On first use, the skill confirms the `[project].name` distribution and asks—with no default—between a GitHub workflow and local `uv publish`. GitHub publishing supports PyPI Trusted Publishing or a `PYPI_API_TOKEN` secret; local publishing uses `UV_PUBLISH_TOKEN`, not `.pypirc`.

Release validation is build-focused by default. Python artifacts also receive metadata checks and a fresh-environment post-publish smoke test. Repository-mandated checks still apply, and any failed build or publishing gate stops without rewriting remote history.

## Project documentation

`setup.sh --project` writes one managed block (between `<!-- pi-implementation-orchestrator:start/end -->` markers) into `AGENTS.md` or `CLAUDE.md` plus `docs/agents/artifacts.md`, `docs/agents/issue-tracker.md`, and `docs/agents/domain.md`. When Epiq is selected, it also stages a merged `.mcp.json` in project scope, or the shared `~/.config/mcp/mcp.json` in global scope. Everything outside the markers is preserved byte-for-byte. The block records the risk-based validation and adaptive-review policies, scoped authority, and a **Routing and authority** section (which skill resolves which kind of decision — including loading the shared `planning-contract` skill and the `docs/agents/artifacts.md` mapping — the `supervised` default with explicit approval gates for candidate assembly/integration/publication, one writer per worktree, evidence discipline, and merge/release authority), followed by a layout-aware documentation map: single-context repositories get a canonical root `CONTEXT.md`; multi-context repositories get per-context glossaries plus an optional `CONTEXT-MAP.md` and never declare a root `CONTEXT.md` canonical. The generated block stays under roughly 700 words: the finding/security/test gates and correction limit are inline so they reach the main agent; detailed procedures remain in skills. It names written conventions rather than inventing a style guide.

Scoped authority inside a project: glossaries own terminology; ADRs own accepted architectural constraints; specifications own behavior; plans/tickets own execution decomposition. No scope silently overrides another — current owner decisions are authoritative but must be reconciled into the affected artifacts before dependent work proceeds. Work stops before implementation when authoritative sources conflict.

`docs/agents/artifacts.md` is the protected project artifact mapping: declarative documentation (never executable configuration) recording the default destinations — `docs/research/` for investigations/design studies/probe reports, `docs/adr/` for architectural decisions, `docs/specs/` for behavioral contracts, `docs/plans/` for execution maps, `docs/tickets/` for local work items, workflow configuration in `docs/agents/` — with links to the tracker (`docs/agents/issue-tracker.md`) and context-layout (`docs/agents/domain.md`) docs. Explicit project mappings recorded in it override the defaults. Setup never moves existing documents or fabricates glossaries/ADRs/placeholder folders to match the map and never infers a destination from a misplaced document.

Documentation map: `CONTEXT.md` (domain vocabulary), `docs/adr/` (decisions), `docs/agents/` (workflow, tracker, and artifact-map configuration), `docs/specs/` or your tracker (feature behavior and acceptance), plans/tickets (execution entry points).

## Execution modes

- **`plan-only`** — normalize inputs, create manifest and task briefs, no source edits.
- **`supervised`** (default) — run the worker with proportional validation/review and fix cycles; pause before integration/publication.
- **`autonomous`** — same loop; cherry-pick accepted commits when clean; pause on conflicts, unresolved decisions, failed gates, push, merge, deploy, or release.

## Worker and reviewer contracts

The orchestrator uses the `worker` and `reviewer` profiles shipped by `pi-subagents`; setup does not create or override user models or agent definitions. Before dispatch, confirm both profiles with `subagent({ action: "list", capabilities: true })`, verify their tool permissions match the role, and record the resolved names in the run manifest.

Evidence is always mandatory; a new test is not. Every validation unit receives exactly one test obligation during preflight; related tasks may share a validation unit:

- **`new-test`** — changed behavior lacks meaningful existing coverage and a named reachable failure would otherwise be unprotected. Focused TDD is required only for `new-test` work: failing test → minimal implementation → passing focused check.
- **`existing-check`** — an existing focused check already exercises the affected behavior. Add no redundant test; run and report that check.
- **`no-new-test`** — a new test would prove little, including documentation, formatting, comments, static metadata, generated artifacts, mechanical changes, or behavior-neutral refactoring. Run the smallest meaningful parse, build, smoke check, or diff inspection.

A worker may challenge its assigned obligation after inspection but must report why; it may never silently skip validation.

- **Worker:** sole writer in one managed worktree; one bounded brief per run; report commit IDs, changed files, obligation, rationale, commands, results, and residual risks. No scope expansion, cross-lane integration, or publication.
- **Review policy:** adaptive and orchestrator-owned — low-risk work uses parent diff inspection; normal-risk work gets one candidate review; high-risk or dependency-defining work gets immediate plus candidate review. `strict`, `final-only`, and `parent-only` are explicit alternatives.
- **Immediate-review triggers:** public API/schema/shared contract; security/auth/permissions/secrets; money/data-loss/migration; concurrency/distributed behavior; broad cross-cutting diff; weak or missing checks; worker uncertainty/scope expansion; integration conflict; a task whose contract will be consumed before the next wave review.
- **Candidate review:** verify the exact candidate range after accepted lanes are assembled. Reuse prior evidence only after checking correspondence; review previously unreviewed changes and integration effects, not settled findings again. Never blindly copy a verdict across branches or trees.
- **Independent reviewer:** fresh read-only context; every dispatch carries the complete finding, security, and test gates plus approved criteria, written conventions, and real-use context. File links alone are insufficient. The parent owns disposition, repairs, rechecks, acceptance, and integration.

### Review guardrails

Priority is the agreed feature, then correctness, then proven risk. A finding needs a named violated requirement/written rule, a change-caused or worsened problem, reachability through actual callers/inputs/environment, material impact, and a proportionate response. Written conventions remain must-fix; reviewer taste never blocks. Test requests need a named real scenario, not coverage percentage or unreachable states.

Security review activates only for touched boundaries: untrusted/external input, credentials, auth, or dependency changes. A finding needs a named asset, realistic attacker, and real attack path. Stolen-secret, broken-TLS, malicious-admin, and generic-hardening stories fail the gate. Untouched boundary: `security: n/a`; missing facts on a security task: `unverified`, not an invented threat model. Trusted internal libraries and user-owned local data are not hostile by default; written safety guarantees remain binding.

The parent dispositions findings **before repair**: reject failed gates in one line, authorize small in-scope repairs, or hand large/out-of-scope repairs to the human. Review ends with `pass` or `fix-first` after criteria, real risks, and written rules are covered; a pass does not resolve unverified criteria or pending human decisions. **One fix pass, one delta recheck; no third round.** Surviving findings go to the human, not a new full review. After each task, restate its goal, compare the result, and choose `accept / fix / hand back / ask`; extra ideas get one line, not code. These rules use existing reports, not new ledgers or sign-off artifacts.

## Herdr visibility

Persistent peers (`architecture-peer`, `domain-peer`, `quality-peer`) run as explicitly named, read-only `pi-intercom` sessions in visible Herdr tabs. The builtin `worker` runs headless through `pi-subagents`; when the selected policy requires it, builtin `reviewer` is a fresh read-only child; optional inspector tabs attach read-only views. Peers never edit code, commit, integrate, or publish.

## Operations

### Setup safety model

- **Approval gates everything.** One approval covers both the external installs (`npx skills add legout/skills`, `pi install npm:pi-subagents`, `pi install npm:pi-intercom`, and conditional `pi install npm:pi-mcp-adapter`) and all project/global config writes. Nothing is installed or written before that approval — declining, or closing input before a question or approval is answered, aborts with zero side effects. `--yes` is noninteractive approval **after** validation; it never skips validation or the preview.
- **Inspect is read-only.** `--inspect` (incompatible with `--dry-run`/`--yes`, never reads stdin) reports the canonical project path, detected existing configuration, per-choice status (explicit / detected / unresolved with a suggestion), custom generated-doc replacement decisions, validation hazards, and a suggested preview command. The setup prompt uses it once; project requests skip it only when the custom generated-doc replacement decision is explicit too.
- **Shared preflight validation.** Inspect, dry-run, and apply all run the same checks before any install: malformed, reversed, or duplicate managed markers; instruction/output/MCP-config paths of the wrong kind; invalid MCP JSON or a conflicting `mcpServers.epiq`; unwritable destinations; symlinked MCP config paths; and missing `git`/`npx`/`pi`/`node` prerequisites (reported in inspect/preview, enforced on apply). All of these fail **before** any external command runs.
- **Symlinks are refused, never followed.** A symlinked instruction file, generated doc, or symlinked ancestor directory below the canonical project root aborts setup, naming the offending path; nothing is modified, unlinked, or replaced. Resolve such links yourself outside setup. The `--project` argument itself may resolve through a symlink to its canonical root.
- **Install-before-write ordering.** After approval, rendered outputs and the Epiq MCP merge are staged in unique temporary files and external installs run **before** any config or project write. The staged MCP config is atomically renamed after installs; prompt commands are copied afterward, followed by project outputs. A failed install leaves config and project files untouched, reports completed external steps, and never attempts destructive uninstall. A config or project write failure exits nonzero with a clear rerun instruction; earlier successful writes remain in place, and rerunning deterministically converges. Multi-file replacement and external installs are not one atomic transaction, and crash/power-loss durability is not promised.
- **Generated docs are managed.** `docs/agents/artifacts.md`, `docs/agents/issue-tracker.md`, and `docs/agents/domain.md` are owned only when they match generated/configuration-only content: unchanged choices regenerate them byte-identically, while custom content (including configured custom artifact mappings) is never silently overwritten. Interactive setup asks; `--replace-custom` records the explicit replacement choice for preview/apply; `--yes` refuses without that flag. Setup never claims arbitrary other `docs/agents/` files.

### Day-to-day operations

- **Inspect:** `./setup.sh --project /path --inspect` — read-only report as described above.
- **Dry run:** `./setup.sh --project /path --dry-run` prints every command and the complete resulting files; nothing is executed or written. The setup prompt always performs this preview before asking for approval.
- **Update / rerun:** rerunning setup replaces the one managed block and regenerates the three managed docs (artifact map, tracker, domain) idempotently; an unchanged Epiq MCP config is left byte-identical and new Epiq configuration is merged without removing other servers. Surrounding content survives. After a partial write failure, rerun setup to converge. Ambiguous or malformed markers abort safely before any install.
- **Worker fixes and recovery:** review evidence is branch-scoped — a verdict applies to an exact reviewed range from a pinned boundary to the reviewed branch tip, never to a moved parent `HEAD`. When an implementation worktree or branch no longer exists, the durable handoff patch is replayed in a parent-owned review worktree at the pinned lane base to reconstruct and review the exact tree; fixes start from the same base with the prior patch applied. Preserve the prior materialized review ref/SHA and reconstruct the full replacement patch, but recheck only the direct old-review-to-replacement delta and affected behavior (not a merge-base/triple-dot diff). Reconstruction and candidate assembly never reset the correction budget; accepted lanes are assembled into an explicitly registered candidate branch that is handed to `merge-worktree` for integration. The recovery boundary is durable patch paths and pinned refs, not child-session or worktree survival. This lifecycle is shipped in `orchestrate-implementation` in [`legout/skills`](https://github.com/legout/skills) (pinned bases, reconstructed review, registered candidates); one remaining native-runtime acceptance run is tracked in [`docs/plans/`](docs/plans/).
- **Safe uninstall:** remove the Pi package with `pi remove git:github.com/legout/pi-implementation-orchestrator`; delete the managed block between the `pi-implementation-orchestrator:start/end` markers from your instruction file (keep everything else in that file); remove `docs/agents/artifacts.md`, `docs/agents/issue-tracker.md`, and `docs/agents/domain.md` **only after confirming they still match the generated content and contain none of your edits** — keep any other documents under `docs/agents/`, modified files, and anything you own. Also remove the prompt-command copies (`setup-implementation-orchestrator.md`, `research.md`, `shape.md`, `plan.md`, `implement.md`, `integrate.md`, `release.md`) from `~/.pi/agent/prompts/` (global scope) or the project's `.pi/prompts/` (project scope) if you no longer want the commands. Shared skills and Pi packages are unaffected by removing this package; remove them separately only if you want to (for example `npx skills remove <skill> --global --agent pi` for globally installed skills).
- **Troubleshooting:** run with `--inspect` and `--dry-run` first; a refusal naming a symlink or a malformed marker is a preflight stop, not a failure to clean up; check `pi install` output; see [pi docs](https://github.com/earendil-works/pi-coding-agent).

### Limitations

- No automatic resolution of semantic merge conflicts.
- Setup never authenticates GitHub, pushes, merges, or deploys.
- External installs are not reproducibly pinned: `npx skills add legout/skills` and `pi install npm:pi-*` (including the conditional `pi-mcp-adapter`) fetch current remote state at install time. The runtime boundary described here reflects the audited `pi-subagents` 0.66.0 behavior (managed implementer worktrees may be removed on completion); live re-verification and pinning are tracked with the [`legout/skills`](https://github.com/legout/skills) release.

## Tests

```bash
# `bash -n a.sh b.sh` parses only the first script; check each file.
for f in setup.sh tests/setup_test.sh tests/setup_runner_test.sh; do
  bash -n "$f" || exit 1
done
bash tests/setup_test.sh
bash tests/setup_runner_test.sh
for p in setup-implementation-orchestrator research shape plan implement integrate release; do
  test -f "prompts/$p.md" || exit 1
done
node -e 'const p=require("./package.json"); \
  if (!p.pi.prompts.includes("./prompts") || p.pi.skills) process.exit(1)'
git diff --check
```

`tests/setup_test.sh` runs every case in an independent shell process so a failed assertion always fails the suite; `tests/setup_runner_test.sh` mutation-probes that runner (a copy of `setup.sh` that omits the generated docs during interactive setup must fail the copied suite) and never invokes a real installer. Both suites run on every push and pull request via GitHub Actions. Generated-contract assertions pin delivery of the guardrails; sibling skill tests pin inline reviewer prompts and full-patch/delta-recheck recovery. The skill's `evals/fixtures/review-guardrails.md` covers trivial changes, pseudo-finding disposition, real bugs/convention violations, and a bounded recheck. Text assertions do not prove model behavior; report live scenario runs separately.

## Attribution

- All planning and orchestration skills: [`legout/skills`](https://github.com/legout/skills) — consolidated from `obra/superpowers`, `mattpocock/skills`, and other MIT-licensed upstreams with pinned provenance in its `sources.json`; installed at runtime via [vercel-labs/skills](https://github.com/vercel-labs/skills) (Agent Skills CLI). This repository vendors nothing.
- Orchestration design: this repository. Both use the MIT license.

## License

[MIT](LICENSE) © 2026 Volker
