#!/usr/bin/env bash
# Regression suite for the test runner in tests/setup_test.sh.
#
# tests/setup_test.sh used to mask real assertion failures: cases were invoked
# inside an `if` condition, where `set -e` is ignored, so a mid-case failure
# followed by a passing command still exited zero. This suite keeps that honest
# by (1) mutation-probing a copied suite: a deliberately broken copy of
# setup.sh that omits the three generated docs (artifact map, tracker, domain)
# during interactive setup must make the copied suite fail, and (2) verifying
# an early failing assertion followed by a passing command still fails a case.
#
# Everything runs against copies in a temporary directory with an isolated
# HOME/TMPDIR and defensive outer pi/npx stubs, so no real installer ever runs.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=
SUITE_OUT=
SUITE_RC=
OUTER_CALLS=

cleanup() { test -z "${TMP:-}" || rm -rf "$TMP"; }
trap cleanup EXIT

fail() {
  echo "FAIL(setup_runner_test): $*" >&2
  exit 1
}

new_run() {
  cleanup
  TMP=$(mktemp -d "${TMPDIR:-/tmp}/pi-orchestrator-runner-test.XXXXXXXX")
  TMP=$(cd "$TMP" && pwd)
  mkdir -p "$TMP/home" "$TMP/tmpdir" "$TMP/bin" "$TMP/suite"
  # Defensive outer stubs: the copied suite stubs pi/npx itself for every
  # case; if anything slips past that, it lands here and is recorded.
  cat >"$TMP/bin/pi" <<'STUB'
#!/usr/bin/env bash
printf 'outer %s %s\n' "${0##*/}" "$*" >> "$OUTER_CALLS"
exit 0
STUB
  cp "$TMP/bin/pi" "$TMP/bin/npx"
  chmod +x "$TMP/bin/pi" "$TMP/bin/npx"
  export OUTER_CALLS="$TMP/outer-calls"
  : >"$OUTER_CALLS"
}

copy_suite() {
  # Copy only the tracked inputs tests/setup_test.sh actually reads.
  local dest="$1"
  mkdir -p "$dest/tests" "$dest/prompts" "$dest/docs"
  cp "$ROOT/setup.sh" "$dest/setup.sh"
  cp "$ROOT/tests/setup_test.sh" "$dest/tests/setup_test.sh"
  cp "$ROOT/package.json" "$dest/package.json"
  cp "$ROOT/README.md" "$dest/README.md"
  cp "$ROOT/prompts/setup-implementation-orchestrator.md" "$dest/prompts/"
  cp "$ROOT/docs/design.md" "$dest/docs/"
}

run_suite() {
  # $1 = suite root; sets SUITE_OUT and SUITE_RC.
  set +e
  SUITE_OUT=$(cd "$1" &&
    env HOME="$TMP/home" TMPDIR="$TMP/tmpdir" PATH="$TMP/bin:$PATH" \
      bash tests/setup_test.sh 2>&1)
  SUITE_RC=$?
  set -e
}

run_single_case() {
  # $1 = suite root, $2 = case name; sets SUITE_OUT and SUITE_RC.
  set +e
  SUITE_OUT=$(cd "$1" &&
    env HOME="$TMP/home" TMPDIR="$TMP/tmpdir" PATH="$TMP/bin:$PATH" \
      bash tests/setup_test.sh --case "$2" 2>&1)
  SUITE_RC=$?
  set -e
}

assert_outer_calls_empty() {
  test ! -s "$OUTER_CALLS" ||
    fail "real external command reached the outer stubs: $(cat "$OUTER_CALLS")"
}

# ---------------------------------------------------------------- test cases

test_syntax_checks_are_per_file() {
  # `bash -n a.sh b.sh c.sh` parses only the first script; check each file.
  local f
  for f in setup.sh tests/setup_test.sh tests/setup_runner_test.sh; do
    bash -n "$ROOT/$f" || fail "bash -n failed for $f"
  done
}

test_control_copy_passes() {
  # Proves the copied inputs are complete and the environment is sane; a
  # failing mutation probe is only meaningful against a passing control.
  new_run
  copy_suite "$TMP/suite"
  run_suite "$TMP/suite"
  [ "$SUITE_RC" -eq 0 ] ||
    fail "unmutated copied suite failed (required inputs incomplete?):
$SUITE_OUT"
  assert_outer_calls_empty
}

test_generated_docs_mutation_is_detected() {
  # Mutate the copied setup.sh so the three generated docs (artifact map,
  # tracker, domain) are written only with --yes (interactive setups omit
  # them). The copied suite must fail specifically at
  # test_initializes_agents_docs; historically it exited zero.
  new_run
  copy_suite "$TMP/suite"
  awk '
    /install_doc "\$PROJECT\/docs\/agents\// {
      print "  if [ \"$ASSUME_YES\" = true ]; then " $0 " ; fi"
      mutated++
      next
    }
    { print }
    END { exit (mutated == 3 ? 0 : 1) }
  ' "$ROOT/setup.sh" >"$TMP/suite/setup.sh" ||
    fail "mutation target not found in setup.sh (expected the three install_doc lines for docs/agents)"
  cmp -s "$ROOT/setup.sh" "$TMP/suite/setup.sh" &&
    fail "mutation did not change setup.sh"
  run_suite "$TMP/suite"
  [ "$SUITE_RC" -ne 0 ] ||
    fail "mutated suite exited zero: missing generated docs no longer fail the suite (false-green runner is back)"
  printf '%s\n' "$SUITE_OUT" | grep -q '^FAIL: test_initializes_agents_docs$' ||
    fail "mutation was not caught by test_initializes_agents_docs:
$SUITE_OUT"
  assert_outer_calls_empty
}

test_early_failure_fails_case_despite_later_success() {
  # A case whose first assertion fails but whose later commands pass must
  # still exit nonzero — both as a single case and in the full run.
  new_run
  copy_suite "$TMP/suite"
  probe_fn="$TMP/probe-fn.sh"
  cat >"$probe_fn" <<'EOF'
test_zzz_runner_probe_early_failure() {
  new_case
  test -f "/nonexistent/pi-orchestrator-probe/missing-file"
  echo "probe: this later command passes"
}

EOF
  awk -v probe_file="$probe_fn" '
    NR == FNR { probe = probe $0 "\n"; next }
    /^main "\$@"$/ && !done { printf "%s", probe; done = 1 }
    { print }
  ' "$probe_fn" "$TMP/suite/tests/setup_test.sh" >"$TMP/suite/tests/setup_test.sh.new"
  mv "$TMP/suite/tests/setup_test.sh.new" "$TMP/suite/tests/setup_test.sh"
  grep -q 'test_zzz_runner_probe_early_failure' "$TMP/suite/tests/setup_test.sh" ||
    fail "probe case was not inserted into the copied suite"

  run_single_case "$TMP/suite" test_zzz_runner_probe_early_failure
  [ "$SUITE_RC" -ne 0 ] ||
    fail "single-case run passed despite an early failing assertion followed by a passing command"
  assert_outer_calls_empty

  run_suite "$TMP/suite"
  [ "$SUITE_RC" -ne 0 ] ||
    fail "full run passed despite the inserted failing case"
  printf '%s\n' "$SUITE_OUT" | grep -q '^FAIL: test_zzz_runner_probe_early_failure$' ||
    fail "full run did not report the inserted failing case:
$SUITE_OUT"
  assert_outer_calls_empty
}

# ---------------------------------------------------------------- runner

main() {
  local failed=0 t out
  for t in test_syntax_checks_are_per_file test_control_copy_passes test_generated_docs_mutation_is_detected test_early_failure_fails_case_despite_later_success; do
    if out=$(bash "$0" --case "$t" 2>&1); then
      echo "ok: $t"
    else
      echo "FAIL: $t"
      [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/    /'
      failed=1
    fi
  done
  if [ "$failed" != 0 ]; then
    echo "runner tests failed" >&2
    exit 1
  fi
  echo "all runner tests passed"
}

if [ "${1:-}" = "--case" ]; then
  [ $# -eq 2 ] || {
    echo "usage: $0 [--case NAME]" >&2
    exit 2
  }
  CASE_NAME=$2
  type "$CASE_NAME" >/dev/null 2>&1 || {
    echo "no such case: $CASE_NAME" >&2
    exit 2
  }
  "$CASE_NAME"
  echo "ok: $CASE_NAME"
  exit 0
fi
[ $# -eq 0 ] || {
  echo "usage: $0 [--case NAME]" >&2
  exit 2
}
main
