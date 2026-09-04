#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
NODE=$(command -v node || true)
TMP=

cleanup() { test -z "${TMP:-}" || rm -rf "$TMP"; }
trap cleanup EXIT

new_case() {
  cleanup
  TMP=$(mktemp -d "${TMPDIR:-/tmp}/pi-orchestrator-test.XXXXXXXX")
  mkdir -p "$TMP/home" "$TMP/bin" "$TMP/project"
  export HOME="$TMP/home"
  export PATH="$TMP/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  : >"$TMP/calls"
}

stub_commands() {
  cat >"$TMP/bin/pi" <<'STUB'
#!/usr/bin/env bash
printf 'pi %s\n' "$*" >> "$TEST_CALLS"
STUB
  cat >"$TMP/bin/npx" <<'STUB'
#!/usr/bin/env bash
printf 'npx %s\n' "$*" >> "$TEST_CALLS"
STUB
  chmod +x "$TMP/bin/pi" "$TMP/bin/npx"
  export TEST_CALLS="$TMP/calls"
}

assert_contains() { grep -F -- "$2" "$1" >/dev/null || {
  echo "missing: $2"
  exit 1
}; }
assert_not_contains() { ! grep -F -- "$2" "$1" >/dev/null || {
  echo "unexpected: $2"
  exit 1
}; }
assert_eq() { test "$1" = "$2" || {
  echo "expected [$2], got [$1]"
  exit 1
}; }

test_matt_profile() {
  new_case
  stub_commands
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
  new_case
  stub_commands
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
  new_case
  stub_commands
  "$ROOT/setup.sh" --planning both --skip-project --yes
  assert_contains "$TEST_CALLS" "obra/superpowers"
  assert_contains "$TEST_CALLS" "mattpocock/skills"
  assert_eq "$(grep -o -- '--skill tdd' "$TEST_CALLS" | wc -l | tr -d ' ')" "1"
}

test_rejects_bad_args() {
  new_case
  stub_commands
  if "$ROOT/setup.sh" --planning nope --skip-project >/dev/null 2>&1; then
    echo "invalid planning accepted"
    exit 1
  fi
  if "$ROOT/setup.sh" --bogus --skip-project >/dev/null 2>&1; then
    echo "unknown flag accepted"
    exit 1
  fi
  if "$ROOT/setup.sh" --planning matt >/dev/null 2>&1; then
    echo "missing project target accepted"
    exit 1
  fi
  if "$ROOT/setup.sh" --planning matt --project "$TMP/project" --skip-project >/dev/null 2>&1; then
    echo "both targets accepted"
    exit 1
  fi
  if "$ROOT/setup.sh" --planning matt --skip-project --instruction-file nope.md >/dev/null 2>&1; then
    echo "invalid instruction-file accepted"
    exit 1
  fi
  if "$ROOT/setup.sh" --planning matt --skip-project --tracker bogus >/dev/null 2>&1; then
    echo "invalid tracker accepted"
    exit 1
  fi
  if "$ROOT/setup.sh" --planning matt --skip-project --tracker other >/dev/null 2>&1; then
    echo "tracker other without description accepted"
    exit 1
  fi
  if "$ROOT/setup.sh" --planning matt --skip-project --tracker other --tracker-description "  " >/dev/null 2>&1; then
    echo "blank tracker description accepted"
    exit 1
  fi
  if "$ROOT/setup.sh" --planning matt --skip-project --domain-layout monorepo >/dev/null 2>&1; then
    echo "invalid domain-layout accepted"
    exit 1
  fi
}

test_installs_pi_packages_and_repo_skill() {
  new_case
  stub_commands
  "$ROOT/setup.sh" --planning matt --skip-project --yes
  assert_contains "$TEST_CALLS" "pi install npm:pi-subagents"
  assert_contains "$TEST_CALLS" "pi install npm:pi-intercom"
  assert_contains "$TEST_CALLS" "--skill orchestrate-implementation"
  assert_contains "$TEST_CALLS" "--global --agent pi --yes --copy"
}

test_dry_run_writes_nothing() {
  new_case
  stub_commands
  mkdir "$TMP/ro-tmp"
  chmod 500 "$TMP/ro-tmp"
  before=$(find "$TMP" -type f | sort | xargs shasum)
  if ! printf '1\n1\ny\n' | TMPDIR="$TMP/ro-tmp" "$ROOT/setup.sh" --planning matt --project "$TMP/project" --dry-run >/dev/null 2>&1; then
    echo "dry-run attempted a filesystem write (read-only TMPDIR made it fail)"
    exit 1
  fi
  after=$(find "$TMP" -type f | sort | xargs shasum)
  assert_eq "$after" "$before"
  assert_eq "$(wc -c <"$TEST_CALLS" | tr -d ' ')" "0"
  test -z "$(find "$TMP/ro-tmp" -mindepth 1 -print -quit)"
}

test_initializes_agents_docs() {
  new_case
  stub_commands
  git -C "$TMP/project" init -q
  printf '1\n2\ny\n' | "$ROOT/setup.sh" --planning matt --project "$TMP/project"
  test -f "$TMP/project/AGENTS.md"
  test -f "$TMP/project/docs/agents/issue-tracker.md"
  test -f "$TMP/project/docs/agents/domain.md"
  assert_contains "$TMP/project/AGENTS.md" "pi-implementation-orchestrator:start"
  assert_contains "$TMP/project/AGENTS.md" "TDD"
  assert_contains "$TMP/project/AGENTS.md" "orchestrator-owned"
}

test_declined_confirmation_writes_nothing() {
  new_case
  stub_commands
  printf '1\n1\nn\n' | "$ROOT/setup.sh" --planning matt --project "$TMP/project"
  test ! -e "$TMP/project/AGENTS.md"
  test ! -e "$TMP/project/docs/agents/issue-tracker.md"
}

test_rerun_is_idempotent() {
  new_case
  stub_commands
  printf '1\n1\ny\n' | "$ROOT/setup.sh" --planning matt --project "$TMP/project" --yes
  printf 'y\n' | "$ROOT/setup.sh" --planning matt --project "$TMP/project" --yes
  assert_eq "$(grep -c 'pi-implementation-orchestrator:start' "$TMP/project/AGENTS.md" | tr -d ' ')" "1"
}

test_preserves_surrounding_text() {
  new_case
  stub_commands
  cat >"$TMP/project/AGENTS.md" <<'EOF'
# Project rules

Keep functions small.

<!-- pi-implementation-orchestrator:start -->
<!-- pi-implementation-orchestrator:end -->

Never commit secrets.
EOF
  printf '1\ny\n' | "$ROOT/setup.sh" --planning matt --project "$TMP/project" --yes
  assert_contains "$TMP/project/AGENTS.md" "# Project rules"
  assert_contains "$TMP/project/AGENTS.md" "Keep functions small."
  assert_contains "$TMP/project/AGENTS.md" "Never commit secrets."
  assert_eq "$(grep -c 'pi-implementation-orchestrator:start' "$TMP/project/AGENTS.md" | tr -d ' ')" "1"
}

test_ambiguous_block_fails() {
  new_case
  stub_commands
  cat >"$TMP/project/AGENTS.md" <<'EOF'
<!-- pi-implementation-orchestrator:start -->
one
<!-- pi-implementation-orchestrator:start -->
two
<!-- pi-implementation-orchestrator:end -->
EOF
  if printf 'y\n' | "$ROOT/setup.sh" --planning matt --project "$TMP/project" --yes >/dev/null 2>&1; then
    echo "duplicate markers accepted"
    exit 1
  fi
  assert_eq "$(grep -c 'pi-implementation-orchestrator:start' "$TMP/project/AGENTS.md" | tr -d ' ')" "2"
}

test_reversed_markers_fail_unchanged() {
  new_case
  stub_commands
  {
    printf '%s\n' '<!-- pi-implementation-orchestrator:end -->'
    printf 'stray content\n'
    printf '%s\n' '<!-- pi-implementation-orchestrator:start -->'
  } >"$TMP/project/AGENTS.md"
  before=$(shasum <"$TMP/project/AGENTS.md")
  if printf '1\ny\n' | "$ROOT/setup.sh" --planning matt --project "$TMP/project" --yes >/dev/null 2>&1; then
    echo "reversed markers accepted"
    exit 1
  fi
  after=$(shasum <"$TMP/project/AGENTS.md")
  assert_eq "$after" "$before"
}

test_replacement_preserves_bytes() {
  new_case
  stub_commands
  {
    printf '# Header\n\n'
    printf '%s\n' '<!-- pi-implementation-orchestrator:start -->'
    printf 'old block line\n'
    printf '%s\n' '<!-- pi-implementation-orchestrator:end -->'
    printf 'suffix without final newline'
  } >"$TMP/project/AGENTS.md"
  printf '1\ny\n' | "$ROOT/setup.sh" --planning matt --project "$TMP/project" --yes >/dev/null
  {
    printf '# Header\n\n'
    printf '%s\n' '<!-- pi-implementation-orchestrator:start -->'
    cat <<'BLOCK'
## Agent workflow

- Every task declares one test obligation: `new-test`, `existing-check`, or `no-new-test`; focused TDD is required only for `new-test` work.
- Review is adaptive and orchestrator-owned: high-risk or dependency-defining changes are reviewed immediately; low-risk changes may be reviewed cumulatively at a wave boundary.
- Plans and tickets reference exact feature sources; this file defines stable repository-wide scope.
- Source precedence: current owner decision → accepted ADR → approved specification → implementation plan → ticket → existing implementation.
- Stop before implementation when authoritative sources conflict.

### Documentation map

- `CONTEXT.md`: canonical domain vocabulary.
- `docs/adr/`: accepted architecture decisions.
- `docs/agents/`: workflow and tracker configuration.
- `docs/specs/` or configured tracker: feature behavior and acceptance.
- implementation plans/tickets: execution entry points and explicit source references.
BLOCK
    printf '%s\n' '<!-- pi-implementation-orchestrator:end -->'
    printf 'suffix without final newline'
  } >"$TMP/expected"
  cmp "$TMP/expected" "$TMP/project/AGENTS.md"
}

test_adaptive_review_and_test_policy() {
  local skill="$ROOT/skills/orchestrate-implementation/SKILL.md"
  for term in new-test existing-check no-new-test adaptive lastReviewedSha; do
    assert_contains "$skill" "$term"
  done
  assert_contains "$skill" '## Test obligations'
  assert_contains "$skill" '## Review policy'
  assert_contains "$ROOT/README.md" 'Focused TDD is required only for `new-test` work'
  assert_contains "$ROOT/README.md" 'low-risk changes may be batch-reviewed'
  assert_contains "$ROOT/README.md" 'high-risk changes are reviewed immediately'
  new_case
  stub_commands
  printf '1\n1\ny\n' | "$ROOT/setup.sh" --planning matt --project "$TMP/project" >/dev/null
  assert_contains "$TMP/project/AGENTS.md" 'Every task declares one test obligation: `new-test`, `existing-check`, or `no-new-test`; focused TDD is required only for `new-test` work.'
  assert_contains "$TMP/project/AGENTS.md" 'Review is adaptive and orchestrator-owned: high-risk or dependency-defining changes are reviewed immediately; low-risk changes may be reviewed cumulatively at a wave boundary.'
}

test_missing_project_dir_fails() {
  new_case
  stub_commands
  if "$ROOT/setup.sh" --planning matt --project "$TMP/nope" >/dev/null 2>&1; then
    echo "missing project accepted"
    exit 1
  fi
}

test_skill_recovery_contract() {
  local skill="$ROOT/skills/orchestrate-implementation/SKILL.md"
  assert_contains "$skill" "when its managed worktree still exists and the child is resumable"
  assert_contains "$skill" "fresh fix worker in a new managed worktree from the exact original base"
  assert_contains "$skill" "apply the durable prior handoff patch"
  assert_contains "$skill" "durable handoff patch paths"
  assert_contains "$ROOT/README.md" "durable handoff patch paths"
}

test_pi_package_manifest() {
  [ -n "$NODE" ] || {
    echo "node not available"
    exit 1
  }
  "$NODE" -e '
    const p = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const fail = (m) => { console.error(m); process.exit(1); };
    if (p.name !== "pi-implementation-orchestrator") fail("bad name: " + p.name);
    if (!Array.isArray(p.keywords) || !p.keywords.includes("pi-package")) fail("missing pi-package keyword");
    if (!p.pi || !Array.isArray(p.pi.skills) || !p.pi.skills.includes("./skills")) fail("pi.skills missing ./skills");
    if (!Array.isArray(p.pi.prompts) || !p.pi.prompts.includes("./prompts")) fail("p.pi.prompts missing ./prompts");
  ' "$ROOT/package.json"
}

test_setup_skill_contract() {
  local skill="$ROOT/skills/setup-implementation-orchestrator/SKILL.md"
  test -f "$skill" || {
    echo "missing skill: $skill"
    exit 1
  }
  local frontmatter
  frontmatter=$(awk 'NR == 1 && $0 == "---" { started = 1; next } started && $0 == "---" { found = 1; exit } started { print } END { if (!found) exit 1 }' "$skill")
  printf '%s\n' "$frontmatter" | grep -Fqx -- 'name: setup-implementation-orchestrator'
  printf '%s\n' "$frontmatter" | grep -Fqx -- 'disable-model-invocation: true'
  printf '%s\n' "$frontmatter" | grep -F -- 'description:' >/dev/null
  assert_contains "$skill" "disable-model-invocation: true"
  assert_contains "$skill" "../../setup.sh"
  assert_contains "$skill" "--instruction-file"
  assert_contains "$skill" "--tracker"
  assert_contains "$skill" "--domain-layout"
  assert_contains "$skill" "approval"
  assert_contains "$skill" "new-project setup"
  assert_contains "$skill" "reconfiguration of an existing project"
  assert_contains "$skill" "same skill again"
  local dry_line yes_line
  dry_line=$(grep -n -m1 -F -- '--dry-run' "$skill" | cut -d: -f1)
  yes_line=$(grep -n -m1 -F -- '--yes' "$skill" | cut -d: -f1)
  if [ -z "$dry_line" ] || [ -z "$yes_line" ] || [ "$dry_line" -ge "$yes_line" ]; then
    echo "skill must require --dry-run before the --yes mutation"
    exit 1
  fi
}

test_single_setup_entrypoint() {
  local prompt="$ROOT/prompts/setup-implementation-orchestrator.md"
  test -f "$prompt"
  assert_contains "$prompt" "skill: setup-implementation-orchestrator"
  assert_contains "$prompt" '$@'
  test ! -e "$ROOT/prompts/init-orchestrator-project.md"
  assert_not_contains "$ROOT/README.md" "prompts/init-orchestrator-project.md"
  assert_not_contains "$ROOT/docs/design.md" "## Init Prompt"
}

test_noninteractive_project_choices() {
  new_case
  stub_commands
  git -C "$TMP/project" init -q
  git -C "$TMP/project" remote add origin https://github.com/example/repo.git
  printf '# claude\n' >"$TMP/project/CLAUDE.md"
  printf '# agents\n' >"$TMP/project/AGENTS.md"
  printf 'packages:\n  - a\n' >"$TMP/project/pnpm-workspace.yaml"
  "$ROOT/setup.sh" --planning matt --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout multi \
    </dev/null >/dev/null 2>&1
  assert_contains "$TMP/project/AGENTS.md" "pi-implementation-orchestrator:start"
  assert_eq "$(cat "$TMP/project/CLAUDE.md")" "# claude"
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Tracker: Local Markdown."
  assert_contains "$TMP/project/docs/agents/domain.md" "Layout: multiple contexts."

  new_case
  stub_commands
  printf '# claude\n' >"$TMP/project/CLAUDE.md"
  "$ROOT/setup.sh" --planning matt --project "$TMP/project" --yes \
    --instruction-file CLAUDE.md --tracker github --domain-layout single \
    </dev/null >/dev/null 2>&1
  assert_contains "$TMP/project/CLAUDE.md" "pi-implementation-orchestrator:start"
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Tracker: GitHub Issues."
  assert_contains "$TMP/project/docs/agents/domain.md" "Layout: single context."

  new_case
  stub_commands
  "$ROOT/setup.sh" --planning matt --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker other --tracker-description "Linear board" --domain-layout single \
    </dev/null >/dev/null 2>&1
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Tracker: Linear board."
}

main() {
  local failed=0
  for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
    if "$t"; then echo "ok: $t"; else
      echo "FAIL: $t"
      failed=1
    fi
  done
  if [ "$failed" != 0 ]; then
    echo "tests failed" >&2
    exit 1
  fi
  echo "all tests passed"
}

main "$@"
