#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
START_MARKER='<!-- pi-implementation-orchestrator:start -->'
END_MARKER='<!-- pi-implementation-orchestrator:end -->'

LEGOUT_SKILLS=(research shape-design grilling domain-modeling write-implementation-plan prototype-question verification-before-completion systematic-debugging orchestrate-implementation merge-worktree make-release)

MODE=apply
INSPECT=false
DRY_RUN_MODE=false
ASSUME_YES=false
REPLACE_CUSTOM=false
TRACKER_CUSTOM_APPROVED=false
DOMAIN_CUSTOM_APPROVED=false
SKIP_PROJECT=false
PROJECT=
PROJECT_ARG=
INSTRUCTION_FILE_CHOICE=auto
TRACKER_CHOICE=auto
TRACKER_DESCRIPTION=
DOMAIN_LAYOUT_CHOICE=auto
SKILL_SCOPE_CHOICE=auto

INSTRUCTION_FILE=
INSTRUCTION_STATUS=
INSTRUCTION_NOTE=
TRACKER=
TRACKER_STATUS=
TRACKER_NOTE=
DOMAIN_LAYOUT=
LAYOUT_STATUS=
LAYOUT_NOTE=
SKILL_SCOPE=
SCOPE_STATUS=
SCOPE_NOTE=
PREREQS_OK=true
POST_INSTALL=false
SYMLINK_PATH=

SKILL_ARGS=()
STEPS_DONE=
ORCH_WORK=
T_REL=()
T_EXIST=()
T_SIG=()
T_MODE=()
T_ACTION=()

usage() {
  cat >&2 <<'EOF'
Usage: ./setup.sh [--project PATH|--skip-project]
            [--instruction-file auto|AGENTS.md|CLAUDE.md] [--tracker auto|github|local|other]
            [--tracker-description TEXT] [--domain-layout auto|single|multi]
            [--skill-scope auto|global|project]
            [--inspect] [--dry-run] [--yes] [--replace-custom]

Modes:
  (default)  resolve choices (explicit flags or questions), validate, preview,
             ask one approval, then install skills/packages and write project docs
  --inspect  read-only report: detected configuration, unresolved choices,
             validation hazards, and a suggested preview command; never prompts,
             installs, or writes anything (incompatible with --dry-run and --yes)
  --dry-run  resolve and validate choices, print the complete preview; install
             and write nothing, never run external installers
  --replace-custom  explicitly allow replacing unrecognized generated-doc
             content; combine with --yes for noninteractive apply
  --yes      noninteractive approval AFTER validation and preview; skips only the
             final confirmation question, never validation

Nothing is installed and no project file is written before approval. Declining
or closing input aborts with zero side effects. Symlinked instruction files,
generated files, or their parent directories under the project root are refused.
EOF
}

bad_usage() {
  echo "error: $*" >&2
  usage
  exit 1
}

die() {
  echo "error: $*" >&2
  if "$POST_INSTALL"; then
    case "$*" in
    *"External installs already performed"*) ;;
    *) echo "External installs already performed: ${STEPS_DONE:-none}; no automatic uninstall is attempted." >&2 ;;
    esac
  fi
  exit 1
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    --project)
      [ $# -ge 2 ] || bad_usage "--project requires a path"
      [ -n "$2" ] || bad_usage "--project requires a non-empty path"
      PROJECT=$2
      shift 2
      ;;
    --skip-project)
      SKIP_PROJECT=true
      shift
      ;;
    --inspect)
      INSPECT=true
      shift
      ;;
    --dry-run)
      DRY_RUN_MODE=true
      shift
      ;;
    --yes)
      ASSUME_YES=true
      shift
      ;;
    --replace-custom)
      REPLACE_CUSTOM=true
      shift
      ;;
    --instruction-file)
      [ $# -ge 2 ] || bad_usage "--instruction-file requires a value"
      INSTRUCTION_FILE_CHOICE=${2-}
      shift 2
      ;;
    --tracker)
      [ $# -ge 2 ] || bad_usage "--tracker requires a value"
      TRACKER_CHOICE=${2-}
      shift 2
      ;;
    --tracker-description)
      [ $# -ge 2 ] || bad_usage "--tracker-description requires a value"
      TRACKER_DESCRIPTION=${2-}
      shift 2
      ;;
    --domain-layout)
      [ $# -ge 2 ] || bad_usage "--domain-layout requires a value"
      DOMAIN_LAYOUT_CHOICE=${2-}
      shift 2
      ;;
    --skill-scope)
      [ $# -ge 2 ] || bad_usage "--skill-scope requires a value"
      SKILL_SCOPE_CHOICE=${2-}
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) bad_usage "unknown flag: $1" ;;
    esac
  done

  case "$INSTRUCTION_FILE_CHOICE" in
  auto | AGENTS.md | CLAUDE.md) ;;
  *) bad_usage "invalid --instruction-file value: ${INSTRUCTION_FILE_CHOICE:-<missing>}" ;;
  esac

  case "$TRACKER_CHOICE" in
  auto | github | local | other) ;;
  *) bad_usage "invalid --tracker value: ${TRACKER_CHOICE:-<missing>}" ;;
  esac
  if [ "$TRACKER_CHOICE" = other ]; then
    case "$TRACKER_DESCRIPTION" in
    *[![:space:]]*) ;;
    *) bad_usage "--tracker other requires a non-empty --tracker-description" ;;
    esac
  fi

  case "$DOMAIN_LAYOUT_CHOICE" in
  auto | single | multi) ;;
  *) bad_usage "invalid --domain-layout value: ${DOMAIN_LAYOUT_CHOICE:-<missing>}" ;;
  esac

  case "$SKILL_SCOPE_CHOICE" in
  auto | global | project) ;;
  *) bad_usage "invalid --skill-scope value: ${SKILL_SCOPE_CHOICE:-<missing>}" ;;
  esac

  if [ -n "$PROJECT" ] && "$SKIP_PROJECT"; then
    bad_usage "choose either --project or --skip-project, not both"
  fi
  if [ "$SKILL_SCOPE_CHOICE" = project ] && "$SKIP_PROJECT"; then
    bad_usage "--skill-scope project requires --project PATH"
  fi
  if "$REPLACE_CUSTOM" && "$SKIP_PROJECT"; then
    bad_usage "--replace-custom requires --project PATH"
  fi
  if [ -z "$PROJECT" ] && ! "$SKIP_PROJECT"; then
    bad_usage "choose either --project PATH or --skip-project"
  fi
  if "$INSPECT" && "$DRY_RUN_MODE"; then
    bad_usage "--inspect cannot be combined with --dry-run"
  fi
  if "$INSPECT" && "$ASSUME_YES"; then
    bad_usage "--inspect cannot be combined with --yes"
  fi
  if "$INSPECT"; then
    MODE=inspect
  elif "$DRY_RUN_MODE"; then
    MODE=dry-run
  fi
}

resolve_project() {
  [ -n "$PROJECT" ] || return 0
  PROJECT_ARG=$PROJECT
  local abs
  abs=$(cd "$PROJECT" 2>/dev/null && pwd -P) || die "project directory not found: $PROJECT"
  PROJECT=$abs
}

ask_choice() {
  local prompt="$1"
  shift
  local opts=("$@")
  local n=${#opts[@]}
  local i ans
  while :; do
    printf '%s:\n' "$prompt" >&2
    i=1
    for opt in ${opts[@]+"${opts[@]}"}; do
      printf '  %d) %s\n' "$i" "$opt" >&2
      i=$((i + 1))
    done
    ans=
    read -r ans || die "standard input closed while asking: $prompt; aborting with no changes"
    if [ -z "$ans" ]; then
      echo "${opts[0]}"
      return
    fi
    case "$ans" in
    *[!0-9]*) ;;
    *)
      if [ "$ans" -ge 1 ] && [ "$ans" -le "$n" ]; then
        echo "${opts[$((ans - 1))]}"
        return
      fi
      ;;
    esac
    printf 'invalid choice: %s\n' "$ans" >&2
  done
}

ask_line() {
  local prompt="$1" default="$2" ans
  printf '%s' "$prompt" >&2
  ans=
  read -r ans || die "standard input closed while asking: $prompt; aborting with no changes"
  if [ -z "$ans" ]; then
    ans="$default"
  fi
  echo "$ans"
}

has_github_origin() {
  git -C "$PROJECT" remote get-url origin 2>/dev/null | grep -q 'github.com'
}

github_origin_url() {
  git -C "$PROJECT" remote get-url origin 2>/dev/null || true
}

has_monorepo_signals() {
  [ -f "$PROJECT/pnpm-workspace.yaml" ] && return 0
  grep -q '"workspaces"' "$PROJECT/package.json" 2>/dev/null && return 0
  find "$PROJECT/packages" -mindepth 2 -maxdepth 2 -type d -name src 2>/dev/null | grep -q . && return 0
  return 1
}

monorepo_evidence() {
  local found=""
  [ -f "$PROJECT/pnpm-workspace.yaml" ] && found="$found pnpm-workspace.yaml"
  if grep -q '"workspaces"' "$PROJECT/package.json" 2>/dev/null; then
    found="$found package.json-workspaces"
  fi
  if find "$PROJECT/packages" -mindepth 2 -maxdepth 2 -type d -name src 2>/dev/null | grep -q .; then
    found="$found packages/*/src"
  fi
  if [ -n "$found" ]; then
    echo "${found# }"
  else
    echo "none"
  fi
}

tracker_doc_label() {
  sed -n 's/^Tracker: \(.*\)\.$/\1/p' "$1" 2>/dev/null | head -n 1
}

recognized_tracker_doc() {
  grep -Eq '^Tracker: .+\.$' "$1" 2>/dev/null
}

layout_doc_label() {
  local label
  label=$(sed -n 's/^Layout: multiple contexts\.$/multiple contexts/p' "$1" 2>/dev/null | head -n 1)
  if [ -z "$label" ]; then
    label=$(sed -n 's/^Layout: single context\.$/single context/p' "$1" 2>/dev/null | head -n 1)
  fi
  echo "$label"
}

recognized_layout_doc() {
  grep -Eq '^Layout: (single context|multiple contexts)\.$' "$1" 2>/dev/null
}

instruction_files_present() {
  local found=""
  [ -f "$PROJECT/AGENTS.md" ] && found="$found AGENTS.md"
  [ -f "$PROJECT/CLAUDE.md" ] && found="$found CLAUDE.md"
  if [ -n "$found" ]; then
    echo "${found# }"
  else
    echo "none"
  fi
}

scope_evidence() {
  if [ -z "$PROJECT" ]; then
    echo "no project (--skip-project); skills install globally"
    return
  fi
  if grep -Eq 'pi-subagents|pi-intercom' "$PROJECT/.pi/settings.json" 2>/dev/null; then
    echo "project .pi/settings.json registers Pi packages (project-scope setup evidence)"
    return
  fi
  if [ -d "$PROJECT/.pi/skills" ] || [ -d "$PROJECT/.agents" ]; then
    echo "project-local skill directories found; verify whether they came from a project-scope setup"
    return
  fi
  echo "no project-scope evidence found; global suggested"
}

detect_instruction_file() {
  if [ -n "$PROJECT" ]; then
    refuse_symlink_ancestors AGENTS.md
    refuse_symlink_ancestors CLAUDE.md
  fi
  if [ "$INSTRUCTION_FILE_CHOICE" != auto ]; then
    INSTRUCTION_FILE=$INSTRUCTION_FILE_CHOICE
    INSTRUCTION_STATUS=explicit
    INSTRUCTION_NOTE="(set by --instruction-file)"
    return
  fi
  local bits=0
  [ -f "$PROJECT/CLAUDE.md" ] && bits=$((bits + 1))
  [ -f "$PROJECT/AGENTS.md" ] && bits=$((bits + 2))
  case "$bits" in
  0)
    INSTRUCTION_FILE=AGENTS.md
    INSTRUCTION_STATUS=unresolved
    INSTRUCTION_NOTE="UNRESOLVED: neither AGENTS.md nor CLAUDE.md exists; AGENTS.md suggested"
    ;;
  1)
    INSTRUCTION_FILE=CLAUDE.md
    INSTRUCTION_STATUS=detected
    INSTRUCTION_NOTE="(existing CLAUDE.md)"
    ;;
  2)
    INSTRUCTION_FILE=AGENTS.md
    INSTRUCTION_STATUS=detected
    INSTRUCTION_NOTE="(existing AGENTS.md)"
    ;;
  3)
    INSTRUCTION_FILE=CLAUDE.md
    INSTRUCTION_STATUS=unresolved
    INSTRUCTION_NOTE="UNRESOLVED: both AGENTS.md and CLAUDE.md exist; CLAUDE.md suggested default"
    ;;
  esac
}

detect_tracker() {
  [ -n "$PROJECT" ] && refuse_symlink_ancestors "docs/agents/issue-tracker.md"
  case "$TRACKER_CHOICE" in
  github)
    TRACKER="GitHub Issues"
    TRACKER_STATUS=explicit
    TRACKER_NOTE="(set by --tracker github)"
    return
    ;;
  local)
    TRACKER="Local Markdown"
    TRACKER_STATUS=explicit
    TRACKER_NOTE="(set by --tracker local)"
    return
    ;;
  other)
    TRACKER=$TRACKER_DESCRIPTION
    TRACKER_STATUS=explicit
    TRACKER_NOTE="(set by --tracker other)"
    return
    ;;
  esac
  local doc="$PROJECT/docs/agents/issue-tracker.md" label
  if [ -f "$doc" ]; then
    label=$(tracker_doc_label "$doc")
    if [ -n "$label" ]; then
      TRACKER=$label
      TRACKER_DESCRIPTION=$label
      TRACKER_STATUS=detected
      TRACKER_NOTE="(existing docs/agents/issue-tracker.md)"
      return
    fi
    TRACKER="GitHub Issues"
    TRACKER_STATUS=unresolved
    TRACKER_NOTE="UNRESOLVED: docs/agents/issue-tracker.md has unrecognized custom content; an explicit replace decision is required"
    return
  fi
  local url
  url=$(github_origin_url)
  if printf '%s' "$url" | grep -q 'github.com'; then
    TRACKER="GitHub Issues"
    TRACKER_STATUS=unresolved
    TRACKER_NOTE="UNRESOLVED: confirm the tracker; GitHub Issues suggested (origin: $url)"
  else
    TRACKER="Local Markdown"
    TRACKER_STATUS=unresolved
    TRACKER_NOTE="UNRESOLVED: confirm the tracker; Local Markdown suggested (no GitHub origin remote)"
  fi
}

detect_domain_layout() {
  [ -n "$PROJECT" ] && refuse_symlink_ancestors "docs/agents/domain.md"
  case "$DOMAIN_LAYOUT_CHOICE" in
  single)
    DOMAIN_LAYOUT="Single context"
    LAYOUT_STATUS=explicit
    LAYOUT_NOTE="(set by --domain-layout single)"
    return
    ;;
  multi)
    DOMAIN_LAYOUT="Multiple contexts"
    LAYOUT_STATUS=explicit
    LAYOUT_NOTE="(set by --domain-layout multi)"
    return
    ;;
  esac
  local doc="$PROJECT/docs/agents/domain.md" layout
  if [ -f "$doc" ]; then
    layout=$(layout_doc_label "$doc")
    if [ -n "$layout" ]; then
      if [ "$layout" = "multiple contexts" ]; then
        DOMAIN_LAYOUT="Multiple contexts"
      else
        DOMAIN_LAYOUT="Single context"
      fi
      LAYOUT_STATUS=detected
      LAYOUT_NOTE="(existing docs/agents/domain.md)"
      return
    fi
    DOMAIN_LAYOUT="Single context"
    LAYOUT_STATUS=unresolved
    LAYOUT_NOTE="UNRESOLVED: docs/agents/domain.md has unrecognized custom content; an explicit replace decision is required"
    return
  fi
  if has_monorepo_signals; then
    DOMAIN_LAYOUT="Single context"
    LAYOUT_STATUS=unresolved
    LAYOUT_NOTE="UNRESOLVED: monorepo signals present ($(monorepo_evidence)); Single context suggested"
  else
    DOMAIN_LAYOUT="Single context"
    LAYOUT_STATUS=resolved
    LAYOUT_NOTE="(no monorepo signals; single context)"
  fi
}

detect_skill_scope() {
  case "$SKILL_SCOPE_CHOICE" in
  global)
    SKILL_SCOPE=Global
    SCOPE_STATUS=explicit
    SCOPE_NOTE="(set by --skill-scope global)"
    return
    ;;
  project)
    SKILL_SCOPE=Project
    SCOPE_STATUS=explicit
    SCOPE_NOTE="(set by --skill-scope project)"
    return
    ;;
  esac
  if [ -n "$PROJECT" ]; then
    SKILL_SCOPE=Global
    SCOPE_STATUS=unresolved
    SCOPE_NOTE="UNRESOLVED: confirm the scope; Global suggested"
  else
    SKILL_SCOPE=Global
    SCOPE_STATUS=resolved
    SCOPE_NOTE="(no project; global)"
  fi
}

resolve_choices() {
  if [ -n "$PROJECT" ]; then
    detect_instruction_file
    if [ "$INSTRUCTION_STATUS" = unresolved ] && [ "$MODE" != inspect ]; then
      if [ -f "$PROJECT/CLAUDE.md" ] && [ -f "$PROJECT/AGENTS.md" ]; then
        INSTRUCTION_FILE=$(ask_choice "Instruction file" "CLAUDE.md" "AGENTS.md")
      else
        INSTRUCTION_FILE=$(ask_choice "Create instruction file" "AGENTS.md" "CLAUDE.md")
      fi
      INSTRUCTION_STATUS=answered
    fi

    detect_tracker
    if [ "$TRACKER_STATUS" = unresolved ] && [ "$MODE" != inspect ]; then
      if has_github_origin; then
        TRACKER=$(ask_choice "Issue tracker" "GitHub Issues" "Local Markdown" "Other")
      else
        TRACKER=$(ask_choice "Issue tracker" "Local Markdown" "GitHub Issues" "Other")
      fi
      if [ "$TRACKER" = "Other" ]; then
        TRACKER=$(ask_line "Describe the tracker in one line: " "Other")
      fi
      TRACKER_STATUS=answered
    fi

    detect_domain_layout
    if [ "$LAYOUT_STATUS" = unresolved ] && [ "$MODE" != inspect ]; then
      DOMAIN_LAYOUT=$(ask_choice "Domain layout" "Single context" "Multiple contexts")
      LAYOUT_STATUS=answered
    fi
  fi

  detect_skill_scope
  if [ "$SCOPE_STATUS" = unresolved ] && [ "$MODE" != inspect ]; then
    SKILL_SCOPE=$(ask_choice "Skill installation scope" "Global" "Project")
    SCOPE_STATUS=answered
  fi
}

count_marker() {
  # usage: count_marker FILE MARKER -> prints every marker occurrence
  if [ ! -f "$1" ]; then
    echo 0
  else
    awk -v marker="$2" '
      function occurrences(line, token, pos, hit, total) {
        pos = 1
        total = 0
        while (pos <= length(line)) {
          hit = index(substr(line, pos), token)
          if (!hit) break
          total++
          pos += hit + length(token) - 1
        }
        return total
      }
      { count += occurrences($0, marker) }
      END { print count + 0 }
    ' "$1"
  fi
}

marker_invalid() {
  # usage: marker_invalid FILE MARKER -> prints 1 for malformed occurrences
  if [ ! -f "$1" ]; then
    echo 0
  elif [ "$2" = "$START_MARKER" ]; then
    awk -v marker="$2" '
      function occurrences(line, token, pos, hit, total) {
        pos = 1
        total = 0
        while (pos <= length(line)) {
          hit = index(substr(line, pos), token)
          if (!hit) break
          total++
          pos += hit + length(token) - 1
        }
        return total
      }
      {
        total = occurrences($0, marker)
        if (total > 0 && !(($0 == marker) ||
            (length($0) > length(marker) &&
             substr($0, length($0) - length(marker) + 1) == marker &&
             index(substr($0, 1, length($0) - length(marker)), marker) == 0))) {
          invalid = 1
        }
        if (total > 1) invalid = 1
      }
      END { print invalid + 0 }
    ' "$1"
  else
    awk -v marker="$2" '
      function occurrences(line, token, pos, hit, total) {
        pos = 1
        total = 0
        while (pos <= length(line)) {
          hit = index(substr(line, pos), token)
          if (!hit) break
          total++
          pos += hit + length(token) - 1
        }
        return total
      }
      {
        total = occurrences($0, marker)
        if (total > 0 && $0 != marker) invalid = 1
        if (total > 1) invalid = 1
      }
      END { print invalid + 0 }
    ' "$1"
  fi
}

marker_line() {
  # usage: marker_line FILE MARKER -> prints the first marker line
  if [ "$2" = "$START_MARKER" ]; then
    awk -v marker="$2" '$0 == marker || (length($0) > length(marker) && substr($0, length($0) - length(marker) + 1) == marker && index(substr($0, 1, length($0) - length(marker)), marker) == 0) { print NR; exit }' "$1"
  else
    grep -n -F -x "$2" "$1" | cut -d: -f1
  fi
}

validate_managed_block() {
  local file="$1" starts ends start_line end_line
  starts=$(count_marker "$file" "$START_MARKER")
  ends=$(count_marker "$file" "$END_MARKER")
  if [ "$(marker_invalid "$file" "$START_MARKER")" = 1 ] || [ "$(marker_invalid "$file" "$END_MARKER")" = 1 ]; then
    die "malformed managed block in $file: marker text must be on its own line or a single start marker may suffix an unterminated prefix; resolve it manually (nothing has been modified)"
  fi
  if [ "$starts" = 0 ] && [ "$ends" = 0 ]; then
    return 0
  fi
  if [ "$starts" = 1 ] && [ "$ends" = 1 ]; then
    start_line=$(marker_line "$file" "$START_MARKER")
    end_line=$(marker_line "$file" "$END_MARKER")
    if [ "$end_line" -gt "$start_line" ]; then
      return 0
    fi
    die "malformed managed block in $file: the end marker appears before the start marker; resolve it manually (nothing has been modified)"
  fi
  die "malformed managed block in $file: found $starts start / $ends end markers (expected 0 or 1 of each); resolve it manually (nothing has been modified)"
}

has_symlink_ancestor() {
  # usage: has_symlink_ancestor RELPATH — returns success and records the first
  # symlink from the project root down to (and including) RELPATH
  local rel="$1" prefix="$PROJECT" part
  local IFS=/
  SYMLINK_PATH=
  if [ -L "$PROJECT" ]; then
    SYMLINK_PATH="$PROJECT"
    return 0
  fi
  for part in $rel; do
    prefix="$prefix/$part"
    if [ -L "$prefix" ]; then
      SYMLINK_PATH="$prefix"
      return 0
    fi
  done
  return 1
}

refuse_symlink_ancestors() {
  # usage: refuse_symlink_ancestors RELPATH — refuses symlinks from the project
  # root down to (and including) RELPATH
  if has_symlink_ancestor "$1"; then
    die "refusing to operate through the symlink: $SYMLINK_PATH
setup never follows, replaces, or unlinks instruction/generated paths or their parent directories below the project root; nothing has been modified. Point setup at a regular file/directory or resolve this link outside setup."
  fi
}

deepest_existing_ancestor() {
  local d
  d=$(dirname "$1")
  while [ ! -e "$d" ]; do
    d=$(dirname "$d")
  done
  echo "$d"
}

require_creatable() {
  local path="$1" d
  d=$(deepest_existing_ancestor "$path")
  [ -d "$d" ] || die "cannot create $path: $d exists and is not a directory (nothing has been modified)"
  [ -x "$d" ] || die "cannot create $path: $d is not searchable (nothing has been modified)"
  [ -w "$d" ] || die "cannot create $path: $d is not writable (nothing has been modified)"
}

validate_output_file() {
  # usage: validate_output_file RELPATH DESCRIPTION
  local rel="$1" desc="$2" path parent
  path="$PROJECT/$rel"
  refuse_symlink_ancestors "$rel"
  if [ -e "$path" ]; then
    [ -f "$path" ] || die "$desc exists and is not a regular file: $path (nothing has been modified)"
    parent=$(dirname "$path")
    [ -d "$parent" ] || die "$desc parent is not a directory: $parent (nothing has been modified)"
    [ -x "$parent" ] || die "$desc parent is not searchable: $parent (nothing has been modified)"
    [ -w "$parent" ] || die "$desc parent is not writable: $parent (nothing has been modified)"
    [ -w "$path" ] || die "$desc exists and is not writable: $path (nothing has been modified)"
  else
    require_creatable "$path"
  fi
}

validate_dir_target() {
  # usage: validate_dir_target RELPATH DESCRIPTION
  local rel="$1" desc="$2" path
  path="$PROJECT/$rel"
  refuse_symlink_ancestors "$rel"
  if [ -e "$path" ]; then
    [ -d "$path" ] || die "$desc exists and is not a directory: $path (nothing has been modified)"
    [ -x "$path" ] || die "$desc is not searchable: $path (nothing has been modified)"
    [ -w "$path" ] || die "$desc exists and is not writable: $path (nothing has been modified)"
  fi
}

validate_project_outputs() {
  [ -n "$PROJECT" ] || return 0
  validate_output_file "$INSTRUCTION_FILE" "instruction file"
  validate_managed_block "$PROJECT/$INSTRUCTION_FILE"
  validate_dir_target "docs" "docs directory"
  validate_dir_target "docs/agents" "docs/agents directory"
  validate_output_file "docs/agents/issue-tracker.md" "generated tracker doc"
  validate_output_file "docs/agents/domain.md" "generated domain doc"
}

resolve_custom_doc_decisions() {
  [ -n "$PROJECT" ] || return 0
  local doc
  doc="$PROJECT/docs/agents/issue-tracker.md"
  if tracker_doc_requires_replace "$doc" && ! "$REPLACE_CUSTOM"; then
    custom_doc_decision "$doc"
  fi
  doc="$PROJECT/docs/agents/domain.md"
  if domain_doc_requires_replace "$doc" && ! "$REPLACE_CUSTOM"; then
    custom_doc_decision "$doc"
  fi
}

custom_doc_decision() {
  local doc="$1"
  if [ "$MODE" = inspect ] || [ "$MODE" = dry-run ]; then
    return 0
  fi
  if "$ASSUME_YES"; then
    die "$doc contains custom content that setup does not own; --yes cannot decide to replace it. Re-run with --replace-custom only after explicitly approving the replacement, or edit/remove the file yourself (nothing has been modified)."
  fi
  printf 'Replace custom content in %s with the generated file? [y/N] ' "$doc"
  local answer=
  read -r answer || die "standard input closed while deciding about $doc; aborting with no changes"
  case "$answer" in
  y | Y | yes | YES)
    if [ "$doc" = "$PROJECT/docs/agents/issue-tracker.md" ]; then
      TRACKER_CUSTOM_APPROVED=true
    else
      DOMAIN_CUSTOM_APPROVED=true
    fi
    ;;
  *)
    echo "Aborted; nothing was installed or written."
    exit 0
    ;;
  esac
}

build_skill_args() {
  SKILL_ARGS=(npx skills add legout/skills)
  local s
  for s in ${LEGOUT_SKILLS[@]+"${LEGOUT_SKILLS[@]}"}; do
    SKILL_ARGS+=(--skill "$s")
  done
  if [ "$SKILL_SCOPE" = Project ]; then
    SKILL_ARGS+=(--agent pi --yes --copy)
  else
    SKILL_ARGS+=(--global --agent pi --yes --copy)
  fi
}

render_install_lines() {
  printf '+'
  printf ' %q' ${SKILL_ARGS[@]+"${SKILL_ARGS[@]}"}
  printf '\n'
  if [ "$SKILL_SCOPE" = Project ]; then
    printf '+ (cd %q && pi install --local npm:pi-subagents)\n' "$PROJECT"
    printf '+ (cd %q && pi install --local npm:pi-intercom)\n' "$PROJECT"
  else
    printf '%s\n' '+ pi install npm:pi-subagents' '+ pi install npm:pi-intercom'
  fi
}

require_prereqs() {
  # usage: require_prereqs report|enforce
  local missing=""
  command -v git >/dev/null 2>&1 || missing="$missing git"
  command -v npx >/dev/null 2>&1 || missing="$missing npx"
  command -v pi >/dev/null 2>&1 || missing="$missing pi"
  command -v node >/dev/null 2>&1 || missing="$missing node"
  if [ -z "$missing" ]; then
    PREREQS_OK=true
    echo "Prerequisites: git ok, npx ok, pi ok, node ok."
    return 0
  fi
  PREREQS_OK=false
  echo "Prerequisites: MISSING:$missing — installation stops before installing or writing anything until these prerequisites are available."
  if [ "${1:-}" = enforce ]; then
    echo "error: required prerequisites not available:$missing" >&2
    exit 1
  fi
}

render_workflow_block() {
  cat <<'EOF'
## Agent workflow

- Every task declares one test obligation: `new-test`, `existing-check`, or `no-new-test`; focused TDD is required only for `new-test` work.
- Review is adaptive and orchestrator-owned: high-risk or dependency-defining changes are reviewed immediately; low-risk changes may be reviewed cumulatively at a wave boundary.
- Plans and tickets reference exact feature sources; this file defines stable repository-wide scope.
- Source precedence: current owner decision → accepted ADR → approved specification → implementation plan → ticket → existing implementation.
- Stop before implementation when authoritative sources conflict.

### Routing and authority

- Read `docs/agents/issue-tracker.md` and `docs/agents/domain.md` when their scope applies; preserve established project conventions.
- Use `shape-design` for unresolved behavior/design choices, `write-implementation-plan` for approved multi-step work, and `orchestrate-implementation` to execute approved work. Do not turn a trivial edit into a planning exercise.
- Default orchestrated execution to `supervised`: workers may implement and validate, but candidate assembly, integration, and publication retain explicit approval gates.
- Keep one writer per worktree. Use `pi-subagents` for spawned-child lifecycle; named persistent `pi-intercom` peers are read-only advisors, not workers or schedulers.
- Use `systematic-debugging` for unexpected failures and `verification-before-completion` before success claims; match evidence to the exact change and report skipped checks.
- Use `merge-worktree` for target integration and `make-release` for releases. Local integration does not authorize pushing; opening a PR does not authorize merging; release or publication requires its own approved plan.
- Stop on conflicting authoritative sources, unclear ownership, failed required gates, or missing required tooling. Never silently switch execution modes to bypass a blocker.

### Documentation map

EOF
  if [ "$DOMAIN_LAYOUT" = "Multiple contexts" ]; then
    cat <<'EOF'
- `docs/agents/domain.md`: this repository's context-layout declaration.
- Per-context `CONTEXT.md` files: canonical vocabulary for their package or context. No single root `CONTEXT.md` is canonical here.
- `CONTEXT-MAP.md`, when present: the map of real contexts and their glossaries; read it before recording vocabulary or new contexts.
- `docs/adr/`: accepted architecture decisions.
- `docs/specs/` or the configured tracker: feature behavior and acceptance.
- implementation plans/tickets: execution entry points and explicit source references.
EOF
  else
    cat <<'EOF'
- `CONTEXT.md`: canonical domain vocabulary for the whole repository.
- `docs/adr/`: accepted architecture decisions.
- `docs/agents/`: workflow and tracker configuration.
- `docs/specs/` or the configured tracker: feature behavior and acceptance.
- implementation plans/tickets: execution entry points and explicit source references.
EOF
  fi
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
    cat <<'EOF'
Layout: multiple contexts.

Each package or context owns the `CONTEXT.md` beside it; no root `CONTEXT.md` is canonical for this repository. Context glossaries live with their package (for example `packages/<name>/CONTEXT.md`), or wherever `CONTEXT-MAP.md` records them.

Consume an existing `CONTEXT-MAP.md` as-is: it maps the real contexts and their glossaries. When context ownership for a term is missing or ambiguous, inspect the package layout and ask the owner which context owns it; do not create a root or global glossary to resolve the ambiguity.

Cross-cutting decisions live in docs/adr/.
EOF
  else
    cat <<'EOF'
Layout: single context.

- CONTEXT.md: canonical domain vocabulary for the whole repository.
- docs/adr/: accepted architecture decisions.
EOF
  fi
}

tracker_doc_is_owned() {
  local doc="$1"
  render_tracker_doc | cmp -s - "$doc" && return 0
  if [ -n "$TRACKER" ]; then
    {
      echo "# Issue tracker"
      echo
      echo "Tracker: $TRACKER."
    } | cmp -s - "$doc" && return 0
  fi
  return 1
}

domain_doc_is_owned() {
  local doc="$1"
  render_domain_doc | cmp -s - "$doc" && return 0
  if [ -n "$DOMAIN_LAYOUT" ]; then
    {
      echo "# Domain documentation"
      echo
      if [ "$DOMAIN_LAYOUT" = "Multiple contexts" ]; then
        echo "Layout: multiple contexts."
      else
        echo "Layout: single context."
      fi
    } | cmp -s - "$doc" && return 0
  fi
  return 1
}

tracker_doc_requires_replace() {
  local doc="$1"
  [ -f "$doc" ] || return 1
  tracker_doc_is_owned "$doc" && return 1
  return 0
}

domain_doc_requires_replace() {
  local doc="$1"
  [ -f "$doc" ] || return 1
  domain_doc_is_owned "$doc" && return 1
  return 0
}

render_before_inline_start() {
  # Preserve an existing instruction file's final unterminated line exactly;
  # the generated start marker is appended directly to that byte stream.
  local file="$1" line
  line=$(marker_line "$file" "$START_MARKER")
  if [ "$line" -gt 1 ]; then
    head -n $((line - 1)) "$file"
  fi
  awk -v marker="$START_MARKER" -v target="$line" '
    NR == target {
      offset = index($0, marker)
      printf "%s", substr($0, 1, offset - 1)
      exit
    }
  ' "$file"
}

render_instruction_file() {
  # streams the complete resulting instruction file; never writes anything
  refuse_symlink_ancestors "$INSTRUCTION_FILE"
  local file="$PROJECT/$INSTRUCTION_FILE" starts ends start_line end_line
  if [ ! -f "$file" ]; then
    printf '%s\n' "$START_MARKER"
    render_workflow_block
    printf '%s\n' "$END_MARKER"
    return
  fi
  starts=$(count_marker "$file" "$START_MARKER")
  ends=$(count_marker "$file" "$END_MARKER")
  if [ "$starts" = 0 ] && [ "$ends" = 0 ]; then
    if [ -s "$file" ]; then
      cat "$file"
    fi
    printf '%s\n' "$START_MARKER"
    render_workflow_block
    printf '%s\n' "$END_MARKER"
    return
  fi
  start_line=$(marker_line "$file" "$START_MARKER")
  end_line=$(marker_line "$file" "$END_MARKER")
  if grep -F -x "$START_MARKER" "$file" >/dev/null 2>&1; then
    head -n "$start_line" "$file"
  else
    render_before_inline_start "$file"
    printf '%s\n' "$START_MARKER"
  fi
  render_workflow_block
  tail -n "+$end_line" "$file"
}

file_mode() {
  local m
  # GNU stat accepts -f as a filesystem query and still exits successfully.
  m=$(stat -c %a "$1" 2>/dev/null || true)
  case "$m" in
  ''|*[!0-7]*) m=$(stat -f %Lp "$1" 2>/dev/null || true) ;;
  esac
  case "$m" in
  ''|*[!0-7]*) m=644 ;;
  esac
  echo "$m"
}

same_file_contents() {
  cmp -s "$1" "$2"
}

stat_sig() {
  local s
  s=$(stat -c '%s:%Y' "$1" 2>/dev/null || true)
  case "$s" in
  ''|*[!0-9:]*) s=$(stat -f '%z:%m' "$1" 2>/dev/null || true) ;;
  esac
  case "$s" in
  ''|*[!0-9:]*) s= ;;
  esac
  echo "$s:$(file_mode "$1")"
}

print_preview() {
  local inst_doc="$PROJECT/$INSTRUCTION_FILE"
  local tracker_doc="$PROJECT/docs/agents/issue-tracker.md"
  local domain_doc="$PROJECT/docs/agents/domain.md"
  echo "=== Preview ==="
  echo "Skill scope: $SKILL_SCOPE"
  if [ -n "$PROJECT" ]; then
    echo "Project: $PROJECT"
  else
    echo "Project: none (--skip-project)"
  fi
  echo "--- install commands (run only after approval) ---"
  render_install_lines
  echo
  require_prereqs report
  if [ -n "$PROJECT" ]; then
    echo
    if [ -f "$inst_doc" ]; then
      echo "--- $INSTRUCTION_FILE (managed block updated; all bytes outside the markers are preserved byte-for-byte) ---"
    else
      echo "--- $INSTRUCTION_FILE (new file) ---"
    fi
    render_instruction_file
    echo "--- docs/agents/issue-tracker.md ($(preview_doc_action "$tracker_doc")) ---"
    render_tracker_doc
    echo "--- docs/agents/domain.md ($(preview_doc_action "$domain_doc")) ---"
    render_domain_doc
  fi
  echo "=== End preview ==="
}

preview_doc_action() {
  local approved=false
  if [ "$1" = "$PROJECT/docs/agents/issue-tracker.md" ] && tracker_doc_requires_replace "$1"; then
    approved="$TRACKER_CUSTOM_APPROVED"
    if "$REPLACE_CUSTOM" || "$approved"; then
      echo "custom content (replacement explicitly approved)"
    else
      echo "custom content (requires --replace-custom)"
    fi
  elif [ "$1" = "$PROJECT/docs/agents/domain.md" ] && domain_doc_requires_replace "$1"; then
    approved="$DOMAIN_CUSTOM_APPROVED"
    if "$REPLACE_CUSTOM" || "$approved"; then
      echo "custom content (replacement explicitly approved)"
    else
      echo "custom content (requires --replace-custom)"
    fi
  elif [ ! -f "$1" ]; then
    echo "new file"
  elif [ -s "$1" ]; then
    echo "replaces the existing generated file"
  else
    echo "replaces the existing empty file"
  fi
}

prepare_target() {
  # usage: prepare_target IDX RELPATH STAGEFILE
  local idx="$1" rel="$2" stage="$3"
  refuse_symlink_ancestors "$rel"
  T_REL[$idx]=$rel
  T_STAGE[$idx]=$stage
  if [ -f "$PROJECT/$rel" ]; then
    T_EXIST[$idx]=yes
    T_SIG[$idx]=$(stat_sig "$PROJECT/$rel")
    T_MODE[$idx]=$(file_mode "$PROJECT/$rel")
  else
    T_EXIST[$idx]=no
    T_SIG[$idx]=""
    T_MODE[$idx]=644
  fi
}

stage_files() {
  validate_project_outputs
  ORCH_WORK=$(mktemp -d "${TMPDIR:-/tmp}/pi-orchestrator-setup.XXXXXX")
  trap 'test -z "${ORCH_WORK:-}" || rm -rf "$ORCH_WORK"' EXIT
  render_instruction_file >"$ORCH_WORK/instruction"
  render_tracker_doc >"$ORCH_WORK/tracker"
  render_domain_doc >"$ORCH_WORK/domain"
  T_REL=()
  T_STAGE=()
  T_EXIST=()
  T_SIG=()
  T_MODE=()
  T_ACTION=()
  prepare_target 1 docs/agents/issue-tracker.md tracker
  prepare_target 2 docs/agents/domain.md domain
  prepare_target 3 "$INSTRUCTION_FILE" instruction
  local idx
  for idx in 1 2 3; do
    chmod "${T_MODE[$idx]}" "$ORCH_WORK/${T_STAGE[$idx]}" || die "failed to stage $ORCH_WORK/${T_STAGE[$idx]} (nothing has been modified)"
  done
}

concurrent_change_error() {
  echo "error: destination changed concurrently or is no longer a regular file: $1; rerun setup to converge" >&2
}

install_doc() {
  # usage: install_doc DEST STAGEFILE IDX — write a staged file atomically
  local dest="$1" stage="$2" idx="$3"
  local dir base tmp oldpwd had sig mode
  had=${T_EXIST[$idx]}
  sig=${T_SIG[$idx]}
  dir=$(dirname "$dest")
  base=$(basename "$dest")
  if has_symlink_ancestor "${T_REL[$idx]}"; then
    concurrent_change_error "$dest"
    return 1
  fi
  if [ "$had" = yes ]; then
    if [ ! -f "$dest" ] || [ "$(stat_sig "$dest")" != "$sig" ]; then
      concurrent_change_error "$dest"
      return 1
    fi
  elif [ -e "$dest" ]; then
    concurrent_change_error "$dest"
    return 1
  fi

  oldpwd=$(pwd)
  if ! cd "$dir" || [ "$(pwd -P)" != "$dir" ]; then
    cd "$oldpwd" || true
    concurrent_change_error "$dest"
    return 1
  fi
  if has_symlink_ancestor "${T_REL[$idx]}"; then
    cd "$oldpwd" || true
    concurrent_change_error "$dest"
    return 1
  fi
  tmp=$(mktemp "./.pi-orchestrator-setup.XXXXXX") || {
    cd "$oldpwd" || true
    return 1
  }
  if ! cat "$ORCH_WORK/$stage" >"$tmp"; then
    rm -f "$tmp"
    cd "$oldpwd" || true
    return 1
  fi
  mode=${T_MODE[$idx]:-644}
  if ! chmod "$mode" "$tmp"; then
    rm -f "$tmp"
    cd "$oldpwd" || true
    return 1
  fi
  if has_symlink_ancestor "${T_REL[$idx]}"; then
    rm -f "$tmp"
    cd "$oldpwd" || true
    concurrent_change_error "$dest"
    return 1
  fi
  if [ "$had" = yes ]; then
    if [ ! -f "$base" ] || [ "$(stat_sig "$base")" != "$sig" ]; then
      rm -f "$tmp"
      cd "$oldpwd" || true
      concurrent_change_error "$dest"
      return 1
    fi
  elif [ -e "$base" ]; then
    rm -f "$tmp"
    cd "$oldpwd" || true
    concurrent_change_error "$dest"
    return 1
  fi
  if ! mv -f "$tmp" "$base"; then
    rm -f "$tmp"
    cd "$oldpwd" || true
    return 1
  fi
  cd "$oldpwd" || return 1
  if [ "$had" = yes ]; then
    T_ACTION[$idx]=updated
  else
    T_ACTION[$idx]=created
  fi
  return 0
}

handle_write_failure() {
  # usage: handle_write_failure RC IDX
  local idx="$2"
  die "project write failed for ${T_REL[$idx]}; files already written remain in place. Rerun setup to converge. External installs already performed remain installed; no automatic uninstall is attempted."
}

handle_directory_failure() {
  local path="$1"
  die "project directory creation failed: $path. Rerun setup to converge. External installs already performed remain installed; no automatic uninstall is attempted."
}

create_project_dir() {
  local rel="$1" full="$PROJECT/$1" parent base oldpwd
  parent=$(dirname "$full")
  base=$(basename "$full")
  if has_symlink_ancestor "$rel"; then
    return 1
  fi
  oldpwd=$(pwd)
  if ! cd "$parent" || [ "$(pwd -P)" != "$parent" ]; then
    cd "$oldpwd" || true
    return 1
  fi
  if [ -L "$base" ] || [ -e "$base" ] && [ ! -d "$base" ]; then
    cd "$oldpwd" || true
    return 1
  fi
  if [ -d "$base" ]; then
    cd "$oldpwd" || true
    return 0
  fi
  if ! mkdir "$base"; then
    cd "$oldpwd" || true
    return 1
  fi
  cd "$oldpwd" || return 1
  return 0
}

write_project_files() {
  # Recheck output symlink boundaries after external installs.
  refuse_symlink_ancestors "$INSTRUCTION_FILE"
  refuse_symlink_ancestors docs
  refuse_symlink_ancestors docs/agents
  create_project_dir docs || handle_directory_failure "$PROJECT/docs"
  create_project_dir docs/agents || handle_directory_failure "$PROJECT/docs/agents"
  install_doc "$PROJECT/docs/agents/issue-tracker.md" tracker 1 || handle_write_failure "$?" 1
  install_doc "$PROJECT/docs/agents/domain.md" domain 2 || handle_write_failure "$?" 2
  install_doc "$PROJECT/$INSTRUCTION_FILE" instruction 3 || handle_write_failure "$?" 3
}

exec_install() {
  # usage: exec_install DESCRIPTION CMD...
  local desc="$1"
  shift
  if [ "$SKILL_SCOPE" = Project ]; then
    (cd "$PROJECT" && "$@") ||
      die "external installation failed: $desc. No project files were changed. External steps already completed: ${STEPS_DONE:-none}."
  else
    "$@" ||
      die "external installation failed: $desc. No project files were changed. External steps already completed: ${STEPS_DONE:-none}."
  fi
  STEPS_DONE="${STEPS_DONE:+$STEPS_DONE; }$desc"
}

run_installs() {
  STEPS_DONE=
  exec_install "npx skills add legout/skills (${#LEGOUT_SKILLS[@]} skills)" ${SKILL_ARGS[@]+"${SKILL_ARGS[@]}"}
  if [ "$SKILL_SCOPE" = Project ]; then
    exec_install "pi install --local npm:pi-subagents" pi install --local npm:pi-subagents
    exec_install "pi install --local npm:pi-intercom" pi install --local npm:pi-intercom
  else
    exec_install "pi install npm:pi-subagents" pi install npm:pi-subagents
    exec_install "pi install npm:pi-intercom" pi install npm:pi-intercom
  fi
}

apply_phase() {
  print_preview
  echo
  if ! "$ASSUME_YES"; then
    if [ -n "$PROJECT" ]; then
      printf 'Install the listed skills/packages and write this project configuration? [y/N] '
    else
      printf 'Install the listed skills and packages? [y/N] '
    fi
    local answer=
    read -r answer || die "standard input closed before approval; aborting with no changes"
    case "$answer" in
    y | Y | yes | YES) ;;
    *)
      echo "Aborted; nothing was installed or written."
      exit 0
      ;;
    esac
  fi
  require_prereqs enforce
  if [ -n "$PROJECT" ]; then
    stage_files
  fi
  run_installs
  POST_INSTALL=true
  if [ -n "$PROJECT" ]; then
    write_project_files
  fi
  echo
  echo "Setup complete ($SKILL_SCOPE skill scope)."
  if [ -n "$PROJECT" ]; then
    echo "Project files in $PROJECT:"
    echo "  $INSTRUCTION_FILE: managed block ${T_ACTION[3]:-written}"
    echo "  docs/agents/issue-tracker.md: ${T_ACTION[1]:-written}"
    echo "  docs/agents/domain.md: ${T_ACTION[2]:-written}"
  fi
}

suggested_command() {
  local cmd="./setup.sh" tflag tdesc
  if [ -n "$PROJECT" ]; then
    cmd="$cmd --project $(printf '%q' "$PROJECT")"
  else
    cmd="$cmd --skip-project"
  fi
  if [ -n "$PROJECT" ]; then
    cmd="$cmd --instruction-file ${INSTRUCTION_FILE:-AGENTS.md}"
    case "${TRACKER:-GitHub Issues}" in
    "GitHub Issues") tflag=github ;;
    "Local Markdown") tflag=local ;;
    *) tflag=other ;;
    esac
    cmd="$cmd --tracker $tflag"
    if [ "$tflag" = other ]; then
      if [ -n "$TRACKER_DESCRIPTION" ]; then
        tdesc=$(printf '%q' "$TRACKER_DESCRIPTION")
      else
        tdesc='<tracker-description>'
      fi
      cmd="$cmd --tracker-description $tdesc"
    fi
    if [ "${DOMAIN_LAYOUT:-Single context}" = "Multiple contexts" ]; then
      cmd="$cmd --domain-layout multi"
    else
      cmd="$cmd --domain-layout single"
    fi
    if tracker_doc_requires_replace "$PROJECT/docs/agents/issue-tracker.md" || domain_doc_requires_replace "$PROJECT/docs/agents/domain.md"; then
      cmd="$cmd --replace-custom"
    fi
  fi
  if [ "${SKILL_SCOPE:-Global}" = Project ]; then
    cmd="$cmd --skill-scope project"
  else
    cmd="$cmd --skill-scope global"
  fi
  echo "$cmd --dry-run"
}

inspect_report() {
  echo "=== pi-implementation-orchestrator --inspect (read-only) ==="
  echo "Setup script: $ROOT/setup.sh"
  if [ -n "$PROJECT" ]; then
    echo "Project: $PROJECT"
    if [ "$PROJECT_ARG" != "$PROJECT" ]; then
      echo "Canonicalized from: $PROJECT_ARG"
    fi
    echo "Instruction files present: $(instruction_files_present)"
    echo "GitHub origin: $(github_origin_url || echo none)"
    echo "Monorepo signals: $(monorepo_evidence)"
    echo "Skill scope evidence: $(scope_evidence)"
  else
    echo "Project: none (--skip-project)"
    echo "Skill scope evidence: $(scope_evidence)"
  fi
  echo
  echo "Choices (--instruction-file / --tracker / --domain-layout / --skill-scope):"
  if [ -n "$PROJECT" ]; then
    echo "  instruction-file: ${INSTRUCTION_FILE:-?} [$INSTRUCTION_STATUS] $INSTRUCTION_NOTE"
    echo "  tracker: ${TRACKER:-?} [$TRACKER_STATUS] $TRACKER_NOTE"
    echo "  domain-layout: ${DOMAIN_LAYOUT:-?} [$LAYOUT_STATUS] $LAYOUT_NOTE"
  else
    echo "  instruction-file / tracker / domain-layout: not applicable without --project"
  fi
  echo "  skill-scope: ${SKILL_SCOPE:-?} [$SCOPE_STATUS] $SCOPE_NOTE"
  if [ -n "$PROJECT" ]; then
    echo "Generated docs:"
    if tracker_doc_requires_replace "$PROJECT/docs/agents/issue-tracker.md"; then
      echo "  docs/agents/issue-tracker.md: UNRESOLVED unrecognized custom content; pass --replace-custom only after explicit approval"
    else
      echo "  docs/agents/issue-tracker.md: owned/generated configuration"
    fi
    if domain_doc_requires_replace "$PROJECT/docs/agents/domain.md"; then
      echo "  docs/agents/domain.md: UNRESOLVED unrecognized custom content; pass --replace-custom only after explicit approval"
    else
      echo "  docs/agents/domain.md: owned/generated configuration"
    fi
  fi
  require_prereqs report
  echo
  if "$PREREQS_OK"; then
    echo "Validation: OK — no symlink, managed-marker, destination-kind, or writability hazards found."
  else
    echo "Validation: project outputs OK; required install prerequisites are missing (see above). Apply will stop before mutation."
  fi
  echo
  echo "Suggested preview command (review its output, then replace --dry-run with --yes only after approval):"
  echo "  $(suggested_command)"
  echo
  echo "Inspect is read-only: nothing was installed, asked, or written."
}

main() {
  parse_args "$@"
  resolve_project
  resolve_choices
  if [ "$MODE" = inspect ]; then
    validate_project_outputs
    inspect_report
    exit 0
  fi
  validate_project_outputs
  resolve_custom_doc_decisions
  build_skill_args
  if [ "$MODE" = dry-run ]; then
    print_preview
    echo
    echo "Dry run: nothing was installed, executed, or written."
    exit 0
  fi
  apply_phase
}

main "$@"
