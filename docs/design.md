# Pi Implementation Orchestrator Design

## Goal

Publish a reusable Pi implementation-orchestration skill with a safe installer that supports selected Superpowers and Matt Pocock planning workflows, TDD workers, native Pi subagents, optional persistent intercom peers, and interactive project initialization.

## Repository

- Local path: `~/coding/libs/pi-implementation-orchestrator`
- GitHub target: `legout/pi-implementation-orchestrator`
- Visibility: public
- License: MIT
- Default branch: `main`

## Architecture

The repository owns the orchestration skill, installer, project-init prompt, tests, and documentation. It does not vendor upstream planning skills.

```text
planning skills
  → ADRs, specifications, tickets, and plans
  → orchestrate-implementation
  → fresh TDD workers in managed worktrees
  → focused validation and independent review
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
├── setup.sh
├── prompts/init-orchestrator-project.md
├── skills/orchestrate-implementation/
│   ├── SKILL.md
│   └── evals/
├── tests/setup_test.sh
└── docs/design.md
```

## Installation Scope

Install reusable skills globally for Pi. Create project configuration locally in the selected repository.

The setup command accepts:

```bash
./setup.sh --planning matt --project /path/to/repo
./setup.sh --planning superpowers --project /path/to/repo
./setup.sh --planning both --project /path/to/repo
./setup.sh --planning both --project /path/to/repo --dry-run
```

The script installs the repository's `orchestrate-implementation` skill globally for Pi and ensures `npm:pi-subagents` and `npm:pi-intercom` are installed through Pi.

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

Do not install Matt's `implement` or `code-review` skills. Workers use TDD; the orchestrator supplies independent reviewers.

### Both profile

Install the union of the two selected profiles without duplicates. TDD remains required.

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

## Interactive Project Initialization

When `--project` is supplied, setup asks only unresolved project questions:

1. choose `CLAUDE.md` or `AGENTS.md` when neither exists;
2. choose GitHub Issues, local Markdown, or another tracker;
3. choose single-context or multi-context domain documentation when monorepo signals exist; and
4. approve the exact managed block and generated docs before writing.

If one of `CLAUDE.md` or `AGENTS.md` already exists, update that file. If both exist, ask which is authoritative. Never overwrite surrounding user content.

Write or update one marked workflow block that documents:

- TDD workers;
- orchestrator-owned independent review;
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

1. each planning profile invokes only its selected upstream skills;
2. `tdd` is installed for Matt and both profiles;
3. excluded implementation/review skills never appear;
4. dry-run performs no package or project writes;
5. interactive choices generate the intended managed block and docs;
6. reruns are idempotent;
7. ambiguous managed blocks fail safely;
8. existing instructions outside the managed block remain unchanged; and
9. `bash -n` succeeds for scripts.

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
- TDD and independent-review boundaries;
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
