# pi-implementation-orchestrator

Set up the [`legout/skills`](https://github.com/legout/skills) planning and implementation stack for Pi, with approved project configuration and thin lifecycle shortcuts. Pi implementers and reviewers run through the host selected by `orchestrate-implementation`.

This repository is the Pi distribution of that stack — installer, setup prompt, and lifecycle prompts — not a runtime service. At execution time the orchestrator is your Pi session running the installed skills. Planning skills also work outside Pi; implementation orchestration uses Pi for every child role (see [Using the stack without pi](#using-the-stack-without-pi)).

## Architecture

```text
planning skills
  → ADRs, specifications, tickets, and plans
  → orchestrate-implementation
  → Pi children through the selected host
  → focused validation and parent/reviewer checks
  → reviewed isolated candidate
  → separately authorized target integration and publication
```

The repository ships: `package.json` (the native Pi manifest), `setup.sh` (the safety-gated installer and project initializer), the `/setup-implementation-orchestrator` prompt, the lifecycle prompts (`/research`, `/shape`, `/plan`, `/implement`, `/integrate`, `/release`), and isolated shell tests. Runtime skills live in [`legout/skills`](https://github.com/legout/skills) and are installed by `setup.sh`. Setup installs `pi-subagents` for native Pi children and `pi-intercom` for Pi-to-Pi messaging. Runtime host selection belongs to the skill: explicit/configured choices win, otherwise it uses the verified current host. Herdr panes, Paseo's Pi provider, and T3's Pi driver are also supported; T3 children remain read-only until supported isolated mutation binding exists. Setup does not install or configure those hosts. Intercom does not provide workspace placement or lifecycle authority.

## Using the stack without pi

The planning workflow is portable; this package's setup and implementation orchestration target Pi. The planning skills (`research`, `shape-design`, `grilling`, `domain-modeling`, `write-implementation-plan`, `planning-contract`) contain no pi assumptions and install into any agent the [Agent Skills CLI](https://skills.sh) supports — repeat per skill:

```bash
npx skills add legout/skills --skill research --global --agent <your-agent> --yes --copy
```

`orchestrate-implementation` requires Pi workers and reviewers, regardless of their model provider or host. Codex, OpenCode, or other agent runtimes are not substitutes. This package adds the safety-gated installer, project instruction/configuration scaffolding, lifecycle shortcuts, and native Pi role-setting wiring—not another orchestration engine.

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
/setup-implementation-orchestrator update
```

The prompt is bounded: after locating the package it performs at most three script executions — a read-only `--inspect` report when the request does not already supply every choice and custom-content decision explicitly, one `--dry-run` preview, and one apply with `--yes` — plus at most one read-only `pi --list-models` query when model choices are needed, one grouped round of unresolved questions, and one explicit approval. It never edits project files or installs skills itself; nothing is installed or written before your approval. Run the prompt again to modify an existing project's orchestrator configuration. Native package installation never runs setup, installs dependencies, or creates target-project files.

To update or remove the package:

```bash
pi update git:github.com/legout/pi-implementation-orchestrator
pi remove git:github.com/legout/pi-implementation-orchestrator
```

For a pinned tag or commit, append `@<ref>` to the Git source. A direct alternative is to clone this repository and run `./setup.sh --project /path/to/repo`; `./setup.sh --help` lists explicit choice flags, `./setup.sh --project /path --inspect` reports detected configuration, unresolved choices, and hazards without side effects, and `--dry-run` previews the exact commands and resulting files without touching anything.

Use `--update` (or include `update`/`upgrade` in the Pi prompt input) to update an existing installation without reinstalling the stack. Update mode reads the selected scope's local skill-lock and Pi settings, runs `npx skills update` only for installed `legout/skills` entries, and runs `pi update` only for installed unpinned Pi packages. Missing or pinned components are reported and skipped; use normal setup to install missing dependencies. A skill with the same name from another source or a Pi package configured in both scopes stops before mutation rather than updating the wrong owner/scope. Managed prompts and project files are refreshed only when their rendered bytes changed. This mode uses the current orchestrator package; update that package separately with `pi update git:github.com/legout/pi-implementation-orchestrator`. Updating skills alone does not refresh project instructions. To adopt a changed generated contract, update the package first, then preview and approve `/setup-implementation-orchestrator update` in each affected project. Surrounding owner-authored instructions remain unchanged.

Use `--migrate-namespace` (or say `migrate` in the Pi prompt input) to move an existing legacy `docs/` artifact installation to the `project/` namespace automatically. Setup previews every move (`docs/agents`, `docs/research`, `docs/adr`, `docs/specs`, `docs/plans`, `docs/tickets` → their `project/` counterparts), refuses when a target already exists or a path is a symlink, moves directories with `git mv` inside a tracked repository (plain `mv` otherwise) only after approval, and regenerates the three managed docs and the instruction-file block at the new namespace — content files are preserved byte-for-byte. Moves run after external installs, so a failed install still leaves the project untouched; an interrupted migration converges on rerun. Everything else under `docs/` stays where it is.

### Direct setup without the prompt

The `/setup-implementation-orchestrator` prompt needs no checkout — it locates the installed package's `setup.sh` itself. To run setup directly from a terminal instead:

**Projects that have the package installed** — the git-backed package is a full clone, version-managed by pi:

```bash
~/.pi/agent/git/github.com/legout/pi-implementation-orchestrator/setup.sh --project . --dry-run
```

Keep it fresh with `pi update git:github.com/legout/pi-implementation-orchestrator`.

To turn that into a plain command, run setup once with `--bin-link` from the installed copy:

```bash
~/.pi/agent/git/github.com/legout/pi-implementation-orchestrator/setup.sh --skip-project --bin-link --yes
pi-orchestrator-init --project . --update --dry-run   # from any directory afterwards
```

The symlink targets the pi-managed clone, so it keeps working across `pi update`; `pi remove` deletes the clone and leaves a dangling link to delete yourself. Setup refuses `--bin-link` from a checkout or extracted tarball (the link would dangle) and never overwrites an existing file or foreign symlink at `~/.local/bin/pi-orchestrator-init`.

**Any machine, no package or prompt needed** — bootstrap from a pinned release tarball (`setup.sh` needs the package's `prompts/` directory, so it is not standalone; download-then-run also preserves interactive approval, which piping into `bash` would break):

```bash
dir=$(mktemp -d) && mkdir "$dir/pkg" && curl -fsSL -o "$dir/repo.tgz" \
  https://github.com/legout/pi-implementation-orchestrator/archive/refs/tags/v0.3.0.tar.gz \
  && tar -xzf "$dir/repo.tgz" -C "$dir/pkg" --strip-components=1 \
  && "$dir/pkg/setup.sh" --project .
```

The same flow works for first initialization; optionally follow with `pi install git:github.com/legout/pi-implementation-orchestrator` to keep the package itself pi-managed (setup copies the prompt commands either way). Pin to a commit via `archive/<sha>.tar.gz` when you need an exact tree.

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
| `orchestrate-implementation` | worker/reviewer orchestration | Superpowers worktree patterns; carries independence-first focused-test guidance for `new-test` validation units |
| `merge-worktree` | worktree integration | Superpowers `finishing-a-development-branch`; resolves conflicts inline (no `resolving-merge-conflicts` dependency) |
| `make-release` | release publication | — |
| `planning-contract` | shared planning artifact and handoff contract (classification defaults, capture checkpoint, approval/readiness rules) consumed by the other planning skills | — (locally authored in `legout/skills`; installed explicitly alongside its consumers) |

Packages: `pi install npm:pi-subagents`, `pi install npm:pi-intercom`. Selecting Epiq additionally installs `pi-mcp-adapter` and configures the standard MCP file: `.mcp.json` for project scope or `~/.config/mcp/mcp.json` for global scope. Existing `mcpServers` entries are preserved; a conflicting existing `epiq` entry stops setup instead of being overwritten. Setup never initializes an Epiq board or project.

Skills and packages install **globally** (user-level) by default. Choose **project** scope to install skills into the project's agent directories and register the Pi packages in the project's `.pi/settings.json` instead: `./setup.sh --project /path --skill-scope project` (non-interactive) or answer the scope question when prompted. Project scope requires `--project`; it cannot be combined with `--skip-project`. The selected scope also decides where setup copies the package's prompt commands (`setup-implementation-orchestrator`, `research`, `shape`, `plan`, `implement`, `integrate`, `release`): global scope installs them into `~/.pi/agent/prompts/`, project scope into the project's `.pi/prompts/`. Copies are idempotent — rerunning setup refreshes them — and the Pi package's own `prompts/` manifest keeps working alongside. Project scope copies missing fields from global `~/.pi/agent/settings.json` when a project role override replaces its global counterpart. If unset, the effective defaults are worker `zai/glm-5.3`/`high` and reviewer `openai-codex/gpt-6.1-sol`/`high`. Interactive setup asks for each role's model and thinking level, showing the current effective value or offering those defaults when unset; it queries `pi --list-models` at most once for alternatives. `--yes` and `--dry-run` skip missing model questions, and `keep` preserves the current value. Optional `--worker-model`/`--reviewer-model` flags accept `keep`, `inherit`, or `provider/model`; matching thinking flags accept `keep`, `inherit`, or a Pi thinking level. `inherit` resolves to the effective global value or spec default, not the parent model. Choices change only requested fields; when setup materializes a project worker/reviewer override, it fills missing model/thinking fields from the effective global/default pair while preserving tools, other agents, and unknown settings. Existing global overrides are unchanged unless explicitly selected. Every apply ends with a field-level overview of the effective models, thinking, and sources (project `.pi/settings.json`, global `~/.pi/agent/settings.json`, or spec default), with change paths including `/subagents` inside pi.

For Epiq, the generated tracker guidance routes board work through `epiq_*` MCP tools and explicit `epiq_sync`; setup never initializes the board or project. The orchestrator skill's Epiq route must be loaded before making board changes.

### Not installed by default

Additional `legout/skills` entries you can add manually: `capture-project-vision`, `doc-coauthoring`, `simplify-code`, `review-codebase-architecture`. The original upstream packs (`mattpocock/skills`, `obra/superpowers`) are never installed — their workflows live on in the consolidated skills above. Whole-pack installation is never used.

## Workflows

You drive intent and approvals; the skills carry the mechanics. Three layers make that work: the generated `AGENTS.md` block routes each request to the right skill, installed skill descriptions auto-load the matching skill when your request fits (no `/skill:` call needed — that just forces it), and each `SKILL.md` holds the actual procedure. You never need to know the workflow internals — phrase the intent and answer the approval gates. Each lifecycle step also has a prompt shortcut: `/research <question>`, `/shape <feature>`, `/plan <spec>`, `/implement`, `/integrate`, `/release`. A shortcut only force-loads the matching skill and passes your arguments through — the skill stays the single source of procedure; if the skill is missing, the shortcut points to `/setup-implementation-orchestrator` instead of improvising. Setup copies these commands into the selected scope's prompt directory, so they also work when the Pi package itself is not installed.

A typical feature lifecycle:

1. **Shape:** "Shape the design for X — ask me the open questions." `shape-design` interviews you, then runs its capture checkpoint: resolved terms go to the owning glossary (`CONTEXT.md` is created lazily only when the first term is actually resolved — "no new terms" is a valid outcome), and only qualifying decisions (costly to reverse, surprising, made among real alternatives) earn an ADR. Feasibility questions hand off to `prototype-question`; durable findings land in `project/research/` as evidence, never as authorization. After your approval, behavior and acceptance are written to `project/specs/`.
2. **Plan:** "Write the implementation plan for the approved spec." `write-implementation-plan` produces the smallest executable map — tracer-bullet slices with files, interfaces, dependencies, validation obligations, and evidence. You approve it.
3. **Implement:** "Implement the plan." `orchestrate-implementation` checks readiness first: an approved behavioral source is mandatory, and research alone or a draft spec refuses and routes back to shaping. It uses the smallest safe decomposition and Pi host selection, validates and reviews an isolated candidate, then pauses before target integration. Explicit owner restrictions still apply.
4. **Integrate:** "Merge the candidate." `merge-worktree` runs local integration; pushing and publication stay separate approvals.

A bounded change collapses this: an approved issue with acceptance criteria goes straight to step 3 — no spec, plan, or tickets.

- **During execution:** Pi children implement or review bounded tasks through the selected host. The parent owns scope, finding disposition, and acceptance; native dispatch uses executable Pi `worker`/read-only `reviewer` profiles.

### Typical runs

**Greenfield — brand-new project, first feature:**

```text
pi install git:github.com/legout/pi-implementation-orchestrator   # once per machine
git init my-project && cd my-project
/setup-implementation-orchestrator    # inspect → choices → dry-run preview → approval
/research <open technical questions>  # optional; findings land in project/research/
/shape <first feature>                # interviews → capture checkpoint → spec in project/specs/
/plan <approved spec>                 # tracer-bullet slices in project/plans/; you approve it
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

Plans and tickets must reference their exact feature sources (ADR, specification, or issue). The orchestrator reads them without rewriting them; a scout is optional and needs a concrete context-gathering job.

Tickets are optional. The plan's tasks already are the execution units — converting them to tickets would create a second, drifting copy of the same task bodies, and the planning contract forbids duplicate editable task definitions. Create tickets only when coordination must outlive the current conversation: multi-session work, team visibility in GitHub Issues, Epiq board visibility, an established tracker convention, or an explicit request. One decision rule: *will someone — including future-you — need to find this task outside this conversation?* No → plan only. Yes → tickets own the canonical task bodies and the plan becomes a thin overview linking them. The tracker setup in `project/agents/issue-tracker.md` only declares which tracker exists; it never mandates creating tickets or initializing an Epiq board.

### Sequential vs. parallel execution

Parallelism comes from the dependency graph and write ownership, not from tickets — distinct ticket files alone never justify parallel writers. Tasks run in parallel managed worktrees only when all three hold: dependencies satisfied, stable consumed interfaces, and non-conflicting file ownership. Plan for it by separating write targets and defining the contract task first (schema → API and CLI in parallel → integration). Sequential execution is the right default when lanes share files, interfaces are still moving, or the feature is small.

## Worktree integration

The setup command installs [`merge-worktree`](https://github.com/legout/skills/tree/main/skills/workflow/merge-worktree). Use `/skill:merge-worktree` to integrate a registered worktree locally or through a GitHub pull request. **Local mode validates on an isolated integration branch and never pushes.** PR mode pushes the source branch and opens a PR — **opening a PR never authorizes merging it**; merging after required checks is a separate, explicitly authorized action. Both modes default to merge commits, run project checks, regenerate conflicted generated files (for example lockfiles) with their owning tool, resolve remaining conflicts inline from source intent, and never force-push. Pass `--clean-up` to remove the successfully merged source worktree automatically; otherwise the skill asks before removal. Branches are retained unless separately requested.

## Releases

The setup command installs [`make-release`](https://github.com/legout/skills/tree/main/skills/workflow/make-release). Use `/skill:make-release patch|minor|major` to version Python/uv or Node projects, finalize the changelog, build artifacts, commit and push, create a `v<version>` tag, and publish a GitHub Release. Add `--dry-run` for a mutation-free release plan; otherwise the exact plan requires approval before files change. Python releases may also publish to PyPI. On first use, the skill confirms the `[project].name` distribution and asks—with no default—between a GitHub workflow and local `uv publish`. GitHub publishing supports PyPI Trusted Publishing or a `PYPI_API_TOKEN` secret; local publishing uses `UV_PUBLISH_TOKEN`, not `.pypirc`.

Release validation is build-focused by default. Python artifacts also receive metadata checks and a fresh-environment post-publish smoke test. Repository-mandated checks still apply, and any failed build or publishing gate stops without rewriting remote history.

## Project documentation

`setup.sh --project` writes one managed block (between `<!-- pi-implementation-orchestrator:start/end -->` markers) into `AGENTS.md` or `CLAUDE.md` plus `project/agents/artifacts.md`, `project/agents/issue-tracker.md`, and `project/agents/domain.md`. Planning artifacts default to the `project/` namespace (`project/research/`, `project/adr/`, `project/specs/`, `project/plans/`, `project/tickets/`) so delivery artifacts stay separate from product or library documentation under `docs/`; existing installations with legacy `docs/` artifact directories keep that namespace automatically, and setup never migrates or duplicates artifacts between namespaces. When Epiq is selected, it also stages a merged `.mcp.json` in project scope, or the shared `~/.config/mcp/mcp.json` in global scope. Everything outside the markers is preserved byte-for-byte. The block delegates execution details to the installed skill, keeps scoped authority and inline review ground rules, and provides a **Routing and authority** section (skill routing, the `planning-contract` and artifact-map references, Pi-only current-host selection, the `supervised` candidate-review boundary, one writer per worktree, and separate target-integration/publication authority), followed by a layout-aware documentation map: single-context repositories get a canonical root `CONTEXT.md`; multi-context repositories get per-context glossaries plus an optional `CONTEXT-MAP.md` and never declare a root `CONTEXT.md` canonical. The generated block stays under roughly 850 words: the finding/security/test gates and correction limit are inline so they reach the main agent; detailed procedures remain in skills. It names written conventions rather than inventing a style guide.

Scoped authority inside a project: glossaries own terminology; ADRs own accepted architectural constraints; specifications own behavior; plans/tickets own execution decomposition. No scope silently overrides another — current owner decisions are authoritative but must be reconciled into the affected artifacts before dependent work proceeds. Work stops before implementation when authoritative sources conflict.

`project/agents/artifacts.md` is the protected project artifact mapping: declarative documentation (never executable configuration) recording the default destinations — `project/research/` for investigations/design studies/probe reports, `project/adr/` for architectural decisions, `project/specs/` for behavioral contracts, `project/plans/` for execution maps, `project/tickets/` for local work items, workflow configuration in `project/agents/` — with links to the tracker (`project/agents/issue-tracker.md`) and context-layout (`project/agents/domain.md`) docs. Explicit project mappings recorded in it override the defaults. Setup never moves existing documents or fabricates glossaries/ADRs/placeholder folders to match the map and never infers a destination from a misplaced document.

Documentation map: `CONTEXT.md` (domain vocabulary), `project/adr/` (decisions), `project/agents/` (workflow, tracker, and artifact-map configuration), `project/specs/` or your tracker (feature behavior and acceptance), plans/tickets (execution entry points).

## Execution modes

Execution procedure belongs to the installed `orchestrate-implementation` skill, not this installer or its generated instruction block:

- **`plan-only`** — read inputs and outline bounded briefs; no source edits, worktrees, or child launches.
- **`supervised`** (default) — implement, validate, and review an isolated candidate; pause before target integration.
- **`autonomous`** — keep the same bounded loop moving while safe work is ready; no implicit integration or publication authority.

Explicit owner restrictions override these defaults. Push, issue/PR changes, deploy, and release require applicable authorization separately.

## Worker and reviewer contracts

For native Pi dispatch, setup uses the `worker`/`reviewer` profiles shipped by `pi-subagents`; it does not create or replace agent definitions. Model/thinking choices and settings preservation are described under [Installed skills](#installed-skills). Other hosts use the skill's adapter and exact role-pair preflight, not an alternative agent runtime.

The skill owns validation obligations, review timing, retained committed-result handoffs, and patch-only recovery. Parent inspection applies to every result; required independent review covers high-risk/contract changes before dependent consumption or the assembled candidate. It does not reopen settled findings. Fresh reviewer prompts carry the complete inline contract, approved criteria, written conventions, and real-use context.

All newly allocated worker/fix, parent review/reconstruction, and candidate worktrees use `<repo-parent>/worktrees/<repo-name>/`. The selected allocator and exact model/thinking pair must be supported or dispatch blocks; setup does not configure host allocators or authorize silent fallback.

### Review guardrails

Priority is the agreed feature, then correctness, then proven risk. A finding needs a named violated requirement/written rule, a change-caused or worsened problem, reachability through actual callers/inputs/environment, material impact, and a proportionate response. Written conventions remain must-fix; reviewer taste never blocks. Test requests need a named real scenario, not coverage percentage or unreachable states.

Security review activates only for touched boundaries: untrusted/external input, credentials, auth, or dependency changes. A finding needs a named asset, realistic attacker, and real attack path. Stolen-secret, broken-TLS, malicious-admin, and generic-hardening stories fail the gate. Untouched boundary: `security: n/a`; missing facts on a security task: `unverified`, not an invented threat model. Trusted internal libraries and user-owned local data are not hostile by default; written safety guarantees remain binding.

The parent dispositions findings **before repair**: reject failed gates in one line, authorize small in-scope repairs, or hand large/out-of-scope repairs to the human. Review ends with `pass` or `fix-first` after criteria, real risks, and written rules are covered; a pass does not resolve unverified criteria or pending human decisions. **One fix pass, one delta recheck; no third round.** Surviving findings go to the human, not a new full review. After each task, restate its goal, compare the result, and choose `accept / fix / hand back / ask`; extra ideas get one line, not code. These rules use existing reports, not new ledgers or sign-off artifacts.

## Herdr visibility

A selected `herdr-pane` host uses fresh visible Pi sessions with verified placement and identity, coordinated through intercom. Persistent Pi peers are optional named read-only consultants, not mandatory architecture/domain/quality stages. Read the installed skill's Herdr adapter for dispatch and cleanup; setup does not install Herdr or its external guidance.

## Operations

### Setup safety model

- **Approval gates everything.** One approval covers external installs or updates (`npx skills add/update`, `pi install/update`) and all project/global config writes. Nothing is installed, updated, or written before that approval — declining, or closing input before a question or approval is answered, aborts with zero side effects. `--yes` is noninteractive approval **after** validation; it never skips validation or the preview.
- **Inspect is read-only.** `--inspect` (incompatible with `--dry-run`/`--yes`, never reads stdin) reports the canonical project path, detected existing configuration, current and requested worker/reviewer settings, per-choice status (explicit / detected / unresolved with a suggestion), custom generated-doc replacement decisions, validation hazards, and a suggested preview command. The setup prompt uses it once; project requests skip it only when the custom generated-doc replacement decision is explicit too.
- **Shared preflight validation.** Inspect, dry-run, and apply all run the same checks before any install: malformed, reversed, or duplicate managed markers; instruction/output/MCP-config paths of the wrong kind; invalid MCP JSON or a conflicting `mcpServers.epiq`; invalid Pi settings JSON for an explicit model update; unwritable destinations; symlinked MCP/settings paths; and missing `git`/`npx`/`pi`/`node` prerequisites (reported in inspect/preview, enforced on apply). All of these fail **before** any external command runs.
- **Symlinks are refused, never followed.** A symlinked instruction file, generated doc, or symlinked ancestor directory below the canonical project root aborts setup, naming the offending path; nothing is modified, unlinked, or replaced. Resolve such links yourself outside setup. The `--project` argument itself may resolve through a symlink to its canonical root.
- **Install-before-write ordering.** After approval, rendered outputs and the Epiq MCP merge are staged in unique temporary files and external installs run **before** any config or project write. The staged MCP config is atomically renamed after installs; prompt commands are copied afterward, followed by project outputs. A failed installer leaves config and project files untouched; a failed updater may have partially changed its own dependency files, but managed config is not written. Both report completed external steps and never attempt destructive rollback. A config or project write failure exits nonzero with a clear rerun instruction; earlier successful writes remain in place, and rerunning deterministically converges. Multi-file replacement and external installs are not one atomic transaction, and crash/power-loss durability is not promised.
- **Generated docs are managed.** `project/agents/artifacts.md`, `project/agents/issue-tracker.md`, and `project/agents/domain.md` are owned only when they match generated/configuration-only content: unchanged choices regenerate them byte-identically, while custom content (including configured custom artifact mappings) is never silently overwritten. Interactive setup asks; `--replace-custom` records the explicit replacement choice for preview/apply; `--yes` refuses without that flag. Setup never claims arbitrary other `project/agents/` files.

### Day-to-day operations

- **Inspect:** `./setup.sh --project /path --inspect` — read-only report as described above.
- **Dry run:** `./setup.sh --project /path --dry-run` prints every command, the resulting worker/reviewer overrides, and the complete resulting files; nothing is executed or written. The setup prompt always performs this preview before asking for approval.
- **Update / rerun:** `./setup.sh --project /path --update --dry-run` previews a selected-scope update; replace `--dry-run` with `--yes` after approval. Update mode refuses a fresh install, updates only installed source-owned/unpinned dependencies, skips missing/pinned dependencies, and writes only changed managed files. A normal rerun reconciles the complete desired installation. Both modes render the managed block and three docs idempotently; an unchanged Epiq MCP config is left byte-identical and new Epiq configuration is merged without removing other servers. Surrounding content survives. After a partial write failure, rerun setup to converge. Ambiguous or malformed markers abort safely before any install.
- **Worker fixes and recovery:** follow the installed skill's Git handoff and recovery references. Freeze committed results before disposable workspaces disappear and verify exact Git identities; surviving result refs do not require patch reconstruction. Fixes normally descend from the prior result and receive one delta recheck. Complete patch-only handoffs use pinned-base recovery. Cancellation preserves work and is separate from authorized cleanup; no live host acceptance is established by setup tests.
- **Safe uninstall:** remove the Pi package with `pi remove git:github.com/legout/pi-implementation-orchestrator`; delete the managed block between the `pi-implementation-orchestrator:start/end` markers from your instruction file (keep everything else in that file); remove `project/agents/artifacts.md`, `project/agents/issue-tracker.md`, and `project/agents/domain.md` **only after confirming they still match the generated content and contain none of your edits** — keep any other documents under `project/agents/`, modified files, and anything you own. Also remove the prompt-command copies (`setup-implementation-orchestrator.md`, `research.md`, `shape.md`, `plan.md`, `implement.md`, `integrate.md`, `release.md`) from `~/.pi/agent/prompts/` (global scope) or the project's `.pi/prompts/` (project scope) if you no longer want the commands. Shared skills and Pi packages are unaffected by removing this package; remove them separately only if you want to (for example `npx skills remove <skill> --global --agent pi` for globally installed skills).
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

During iteration, run affected cases directly, e.g. `bash tests/setup_test.sh --case test_initializes_agents_docs`; run both suites before completion.

`tests/setup_test.sh` runs every case in an independent shell process so a failed assertion always fails the suite; `tests/setup_runner_test.sh` mutation-probes that runner using only the interactive-docs case and synthetic failure/success cases, not repeated full setup-suite runs. A copy of `setup.sh` that omits the generated docs during interactive setup must fail the copied suite; an early failed assertion and a failed case followed by a passing case must also fail. The runner itself stays unchanged and no real installer runs. Both suites run on every push and pull request via GitHub Actions. Generated-contract assertions pin delivery of the guardrails; sibling skill tests cover inline reviewer prompts, retained committed results, shared-root refusals, candidate assembly, and patch-only recovery. The skill's `evals/fixtures/review-guardrails.md` covers trivial changes, pseudo-finding disposition, real bugs/convention violations, and a bounded recheck. Text assertions do not prove model behavior; report live scenario runs separately.

## Attribution

- All planning and orchestration skills: [`legout/skills`](https://github.com/legout/skills) — consolidated from `obra/superpowers`, `mattpocock/skills`, and other MIT-licensed upstreams with pinned provenance in its `sources.json`; installed at runtime via [vercel-labs/skills](https://github.com/vercel-labs/skills) (Agent Skills CLI). This repository vendors nothing.
- Orchestration design: this repository. Both use the MIT license.

## License

[MIT](LICENSE) © 2026 Volker
