#!/usr/bin/env bash
# Test suite for setup.sh.
#
# Every test case runs in a genuinely independent shell process (`bash "$0"
# --case NAME`), so a failing assertion aborts the case immediately and cannot
# be masked by a later successful command. Assertion helpers additionally
# report explicit messages. tests/setup_runner_test.sh mutation-probes this
# runner to keep it honest.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
NODE=$(command -v node || true)
CASE=runner
TMP=
TEST_CALLS=
TEST_DIR=
START_MARKER='<!-- pi-implementation-orchestrator:start -->'
END_MARKER='<!-- pi-implementation-orchestrator:end -->'
SKILLS=(research shape-design grilling domain-modeling write-implementation-plan prototype-question verification-before-completion systematic-debugging orchestrate-implementation merge-worktree make-release planning-contract)

cleanup() { test -z "${TMP:-}" || rm -rf "$TMP"; }
trap cleanup EXIT

fail() {
  echo "FAIL($CASE): $*" >&2
  exit 1
}

new_case() {
  cleanup
  TMP=$(mktemp -d "${TMPDIR:-/tmp}/pi-orchestrator-test.XXXXXXXX")
  TMP=$(cd "$TMP" && pwd)
  mkdir -p "$TMP/home" "$TMP/bin" "$TMP/project"
  export HOME="$TMP/home"
  export PATH="$TMP/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  : >"$TMP/calls"
}

stub_commands() {
  cat >"$TMP/bin/pi" <<'STUB'
#!/usr/bin/env bash
name=${0##*/}
printf '%s %s @ %s\n' "$name" "$*" "$(pwd)" >> "$TEST_CALLS"
if [ -n "${TEST_FAIL_PROG:-}" ] && [ "${TEST_FAIL_PROG}" = "$name" ]; then
  count_file="$TEST_DIR/fail-$name"
  n=$(( $(cat "$count_file" 2>/dev/null || echo 0) + 1 ))
  echo "$n" >"$count_file"
  if [ "$n" -ge "${TEST_FAIL_AT:-1}" ]; then
    echo "$name stub: simulated failure" >&2
    exit 1
  fi
fi
if [ -n "${TEST_SABOTAGE:-}" ] && [ "$name" = npx ]; then
  case "$TEST_SABOTAGE" in
  make-agents-dir) rm -rf "$TEST_PROJECT/AGENTS.md"; mkdir -p "$TEST_PROJECT/AGENTS.md" ;;
  make-domain-dir) rm -rf "$TEST_PROJECT/docs/agents/domain.md"; mkdir -p "$TEST_PROJECT/docs/agents/domain.md" ;;
  make-artifacts-dir) rm -rf "$TEST_PROJECT/docs/agents/artifacts.md"; mkdir -p "$TEST_PROJECT/docs/agents/artifacts.md" ;;
  append-agents) printf 'concurrent edit\n' >> "$TEST_PROJECT/AGENTS.md" ;;
  same-size-agents)
    cp "$TEST_PROJECT/AGENTS.md" "$TEST_DIR/agents-reference"
    size=$(wc -c <"$TEST_PROJECT/AGENTS.md" | tr -d ' ')
    printf '%*s' "$size" '' | tr ' ' x >"$TEST_PROJECT/AGENTS.md"
    touch -r "$TEST_DIR/agents-reference" "$TEST_PROJECT/AGENTS.md"
    ;;
  replace-docs-link)
    mkdir -p "$TEST_DIR/outside/agents"
    rm -rf "$TEST_PROJECT/docs"
    ln -s "$TEST_DIR/outside" "$TEST_PROJECT/docs"
    ;;
  esac
fi
exit 0
STUB
  cp "$TMP/bin/pi" "$TMP/bin/npx"
  cat >"$TMP/bin/node" <<'STUB'
#!/usr/bin/env bash
# Node is a documented npx prerequisite.
exit 0
STUB
  chmod +x "$TMP/bin/pi" "$TMP/bin/npx" "$TMP/bin/node"
  export TEST_CALLS="$TMP/calls"
  export TEST_DIR="$TMP"
}

gnu_stat_stub() {
  cat >"$TMP/bin/stat" <<'STUB'
#!/usr/bin/env bash
case "$1:$2" in
-c:%a) printf '640\n' ;;
-c:%s:%Y) printf '1:1\n' ;;
-f:%Lp|-f:%z:%m) printf 'File: fake\nFilesystem: fake\n' ;;
*) exit 1 ;;
esac
STUB
  chmod +x "$TMP/bin/stat"
}

assert_contains() { grep -F -- "$2" "$1" >/dev/null || fail "missing in $(basename "$1"): $2"; }
assert_not_contains() { ! grep -F -- "$2" "$1" >/dev/null || fail "unexpected in $(basename "$1"): $2"; }
assert_eq() { test "$1" = "$2" || fail "expected [$2], got [$1]"; }
assert_file() { test -f "$1" || fail "expected file: $1"; }
assert_no_file() { test ! -e "$1" || fail "unexpected path: $1"; }
assert_calls_empty() { test ! -s "$TEST_CALLS" || fail "expected zero external calls, got: $(cat "$TEST_CALLS")"; }

mode_of() {
  local m
  m=$(stat -c %a "$1" 2>/dev/null || true)
  case "$m" in
  '' | *[!0-7]*) m=$(stat -f %Lp "$1" 2>/dev/null || true) ;;
  esac
  printf '%s\n' "$m"
}

assert_global_calls() {
  # exact external-call contract for global scope, run from cwd "$1"
  local expected="$TMP/expected-calls"
  local cwd
  cwd=$(cd "$1" && pwd)
  {
    printf 'npx skills add legout/skills'
    local s
    for s in ${SKILLS[@]+"${SKILLS[@]}"}; do printf ' --skill %s' "$s"; done
    printf ' --global --agent pi --yes --copy @ %s\n' "$cwd"
    printf 'pi install npm:pi-subagents @ %s\n' "$cwd"
    printf 'pi install npm:pi-intercom @ %s\n' "$cwd"
  } >"$expected"
  cmp -s "$expected" "$TEST_CALLS" || fail "unexpected external call log:
$(cat "$TEST_CALLS")
expected:
$(cat "$expected")"
}

assert_project_calls() {
  # exact external-call contract for project scope "$1"
  local expected="$TMP/expected-calls"
  local cwd
  cwd=$(cd "$1" && pwd -P)
  {
    printf 'npx skills add legout/skills'
    local s
    for s in ${SKILLS[@]+"${SKILLS[@]}"}; do printf ' --skill %s' "$s"; done
    printf ' --agent pi --yes --copy @ %s\n' "$cwd"
    printf 'pi install --local npm:pi-subagents @ %s\n' "$cwd"
    printf 'pi install --local npm:pi-intercom @ %s\n' "$cwd"
  } >"$expected"
  cmp -s "$expected" "$TEST_CALLS" || fail "unexpected external call log:
$(cat "$TEST_CALLS")
expected:
$(cat "$expected")"
}

extract_block() {
  sed -n "/^${START_MARKER}\$/,/^${END_MARKER}\$/p" "$1"
}

tree_hash() {
  (
    cd "$1" &&
      find . \( -type f -o -type l \) -print |
      LC_ALL=C sort |
        while IFS= read -r p; do
          if [ -L "$p" ]; then
            printf 'L %s -> %s\n' "$p" "$(readlink "$p")"
          else
            printf 'F %s %s\n' "$p" "$(shasum <"$p" | cut -d' ' -f1)"
          fi
        done | shasum
  )
}

skip_if_root() { [ "$(id -u)" != 0 ] || {
  echo "skip: needs non-root"
  exit 0
}; }

# ---------------------------------------------------------------- test cases

test_legout_stack() {
  new_case
  stub_commands
  (cd "$TMP" && "$ROOT/setup.sh" --skip-project --yes) >/dev/null 2>&1
  assert_global_calls "$TMP"
  # exactly twelve skills, one skills-install invocation, no unrelated commands
  assert_eq "$(grep -c 'skills add' "$TEST_CALLS" | tr -d ' ')" "1"
  assert_eq "$(grep -o -- '--skill [a-z-]*' "$TEST_CALLS" | wc -l | tr -d ' ')" "12"
  assert_contains "$TEST_CALLS" "--skill planning-contract"
  assert_not_contains "$TEST_CALLS" "mattpocock/skills"
  assert_not_contains "$TEST_CALLS" "obra/superpowers"
  assert_not_contains "$TEST_CALLS" "skills add $ROOT"
}

test_rejects_planning_flag() {
  new_case
  stub_commands
  if "$ROOT/setup.sh" --planning matt --skip-project --yes >/dev/null 2>&1; then
    fail "removed --planning flag accepted"
  fi
  assert_calls_empty
}

test_rejects_bad_args() {
  new_case
  stub_commands
  if "$ROOT/setup.sh" --bogus --skip-project >/dev/null 2>&1; then fail "unknown flag accepted"; fi
  if "$ROOT/setup.sh" >/dev/null 2>&1; then fail "missing project target accepted"; fi
  if "$ROOT/setup.sh" --project "$TMP/project" --skip-project >/dev/null 2>&1; then fail "both targets accepted"; fi
  if "$ROOT/setup.sh" --skip-project --instruction-file nope.md >/dev/null 2>&1; then fail "invalid instruction-file accepted"; fi
  if "$ROOT/setup.sh" --skip-project --tracker bogus >/dev/null 2>&1; then fail "invalid tracker accepted"; fi
  if "$ROOT/setup.sh" --skip-project --tracker other >/dev/null 2>&1; then fail "tracker other without description accepted"; fi
  if "$ROOT/setup.sh" --skip-project --tracker other --tracker-description "  " >/dev/null 2>&1; then fail "blank tracker description accepted"; fi
  if "$ROOT/setup.sh" --skip-project --skill-scope bogus >/dev/null 2>&1; then fail "invalid skill-scope accepted"; fi
  if "$ROOT/setup.sh" --skip-project --skill-scope project >/dev/null 2>&1; then fail "project scope with skip-project accepted"; fi
  if "$ROOT/setup.sh" --skip-project --domain-layout monorepo >/dev/null 2>&1; then fail "invalid domain-layout accepted"; fi
  # missing flag operands
  if "$ROOT/setup.sh" --project >/dev/null 2>&1; then fail "missing --project operand accepted"; fi
  if "$ROOT/setup.sh" --instruction-file >/dev/null 2>&1; then fail "missing --instruction-file operand accepted"; fi
  if "$ROOT/setup.sh" --tracker >/dev/null 2>&1; then fail "missing --tracker operand accepted"; fi
  if "$ROOT/setup.sh" --tracker-description >/dev/null 2>&1; then fail "missing --tracker-description operand accepted"; fi
  if "$ROOT/setup.sh" --domain-layout >/dev/null 2>&1; then fail "missing --domain-layout operand accepted"; fi
  if "$ROOT/setup.sh" --skill-scope >/dev/null 2>&1; then fail "missing --skill-scope operand accepted"; fi
  # --inspect mode incompatibilities
  if "$ROOT/setup.sh" --skip-project --inspect --dry-run >/dev/null 2>&1; then fail "--inspect with --dry-run accepted"; fi
  if "$ROOT/setup.sh" --skip-project --inspect --yes >/dev/null 2>&1; then fail "--inspect with --yes accepted"; fi
  assert_calls_empty
}

test_declined_skip_project_installs_nothing() {
  new_case
  stub_commands
  printf 'n\n' | "$ROOT/setup.sh" --skip-project >/dev/null 2>&1
  assert_calls_empty
}

test_eof_before_approval_installs_nothing() {
  new_case
  stub_commands
  if "$ROOT/setup.sh" --skip-project </dev/null >/dev/null 2>&1; then
    fail "EOF at approval exited zero"
  fi
  assert_calls_empty
}

test_installs_pi_packages_and_external_skills() {
  new_case
  stub_commands
  (cd "$TMP" && "$ROOT/setup.sh" --skip-project --yes) >/dev/null 2>&1
  assert_contains "$TEST_CALLS" "pi install npm:pi-subagents"
  assert_contains "$TEST_CALLS" "pi install npm:pi-intercom"
  assert_not_contains "$TEST_CALLS" "skills add $ROOT"
}

test_dry_run_writes_nothing() {
  new_case
  stub_commands
  mkdir "$TMP/ro-tmp"
  chmod 500 "$TMP/ro-tmp"
  before=$(find "$TMP" -type f | sort | xargs shasum)
  out=$(printf '1\n1\n1\ny\n' | TMPDIR="$TMP/ro-tmp" "$ROOT/setup.sh" --project "$TMP/project" --dry-run 2>&1) ||
    fail "dry-run attempted a filesystem write (read-only TMPDIR made it fail)"
  after=$(find "$TMP" -type f | sort | xargs shasum)
  assert_eq "$after" "$before"
  assert_eq "$(wc -c <"$TEST_CALLS" | tr -d ' ')" "0"
  test -z "$(find "$TMP/ro-tmp" -mindepth 1 -print -quit)"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "+ npx skills add legout/skills --skill research"
  assert_contains "$TMP/out" "+ pi install npm:pi-subagents"
  assert_contains "$TMP/out" "docs/agents/issue-tracker.md"
  assert_contains "$TMP/out" "Dry run: nothing was installed, executed, or written."
  assert_contains "$TMP/out" "Prerequisites: git ok, npx ok, pi ok, node ok."
}

test_dry_run_reports_missing_prereqs() {
  new_case
  # no pi/npx stubs: only core utilities on PATH
  out=$("$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) || fail "dry-run with missing prerequisites failed"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "Prerequisites: MISSING:"
  assert_contains "$TMP/out" "npx"
  assert_contains "$TMP/out" "pi"
  assert_no_file "$TMP/project/AGENTS.md"
}

test_apply_missing_prereqs_fails_before_changes() {
  new_case
  if "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "apply with missing prerequisites exited zero"
  fi
  assert_no_file "$TMP/project/AGENTS.md"
  assert_no_file "$TMP/project/docs"
}

test_initializes_agents_docs() {
  new_case
  stub_commands
  git -C "$TMP/project" init -q
  printf '1\n1\n1\ny\n' | "$ROOT/setup.sh" --project "$TMP/project" >/dev/null 2>&1
  assert_file "$TMP/project/AGENTS.md"
  assert_file "$TMP/project/docs/agents/issue-tracker.md"
  assert_file "$TMP/project/docs/agents/domain.md"
  assert_file "$TMP/project/docs/agents/artifacts.md"
  assert_contains "$TMP/project/AGENTS.md" "pi-implementation-orchestrator:start"
  assert_contains "$TMP/project/AGENTS.md" "TDD"
  assert_contains "$TMP/project/AGENTS.md" "orchestrator-owned"
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Tracker: Local Markdown."
  assert_contains "$TMP/project/docs/agents/domain.md" "Layout: single context."
  assert_contains "$TMP/project/docs/agents/artifacts.md" "# Artifact mapping"
}

test_declined_confirmation_writes_nothing() {
  new_case
  stub_commands
  printf '1\n1\n1\nn\n' | "$ROOT/setup.sh" --project "$TMP/project" >/dev/null 2>&1
  assert_no_file "$TMP/project/AGENTS.md"
  assert_no_file "$TMP/project/docs/agents/issue-tracker.md"
  assert_calls_empty
}

test_eof_fails_closed_with_zero_calls() {
  new_case
  stub_commands
  if "$ROOT/setup.sh" --project "$TMP/project" </dev/null >/dev/null 2>&1; then
    fail "EOF during choice questions exited zero"
  fi
  assert_calls_empty
  assert_no_file "$TMP/project/AGENTS.md"
  assert_no_file "$TMP/project/docs"

  new_case
  stub_commands
  if "$ROOT/setup.sh" --project "$TMP/project" \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "EOF at approval exited zero"
  fi
  assert_calls_empty
  assert_no_file "$TMP/project/AGENTS.md"
}

test_rerun_is_idempotent() {
  new_case
  stub_commands
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  cp "$TMP/project/AGENTS.md" "$TMP/agents-1"
  cp "$TMP/project/docs/agents/issue-tracker.md" "$TMP/tracker-1"
  cp "$TMP/project/docs/agents/domain.md" "$TMP/domain-1"
  cp "$TMP/project/docs/agents/artifacts.md" "$TMP/artifacts-1"
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  cmp -s "$TMP/agents-1" "$TMP/project/AGENTS.md" || fail "rerun changed AGENTS.md"
  cmp -s "$TMP/tracker-1" "$TMP/project/docs/agents/issue-tracker.md" || fail "rerun changed tracker doc"
  cmp -s "$TMP/domain-1" "$TMP/project/docs/agents/domain.md" || fail "rerun changed domain doc"
  cmp -s "$TMP/artifacts-1" "$TMP/project/docs/agents/artifacts.md" || fail "rerun changed artifact-map doc"
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
  printf '1\n1\n' | "$ROOT/setup.sh" --project "$TMP/project" --yes >/dev/null 2>&1
  assert_contains "$TMP/project/AGENTS.md" "# Project rules"
  assert_contains "$TMP/project/AGENTS.md" "Keep functions small."
  assert_contains "$TMP/project/AGENTS.md" "Never commit secrets."
  assert_eq "$(grep -c 'pi-implementation-orchestrator:start' "$TMP/project/AGENTS.md" | tr -d ' ')" "1"

  # A missing final newline is preserved: the start marker is appended directly
  # instead of adding a byte outside the managed block.
  new_case
  stub_commands
  printf '# no final newline' >"$TMP/project/AGENTS.md"
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  assert_contains "$TMP/project/AGENTS.md" "# no final newline<!-- pi-implementation-orchestrator:start -->"
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
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
  if "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "duplicate markers accepted"
  fi
  assert_eq "$(grep -c 'pi-implementation-orchestrator:start' "$TMP/project/AGENTS.md" | tr -d ' ')" "2"
  assert_calls_empty
}

test_reversed_markers_fail_unchanged() {
  new_case
  stub_commands
  {
    printf '%s\n' "$END_MARKER"
    printf 'stray content\n'
    printf '%s\n' "$START_MARKER"
  } >"$TMP/project/AGENTS.md"
  before=$(shasum <"$TMP/project/AGENTS.md")
  if "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "reversed markers accepted"
  fi
  after=$(shasum <"$TMP/project/AGENTS.md")
  assert_eq "$after" "$before"
  assert_calls_empty
}

test_dry_run_detects_malformed_markers() {
  new_case
  stub_commands
  {
    printf '%s\n' "$END_MARKER"
    printf 'stray\n'
    printf '%s\n' "$START_MARKER"
  } >"$TMP/project/AGENTS.md"
  if "$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "dry-run accepted reversed markers"
  fi
  assert_calls_empty
  assert_no_file "$TMP/project/docs"

  new_case
  stub_commands
  cat >"$TMP/project/AGENTS.md" <<EOF
$START_MARKER
$END_MARKER
$END_MARKER
EOF
  if "$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "dry-run accepted duplicate markers"
  fi
  assert_calls_empty

  new_case
  stub_commands
  {
    printf '%s user text\n' "$START_MARKER"
    printf '%s\n' "$END_MARKER"
  } >"$TMP/project/AGENTS.md"
  if "$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "dry-run accepted trailing start-marker text"
  fi
  assert_calls_empty

  new_case
  stub_commands
  {
    printf '%s\n' "$START_MARKER"
    printf '%s trailing duplicate bytes\n' "$START_MARKER"
    printf '%s\n' "$END_MARKER"
  } >"$TMP/project/AGENTS.md"
  if "$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "dry-run accepted malformed duplicate start marker"
  fi
  assert_calls_empty
}

test_replacement_preserves_bytes() {
  new_case
  stub_commands
  {
    printf '# Header\n\n'
    printf '%s\n' "$START_MARKER"
    printf 'old block line\n'
    printf '%s\n' "$END_MARKER"
    printf 'suffix without final newline'
  } >"$TMP/project/AGENTS.md"
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  {
    printf '# Header\n\n'
    printf '%s\n' "$START_MARKER"
    "$ROOT/setup.sh" --project "$TMP/project" --dry-run \
      --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
      </dev/null 2>/dev/null |
      sed -n '/^## Agent workflow$/,/^- implementation plans\/tickets: execution entry points and explicit source references\.$/p'
    printf '%s\n' "$END_MARKER"
    printf 'suffix without final newline'
  } >"$TMP/expected"
  cmp "$TMP/expected" "$TMP/project/AGENTS.md" || fail "replacement changed bytes outside the managed block"
}

test_replacement_preserves_file_mode() {
  new_case
  stub_commands
  gnu_stat_stub
  printf 'old\n' >"$TMP/project/AGENTS.md"
  chmod 640 "$TMP/project/AGENTS.md"
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  assert_eq "$(mode_of "$TMP/project/AGENTS.md")" "640"
}

test_adaptive_review_and_test_policy() {
  assert_contains "$ROOT/README.md" 'Focused TDD is required only for `new-test` work'
  assert_contains "$ROOT/README.md" 'low-risk changes may be batch-reviewed'
  assert_contains "$ROOT/README.md" 'high-risk changes are reviewed immediately'
  new_case
  stub_commands
  printf '1\n1\n1\ny\n' | "$ROOT/setup.sh" --project "$TMP/project" >/dev/null 2>&1
  assert_contains "$TMP/project/AGENTS.md" 'Every task declares one test obligation: `new-test`, `existing-check`, or `no-new-test`; focused TDD is required only for `new-test` work.'
  assert_contains "$TMP/project/AGENTS.md" 'Review is adaptive and orchestrator-owned: high-risk or dependency-defining changes are reviewed immediately; low-risk changes may be reviewed cumulatively at a wave boundary.'
}

test_routing_authority_block() {
  new_case
  stub_commands
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  local block="$TMP/project/AGENTS.md"
  assert_contains "$block" '### Routing and authority'
  assert_contains "$block" 'docs/agents/artifacts.md'
  assert_contains "$block" 'planning-contract'
  assert_contains "$block" 'Scoped authority: glossaries own terminology'
  assert_not_contains "$block" 'Source precedence:'
  assert_contains "$block" 'Use `shape-design` for unresolved behavior/design choices'
  assert_contains "$block" 'Default orchestrated execution to `supervised`'
  assert_contains "$block" 'Route implementation to the preconfigured `implementer` agent and independent review to a fresh read-only `code-reviewer`'
  assert_contains "$block" 'stop and ask the owner before using builtin `worker`/`reviewer`'
  assert_contains "$block" 'record the approved resolved names in the run manifest'
  assert_contains "$block" 'Use `pi-subagents` for spawned-child lifecycle'
  assert_contains "$block" 'Use `systematic-debugging` for unexpected failures'
  assert_contains "$block" 'Use `merge-worktree` for target integration'
  assert_contains "$block" 'Local integration does not authorize pushing; opening a PR does not authorize merging'
  assert_contains "$block" 'Never silently switch execution modes to bypass a blocker.'
  # the whole managed block stays under the ~500-word budget
  local words
  words=$(extract_block "$block" | wc -w | tr -d ' ')
  if [ "$words" -gt 500 ]; then
    fail "managed block is $words words (budget ~500)"
  fi
}

test_missing_project_dir_fails() {
  new_case
  stub_commands
  if "$ROOT/setup.sh" --project "$TMP/nope" >/dev/null 2>&1; then
    fail "missing project accepted"
  fi
  assert_calls_empty
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
    if (!p.pi || Object.prototype.hasOwnProperty.call(p.pi, "skills")) fail("package must not bundle skills");
    if (!Array.isArray(p.pi.prompts) || !p.pi.prompts.includes("./prompts")) fail("p.pi.prompts missing ./prompts");
  ' "$ROOT/package.json"
}

test_skill_scope_project() {
  new_case
  stub_commands
  "$ROOT/setup.sh" --project "$TMP/project" --skill-scope project --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single \
    </dev/null >/dev/null 2>&1
  assert_project_calls "$TMP/project"
  assert_not_contains "$TEST_CALLS" "--global"
  assert_file "$TMP/project/AGENTS.md"
}

test_single_setup_entrypoint() {
  local prompt="$ROOT/prompts/setup-implementation-orchestrator.md"
  test -f "$prompt"
  assert_not_contains "$prompt" "skill: setup-implementation-orchestrator"
  assert_contains "$prompt" "setup.sh"
  assert_contains "$prompt" "--inspect"
  assert_contains "$prompt" "--dry-run"
  assert_contains "$prompt" "--yes"
  assert_contains "$prompt" "--replace-custom"
  assert_contains "$prompt" "legout/skills"
  assert_contains "$prompt" "record the approved resolved names in the run manifest"
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
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout multi --skill-scope global \
    </dev/null >/dev/null 2>&1
  assert_contains "$TMP/project/AGENTS.md" "pi-implementation-orchestrator:start"
  assert_eq "$(cat "$TMP/project/CLAUDE.md")" "# claude"
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Tracker: Local Markdown."
  assert_contains "$TMP/project/docs/agents/domain.md" "Layout: multiple contexts."

  new_case
  stub_commands
  printf '# claude\n' >"$TMP/project/CLAUDE.md"
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file CLAUDE.md --tracker github --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  assert_contains "$TMP/project/CLAUDE.md" "pi-implementation-orchestrator:start"
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Tracker: GitHub Issues."
  assert_contains "$TMP/project/docs/agents/domain.md" "Layout: single context."

  new_case
  stub_commands
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker other --tracker-description "Linear board" --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Tracker: Linear board."
}

test_paths_with_spaces() {
  new_case
  stub_commands
  local proj="$TMP/my project"
  mkdir -p "$proj"
  "$ROOT/setup.sh" --project "$proj" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope project \
    </dev/null >/dev/null 2>&1
  assert_file "$proj/AGENTS.md"
  assert_file "$proj/docs/agents/issue-tracker.md"
  assert_file "$proj/docs/agents/domain.md"
  assert_project_calls "$proj"
  assert_contains "$proj/AGENTS.md" "pi-implementation-orchestrator:start"
}

test_symlinked_project_argument_is_canonicalized() {
  new_case
  stub_commands
  ln -s "$TMP/project" "$TMP/project-link"
  "$ROOT/setup.sh" --project "$TMP/project-link" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  assert_file "$TMP/project/AGENTS.md"
  assert_file "$TMP/project/docs/agents/domain.md"
}

test_symlinked_instruction_file_refused() {
  new_case
  stub_commands
  printf 'real target\n' >"$TMP/project/real.md"
  ln -s "$TMP/project/real.md" "$TMP/project/AGENTS.md"
  local before
  before=$(tree_hash "$TMP/project")
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "instruction symlink accepted"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "refusing to operate through the symlink"
  assert_contains "$TMP/out" "AGENTS.md"
  assert_eq "$(tree_hash "$TMP/project")" "$before"
  assert_calls_empty
}

test_dangling_instruction_symlink_refused() {
  new_case
  stub_commands
  ln -s "$TMP/project/does-not-exist.md" "$TMP/project/AGENTS.md"
  if "$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "dangling instruction symlink accepted"
  fi
  test -L "$TMP/project/AGENTS.md" || fail "dangling symlink was modified"
  assert_calls_empty
}

test_symlinked_generated_outputs_refused() {
  new_case
  stub_commands
  # symlinked generated doc
  mkdir -p "$TMP/project/docs/agents"
  ln -s "$TMP/project/elsewhere.md" "$TMP/project/docs/agents/issue-tracker.md"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) || true
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "refusing to operate through the symlink"
  assert_contains "$TMP/out" "issue-tracker.md"
  test -L "$TMP/project/docs/agents/issue-tracker.md" || fail "symlink replaced"

  new_case
  stub_commands
  # symlinked docs/agents ancestor
  mkdir -p "$TMP/project/real-agents"
  mkdir -p "$TMP/project/docs"
  ln -s "$TMP/project/real-agents" "$TMP/project/docs/agents"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "symlinked docs/agents accepted"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "refusing to operate through the symlink"
  assert_contains "$TMP/out" "docs/agents"
  test -L "$TMP/project/docs/agents" || fail "ancestor symlink modified"

  new_case
  stub_commands
  # symlinked docs ancestor
  mkdir -p "$TMP/project/real-docs/agents"
  ln -s "$TMP/project/real-docs" "$TMP/project/docs"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --inspect \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) || true
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "refusing to operate through the symlink"
  test -L "$TMP/project/docs" || fail "docs symlink modified"
  assert_calls_empty
}

test_wrong_kind_paths_fail_before_installs() {
  new_case
  stub_commands
  # docs is a regular file
  printf 'not a dir\n' >"$TMP/project/docs"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "docs-as-file accepted"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "docs"
  assert_calls_empty
  assert_eq "$(cat "$TMP/project/docs")" "not a dir"

  new_case
  stub_commands
  # generated doc path is a directory
  mkdir -p "$TMP/project/docs/agents/issue-tracker.md"
  if "$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "directory at generated-doc path accepted"
  fi
  assert_calls_empty
  test -d "$TMP/project/docs/agents/issue-tracker.md"

  new_case
  stub_commands
  # instruction file path is a directory
  mkdir -p "$TMP/project/AGENTS.md"
  if "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "directory at instruction path accepted"
  fi
  assert_calls_empty
}

test_unsearchable_directory_fails_before_installs() {
  skip_if_root
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  chmod 200 "$TMP/project/docs/agents"
  if "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "unsearchable docs/agents accepted"
  fi
  assert_calls_empty
  chmod 755 "$TMP/project/docs/agents"
}

test_unwritable_destination_fails_before_installs() {
  skip_if_root
  new_case
  stub_commands
  chmod 555 "$TMP/project"
  if "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "unwritable project accepted"
  fi
  assert_calls_empty
  chmod 755 "$TMP/project"

  new_case
  stub_commands
  printf 'existing\n' >"$TMP/project/AGENTS.md"
  chmod 555 "$TMP/project"
  if "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1; then
    fail "unwritable existing-file parent accepted"
  fi
  assert_calls_empty
  chmod 755 "$TMP/project"
}

test_install_failure_leaves_project_unchanged() {
  new_case
  stub_commands
  printf 'original\n' >"$TMP/project/AGENTS.md"
  export TEST_FAIL_PROG=npx TEST_FAIL_AT=1
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "failing npx accepted"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "external installation failed"
  assert_contains "$TMP/out" "already completed: none"
  assert_eq "$(cat "$TMP/project/AGENTS.md")" "original"
  assert_no_file "$TMP/project/docs"
  assert_eq "$(grep -c ' pi install' "$TEST_CALLS" | tr -d ' ')" "0"

  new_case
  stub_commands
  printf 'original\n' >"$TMP/project/AGENTS.md"
  export TEST_FAIL_PROG=pi TEST_FAIL_AT=2
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "failing second pi install accepted"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "External steps already completed"
  assert_contains "$TMP/out" "npx skills add legout/skills"
  assert_eq "$(cat "$TMP/project/AGENTS.md")" "original"
  assert_no_file "$TMP/project/docs"
  assert_contains "$TEST_CALLS" "pi install npm:pi-subagents"
}

test_late_write_failure_leaves_prior_writes() {
  new_case
  stub_commands
  printf 'original agents\n' >"$TMP/project/AGENTS.md"
  mkdir -p "$TMP/project/docs/agents"
  printf '# Issue tracker\n\nTracker: Local Markdown.\n' >"$TMP/project/docs/agents/issue-tracker.md"
  printf '# Domain documentation\n\nLayout: single context.\n' >"$TMP/project/docs/agents/domain.md"
  export TEST_SABOTAGE=make-agents-dir
  export TEST_PROJECT="$TMP/project"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "write failure accepted"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "Rerun setup"
  assert_contains "$TMP/project/docs/agents/artifacts.md" "# Artifact mapping"
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Tracker: Local Markdown."
  assert_contains "$TMP/project/docs/agents/domain.md" "Layout: single context."
  test -d "$TMP/project/AGENTS.md" || fail "foreign concurrent change was overwritten"
}

test_artifacts_map_late_write_failure() {
  new_case
  stub_commands
  export TEST_SABOTAGE=make-artifacts-dir
  export TEST_PROJECT="$TMP/project"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "artifact-map write failure accepted"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "Rerun setup"
  assert_contains "$TMP/out" "External installs already performed"
  assert_contains "$TMP/out" "docs/agents/artifacts.md"
  # the map is written first: its failure leaves no later writes behind
  assert_no_file "$TMP/project/AGENTS.md"
  assert_no_file "$TMP/project/docs/agents/issue-tracker.md"
  test -d "$TMP/project/docs/agents/artifacts.md" || fail "foreign concurrent change was overwritten"
  assert_contains "$TEST_CALLS" "npx skills add legout/skills"
}

test_second_write_failure_leaves_first_write() {
  new_case
  stub_commands
  export TEST_SABOTAGE=make-domain-dir
  export TEST_PROJECT="$TMP/project"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "write failure accepted"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "Rerun setup"
  assert_file "$TMP/project/docs/agents/artifacts.md"
  assert_file "$TMP/project/docs/agents/issue-tracker.md"
  assert_no_file "$TMP/project/AGENTS.md"
}

test_concurrent_edit_fails_before_target_write() {
  new_case
  stub_commands
  printf 'original agents
' >"$TMP/project/AGENTS.md"
  export TEST_SABOTAGE=append-agents
  export TEST_PROJECT="$TMP/project"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "concurrent edit was silently accepted"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "changed concurrently"
  assert_contains "$TMP/out" "rerun setup"
  assert_contains "$TMP/project/AGENTS.md" "concurrent edit"
  assert_contains "$TMP/project/AGENTS.md" "original agents"
  assert_file "$TMP/project/docs/agents/issue-tracker.md"

  new_case
  stub_commands
  export TEST_SABOTAGE=replace-docs-link
  export TEST_PROJECT="$TMP/project"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "post-approval symlink was followed"
  assert_contains <(printf '%s\n' "$out") "symlink"
  assert_no_file "$TMP/outside/agents/issue-tracker.md"
  test -L "$TMP/project/docs" || fail "post-approval docs symlink disappeared"
}

test_custom_generated_doc_requires_decision() {
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Our own tracker doc with custom content\n' >"$TMP/project/docs/agents/issue-tracker.md"
  # --yes cannot decide to replace custom content
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "--yes replaced custom doc"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "custom content"
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Our own tracker doc"
  assert_calls_empty

  # dry-run remains noninteractive and makes the replacement gate visible
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Our own tracker doc\n' >"$TMP/project/docs/agents/issue-tracker.md"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) || fail "dry-run asked for a custom-doc answer"
  assert_contains <(printf '%s\n' "$out") "custom content (requires --replace-custom)"
  assert_calls_empty

  # A config-looking line plus user text is still custom and cannot be bypassed.
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Issue tracker\n\nTracker: Local Markdown.\nmy note\n' >"$TMP/project/docs/agents/issue-tracker.md"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "--yes replaced config-looking custom doc"
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "my note"
  assert_calls_empty

  # --replace-custom makes the explicit replacement decision usable in the
  # prompt's dry-run -> approval -> --yes sequence.
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Our own tracker doc\n' >"$TMP/project/docs/agents/issue-tracker.md"
  (cd "$TMP" && "$ROOT/setup.sh" --project "$TMP/project" --replace-custom --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global) \
    >/dev/null 2>&1
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Tracker: Local Markdown."
  assert_global_calls "$TMP"

  # interactive decline leaves everything untouched
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Our own tracker doc\n' >"$TMP/project/docs/agents/issue-tracker.md"
  printf 'n\n' | "$ROOT/setup.sh" --project "$TMP/project" \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    >/dev/null 2>&1
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Our own tracker doc"
  assert_calls_empty
  assert_no_file "$TMP/project/AGENTS.md"

  # interactive approval replaces it (custom decision, then final approval)
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Our own tracker doc\n' >"$TMP/project/docs/agents/issue-tracker.md"
  out=$(printf 'y\ny\n' | "$ROOT/setup.sh" --project "$TMP/project" \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    2>&1) || fail "interactive custom-doc approval failed"
  assert_contains <(printf '%s\n' "$out") "custom content (replacement explicitly approved)"
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Tracker: Local Markdown."
}

test_artifacts_map_creation() {
  new_case
  stub_commands
  printf '1\n1\n1\ny\n' | "$ROOT/setup.sh" --project "$TMP/project" >/dev/null 2>&1
  local map="$TMP/project/docs/agents/artifacts.md"
  assert_file "$map"
  assert_contains "$map" "# Artifact mapping"
  assert_contains "$map" "declarative documentation, not executable configuration"
  assert_contains "$map" "docs/research/:"
  assert_contains "$map" "docs/adr/:"
  assert_contains "$map" "docs/specs/:"
  assert_contains "$map" "docs/plans/:"
  assert_contains "$map" "docs/tickets/:"
  assert_contains "$map" "docs/agents/issue-tracker.md"
  assert_contains "$map" "docs/agents/domain.md"
  assert_contains "$map" "planning-contract"
  # the map and the contract are linked from the managed root block
  assert_contains "$TMP/project/AGENTS.md" "docs/agents/artifacts.md"
  assert_contains "$TMP/project/AGENTS.md" "planning-contract"
}

test_legacy_project_receives_map() {
  new_case
  stub_commands
  # a project configured by an older setup: managed block and the full set of
  # generated docs exist, but no docs/agents/artifacts.md yet
  mkdir -p "$TMP/seed"
  "$ROOT/setup.sh" --project "$TMP/seed" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  mkdir -p "$TMP/project/docs/agents" "$TMP/project/docs/specs" "$TMP/project/docs/adr"
  {
    printf '# Project rules\n\n'
    printf '%s\n' "$START_MARKER"
    printf 'old managed line\n'
    printf '%s\n' "$END_MARKER"
    printf '\nNever commit secrets.\n'
  } >"$TMP/project/AGENTS.md"
  cp "$TMP/seed/docs/agents/issue-tracker.md" "$TMP/project/docs/agents/issue-tracker.md"
  cp "$TMP/seed/docs/agents/domain.md" "$TMP/project/docs/agents/domain.md"
  printf '# Feasibility report\n\nEvidence from a probe.\n' >"$TMP/project/docs/specs/feasibility.md"
  printf '# Existing decision\n' >"$TMP/project/docs/adr/0001-existing.md"
  local spec_before adr_before tracker_before domain_before
  spec_before=$(shasum <"$TMP/project/docs/specs/feasibility.md")
  adr_before=$(shasum <"$TMP/project/docs/adr/0001-existing.md")
  tracker_before=$(shasum <"$TMP/project/docs/agents/issue-tracker.md")
  domain_before=$(shasum <"$TMP/project/docs/agents/domain.md")
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  # the map is added; existing documents are not moved, rewritten, or fabricated
  assert_file "$TMP/project/docs/agents/artifacts.md"
  assert_eq "$(shasum <"$TMP/project/docs/specs/feasibility.md")" "$spec_before"
  assert_eq "$(shasum <"$TMP/project/docs/adr/0001-existing.md")" "$adr_before"
  assert_eq "$(shasum <"$TMP/project/docs/agents/issue-tracker.md")" "$tracker_before"
  assert_eq "$(shasum <"$TMP/project/docs/agents/domain.md")" "$domain_before"
  assert_no_file "$TMP/project/CONTEXT.md"
  assert_no_file "$TMP/project/docs/research"
  assert_not_contains "$TMP/project/docs/agents/artifacts.md" "feasibility.md"
  # surrounding instruction-file bytes survive the block refresh
  assert_contains "$TMP/project/AGENTS.md" "# Project rules"
  assert_contains "$TMP/project/AGENTS.md" "Never commit secrets."
}

test_configured_artifacts_map_reused() {
  new_case
  stub_commands
  # generate the canonical map once, then treat it as the configured mapping
  mkdir -p "$TMP/seed" "$TMP/project/docs/agents"
  "$ROOT/setup.sh" --project "$TMP/seed" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  cp "$TMP/seed/docs/agents/artifacts.md" "$TMP/generated-map"

  # a fully generated map is owned: rerun regenerates it without questions
  cp "$TMP/generated-map" "$TMP/project/docs/agents/artifacts.md"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) || fail "configured map required a replace decision"
  printf '%s\n' "$out" >"$TMP/out"
  assert_not_contains "$TMP/out" "custom content"
  cmp -s "$TMP/generated-map" "$TMP/project/docs/agents/artifacts.md" ||
    fail "regenerated map differs from the configured map"

  # the recognized mapping header alone is also owned configuration
  new_case
  stub_commands
  mkdir -p "$TMP/seed" "$TMP/project/docs/agents"
  "$ROOT/setup.sh" --project "$TMP/seed" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  head -n 3 "$TMP/seed/docs/agents/artifacts.md" >"$TMP/project/docs/agents/artifacts.md"
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  cmp -s "$TMP/seed/docs/agents/artifacts.md" "$TMP/project/docs/agents/artifacts.md" ||
    fail "header-only map was not regenerated deterministically"
}

test_custom_artifacts_map_requires_decision() {
  # --yes cannot decide to replace custom mapping content
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Our artifact routing\n\n- docs/notes/: everything\n' >"$TMP/project/docs/agents/artifacts.md"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "--yes replaced custom artifact map"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "custom content"
  assert_contains "$TMP/out" "artifacts.md"
  assert_contains "$TMP/project/docs/agents/artifacts.md" "Our artifact routing"
  assert_calls_empty

  # dry-run makes the replacement gate visible without prompting
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Our artifact routing\n' >"$TMP/project/docs/agents/artifacts.md"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) || fail "dry-run asked for a custom-map answer"
  assert_contains <(printf '%s\n' "$out") "docs/agents/artifacts.md (custom content (requires --replace-custom))"
  assert_calls_empty

  # the generated mapping header plus custom entries stays custom
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  {
    printf '# Artifact mapping\n\n'
    printf 'Mapping: generated defaults. This file is declarative documentation, not executable configuration.\n\n'
    printf '%s\n' '- docs/notes/: everything'
  } >"$TMP/project/docs/agents/artifacts.md"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "--yes replaced configured custom mapping entries"
  assert_contains "$TMP/project/docs/agents/artifacts.md" "docs/notes/"
  assert_calls_empty

  # --replace-custom records the explicit replacement decision
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Our artifact routing\n' >"$TMP/project/docs/agents/artifacts.md"
  "$ROOT/setup.sh" --project "$TMP/project" --replace-custom --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  assert_contains "$TMP/project/docs/agents/artifacts.md" "# Artifact mapping"

  # interactive decline leaves everything untouched
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Our artifact routing\n' >"$TMP/project/docs/agents/artifacts.md"
  printf 'n\n' | "$ROOT/setup.sh" --project "$TMP/project" \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    >/dev/null 2>&1
  assert_contains "$TMP/project/docs/agents/artifacts.md" "Our artifact routing"
  assert_calls_empty
  assert_no_file "$TMP/project/AGENTS.md"

  # interactive approval replaces it (custom decision, then final approval)
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Our artifact routing\n' >"$TMP/project/docs/agents/artifacts.md"
  out=$(printf 'y\ny\n' | "$ROOT/setup.sh" --project "$TMP/project" \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    2>&1) || fail "interactive custom-map approval failed"
  assert_contains <(printf '%s\n' "$out") "custom content (replacement explicitly approved)"
  assert_contains "$TMP/project/docs/agents/artifacts.md" "# Artifact mapping"
}

test_artifacts_map_purity() {
  new_case
  stub_commands
  out=$("$ROOT/setup.sh" --inspect --project "$TMP/project" \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) || fail "inspect failed on a project without a map"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "docs/agents/artifacts.md: owned/generated configuration"
  assert_no_file "$TMP/project/docs"
  assert_no_file "$TMP/project/AGENTS.md"
  assert_calls_empty

  out=$("$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) || fail "dry-run failed on a project without a map"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "docs/agents/artifacts.md (new file)"
  assert_contains "$TMP/out" "--- docs/agents/artifacts.md"
  assert_no_file "$TMP/project/docs"
  assert_no_file "$TMP/project/AGENTS.md"
  assert_calls_empty
}

test_artifacts_map_symlink_refused() {
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  ln -s "$TMP/project/elsewhere.md" "$TMP/project/docs/agents/artifacts.md"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "artifact-map symlink accepted"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "refusing to operate through the symlink"
  assert_contains "$TMP/out" "artifacts.md"
  test -L "$TMP/project/docs/agents/artifacts.md" || fail "symlink replaced"
  assert_calls_empty
  assert_no_file "$TMP/project/AGENTS.md"
}

test_artifacts_map_wrong_kind_refused() {
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents/artifacts.md"
  out=$("$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) && fail "directory at artifact-map path accepted"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "not a regular file"
  assert_contains "$TMP/out" "artifacts.md"
  assert_calls_empty
  test -d "$TMP/project/docs/agents/artifacts.md"
  assert_no_file "$TMP/project/AGENTS.md"
}

test_existing_tracker_doc_suppresses_question() {
  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# Issue tracker\n\nTracker: Local Markdown.\n' >"$TMP/project/docs/agents/issue-tracker.md"
  # questions: instruction (create: 1) -> tracker skipped -> scope (1) -> approval (y)
  printf '1\n1\ny\n' | "$ROOT/setup.sh" --project "$TMP/project" >/dev/null 2>&1
  assert_contains "$TMP/project/docs/agents/issue-tracker.md" "Tracker: Local Markdown."
  assert_contains "$TMP/project/docs/agents/domain.md" "Layout: single context."
}

test_inspect_new_project() {
  new_case
  stub_commands
  before=$(tree_hash "$TMP/project")
  out=$("$ROOT/setup.sh" --inspect --project "$TMP/project" </dev/null 2>&1) ||
    fail "inspect of a new project failed"
  printf '%s\n' "$out" >"$TMP/out"
  assert_eq "$(tree_hash "$TMP/project")" "$before"
  assert_calls_empty
  assert_contains "$TMP/out" "--inspect (read-only)"
  assert_contains "$TMP/out" "UNRESOLVED: neither AGENTS.md nor CLAUDE.md exists"
  assert_contains "$TMP/out" "instruction-file"
  assert_contains "$TMP/out" "tracker"
  assert_contains "$TMP/out" "domain-layout"
  assert_contains "$TMP/out" "skill-scope"
  assert_contains "$TMP/out" "Validation: OK"
  assert_contains "$TMP/out" "--dry-run"
  assert_contains "$TMP/out" "nothing was installed, asked, or written"
}

test_inspect_existing_project() {
  new_case
  stub_commands
  git -C "$TMP/project" init -q
  git -C "$TMP/project" remote add origin https://github.com/example/repo.git
  printf '# agents\n' >"$TMP/project/AGENTS.md"
  printf 'packages:\n  - a\n' >"$TMP/project/pnpm-workspace.yaml"
  before=$(tree_hash "$TMP/project")
  out=$("$ROOT/setup.sh" --inspect --project "$TMP/project" </dev/null 2>&1) ||
    fail "inspect of an existing project failed"
  printf '%s\n' "$out" >"$TMP/out"
  assert_eq "$(tree_hash "$TMP/project")" "$before"
  assert_calls_empty
  assert_contains "$TMP/out" "Instruction files present: AGENTS.md"
  assert_contains "$TMP/out" "github.com/example/repo.git"
  assert_contains "$TMP/out" "pnpm-workspace.yaml"
  assert_contains "$TMP/out" "monorepo signals present"
  assert_contains "$TMP/out" "UNRESOLVED"
  assert_contains "$TMP/out" "--instruction-file AGENTS.md"
  assert_contains "$TMP/out" "--tracker github"
  assert_contains "$TMP/out" "--domain-layout single"
  assert_contains "$TMP/out" "--skill-scope global"
}

test_inspect_reads_existing_configuration() {
  new_case
  stub_commands
  printf '# claude\n' >"$TMP/project/CLAUDE.md"
  mkdir -p "$TMP/project/docs/agents"
  printf '# Issue tracker\n\nTracker: Local Markdown.\n' >"$TMP/project/docs/agents/issue-tracker.md"
  printf '# Domain documentation\n\nLayout: multiple contexts.\n' >"$TMP/project/docs/agents/domain.md"
  before=$(tree_hash "$TMP/project")
  out=$("$ROOT/setup.sh" --inspect --project "$TMP/project" </dev/null 2>&1) ||
    fail "inspect failed with existing configuration"
  printf '%s\n' "$out" >"$TMP/out"
  assert_eq "$(tree_hash "$TMP/project")" "$before"
  assert_contains "$TMP/out" "[detected] (existing CLAUDE.md)"
  assert_contains "$TMP/out" "[detected] (existing docs/agents/issue-tracker.md)"
  assert_contains "$TMP/out" "Multiple contexts [detected]"
  assert_contains "$TMP/out" "--domain-layout multi"
  assert_contains "$TMP/out" "--tracker local"

  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  {
    printf '# Issue tracker\n\n'
    printf 'Tracker: Linear board.\n\n'
    printf 'Tickets are tracked as described above.\n'
    printf 'Every ticket references its authoritative feature sources (specification, ADR, or plan).\n'
  } >"$TMP/project/docs/agents/issue-tracker.md"
  out=$("$ROOT/setup.sh" --inspect --project "$TMP/project" </dev/null 2>&1) ||
    fail "inspect failed with a detected custom tracker"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "[detected] (existing docs/agents/issue-tracker.md)"
  assert_contains "$TMP/out" '--tracker other --tracker-description Linear\ board'
}

test_inspect_ambiguous_configuration() {
  new_case
  stub_commands
  printf '# agents\n' >"$TMP/project/AGENTS.md"
  printf '# claude\n' >"$TMP/project/CLAUDE.md"
  out=$("$ROOT/setup.sh" --inspect --project "$TMP/project" </dev/null 2>&1) ||
    fail "inspect failed on ambiguous instruction files"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "UNRESOLVED: both AGENTS.md and CLAUDE.md exist"

  new_case
  stub_commands
  mkdir -p "$TMP/project/docs/agents"
  printf '# totally custom tracker content\n' >"$TMP/project/docs/agents/issue-tracker.md"
  out=$("$ROOT/setup.sh" --inspect --project "$TMP/project" </dev/null 2>&1) ||
    fail "inspect failed on custom doc"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "unrecognized custom content"
}

test_inspect_reports_validation_hazards() {
  new_case
  stub_commands
  {
    printf '%s\n' "$END_MARKER"
    printf 'x\n'
    printf '%s\n' "$START_MARKER"
  } >"$TMP/project/AGENTS.md"
  before=$(tree_hash "$TMP/project")
  out=$("$ROOT/setup.sh" --inspect --project "$TMP/project" </dev/null 2>&1) &&
    fail "inspect ignored malformed markers"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "malformed managed block"
  assert_eq "$(tree_hash "$TMP/project")" "$before"

  new_case
  stub_commands
  ln -s "$TMP/project/real.md" "$TMP/project/AGENTS.md"
  out=$("$ROOT/setup.sh" --inspect --project "$TMP/project" </dev/null 2>&1) &&
    fail "inspect ignored symlink hazard"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "refusing to operate through the symlink"
}

test_inspect_missing_prerequisites() {
  new_case
  stub_commands
  mkdir -p "$TMP/empty"
  out=$(PATH="$TMP/empty:/usr/bin:/bin" "$ROOT/setup.sh" --inspect --project "$TMP/project" </dev/null 2>&1) ||
    fail "inspect failed with missing prerequisites"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "Prerequisites: MISSING: npx pi"
  assert_contains "$TMP/out" "required install prerequisites are missing"
  assert_calls_empty
}

test_inspect_skip_project() {
  new_case
  stub_commands
  out=$("$ROOT/setup.sh" --inspect --skip-project </dev/null 2>&1) ||
    fail "inspect --skip-project failed"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "Project: none (--skip-project)"
  assert_contains "$TMP/out" "skill-scope: Global [resolved]"
  assert_contains "$TMP/out" "./setup.sh --skip-project --skill-scope global --dry-run"
  assert_calls_empty
}

test_inspect_explicit_values() {
  new_case
  stub_commands
  out=$("$ROOT/setup.sh" --inspect --project "$TMP/project" \
    --instruction-file CLAUDE.md --tracker other --tracker-description "Linear board" \
    --domain-layout multi --skill-scope project </dev/null 2>&1) ||
    fail "inspect with explicit values failed"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "CLAUDE.md [explicit]"
  assert_contains "$TMP/out" "Linear board [explicit]"
  assert_contains "$TMP/out" "Multiple contexts [explicit]"
  assert_contains "$TMP/out" "Project [explicit]"
  assert_contains "$TMP/out" '--tracker other --tracker-description Linear\ board'
  assert_contains "$TMP/out" "--domain-layout multi --skill-scope project"
}

test_prompt_fast_path_skips_inspect_interactive() {
  # fully explicit choices: no questions, no stdin, straight preview->apply
  new_case
  stub_commands
  out=$("$ROOT/setup.sh" --project "$TMP/project" --dry-run \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null 2>&1) || fail "fully explicit dry-run needed stdin"
  printf '%s\n' "$out" >"$TMP/out"
  assert_contains "$TMP/out" "Dry run: nothing was installed, executed, or written."
  assert_calls_empty
}

test_multi_layout_not_root_canonical() {
  new_case
  stub_commands
  mkdir -p "$TMP/project/packages/a"
  printf 'packages:\n  - a\n' >"$TMP/project/pnpm-workspace.yaml"
  printf 'glossary\n' >"$TMP/project/packages/a/CONTEXT.md"
  printf '# context map\n\n- packages/a -> packages/a/CONTEXT.md\n' >"$TMP/project/CONTEXT-MAP.md"
  printf 'root glossary\n' >"$TMP/project/CONTEXT.md"
  map_before=$(shasum <"$TMP/project/CONTEXT-MAP.md")
  pkg_before=$(shasum <"$TMP/project/packages/a/CONTEXT.md")
  root_before=$(shasum <"$TMP/project/CONTEXT.md")
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout multi --skill-scope global \
    </dev/null >/dev/null 2>&1
  assert_eq "$(shasum <"$TMP/project/CONTEXT-MAP.md")" "$map_before"
  assert_eq "$(shasum <"$TMP/project/packages/a/CONTEXT.md")" "$pkg_before"
  assert_eq "$(shasum <"$TMP/project/CONTEXT.md")" "$root_before"
  local block="$TMP/project/AGENTS.md" domain="$TMP/project/docs/agents/domain.md"
  assert_not_contains "$block" '`CONTEXT.md`: canonical domain vocabulary for the whole repository.'
  assert_contains "$block" 'No single root `CONTEXT.md` is canonical here.'
  assert_contains "$block" '`CONTEXT-MAP.md`, when present'
  assert_contains "$domain" 'no root `CONTEXT.md` is canonical for this repository'
  assert_contains "$domain" 'CONTEXT-MAP.md'
  assert_contains "$domain" 'do not create a root or global glossary'
}

test_single_layout_claims_root_context() {
  new_case
  stub_commands
  "$ROOT/setup.sh" --project "$TMP/project" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  assert_contains "$TMP/project/AGENTS.md" '`CONTEXT.md`: canonical domain vocabulary for the whole repository.'
  assert_not_contains "$TMP/project/AGENTS.md" 'No single root `CONTEXT.md` is canonical here.'
}

test_direct_and_flag_driven_blocks_identical() {
  new_case
  stub_commands
  mkdir -p "$TMP/p1" "$TMP/p2"
  printf '1\n1\n1\ny\n' | "$ROOT/setup.sh" --project "$TMP/p1" >/dev/null 2>&1
  extract_block "$TMP/p1/AGENTS.md" >"$TMP/block-interactive"
  "$ROOT/setup.sh" --project "$TMP/p2" --yes \
    --instruction-file AGENTS.md --tracker local --domain-layout single --skill-scope global \
    </dev/null >/dev/null 2>&1
  extract_block "$TMP/p2/AGENTS.md" >"$TMP/block-explicit"
  cmp -s "$TMP/block-interactive" "$TMP/block-explicit" ||
    fail "interactive and flag-driven managed blocks differ"
}

# ---------------------------------------------------------------- runner

run_all() {
  local failed=0 t out
  for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
    if out=$(bash "$0" --case "$t" 2>&1); then
      echo "ok: $t"
    else
      echo "FAIL: $t"
      [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    /'
      failed=1
    fi
  done
  if [ "$failed" != 0 ]; then
    echo "tests failed" >&2
    exit 1
  fi
  echo "all tests passed"
}

main() {
  if [ "${1:-}" = "--case" ]; then
    [ $# -eq 2 ] || {
      echo "usage: $0 [--case NAME]" >&2
      exit 2
    }
    CASE=$2
    type "$CASE" >/dev/null 2>&1 || {
      echo "no such case: $CASE" >&2
      exit 2
    }
    "$CASE"
    echo "ok: $CASE"
    exit 0
  fi
  [ $# -eq 0 ] || {
    echo "usage: $0 [--case NAME]" >&2
    exit 2
  }
  run_all
}

main "$@"
