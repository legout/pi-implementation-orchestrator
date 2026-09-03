#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
START_MARKER='<!-- pi-implementation-orchestrator:start -->'
END_MARKER='<!-- pi-implementation-orchestrator:end -->'

PLANNING=
PROJECT=
DRY_RUN=false
ASSUME_YES=false
SKIP_PROJECT=false

usage() {
  echo "Usage: ./setup.sh --planning matt|superpowers|both [--project PATH|--skip-project] [--dry-run] [--yes]" >&2
}

die() {
  echo "error: $*" >&2
  usage
  exit 1
}

run() {
  if "$DRY_RUN"; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else "$@"; fi
}

SUPERPOWERS_SKILLS=(brainstorming writing-plans)
MATT_PLANNING_SKILLS=(setup-matt-pocock-skills grilling domain-modeling grill-with-docs to-spec to-tickets)
TDD_SKILL=tdd

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    --planning)
      PLANNING=${2-}
      shift 2
      ;;
    --project)
      PROJECT=${2-}
      shift 2
      ;;
    --skip-project)
      SKIP_PROJECT=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --yes)
      ASSUME_YES=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "unknown flag: $1" ;;
    esac
  done

  case "$PLANNING" in
  matt | superpowers | both) ;;
  *) die "invalid --planning value: ${PLANNING:-<missing>}" ;;
  esac

  if [ -n "$PROJECT" ] && "$SKIP_PROJECT"; then
    die "choose either --project or --skip-project, not both"
  fi
  if [ -z "$PROJECT" ] && ! "$SKIP_PROJECT"; then
    die "choose either --project PATH or --skip-project"
  fi
}

resolve_project() {
  [ -n "$PROJECT" ] || return 0
  local abs
  abs=$(cd "$PROJECT" 2>/dev/null && pwd) || die "project directory not found: $PROJECT"
  PROJECT=$abs
}

ask_choice() {
  local prompt="$1"
  shift
  local opts=("$@")
  local n=${#opts[@]}
  local i ans
  while true; do
    printf '%s:\n' "$prompt" >&2
    i=1
    for opt in "${opts[@]}"; do
      printf '  %d) %s\n' "$i" "$opt" >&2
      i=$((i + 1))
    done
    ans=
    read -r ans || true
    if [ -z "$ans" ]; then
      echo "${opts[0]}"
      return
    fi
    case "$ans" in
    *[!0-9]*) ;;
    *) if [ "$ans" -ge 1 ] && [ "$ans" -le "$n" ]; then
      echo "${opts[$((ans - 1))]}"
      return
    fi ;;
    esac
    printf 'invalid choice: %s\n' "$ans" >&2
  done
}

choose_instruction_file() {
  if [ -f "$PROJECT/CLAUDE.md" ] && [ -f "$PROJECT/AGENTS.md" ]; then
    ask_choice "Instruction file" "CLAUDE.md" "AGENTS.md"
  elif [ -f "$PROJECT/CLAUDE.md" ]; then
    echo CLAUDE.md
  elif [ -f "$PROJECT/AGENTS.md" ]; then
    echo AGENTS.md
  else
    ask_choice "Create instruction file" "AGENTS.md" "CLAUDE.md"
  fi
}

choose_tracker() {
  local tracker
  if git -C "$PROJECT" remote get-url origin 2>/dev/null | grep -q 'github.com'; then
    tracker=$(ask_choice "Issue tracker" "GitHub Issues" "Local Markdown" "Other")
  else
    tracker=$(ask_choice "Issue tracker" "Local Markdown" "GitHub Issues" "Other")
  fi
  if [ "$tracker" = "Other" ]; then
    printf 'Describe the tracker in one line: ' >&2
    local desc=
    read -r desc || true
    [ -n "$desc" ] || desc="Other"
    tracker=$desc
  fi
  echo "$tracker"
}

has_monorepo_signals() {
  [ -f "$PROJECT/pnpm-workspace.yaml" ] && return 0
  grep -q '"workspaces"' "$PROJECT/package.json" 2>/dev/null && return 0
  find "$PROJECT/packages" -mindepth 2 -maxdepth 2 -type d -name src 2>/dev/null | grep -q . && return 0
  return 1
}

choose_domain_layout() {
  if has_monorepo_signals; then
    ask_choice "Domain layout" "Single context" "Multiple contexts"
  else
    echo "Single context"
  fi
}

install_skills() {
  if [ "$PLANNING" = superpowers ] || [ "$PLANNING" = both ]; then
    local args=(npx skills add obra/superpowers)
    local s
    for s in "${SUPERPOWERS_SKILLS[@]}"; do args+=(--skill "$s"); done
    args+=(--global --agent pi --yes --copy)
    run "${args[@]}"
  fi

  if [ "$PLANNING" = matt ] || [ "$PLANNING" = both ]; then
    local args=(npx skills add mattpocock/skills)
    local s
    for s in "${MATT_PLANNING_SKILLS[@]}"; do args+=(--skill "$s"); done
    args+=(--skill "$TDD_SKILL" --global --agent pi --yes --copy)
    run "${args[@]}"
  else
    run npx skills add mattpocock/skills --skill "$TDD_SKILL" --global --agent pi --yes --copy
  fi

  run pi install npm:pi-subagents
  run pi install npm:pi-intercom
  run npx skills add "$ROOT" --skill orchestrate-implementation --global --agent pi --yes --copy
}

render_workflow_block() {
  cat <<'EOF'
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
EOF
}

render_tracker_doc() {
  echo "# Issue tracker"
  echo
  echo "Tracker: $TRACKER."
  echo
  if [ "$TRACKER" = "GitHub Issues" ]; then
    echo "Tickets are GitHub issues in this repository. Use the GitHub CLI (gh) to read and manage them."
  elif [ "$TRACKER" = "Local Markdown" ]; then
    echo "Tickets are Markdown files under docs/tickets/."
  else
    echo "Tickets are tracked as described above."
  fi
  echo "Every ticket references its authoritative feature sources (specification, ADR, or plan)."
}

render_domain_doc() {
  echo "# Domain documentation"
  echo
  if [ "$DOMAIN_LAYOUT" = "Multiple contexts" ]; then
    echo "Layout: multiple contexts."
    echo
    echo "Each package or context keeps its own CONTEXT.md with its canonical vocabulary."
    echo "Cross-cutting decisions live in docs/adr/."
  else
    echo "Layout: single context."
    echo
    echo "- CONTEXT.md: canonical domain vocabulary for the whole repository."
    echo "- docs/adr/: accepted architecture decisions."
  fi
}

count_marker() {
  # usage: count_marker FILE MARKER -> prints count (0 when file missing)
  if [ -f "$1" ]; then grep -c -F -x "$2" "$1" || true; else echo 0; fi
}

update_instruction_file() {
  local file="$PROJECT/$INSTRUCTION_FILE"
  local starts ends
  starts=$(count_marker "$file" "$START_MARKER")
  ends=$(count_marker "$file" "$END_MARKER")

  if [ "$starts" = 0 ] && [ "$ends" = 0 ]; then
    local tmp="$PROJECT/.orchestrator-tmp.$$"
    {
      if [ -s "$file" ]; then
        cat "$file"
        if [ -n "$(tail -c 1 "$file")" ]; then echo; fi
      fi
      printf '%s\n' "$START_MARKER"
      cat "$BLOCK_FILE"
      printf '%s\n' "$END_MARKER"
    } >"$tmp"
    mv "$tmp" "$file"
  elif [ "$starts" = 1 ] && [ "$ends" = 1 ]; then
    local start_line end_line
    start_line=$(grep -n -F -x "$START_MARKER" "$file" | cut -d: -f1)
    end_line=$(grep -n -F -x "$END_MARKER" "$file" | cut -d: -f1)
    if [ -z "$start_line" ] || [ -z "$end_line" ] || [ "$end_line" -le "$start_line" ]; then
      die "malformed managed block in $INSTRUCTION_FILE (end marker does not follow start marker); resolve manually"
    fi
    local tmp="$PROJECT/.orchestrator-tmp.$$"
    {
      head -n "$start_line" "$file"
      cat "$BLOCK_FILE"
      tail -n +"$end_line" "$file"
    } >"$tmp"
    mv "$tmp" "$file"
  else
    die "ambiguous managed block in $INSTRUCTION_FILE ($starts start / $ends end markers); resolve manually"
  fi
}

install_doc() {
  # usage: install_doc DEST SRC
  mkdir -p "$(dirname "$1")"
  local tmp
  tmp="$(dirname "$1")/.orchestrator-tmp.$$"
  cat "$2" >"$tmp"
  mv "$tmp" "$1"
}

init_project() {
  INSTRUCTION_FILE=$(choose_instruction_file)
  TRACKER=$(choose_tracker)
  DOMAIN_LAYOUT=$(choose_domain_layout)

  echo
  echo "=== Preview ==="
  echo "Instruction file: $INSTRUCTION_FILE"
  echo "--- managed block ---"
  printf '%s\n' "$START_MARKER"
  render_workflow_block
  printf '%s\n' "$END_MARKER"
  echo "--- docs/agents/issue-tracker.md ---"
  render_tracker_doc
  echo "--- docs/agents/domain.md ---"
  render_domain_doc
  echo "=== End preview ==="
  echo

  if "$DRY_RUN"; then
    echo "Dry run: nothing written."
    return 0
  fi
  if ! "$ASSUME_YES"; then
    printf 'Write this project configuration? [y/N] '
    local answer=
    read -r answer || true
    case "$answer" in
    y | Y | yes | YES) ;;
    *)
      echo "Aborted; no project files written."
      return 0
      ;;
    esac
  fi

  ORCH_WORK=$(mktemp -d "${TMPDIR:-/tmp}/pi-orch-setup.XXXXXX")
  trap 'test -z "${ORCH_WORK:-}" || rm -rf "$ORCH_WORK"' EXIT
  BLOCK_FILE="$ORCH_WORK/block"
  render_workflow_block >"$BLOCK_FILE"
  render_tracker_doc >"$ORCH_WORK/tracker"
  render_domain_doc >"$ORCH_WORK/domain"

  update_instruction_file
  install_doc "$PROJECT/docs/agents/issue-tracker.md" "$ORCH_WORK/tracker"
  install_doc "$PROJECT/docs/agents/domain.md" "$ORCH_WORK/domain"
  echo "Project configuration written to $PROJECT."
}

main() {
  parse_args "$@"
  resolve_project
  install_skills
  if [ -n "$PROJECT" ]; then
    init_project
  else
    echo "Skill installation complete (--skip-project: no project initialized)."
  fi
}

main "$@"
