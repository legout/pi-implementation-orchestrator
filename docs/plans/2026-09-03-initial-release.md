# Pi Implementation Orchestrator Initial Release Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `orchestrate-implementation` with TDD workers to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, test, document, and publish the first public release of `legout/pi-implementation-orchestrator`.

**Architecture:** A dependency-free Bash installer uses the Agent Skills CLI to install only selected planning skills globally for Pi, ensures `pi-subagents` and `pi-intercom` are installed, installs this repository's orchestration skill, and interactively initializes one target project. Plain Bash tests run with a temporary HOME and stubbed external commands.

**Tech Stack:** Bash 3.2-compatible shell, Git, Pi CLI, `npx skills`, Markdown, GitHub Actions.

## Global Constraints

- Install reusable skills globally for Pi; write project configuration only inside the selected project.
- Install only the approved Superpowers and Matt skill subsets.
- Always install Matt's `tdd`; never install Matt `implement` or `code-review`.
- Never install Superpowers execution, review, worktree, or branch-finishing skills.
- Use `pi-subagents` for lifecycle and `pi-intercom` only for persistent read-only peers.
- Preserve project instructions outside one marked managed block.
- `--dry-run` performs no package or filesystem mutations.
- Do not add runtime dependencies.
- Do not vendor upstream skills.
- Use MIT license and preserve upstream attribution in README.
- Do not create or publish the GitHub repository until local tests and independent review pass.

---

### Task 1: Add failing installer tests

**Files:**
- Create: `tests/setup_test.sh`

**Interfaces:**
- Consumes: `setup.sh` CLI.
- Produces: isolated behavioral checks using temporary HOME, project, and command stubs.

- [ ] **Step 1: Create the shell test harness**

Create an executable `tests/setup_test.sh` with helpers:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=

cleanup() { test -z "${TMP:-}" || rm -rf "$TMP"; }
trap cleanup EXIT

new_case() {
  cleanup
  TMP=$(mktemp -d -t pi-orchestrator-test)
  mkdir -p "$TMP/home" "$TMP/bin" "$TMP/project"
  export HOME="$TMP/home"
  export PATH="$TMP/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  : > "$TMP/calls"
}

stub_commands() {
  cat > "$TMP/bin/pi" <<'STUB'
#!/usr/bin/env bash
printf 'pi %s\n' "$*" >> "$TEST_CALLS"
STUB
  cat > "$TMP/bin/npx" <<'STUB'
#!/usr/bin/env bash
printf 'npx %s\n' "$*" >> "$TEST_CALLS"
STUB
  chmod +x "$TMP/bin/pi" "$TMP/bin/npx"
  export TEST_CALLS="$TMP/calls"
}

assert_contains() { grep -F "$2" "$1" >/dev/null || { echo "missing: $2"; exit 1; }; }
assert_not_contains() { ! grep -F "$2" "$1" >/dev/null || { echo "unexpected: $2"; exit 1; }; }
assert_eq() { test "$1" = "$2" || { echo "expected [$2], got [$1]"; exit 1; }; }
```

- [ ] **Step 2: Add profile-selection tests**

Add cases that call the future installer with `--skip-project`:

```bash
test_matt_profile() {
  new_case; stub_commands
  "$ROOT/setup.sh" --planning matt --skip-project --yes
  assert_contains "$TEST_CALLS" "mattpocock/skills"
  for skill in setup-matt-pocock-skills grilling domain-modeling grill-with-docs to-spec to-tickets tdd; do
    assert_contains "$TEST_CALLS" "--skill $skill"
  done
  assert_not_contains "$TEST_CALLS" "--skill implement"
  assert_not_contains "$TEST_CALLS" "--skill code-review"
  assert_not_contains "$TEST_CALLS" "obra/superpowers"
}

test_superpowers_profile() {
  new_case; stub_commands
  "$ROOT/setup.sh" --planning superpowers --skip-project --yes
  assert_contains "$TEST_CALLS" "obra/superpowers"
  assert_contains "$TEST_CALLS" "--skill brainstorming"
  assert_contains "$TEST_CALLS" "--skill writing-plans"
  assert_contains "$TEST_CALLS" "mattpocock/skills"
  assert_contains "$TEST_CALLS" "--skill tdd"
  assert_not_contains "$TEST_CALLS" "subagent-driven-development"
  assert_not_contains "$TEST_CALLS" "executing-plans"
  assert_not_contains "$TEST_CALLS" "requesting-code-review"
}

test_both_profile() {
  new_case; stub_commands
  "$ROOT/setup.sh" --planning both --skip-project --yes
  assert_contains "$TEST_CALLS" "obra/superpowers"
  assert_contains "$TEST_CALLS" "mattpocock/skills"
  assert_eq "$(grep -o -- '--skill tdd' "$TEST_CALLS" | wc -l | tr -d ' ')" "1"
}
```

- [ ] **Step 3: Add dry-run and project-init tests**

Add tests for:

```bash
test_dry_run_writes_nothing() {
  new_case; stub_commands
  before=$(find "$TMP" -type f | sort | xargs shasum)
  printf '1\n1\ny\n' | "$ROOT/setup.sh" --planning matt --project "$TMP/project" --dry-run
  after=$(find "$TMP" -type f | sort | xargs shasum)
  assert_eq "$after" "$before"
  assert_eq "$(wc -c < "$TEST_CALLS" | tr -d ' ')" "0"
}

test_initializes_agents_docs() {
  new_case; stub_commands
  git -C "$TMP/project" init -q
  printf '1\n2\ny\n' | "$ROOT/setup.sh" --planning matt --project "$TMP/project"
  test -f "$TMP/project/AGENTS.md"
  test -f "$TMP/project/docs/agents/issue-tracker.md"
  test -f "$TMP/project/docs/agents/domain.md"
  assert_contains "$TMP/project/AGENTS.md" "pi-implementation-orchestrator:start"
  assert_contains "$TMP/project/AGENTS.md" "TDD"
  assert_contains "$TMP/project/AGENTS.md" "orchestrator-owned"
}
```

Also add cases proving reruns produce one managed block, surrounding text survives, and duplicate start/end markers fail non-zero.

- [ ] **Step 4: Run tests and verify RED**

Run:

```bash
chmod +x tests/setup_test.sh
bash tests/setup_test.sh
```

Expected: FAIL because `setup.sh` does not exist.

- [ ] **Step 5: Commit the failing tests**

```bash
git add tests/setup_test.sh
git commit -m "test: define installer behavior"
```

---

### Task 2: Implement selected global skill installation

**Files:**
- Create: `setup.sh`
- Test: `tests/setup_test.sh`

**Interfaces:**
- Consumes: `--planning matt|superpowers|both`, `--project PATH`, `--skip-project`, `--dry-run`, `--yes`.
- Produces: explicit `pi install` and `npx skills add` calls.

- [ ] **Step 1: Implement argument parsing and command wrappers**

Create executable `setup.sh` beginning with:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
PLANNING=
PROJECT=
DRY_RUN=false
ASSUME_YES=false
SKIP_PROJECT=false

usage() {
  echo "Usage: ./setup.sh --planning matt|superpowers|both [--project PATH|--skip-project] [--dry-run] [--yes]"
}

run() {
  if "$DRY_RUN"; then printf '+ '; printf '%q ' "$@"; printf '\n'; else "$@"; fi
}
```

Parse the documented flags, reject unknown flags, reject invalid planning values, require exactly one of `--project` or `--skip-project`, and resolve the project to an absolute directory.

- [ ] **Step 2: Add exact selected-skill arrays**

Use Bash arrays:

```bash
SUPERPOWERS_SKILLS=(brainstorming writing-plans)
MATT_PLANNING_SKILLS=(setup-matt-pocock-skills grilling domain-modeling grill-with-docs to-spec to-tickets)
TDD_SKILL=tdd
```

Build `npx skills add` commands by appending one `--skill NAME` per item. Always install `tdd` from `mattpocock/skills`, including the Superpowers-only profile. End every skills command with `--global --agent pi --yes --copy`.

- [ ] **Step 3: Ensure Pi packages and install this repository skill**

Run through the wrapper:

```bash
pi install npm:pi-subagents
pi install npm:pi-intercom
npx skills add "$ROOT" --skill orchestrate-implementation --global --agent pi --yes --copy
```

Do not add package commands in `--dry-run`. Let a failed package or skill command stop the script.

- [ ] **Step 4: Run focused tests**

```bash
bash tests/setup_test.sh
```

Expected: profile-selection tests pass; project-init tests still fail because project initialization is not implemented.

- [ ] **Step 5: Commit installation behavior**

```bash
git add setup.sh tests/setup_test.sh
git commit -m "feat: install selected planning skills"
```

---

### Task 3: Implement interactive project initialization

**Files:**
- Modify: `setup.sh`
- Create: `prompts/init-orchestrator-project.md`
- Test: `tests/setup_test.sh`

**Interfaces:**
- Consumes: interactive choices and repository signals.
- Produces: one managed instruction block plus `docs/agents/issue-tracker.md` and `docs/agents/domain.md`.

- [ ] **Step 1: Add project inspection and questions**

Implement functions:

```bash
choose_instruction_file() {
  if test -f "$PROJECT/CLAUDE.md" && test -f "$PROJECT/AGENTS.md"; then
    ask_choice "Instruction file" "CLAUDE.md" "AGENTS.md"
  elif test -f "$PROJECT/CLAUDE.md"; then echo CLAUDE.md
  elif test -f "$PROJECT/AGENTS.md"; then echo AGENTS.md
  else ask_choice "Create instruction file" "AGENTS.md" "CLAUDE.md"
  fi
}

choose_tracker() {
  if git -C "$PROJECT" remote get-url origin 2>/dev/null | grep -q 'github.com'; then
    ask_choice "Issue tracker" "GitHub Issues" "Local Markdown" "Other"
  else
    ask_choice "Issue tracker" "Local Markdown" "GitHub Issues" "Other"
  fi
}

has_monorepo_signals() {
  test -f "$PROJECT/pnpm-workspace.yaml" ||
    grep -q '"workspaces"' "$PROJECT/package.json" 2>/dev/null ||
    find "$PROJECT/packages" -mindepth 2 -maxdepth 2 -type d -name src 2>/dev/null | grep -q .
}

choose_domain_layout() {
  if has_monorepo_signals; then
    ask_choice "Domain layout" "Single context" "Multiple contexts"
  else
    echo "Single context"
  fi
}
```

Behavior:

- one existing `CLAUDE.md` or `AGENTS.md` wins automatically;
- both existing files trigger a choice;
- neither triggers a choice, defaulting to `AGENTS.md`;
- a GitHub `origin` makes GitHub Issues the tracker default; otherwise local Markdown is default;
- another tracker asks for one descriptive line;
- domain layout is single-context unless monorepo signals exist, then ask.

- [ ] **Step 2: Render the managed block and generated docs**

Use exact markers:

```text
<!-- pi-implementation-orchestrator:start -->
<!-- pi-implementation-orchestrator:end -->
```

The block must state:

```markdown
## Agent workflow

- Implementation workers use TDD and report red/green evidence.
- Independent review is orchestrator-owned.
- Plans and tickets reference exact feature sources; this file defines stable repository-wide scope.
- Source precedence: current owner decision → accepted ADR → approved specification → implementation plan → ticket → existing implementation.
- Stop before implementation when authoritative sources conflict.

### Documentation map

- `CONTEXT.md`: canonical domain vocabulary.
- `docs/adr/`: accepted architecture decisions.
- `docs/agents/`: workflow and tracker configuration.
- `docs/specs/` or configured tracker: feature behavior and acceptance.
- implementation plans/tickets: execution entry points and explicit source references.
```

Generate tracker and domain docs from the chosen values.

- [ ] **Step 3: Add safe block replacement**

Before writing, count exact start/end markers. Allow `0/0` to append and `1/1` to replace. Reject every other count. Write through a temporary file in the destination directory and `mv` it into place. Preserve all content outside the managed block byte-for-byte except one separating newline.

- [ ] **Step 4: Add preview and confirmation**

Print the selected instruction file and generated contents. Unless `--yes` is set, ask:

```text
Write this project configuration? [y/N]
```

A non-yes response exits without project writes. `--dry-run` prints the preview but performs no writes or package installation.

- [ ] **Step 5: Write the reconfiguration prompt**

Create `prompts/init-orchestrator-project.md` with Pi prompt frontmatter and instructions to inspect the repository, ask the same unresolved choices, update only the managed block/docs, and preserve user content. It must not install packages or skills.

- [ ] **Step 6: Run tests and verify GREEN**

```bash
bash tests/setup_test.sh
```

Expected: all setup tests pass.

- [ ] **Step 7: Commit project initialization**

```bash
git add setup.sh prompts/init-orchestrator-project.md tests/setup_test.sh
git commit -m "feat: initialize project workflow docs"
```

---

### Task 4: Package the orchestration skill and evaluations

**Files:**
- Create: `skills/orchestrate-implementation/SKILL.md`
- Create: `skills/orchestrate-implementation/evals/evals.json`
- Create: `skills/orchestrate-implementation/evals/fixtures/feature-plan.md`
- Create: `skills/orchestrate-implementation/evals/fixtures/conflicting-inputs.md`

**Interfaces:**
- Consumes: the verified machine-global skill at `~/.agents/skills/orchestrate-implementation/`.
- Produces: the canonical publishable skill source.

- [ ] **Step 1: Copy the verified skill source**

```bash
mkdir -p skills/orchestrate-implementation/evals/fixtures
cp ~/.agents/skills/orchestrate-implementation/SKILL.md skills/orchestrate-implementation/SKILL.md
cp ~/.agents/skills/orchestrate-implementation/evals/evals.json skills/orchestrate-implementation/evals/evals.json
cp ~/.agents/skills/orchestrate-implementation/evals/fixtures/*.md skills/orchestrate-implementation/evals/fixtures/
```

- [ ] **Step 2: Validate skill structure and TDD contract**

```bash
uv run --with pyyaml ~/.agents/skills/skill-creator/scripts/quick_validate.py skills/orchestrate-implementation
python - <<'PY'
from pathlib import Path
s = Path('skills/orchestrate-implementation/SKILL.md').read_text().lower()
for required in ('skill: "tdd"', 'failing test', 'red-green-refactor', 'tdd evidence'):
    assert required in s, required
print('skill contract valid')
PY
```

Expected: both commands exit `0`.

- [ ] **Step 3: Commit the packaged skill**

```bash
git add skills/orchestrate-implementation
git commit -m "feat: package orchestration skill"
```

---

### Task 5: Add README, license, and CI

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `.github/workflows/test.yml`

**Interfaces:**
- Consumes: implemented CLI and approved design.
- Produces: public usage documentation and continuous verification.

- [ ] **Step 1: Write the concise comprehensive README**

Cover, in this order:

1. purpose and architecture;
2. prerequisites (`pi`, Git, Node/npx, GitHub CLI only for GitHub tracker use);
3. clone and quick-start commands;
4. exact selected skill tables for `matt`, `superpowers`, and `both`;
5. explicit exclusions;
6. Superpowers, Matt, and mixed planning workflows;
7. ticket/plan source-reference behavior;
8. project documentation map and precedence;
9. `plan-only`, `supervised`, and `autonomous` modes;
10. TDD worker and independent reviewer contracts;
11. Herdr: persistent peers in tabs, native workers headless with optional inspectors;
12. dry-run, rerun/update, uninstall, troubleshooting, and limitations;
13. attribution to `obra/superpowers`, `mattpocock/skills`, and `vercel-labs/skills` with links and license notes.

Use the published installation command:

```bash
git clone https://github.com/legout/pi-implementation-orchestrator.git
cd pi-implementation-orchestrator
./setup.sh --planning both --project /path/to/repo
```

- [ ] **Step 2: Add MIT license**

Create `LICENSE` with the standard MIT text, copyright `2026 Volker`.

- [ ] **Step 3: Add GitHub Actions**

Create `.github/workflows/test.yml`:

```yaml
name: test
on: [push, pull_request]
jobs:
  setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash -n setup.sh tests/setup_test.sh
      - run: bash tests/setup_test.sh
```

- [ ] **Step 4: Run documentation and test checks**

```bash
bash -n setup.sh tests/setup_test.sh
bash tests/setup_test.sh
git diff --check
```

Expected: all exit `0` with no warnings.

- [ ] **Step 5: Commit documentation and CI**

```bash
git add README.md LICENSE .github/workflows/test.yml
git commit -m "docs: add usage and CI"
```

---

### Task 6: Review and publish

**Files:**
- Review: all files changed since `2ca528b`
- Create remotely: `github.com/legout/pi-implementation-orchestrator`

**Interfaces:**
- Consumes: tested local `main` branch.
- Produces: public GitHub repository and verified clone/install instructions.

- [ ] **Step 1: Run full local verification**

```bash
bash -n setup.sh tests/setup_test.sh
bash tests/setup_test.sh
uv run --with pyyaml ~/.agents/skills/skill-creator/scripts/quick_validate.py skills/orchestrate-implementation
git diff --check 2ca528b..HEAD
git status --short
```

Expected: commands pass and worktree is clean.

- [ ] **Step 2: Request independent review**

Dispatch a fresh read-only reviewer against `git diff 2ca528b..HEAD`, `docs/design.md`, and this plan. Fix every blocking finding with TDD and rerun affected checks; obtain a clean re-review.

- [ ] **Step 3: Create and push the public repository**

```bash
gh repo create legout/pi-implementation-orchestrator \
  --public --source=. --remote=origin --push \
  --description "Plan with Superpowers or Matt Pocock skills; execute with isolated Pi workers and reviewers."
```

Expected: repository creation and initial push succeed.

- [ ] **Step 4: Verify publication**

```bash
gh repo view legout/pi-implementation-orchestrator --json url,visibility,defaultBranchRef \
  --jq '{url, visibility, defaultBranch: .defaultBranchRef.name}'
git remote -v
git status --short --branch
```

Expected: URL is `https://github.com/legout/pi-implementation-orchestrator`, visibility is `PUBLIC`, default branch is `main`, and local branch tracks `origin/main` cleanly.
