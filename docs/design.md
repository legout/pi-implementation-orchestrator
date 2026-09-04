# Pi Implementation Orchestrator Design

## Goal

Publish a reusable Pi implementation-orchestration skill with a safe installer that supports selected Superpowers and Matt Pocock planning workflows, workers with per-task test obligations, native Pi subagents, optional persistent intercom peers, and interactive project initialization.

## Repository

- Local path: `~/coding/libs/pi-implementation-orchestrator`
- GitHub target: `legout/pi-implementation-orchestrator`
- Visibility: public
- License: MIT
- Default branch: `main`

## Architecture

The repository owns the native Pi manifest, orchestration and setup skills, installer, project-init prompt, tests, and documentation. It does not vendor upstream planning skills.

Native package installation is passive: Pi loads the declared `skills/` and `prompts/` resources from `package.json` and does not execute `setup.sh`. Project configuration and dependency installation happen only after an explicit `/skill:setup-implementation-orchestrator` invocation (or direct `setup.sh` use) and user approval.

```text
planning skills
  → ADRs, specifications, tickets, and plans
  → orchestrate-implementation
  → fresh workers in managed worktrees
  → focused validation and adaptive review
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
├── prompts/init-orchestrator-project.md
├── skills/orchestrate-implementation/
│   ├── SKILL.md
│   └── evals/
├── skills/setup-implementation-orchestrator/SKILL.md
├── tests/setup_test.sh
└── docs/design.md
```

## Installation Scope

Install the repository as a native Git-backed Pi package:

```bash
pi install git:github.com/legout/pi-implementation-orchestrator
```

The manifest declares `./skills` and `./prompts`. This install is passive and must not execute setup, install upstream skills or npm packages, or create files in a target project. `pi update git:github.com/legout/pi-implementation-orchestrator` updates it and `pi remove git:github.com/legout/pi-implementation-orchestrator` removes it. Append `@<tag-or-commit>` to pin a Git ref.

After installation, invoke `/skill:setup-implementation-orchestrator`. That manual skill resolves the package-local `../../setup.sh`, asks only unresolved choices, runs one dry-run preview, obtains explicit approval, and invokes the same command once with `--yes` to mutate state. It never edits projects itself.

Direct setup remains available from a checkout:

```bash
./setup.sh --planning matt --project /path/to/repo
./setup.sh --planning superpowers --project /path/to/repo
./setup.sh --planning both --project /path/to/repo
./setup.sh --planning both --project /path/to/repo --dry-run
```

Project choices can be made non-interactively with `--instruction-file auto|AGENTS.md|CLAUDE.md`, `--tracker auto|github|local|other`, `--tracker-description TEXT` (required for `other`), and `--domain-layout auto|single|multi`. The script installs the repository's `orchestrate-implementation` skill globally for Pi and ensures `npm:pi-subagents` and `npm:pi-intercom` are installed through Pi.

## Selected Upstream Skills

### Superpowers profile

Install only:

- `brainstorming`
- `writing-plans`

Do not install Superpowers execution, review, branch-finishing, or worktree orchestration skills. The repository's orchestrator owns those responsibilities.

### Matt profile

Install only:

- `setup-matt-pocock-skills`
- `grilling`
- `domain-modeling`
- `grill-with-docs`
- `to-spec`
- `to-tickets`
- `tdd`

Do not install Matt's `implement` or `code-review` skills. Workers use TDD for `new-test` tasks; the orchestrator supplies independent reviewers.

### Both profile

Install the union of the two selected profiles without duplicates. TDD remains required for `new-test` tasks.

## Upstream Installation

Use the standard Agent Skills CLI with explicit skill names, global scope, and Pi as the target agent. Do not use whole-pack installation.

Example:

```bash
npx skills add obra/superpowers \
  --skill brainstorming \
  --skill writing-plans \
  --global --agent pi --yes
```

```bash
npx skills add mattpocock/skills \
  --skill setup-matt-pocock-skills \
  --skill grilling \
  --skill domain-modeling \
  --skill grill-with-docs \
  --skill to-spec \
  --skill to-tickets \
  --skill tdd \
  --global --agent pi --yes
```

The setup script reports installed, skipped, and already-present components. It does not authenticate GitHub, overwrite modified skills silently, or install unrelated upstream skills.

## Manual Setup Skill and Interactive Project Initialization

`skills/setup-implementation-orchestrator/SKILL.md` is trigger-only (`disable-model-invocation: true`). It accepts optional profile and project arguments; missing inputs are requested rather than guessed. For a supplied project it inspects existing instruction files, GitHub remotes, and monorepo signals, then turns the resulting answers into explicit setup flags. The dry-run output is shown verbatim for approval before any mutation. Setup is always delegated to `setup.sh`, so direct and skill-driven setup share validation, rendering, idempotence, and safety behavior.

When `--project` is supplied, setup asks only unresolved project questions:

1. choose `CLAUDE.md` or `AGENTS.md` when neither exists;
2. choose GitHub Issues, local Markdown, or another tracker;
3. choose single-context or multi-context domain documentation when monorepo signals exist; and
4. approve the exact managed block and generated docs before writing.

If one of `CLAUDE.md` or `AGENTS.md` already exists, update that file. If both exist, ask which is authoritative. Never overwrite surrounding user content.

Write or update one marked workflow block that documents:

- per-task test obligations (`new-test`, `existing-check`, `no-new-test`);
- adaptive orchestrator-owned review;
- documentation directory scopes;
- source precedence; and
- stop-on-conflict behavior.

Create:

- `docs/agents/issue-tracker.md`
- `docs/agents/domain.md`

Use `CONTEXT.md` plus `docs/adr/` for single-context repositories. Offer multi-context only when monorepo signals exist.

Re-running setup updates the one managed block and generated files idempotently. Ambiguous or malformed managed blocks stop safely.

## Init Prompt

Install or include `prompts/init-orchestrator-project.md` for later model-guided reconfiguration. The deterministic setup handles initial configuration; the prompt supports changes that require repository inspection and human decisions.

## Test obligations and review policy

Validation evidence is mandatory for every task; a new test is not. During preflight each task receives exactly one obligation:

- `new-test`: meaningful behavior, bug regression, branching/state, parsing/validation, security, permissions, money, destructive data handling, concurrency, public contracts, or behavior without existing coverage. Load `skill: "tdd"` and require red-green-refactor evidence.
- `existing-check`: existing tests already exercise the affected behavior. Run and report the named focused checks without adding redundant tests.
- `no-new-test`: documentation, formatting, comments, static metadata, generated artifacts, typo correction, or similar low-yield changes. Run the smallest meaningful validation.

The review policy is chosen per run and defaults to `adaptive`:

- `adaptive` (default): immediate review for high-risk or dependency-defining work; low-risk work queues behind a `lastReviewedSha` boundary.
- `strict`: immediate task review plus final review.
- `wave`: review only completed waves plus final review.
- `final-only`: explicit opt-in for prototypes, mechanical work, or owner-approved low-risk slices.

Immediate-review triggers: public API/schema/shared contract; security/auth/permissions/secrets; money/data-loss/migration; concurrency/distributed behavior; broad cross-cutting diff; weak or missing checks; worker uncertainty/scope expansion; integration conflict; a task whose contract will be consumed before the next wave review.

Pending low-risk changes receive one cumulative review of the exact range `lastReviewedSha..HEAD` at the end of a wave, before fan-in, when the diff becomes incoherent, or before integration/publication; the boundary advances only after a clean verdict. One batch fix worker handles the complete accepted finding list, then the affected range is revalidated and re-reviewed. A final exact-range/whole-branch review precedes main-branch integration or publication.

## Safety

- Support `--dry-run` without filesystem or package mutations.
- Validate project paths before writing.
- Preserve existing instructions outside the managed block.
- Require confirmation before project writes.
- Refuse ambiguous managed blocks.
- Never install whole upstream skill collections.
- Never install competing implementation or review workflows.
- Never push, merge, deploy, or release during setup.

## Tests

Use dependency-free shell tests with temporary HOME and project directories. Stub `pi`, `npx`, and `gh` so tests cannot alter the real machine.

Verify:

1. `package.json` parses and declares the expected Pi skills/prompts;
2. setup-skill frontmatter is trigger-only and points to the package-local script;
3. each planning profile invokes only its selected upstream skills;
4. `tdd` is installed for Matt and both profiles;
5. excluded implementation/review skills never appear;
6. explicit project-choice flags bypass prompts and validate values;
7. dry-run performs no package or project writes;
8. interactive choices generate the intended managed block and docs;
9. reruns are idempotent;
10. ambiguous managed blocks fail safely;
11. existing instructions outside the managed block remain unchanged; and
12. `bash -n` succeeds for scripts.

In addition to the shell suite, validate both skills with the repository's skill validator, parse `package.json` with Node, run `git diff --check`, and install the package in an isolated temporary `PI_CODING_AGENT_DIR`. The isolated install must list the package while leaving a separate target project unchanged; installation itself must not invoke `setup.sh`.

GitHub Actions runs the shell tests on pushes and pull requests.

## README

The root README is short but comprehensive. It includes:

- purpose and architecture;
- prerequisites;
- quick start;
- planning-profile skill tables;
- typical Superpowers, Matt, and mixed workflows;
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
- Replacing Superpowers or Matt planning methods.
- Installing Matt `implement` or `code-review`.
- Installing Superpowers implementation/review orchestration.
- Running all workers as interactive Herdr sessions.
- Automatically resolving semantic merge conflicts.
- Publishing releases or packages in the first version.
