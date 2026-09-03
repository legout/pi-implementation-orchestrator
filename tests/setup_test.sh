#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
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
BLOCK
    printf '%s\n' '<!-- pi-implementation-orchestrator:end -->'
    printf 'suffix without final newline'
  } >"$TMP/expected"
  cmp "$TMP/expected" "$TMP/project/AGENTS.md"
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

main() {
  local failed=0
  for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
    if "$t"; then echo "ok: $t"; else
      echo "FAIL: $t"
      failed=1
    fi
  done
  if [ "$failed" != "0" ]; then
    echo "tests failed" >&2
    exit 1
  fi
  echo "all tests passed"
}

main "$@"
