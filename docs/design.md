# Pi Implementation Orchestrator Design

## Goal

Publish a safe Pi installer and setup prompt for implementation-orchestration skills maintained in `legout/skills`, with selected Superpowers and Matt Pocock planning workflows, workers with per-task test obligations, native Pi subagents, optional persistent intercom peers, and interactive project setup.

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
├── prompts/setup-implementation-orchestrator.md
├── tests/setup_test.sh
└── docs/design.md
```

## Installation Scope

Install the repository as a native Git-backed Pi package:

```bash
pi install git:github.com/legout/pi-implementation-orchestrator
```

The manifest declares `./prompts`. This install is passive and must not execute setup, install skills or npm packages, or create files in a target project. `pi update git:github.com/legout/pi-implementation-orchestrator` updates it and `pi remove git:github.com/legout/pi-implementation-orchestrator` removes it. Append `@<tag-or-commit>` to pin a Git ref.

After installation, invoke `/setup-implementation-orchestrator`. That prompt locates the package's `setup.sh`, asks only unresolved choices, runs one dry-run preview, obtains explicit approval, and invokes the same command once with `--yes` to mutate state. It never edits projects itself.

Direct setup remains available from a checkout:

```bash
./setup.sh --planning matt --project /path/to/repo
./setup.sh --planning superpowers --project /path/to/repo
./setup.sh --planning both --project /path/to/repo
./setup.sh --planning both --project /path/to/repo --dry-run
```

Project choices can be made non-interactively with `--instruction-file auto|AGENTS.md|CLAUDE.md`, `--tracker auto|github|local|other`, `--tracker-description TEXT` (required for `other`), and `--domain-layout auto|single|multi`. The script installs `orchestrate-implementation`, `merge-worktree`, and `make-release` from `legout/skills` globally for Pi, installs Matt Pocock's `resolving-merge-conflicts` dependency, and ensures `npm:pi-subagents` and `npm:pi-intercom` are installed through Pi.

## Selected Upstream Skills

### Superpowers profile

Install only:

- `brainstorming`
- `writing-plans`

Do not install Superpowers execution, review, branch-finishing, or worktree orchestration skills. `orchestrate-implementation` owns those responsibilities.

### Matt profile

Install only:

- `setup-matt-pocock-skills`
- `grilling`
- `domain-modeling`
- `grill-with-docs`
- `to-spec`
- `to-tickets`
- `tdd`
- `resolving-merge-conflicts`

Do not install Matt's `implement` or `code-review` skills. Workers use TDD for `new-test` tasks; the orchestrator supplies independent reviewers.

### Both profile

Install the union of the two selected profiles without duplicates. TDD remains required for `new-test` tasks. Install `resolving-merge-conflicts` for every profile because `merge-worktree` uses it when integration conflicts occur.

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
  --skill resolving-merge-conflicts \
  --global --agent pi --yes
```

The setup script reports installed, skipped, and already-present components. It does not authenticate GitHub, overwrite modified skills silently, or install unrelated upstream skills.

## Worktree Integration

The externally maintained [`merge-worktree`](https://github.com/legout/skills/tree/main/skills/merge-worktree) skill integrates a registered source worktree either locally or through GitHub. Local mode first merges and validates on an isolated temporary integration branch, then fast-forwards the unchanged target to the verified merge commit. Both modes default to merge commits, validate before and after integration, push and verify the target, and never force-push. PR mode uses the `github` skill, waits for required checks, and merges automatically without bypassing branch protection. Conflicts load Matt Pocock's `resolving-merge-conflicts` skill and are resolved from source intent before checks resume.

Cleanup is a post-success operation. `--clean-up` removes and prunes the source worktree automatically; without the flag the skill asks. It never removes a dirty or unmerged worktree and does not delete branches unless separately requested.

## Release Publishing

The externally maintained [`make-release`](https://github.com/legout/skills/tree/main/skills/make-release) skill supports explicit patch, minor, and major releases for Python/uv and Node packages. It previews the complete release plan and requires approval before the first mutation (`--dry-run` stops at the preview). It updates the canonical manifest and lockfile, verifies the finalized changelog against actual commits, performs build-focused validation, creates `chore(release): <version>`, pushes the default branch, creates and verifies an immutable `v<version>` tag, and publishes a GitHub Release.

Python releases optionally publish to PyPI. The first publishing run confirms `[project].name` and requires an explicit choice between a GitHub workflow and local `uv publish`. GitHub publishing supports either Trusted Publishing with `id-token: write` or a `PYPI_API_TOKEN` repository secret. Local publishing uses a securely supplied `UV_PUBLISH_TOKEN`; `.pypirc` is not created because uv does not consume it. Python artifacts receive metadata validation before publication and a fresh-environment consumer smoke check afterward. Failed remote steps are reported as partial state and never repaired by rewriting history.

## Single Setup Prompt for New and Existing Projects

`prompts/setup-implementation-orchestrator.md` is the user-facing command for both new-project setup and existing-project reconfiguration. It accepts optional profile and project arguments; missing inputs are requested rather than guessed. For a supplied project it inspects existing instruction files, GitHub remotes, and monorepo signals, then turns the resulting answers into explicit setup flags. The dry-run output is shown verbatim for approval before any mutation. Setup is always delegated to `setup.sh`, so direct and prompt-driven setup share validation, rendering, idempotence, and safety behavior. Re-run the same prompt to modify an existing project's orchestrator configuration.

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

1. `package.json` parses and declares only the setup prompt;
2. the setup prompt requires a dry-run and approval before `--yes`;
3. each planning profile invokes only its selected upstream skills;
4. all runtime skills are installed from `legout/skills`;
5. `tdd` is installed for Matt and both profiles;
6. excluded implementation/review skills never appear;
7. explicit project-choice flags bypass prompts and validate values;
8. dry-run performs no package or project writes;
9. interactive choices generate the intended managed block and docs;
10. reruns are idempotent;
11. ambiguous managed blocks fail safely;
12. existing instructions outside the managed block remain unchanged; and
13. `bash -n` succeeds for scripts.

In addition to the shell suite, parse `package.json` with Node, run `git diff --check`, and install the package in an isolated temporary `PI_CODING_AGENT_DIR`. Runtime skill contract tests belong in `legout/skills`. The isolated install must list the package while leaving a separate target project unchanged; installation itself must not invoke `setup.sh`.

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
