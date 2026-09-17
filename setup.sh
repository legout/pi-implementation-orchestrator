#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
START_MARKER='<!-- pi-implementation-orchestrator:start -->'
END_MARKER='<!-- pi-implementation-orchestrator:end -->'

LEGOUT_SKILLS=(research shape-design grilling domain-modeling write-implementation-plan prototype-question verification-before-completion systematic-debugging orchestrate-implementation merge-worktree make-release planning-contract)

MODE=apply
OPERATION=install
INSPECT=false
DRY_RUN_MODE=false
ASSUME_YES=false
REPLACE_CUSTOM=false
MIGRATE_NAMESPACE=false
BIN_LINK=false
BIN_LINK_PATH=
MIGRATE_DIRS=(agents research adr specs plans tickets)
MIGRATE_MOVES=()
TRACKER_CUSTOM_APPROVED=false
DOMAIN_CUSTOM_APPROVED=false
ARTIFACTS_CUSTOM_APPROVED=false
SKIP_PROJECT=false
PROJECT=
PROJECT_ARG=
INSTRUCTION_FILE_CHOICE=auto
TRACKER_CHOICE=auto
TRACKER_DESCRIPTION=
DOMAIN_LAYOUT_CHOICE=auto
SKILL_SCOPE_CHOICE=auto
WORKER_MODEL_CHOICE=keep
REVIEWER_MODEL_CHOICE=keep
WORKER_THINKING_CHOICE=keep
REVIEWER_THINKING_CHOICE=keep
MODEL_FLAGS_EXPLICIT=false

INSTRUCTION_FILE=
INSTRUCTION_STATUS=
INSTRUCTION_NOTE=
TRACKER=
TRACKER_PROFILE=
TRACKER_STATUS=
TRACKER_NOTE=
MCP_CONFIG_PATH=
MCP_CONFIG_STATUS=
MCP_CONFIG_NOTE=
MCP_CONFIG_STAGE=
MCP_CONFIG_EXIST=
MCP_CONFIG_SIG=
MCP_CONFIG_MODE=
MCP_CONFIG_ACTION=
MCP_SYMLINK_PATH=
PROJECT_NS=project
NS_AGENTS=
NS_ARTIFACTS=
NS_TRACKER=
NS_DOMAIN=
NS_RESEARCH=
NS_ADR=
NS_SPECS=
NS_PLANS=
NS_TICKETS=
DOMAIN_LAYOUT=
LAYOUT_STATUS=
LAYOUT_NOTE=
SKILL_SCOPE=
SCOPE_STATUS=
SCOPE_NOTE=
SUBAGENT_SETTINGS_PATH=
PREREQS_OK=true
POST_INSTALL=false
SYMLINK_PATH=

SKILL_ARGS=()
UPDATE_SKILLS=()
UPDATE_PI_PACKAGES=()
UPDATE_SKILL_MISSING=()
UPDATE_PI_MISSING=()
UPDATE_PINNED=()
_UPDATE_STATUS=
_UPDATE_NOTE=
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
            [--instruction-file auto|AGENTS.md|CLAUDE.md] [--tracker auto|github|epiq|local|other]
            [--tracker-description TEXT] [--domain-layout auto|single|multi]
            [--skill-scope auto|global|project]
            [--worker-model keep|inherit|PROVIDER/MODEL]
            [--reviewer-model keep|inherit|PROVIDER/MODEL]
            [--worker-thinking keep|inherit|off|minimal|low|medium|high|xhigh|max]
            [--reviewer-thinking keep|inherit|off|minimal|low|medium|high|xhigh|max]
            [--update] [--inspect] [--dry-run] [--yes] [--replace-custom] [--migrate-namespace]
            [--bin-link]

Modes:
  (default)  resolve choices (explicit flags or questions), validate, preview,
             ask one approval, then install skills/packages, copy prompt
             commands to the selected scope's prompt directory, and write
             project docs
  --inspect  read-only report: detected configuration, unresolved choices,
             validation hazards, and a suggested preview command; never prompts,
             installs, or writes anything (incompatible with --dry-run and --yes)
  --dry-run  resolve and validate choices, print the complete preview; install
             and write nothing, never run external installers
  --update   require an existing installation at the selected scope, update only
             its managed skills/packages, and refresh changed managed files;
             missing dependencies are reported but not installed
  --replace-custom  explicitly allow replacing unrecognized generated-doc
             content; combine with --yes for noninteractive apply
  --migrate-namespace  move legacy docs/ artifact directories to project/ (git
             mv inside a repository, plain mv otherwise) and regenerate the three
             managed docs at the new namespace; requesting it approves that
             regeneration. Moves run only after approval; partial moves are
             converged by rerunning
  --bin-link       create ~/.local/bin/pi-orchestrator-init as a symlink to this
             package's setup.sh; requires running from the pi-managed clone
             under ~/.pi/agent/git/ so the link survives pi update; never
             overwrites an existing file or foreign symlink
  --yes      noninteractive approval AFTER validation and preview; skips only the
             final confirmation question, never validation

Subagent model choices default to keep. Existing worker/reviewer override fields
are never changed unless a model or thinking flag explicitly requests it.

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
    --update)
      OPERATION=update
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
    --migrate-namespace)
      MIGRATE_NAMESPACE=true
      shift
      ;;
    --bin-link)
      BIN_LINK=true
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
    --worker-model)
      [ $# -ge 2 ] || bad_usage "--worker-model requires a value"
      WORKER_MODEL_CHOICE=${2-}
      MODEL_FLAGS_EXPLICIT=true
      shift 2
      ;;
    --reviewer-model)
      [ $# -ge 2 ] || bad_usage "--reviewer-model requires a value"
      REVIEWER_MODEL_CHOICE=${2-}
      MODEL_FLAGS_EXPLICIT=true
      shift 2
      ;;
    --worker-thinking)
      [ $# -ge 2 ] || bad_usage "--worker-thinking requires a value"
      WORKER_THINKING_CHOICE=${2-}
      MODEL_FLAGS_EXPLICIT=true
      shift 2
      ;;
    --reviewer-thinking)
      [ $# -ge 2 ] || bad_usage "--reviewer-thinking requires a value"
      REVIEWER_THINKING_CHOICE=${2-}
      MODEL_FLAGS_EXPLICIT=true
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
  auto | github | epiq | local | other) ;;
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
  if "$MIGRATE_NAMESPACE" && "$SKIP_PROJECT"; then
    bad_usage "--migrate-namespace requires --project PATH"
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

# Legacy installations keep the docs/ artifact namespace; new installations
# use project/ so delivery artifacts never collide with product documentation.
# Any existing legacy artifact directory keeps the whole project on docs/.
resolve_project_namespace() {
  PROJECT_NS=project
  if ! "$MIGRATE_NAMESPACE"; then
    local rel
    for rel in docs/agents docs/research docs/adr docs/specs docs/plans docs/tickets; do
      if [ -e "$PROJECT/$rel" ] || [ -L "$PROJECT/$rel" ]; then
        PROJECT_NS=docs
      fi
    done
  fi
  NS_AGENTS="$PROJECT_NS/agents"
  NS_ARTIFACTS="$NS_AGENTS/artifacts.md"
  NS_TRACKER="$NS_AGENTS/issue-tracker.md"
  NS_DOMAIN="$NS_AGENTS/domain.md"
  NS_RESEARCH="$PROJECT_NS/research/"
  NS_ADR="$PROJECT_NS/adr/"
  NS_SPECS="$PROJECT_NS/specs/"
  NS_PLANS="$PROJECT_NS/plans/"
  NS_TICKETS="$PROJECT_NS/tickets/"
}

# --migrate-namespace moves legacy docs/ artifact directories into project/.
# Targets are validated before approval; moves themselves run after external
# installs, before staging, so failed installs leave the project untouched.
validate_migrate_targets() {
  MIGRATE_MOVES=()
  "$MIGRATE_NAMESPACE" || return 0
  [ -n "$PROJECT" ] || return 0
  local rel
  if [ -e "$PROJECT/project" ] || [ -L "$PROJECT/project" ]; then
    [ -L "$PROJECT/project" ] && die "refusing to migrate through the symlink: $PROJECT/project (nothing has been modified)"
    [ -d "$PROJECT/project" ] || die "cannot migrate into $PROJECT/project: exists and is not a directory (nothing has been modified)"
    [ -w "$PROJECT/project" ] || die "cannot migrate into $PROJECT/project: not writable (nothing has been modified)"
  fi
  for rel in ${MIGRATE_DIRS[@]+"${MIGRATE_DIRS[@]}"}; do
    if [ -e "$PROJECT/docs/$rel" ] || [ -L "$PROJECT/docs/$rel" ]; then
      refuse_symlink_ancestors "docs/$rel"
      if [ -e "$PROJECT/project/$rel" ] || [ -L "$PROJECT/project/$rel" ]; then
        die "cannot migrate docs/$rel: project/$rel already exists; resolve it yourself outside setup (nothing has been modified)"
      fi
      MIGRATE_MOVES+=("docs/$rel -> project/$rel")
    fi
  done
  if [ ${#MIGRATE_MOVES[@]} -gt 0 ]; then
    [ -d "$PROJECT/docs" ] && [ -w "$PROJECT/docs" ] ||
      die "cannot migrate out of $PROJECT/docs: not a writable directory (nothing has been modified)"
  fi
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

layout_doc_label() {
  local label
  label=$(sed -n 's/^Layout: multiple contexts\.$/multiple contexts/p' "$1" 2>/dev/null | head -n 1)
  if [ -z "$label" ]; then
    label=$(sed -n 's/^Layout: single context\.$/single context/p' "$1" 2>/dev/null | head -n 1)
  fi
  echo "$label"
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
  [ -n "$PROJECT" ] && refuse_symlink_ancestors "$NS_TRACKER"
  case "$TRACKER_CHOICE" in
  github)
    TRACKER="GitHub Issues"
    TRACKER_STATUS=explicit
    TRACKER_NOTE="(set by --tracker github)"
    return
    ;;
  epiq)
    TRACKER="Epiq"
    TRACKER_PROFILE=epiq
    TRACKER_STATUS=explicit
    TRACKER_NOTE="(set by --tracker epiq)"
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
  local doc="$PROJECT/$NS_TRACKER" label
  if [ -f "$doc" ]; then
    label=$(tracker_doc_label "$doc")
    if [ -n "$label" ]; then
      TRACKER=$label
      TRACKER_DESCRIPTION=$label
      [ "$label" = "Epiq" ] && TRACKER_PROFILE=epiq
      TRACKER_STATUS=detected
      TRACKER_NOTE="(existing $NS_TRACKER)"
      return
    fi
    TRACKER="GitHub Issues"
    TRACKER_STATUS=unresolved
    TRACKER_NOTE="UNRESOLVED: $NS_TRACKER has unrecognized custom content; an explicit replace decision is required"
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
  [ -n "$PROJECT" ] && refuse_symlink_ancestors "$NS_DOMAIN"
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
  local doc="$PROJECT/$NS_DOMAIN" layout
  if [ -f "$doc" ]; then
    layout=$(layout_doc_label "$doc")
    if [ -n "$layout" ]; then
      if [ "$layout" = "multiple contexts" ]; then
        DOMAIN_LAYOUT="Multiple contexts"
      else
        DOMAIN_LAYOUT="Single context"
      fi
      LAYOUT_STATUS=detected
      LAYOUT_NOTE="(existing $NS_DOMAIN)"
      return
    fi
    DOMAIN_LAYOUT="Single context"
    LAYOUT_STATUS=unresolved
    LAYOUT_NOTE="UNRESOLVED: $NS_DOMAIN has unrecognized custom content; an explicit replace decision is required"
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

mcp_config_has_symlink_ancestor() {
  local path="$1" boundary
  MCP_SYMLINK_PATH=
  if [ -n "$PROJECT" ] && [ "$path" = "$PROJECT/.mcp.json" ]; then
    boundary="$PROJECT"
  else
    boundary="$HOME"
  fi
  while :; do
    if [ -L "$path" ]; then
      MCP_SYMLINK_PATH="$path"
      return 0
    fi
    [ "$path" = "$boundary" ] && break
    path=$(dirname "$path")
  done
  return 1
}

refuse_mcp_symlink_ancestors() {
  if mcp_config_has_symlink_ancestor "$1"; then
    die "refusing to operate through the MCP config symlink: $MCP_SYMLINK_PATH; resolve it yourself outside setup (nothing has been modified)"
  fi
}

mcp_config_merge() {
  node - "$MCP_CONFIG_PATH" <<'EOF'
const fs = require('fs');
const path = process.argv[2];
const desired = {
  command: 'npx',
  args: ['-y', '-p', 'epiq', 'epiq-mcp'],
  lifecycle: 'lazy',
};
let config = {};
try {
  config = JSON.parse(fs.readFileSync(path, 'utf8'));
} catch (error) {
  if (error.code !== 'ENOENT') {
    console.error(`invalid JSON in ${path}: ${error.message}`);
    process.exit(1);
  }
}
if (!config || Array.isArray(config) || typeof config !== 'object') {
  console.error(`${path} must contain a JSON object`);
  process.exit(1);
}
if (config.mcpServers === undefined) config.mcpServers = {};
if (!config.mcpServers || Array.isArray(config.mcpServers) || typeof config.mcpServers !== 'object') {
  console.error(`${path} mcpServers must be a JSON object`);
  process.exit(1);
}
const sameJson = (a, b) => {
  if (a === b) return true;
  if (!a || !b || typeof a !== 'object' || typeof b !== 'object') return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  const ak = Object.keys(a);
  const bk = Object.keys(b);
  return ak.length === bk.length && ak.every(key => Object.prototype.hasOwnProperty.call(b, key) && sameJson(a[key], b[key]));
};
if (Object.prototype.hasOwnProperty.call(config.mcpServers, 'epiq')) {
  if (!sameJson(config.mcpServers.epiq, desired)) {
    console.error(`${path} already defines mcpServers.epiq with different settings; resolve it manually`);
    process.exit(2);
  }
} else {
  config.mcpServers.epiq = desired;
}
process.stdout.write(JSON.stringify(config, null, 2) + '\n');
EOF
}

validate_mcp_config() {
  [ -n "$MCP_CONFIG_PATH" ] || return 0
  refuse_mcp_symlink_ancestors "$MCP_CONFIG_PATH"
  local parent
  if [ -e "$MCP_CONFIG_PATH" ]; then
    [ -f "$MCP_CONFIG_PATH" ] || die "MCP config exists and is not a regular file: $MCP_CONFIG_PATH (nothing has been modified)"
    parent=$(dirname "$MCP_CONFIG_PATH")
    [ -d "$parent" ] || die "MCP config parent is not a directory: $parent (nothing has been modified)"
    [ -x "$parent" ] || die "MCP config parent is not searchable: $parent (nothing has been modified)"
    [ -w "$parent" ] || die "MCP config parent is not writable: $parent (nothing has been modified)"
    [ -w "$MCP_CONFIG_PATH" ] || die "MCP config is not writable: $MCP_CONFIG_PATH (nothing has been modified)"
  else
    require_creatable "$MCP_CONFIG_PATH"
  fi
  if command -v node >/dev/null 2>&1; then
    if ! mcp_config_merge >/dev/null; then
      die "cannot use MCP config $MCP_CONFIG_PATH; fix it or resolve the existing Epiq server manually (nothing has been modified)"
    fi
  fi
}

resolve_mcp_config() {
  MCP_CONFIG_PATH=
  MCP_CONFIG_STATUS=
  MCP_CONFIG_NOTE=
  MCP_CONFIG_STAGE=
  MCP_CONFIG_ACTION=
  [ "$TRACKER_PROFILE" = epiq ] || return 0
  if [ "$SKILL_SCOPE" = Project ]; then
    MCP_CONFIG_PATH="$PROJECT/.mcp.json"
  else
    MCP_CONFIG_PATH="$HOME/.config/mcp/mcp.json"
  fi
  if [ -e "$MCP_CONFIG_PATH" ] || [ -L "$MCP_CONFIG_PATH" ]; then
    MCP_CONFIG_STATUS=detected
    MCP_CONFIG_NOTE="(existing standard MCP config)"
  else
    MCP_CONFIG_STATUS=new
    MCP_CONFIG_NOTE="(will create standard MCP config)"
  fi
  validate_mcp_config
}

model_update_requested() {
  [ "$WORKER_MODEL_CHOICE" != keep ] ||
    [ "$REVIEWER_MODEL_CHOICE" != keep ] ||
    [ "$WORKER_THINKING_CHOICE" != keep ] ||
    [ "$REVIEWER_THINKING_CHOICE" != keep ]
}

validate_model_choice() {
  case "$2" in
  keep | inherit) ;;
  ?*/?*)
    case "$2" in
    *[[:space:]]*) bad_usage "$1 must not contain whitespace" ;;
    esac
    ;;
  *) bad_usage "$1 must be keep, inherit, or PROVIDER/MODEL" ;;
  esac
}

validate_thinking_choice() {
  case "$2" in
  keep | inherit | off | minimal | low | medium | high | xhigh | max) ;;
  *) bad_usage "$1 must be keep, inherit, off, minimal, low, medium, high, xhigh, or max" ;;
  esac
}

resolve_subagent_settings() {
  local settings
  validate_model_choice --worker-model "$WORKER_MODEL_CHOICE"
  validate_model_choice --reviewer-model "$REVIEWER_MODEL_CHOICE"
  validate_thinking_choice --worker-thinking "$WORKER_THINKING_CHOICE"
  validate_thinking_choice --reviewer-thinking "$REVIEWER_THINKING_CHOICE"
  if [ "$SKILL_SCOPE" = Project ]; then
    SUBAGENT_SETTINGS_PATH="$PROJECT/.pi/settings.json"
  else
    SUBAGENT_SETTINGS_PATH="$HOME/.pi/agent/settings.json"
  fi
  if model_update_requested; then
    if [ "$SKILL_SCOPE" = Project ]; then
      refuse_symlink_ancestors ".pi/settings.json"
    else
      if mcp_config_has_symlink_ancestor "$SUBAGENT_SETTINGS_PATH"; then
        die "refusing to update Pi settings through the symlink: $MCP_SYMLINK_PATH (nothing has been modified)"
      fi
    fi
    if [ -e "$SUBAGENT_SETTINGS_PATH" ]; then
      [ -f "$SUBAGENT_SETTINGS_PATH" ] || die "Pi settings exist and are not a regular file: $SUBAGENT_SETTINGS_PATH (nothing has been modified)"
      [ -w "$SUBAGENT_SETTINGS_PATH" ] || die "Pi settings are not writable: $SUBAGENT_SETTINGS_PATH (nothing has been modified)"
    else
      require_creatable "$SUBAGENT_SETTINGS_PATH"
    fi
    if command -v node >/dev/null 2>&1; then
      for settings in "$HOME/.pi/agent/settings.json" "$SUBAGENT_SETTINGS_PATH"; do
        [ -f "$settings" ] || continue
        node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$settings" >/dev/null 2>&1 ||
          die "cannot update invalid Pi settings JSON: $settings (nothing has been modified)"
      done
    fi
  fi
}

resolve_update_plan() {
  [ "$OPERATION" = update ] || return 0
  UPDATE_SKILLS=()
  UPDATE_PI_PACKAGES=()
  UPDATE_SKILL_MISSING=()
  UPDATE_PI_MISSING=()
  UPDATE_PINNED=()
  _UPDATE_STATUS=unavailable
  _UPDATE_NOTE="(node is required to inspect installation metadata)"
  command -v node >/dev/null 2>&1 || return 0

  local project_lock_v3="" project_lock_v1="" project_lock_legacy="" project_settings="" output kind name
  if [ -n "$PROJECT" ]; then
    project_lock_v3="$PROJECT/.agents/.skill-lock.json"
    project_lock_v1="$PROJECT/.agents/skills/skills-lock.json"
    project_lock_legacy="$PROJECT/skills-lock.json"
    project_settings="$PROJECT/.pi/settings.json"
  fi
  output=$(
    node - "$SKILL_SCOPE" "$HOME/.agents/.skill-lock.json" "$HOME/.agents/skills/skills-lock.json" \
      "$project_lock_v3" "$project_lock_v1" "$project_lock_legacy" \
      "$HOME/.pi/agent/settings.json" "$project_settings" "$TRACKER_PROFILE" \
      "${LEGOUT_SKILLS[*]}" <<'EOF'
const fs = require('fs');
const [scope, globalLockV3, globalLockV1, projectLockV3, projectLockV1, projectLockLegacy,
  globalSettingsPath, projectSettingsPath, trackerProfile, skillList] = process.argv.slice(2);
const read = file => {
  if (!file || !fs.existsSync(file)) return {};
  return JSON.parse(fs.readFileSync(file, 'utf8'));
};
const first = files => files.find(file => file && fs.existsSync(file));
const lockPath = scope === 'Project'
  ? first([projectLockV3, projectLockV1, projectLockLegacy])
  : first([globalLockV3, globalLockV1]);
const installedSkills = read(lockPath).skills ?? {};
for (const name of skillList.split(' ')) {
  const installed = installedSkills[name];
  if (!installed) console.log(`skill-missing\t${name}`);
  else if (installed.source !== 'legout/skills') console.log(`skill-conflict\t${name}:${installed.source ?? 'unknown source'}`);
  else console.log(`skill-update\t${name}`);
}

const sourceOf = entry => typeof entry === 'string' ? entry : entry?.source;
const packagesOf = file => (read(file).packages ?? []).map(sourceOf).filter(Boolean);
const globalPackages = packagesOf(globalSettingsPath);
const projectPackages = packagesOf(projectSettingsPath);
const selected = scope === 'Project' ? projectPackages : globalPackages;
const other = scope === 'Project' ? globalPackages : projectPackages;
const matching = (sources, name) => sources.filter(source => source === `npm:${name}` || source.startsWith(`npm:${name}@`));
const desired = ['pi-subagents', 'pi-intercom'];
if (trackerProfile === 'epiq' || matching(selected, 'pi-mcp-adapter').length) desired.push('pi-mcp-adapter');
for (const name of desired) {
  const configured = matching(selected, name);
  if (!configured.length) {
    console.log(`package-missing\tnpm:${name}`);
    continue;
  }
  if (matching(other, name).length) {
    console.log(`package-duplicate\tnpm:${name}`);
    continue;
  }
  if (configured.every(source => source !== `npm:${name}`)) console.log(`package-pinned\t${configured[0]}`);
  else console.log(`package-update\tnpm:${name}`);
}
EOF
  ) || die "cannot inspect existing installation metadata; fix invalid skill lock or Pi settings JSON (nothing has been modified)"

  while IFS=$(printf '\t') read -r kind name; do
    [ -n "$kind" ] || continue
    case "$kind" in
    skill-update) UPDATE_SKILLS+=("$name") ;;
    skill-missing) UPDATE_SKILL_MISSING+=("$name") ;;
    skill-conflict) die "managed skill source conflict: $name; use normal setup to replace it deliberately (nothing has been modified)" ;;
    package-update) UPDATE_PI_PACKAGES+=("$name") ;;
    package-missing) UPDATE_PI_MISSING+=("$name") ;;
    package-pinned) UPDATE_PINNED+=("$name") ;;
    package-duplicate) die "$name is configured in both global and project scope; Pi cannot update one scope independently (nothing has been modified)" ;;
    esac
  done <<EOF
$output
EOF

  local existing=false prompt_dir
  if [ ${#UPDATE_SKILLS[@]} -gt 0 ] || [ ${#UPDATE_PI_PACKAGES[@]} -gt 0 ] || [ ${#UPDATE_PINNED[@]} -gt 0 ]; then
    existing=true
  fi
  prompt_dir=$(prompt_dest_dir)
  [ -f "$prompt_dir/setup-implementation-orchestrator.md" ] && existing=true
  if [ -n "$PROJECT" ] && { grep -F "$START_MARKER" "$PROJECT/AGENTS.md" >/dev/null 2>&1 || grep -F "$START_MARKER" "$PROJECT/CLAUDE.md" >/dev/null 2>&1; }; then
    existing=true
  fi
  if "$existing"; then
    _UPDATE_STATUS=detected
    _UPDATE_NOTE="(updates installed components only; missing dependencies are skipped)"
  else
    _UPDATE_STATUS=missing
    _UPDATE_NOTE="(no existing managed installation at selected scope)"
    [ "$MODE" = inspect ] || die "no existing orchestrator installation found at $SKILL_SCOPE scope; run normal setup first (nothing has been modified)"
  fi
}

# --bin-link creates ~/.local/bin/pi-orchestrator-init pointing at this
# package's setup.sh. Only the pi-managed clone has a stable path that survives
# pi update, so running from a checkout or extracted tarball is refused.
resolve_bin_link() {
  "$BIN_LINK" || return 0
  BIN_LINK_PATH="$HOME/.local/bin/pi-orchestrator-init"
  case "$ROOT" in
  "$HOME"/.pi/agent/git/*) ;;
  *) die "--bin-link requires running from the pi-managed package clone under ~/.pi/agent/git/; a link to a checkout or extracted tarball would dangle (nothing has been modified)" ;;
  esac
  local dir="$HOME/.local/bin"
  if [ -e "$dir" ] || [ -L "$dir" ]; then
    { [ -d "$dir" ] && [ ! -L "$dir" ]; } ||
      die "--bin-link: $dir exists and is not a directory (nothing has been modified)"
    [ -w "$dir" ] || die "--bin-link: $dir is not writable (nothing has been modified)"
  fi
  if [ -L "$BIN_LINK_PATH" ]; then
    [ "$(readlink "$BIN_LINK_PATH")" = "$ROOT/setup.sh" ] ||
      die "--bin-link: $BIN_LINK_PATH already points elsewhere; resolve it yourself outside setup (nothing has been modified)"
  elif [ -e "$BIN_LINK_PATH" ]; then
    die "--bin-link: $BIN_LINK_PATH exists and is not a symlink to this package (nothing has been modified)"
  fi
}

bin_link_path_warning() {
  case ":$PATH:" in
  *":$HOME/.local/bin:"*) return 0 ;;
  esac
  echo "  Warning: $HOME/.local/bin is not on PATH; add it to use the pi-orchestrator-init command."
}

install_bin_link() {
  "$BIN_LINK" || return 0
  local dir="$HOME/.local/bin"
  mkdir -p "$dir" || die "failed to create $dir; rerun setup to converge."
  if [ -L "$BIN_LINK_PATH" ] && [ "$(readlink "$BIN_LINK_PATH")" = "$ROOT/setup.sh" ]; then
    echo "Command symlink unchanged: $BIN_LINK_PATH -> $ROOT/setup.sh"
    return 0
  fi
  ln -s "$ROOT/setup.sh" "$BIN_LINK_PATH" ||
    die "failed to create command symlink $BIN_LINK_PATH; rerun setup to converge."
  echo "Command symlink created: $BIN_LINK_PATH -> $ROOT/setup.sh"
  bin_link_path_warning
}

resolve_choices() {
  if [ -n "$PROJECT" ]; then
    resolve_project_namespace
    validate_migrate_targets
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
        TRACKER=$(ask_choice "Issue tracker" "GitHub Issues" "Epiq" "Local Markdown" "Other")
      else
        TRACKER=$(ask_choice "Issue tracker" "Local Markdown" "Epiq" "GitHub Issues" "Other")
      fi
      if [ "$TRACKER" = "Other" ]; then
        TRACKER=$(ask_line "Describe the tracker in one line: " "Other")
      elif [ "$TRACKER" = "Epiq" ]; then
        TRACKER_PROFILE=epiq
      fi
      TRACKER_STATUS=answered
    fi

    detect_domain_layout
    if [ "$LAYOUT_STATUS" = unresolved ] && [ "$MODE" != inspect ]; then
      DOMAIN_LAYOUT=$(ask_choice "Domain layout" "Single context" "Multiple contexts")
      LAYOUT_STATUS=answered
    fi
  fi

  if [ -z "$PROJECT" ] && [ "$TRACKER_CHOICE" != auto ]; then
    detect_tracker
  fi

  detect_skill_scope
  if [ "$SCOPE_STATUS" = unresolved ] && [ "$MODE" != inspect ]; then
    SKILL_SCOPE=$(ask_choice "Skill installation scope" "Global" "Project")
    SCOPE_STATUS=answered
  fi

  resolve_subagent_settings
  resolve_mcp_config
  resolve_update_plan
  resolve_bin_link
}

# Shared awk helper: literal (not regex) occurrence count of one token per line.
MARKER_OCCURRENCES_AWK='
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
'

count_marker() {
  # usage: count_marker FILE MARKER -> prints every marker occurrence
  if [ ! -f "$1" ]; then
    echo 0
  else
    awk -v marker="$2" "$MARKER_OCCURRENCES_AWK"'
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
    awk -v marker="$2" "$MARKER_OCCURRENCES_AWK"'
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
    awk -v marker="$2" "$MARKER_OCCURRENCES_AWK"'
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
  validate_prompt_outputs
  [ -n "$PROJECT" ] || return 0
  validate_output_file "$INSTRUCTION_FILE" "instruction file"
  validate_managed_block "$PROJECT/$INSTRUCTION_FILE"
  validate_dir_target "$PROJECT_NS" "$PROJECT_NS directory"
  validate_dir_target "$NS_AGENTS" "$NS_AGENTS directory"
  validate_output_file "$NS_ARTIFACTS" "generated artifact-map doc"
  validate_output_file "$NS_TRACKER" "generated tracker doc"
  validate_output_file "$NS_DOMAIN" "generated domain doc"
  validate_mcp_config
}

prompt_dest_dir() {
  if [ "$SKILL_SCOPE" = Project ]; then
    echo "$PROJECT/.pi/prompts"
  else
    echo "$HOME/.pi/agent/prompts"
  fi
}

package_prompt_files() {
  [ -d "$ROOT/prompts" ] || die "package prompts directory not found: $ROOT/prompts (nothing has been modified)"
  local f
  for f in "$ROOT"/prompts/*.md; do
    [ -f "$f" ] || die "no prompt templates found in $ROOT/prompts (nothing has been modified)"
    echo "$f"
  done
}

validate_prompt_outputs() {
  local dest f base
  dest=$(prompt_dest_dir)
  # The prompts directory itself may be a managed symlink (dotfiles setups);
  # prompt files inside it are never written through a symlink.
  if [ -e "$dest" ]; then
    [ -d "$dest" ] || die "prompt-command destination exists and is not a directory: $dest (nothing has been modified)"
    [ -x "$dest" ] || die "prompt-command destination is not searchable: $dest (nothing has been modified)"
    [ -w "$dest" ] || die "prompt-command destination is not writable: $dest (nothing has been modified)"
  else
    require_creatable "$dest"
  fi
  for f in $(package_prompt_files); do
    base=${f##*/}
    if [ -e "$dest/$base" ]; then
      [ ! -L "$dest/$base" ] || die "refusing to write prompt command through a symlink: $dest/$base; resolve it yourself outside setup (nothing has been modified)"
      [ -f "$dest/$base" ] || die "prompt-command destination exists and is not a regular file: $dest/$base (nothing has been modified)"
      [ -w "$dest/$base" ] || die "prompt-command file is not writable: $dest/$base (nothing has been modified)"
    fi
  done
}

resolve_custom_doc_decisions() {
  [ -n "$PROJECT" ] || return 0
  # --migrate-namespace requests regeneration at the new namespace; that request
  # is the explicit owner approval for replacing the three managed docs.
  "$MIGRATE_NAMESPACE" && return 0
  local doc
  doc="$PROJECT/$NS_ARTIFACTS"
  if artifacts_doc_requires_replace "$doc" && ! "$REPLACE_CUSTOM"; then
    custom_doc_decision "$doc"
  fi
  doc="$PROJECT/$NS_TRACKER"
  if tracker_doc_requires_replace "$doc" && ! "$REPLACE_CUSTOM"; then
    custom_doc_decision "$doc"
  fi
  doc="$PROJECT/$NS_DOMAIN"
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
    case "$doc" in
    "$PROJECT/$NS_TRACKER") TRACKER_CUSTOM_APPROVED=true ;;
    "$PROJECT/$NS_DOMAIN") DOMAIN_CUSTOM_APPROVED=true ;;
    *) ARTIFACTS_CUSTOM_APPROVED=true ;;
    esac
    ;;
  *)
    echo "Aborted; nothing was installed or written."
    exit 0
    ;;
  esac
}

build_skill_args() {
  local s
  if [ "$OPERATION" = update ]; then
    SKILL_ARGS=()
    if [ ${#UPDATE_SKILLS[@]} -gt 0 ]; then
      SKILL_ARGS=(npx skills update)
      for s in ${UPDATE_SKILLS[@]+"${UPDATE_SKILLS[@]}"}; do
        SKILL_ARGS+=("$s")
      done
      if [ "$SKILL_SCOPE" = Project ]; then
        SKILL_ARGS+=(--project --yes)
      else
        SKILL_ARGS+=(--global --yes)
      fi
    fi
  else
    SKILL_ARGS=(npx skills add legout/skills)
    for s in ${LEGOUT_SKILLS[@]+"${LEGOUT_SKILLS[@]}"}; do
      SKILL_ARGS+=(--skill "$s")
    done
    if [ "$SKILL_SCOPE" = Project ]; then
      SKILL_ARGS+=(--agent pi --yes --copy)
    else
      SKILL_ARGS+=(--global --agent pi --yes --copy)
    fi
  fi
}

render_install_lines() {
  local package
  if [ ${#SKILL_ARGS[@]} -gt 0 ]; then
    printf '+'
    printf ' %q' ${SKILL_ARGS[@]+"${SKILL_ARGS[@]}"}
    printf '\n'
  fi
  if [ "$OPERATION" = update ]; then
    for package in ${UPDATE_PI_PACKAGES[@]+"${UPDATE_PI_PACKAGES[@]}"}; do
      if [ "$SKILL_SCOPE" = Project ]; then
        printf '+ (cd %q && pi update %q)\n' "$PROJECT" "$package"
      else
        printf '+ (cd %q && pi update %q)\n' "$HOME" "$package"
      fi
    done
    [ ${#UPDATE_SKILL_MISSING[@]} -eq 0 ] || printf '  skipped missing skills: %s\n' "${UPDATE_SKILL_MISSING[*]}"
    [ ${#UPDATE_PI_MISSING[@]} -eq 0 ] || printf '  skipped missing Pi packages: %s\n' "${UPDATE_PI_MISSING[*]}"
    [ ${#UPDATE_PINNED[@]} -eq 0 ] || printf '  skipped pinned Pi packages: %s\n' "${UPDATE_PINNED[*]}"
  else
    if [ "$SKILL_SCOPE" = Project ]; then
      printf '+ (cd %q && pi install --local npm:pi-subagents)\n' "$PROJECT"
      printf '+ (cd %q && pi install --local npm:pi-intercom)\n' "$PROJECT"
      if [ "$TRACKER_PROFILE" = epiq ]; then
        printf '+ (cd %q && pi install --local npm:pi-mcp-adapter)\n' "$PROJECT"
      fi
      printf '%s\n' '+ merge global subagent model/thinking settings into .pi/settings.json (fills missing fields only; never overwrites project choices)'
    else
      printf '%s\n' '+ pi install npm:pi-subagents' '+ pi install npm:pi-intercom'
      if [ "$TRACKER_PROFILE" = epiq ]; then
        printf '%s\n' '+ pi install npm:pi-mcp-adapter'
      fi
    fi
  fi
  if model_update_requested; then
    printf '+ update %q subagent overrides: worker model=%q thinking=%q; reviewer model=%q thinking=%q\n' \
      "$SUBAGENT_SETTINGS_PATH" "$WORKER_MODEL_CHOICE" "$WORKER_THINKING_CHOICE" \
      "$REVIEWER_MODEL_CHOICE" "$REVIEWER_THINKING_CHOICE"
  fi
}

subagent_model_settings() {
  # usage: subagent_model_settings preview|apply
  local action="$1" project_settings=""
  [ -n "$PROJECT" ] && project_settings="$PROJECT/.pi/settings.json"
  node - "$action" "$HOME/.pi/agent/settings.json" "$SUBAGENT_SETTINGS_PATH" "$project_settings" "$SKILL_SCOPE" \
    "$WORKER_MODEL_CHOICE" "$WORKER_THINKING_CHOICE" \
    "$REVIEWER_MODEL_CHOICE" "$REVIEWER_THINKING_CHOICE" <<'EOF'
const fs = require('fs');
const path = require('path');
const [action, globalPath, targetPath, projectPath, scope, workerModel, workerThinking, reviewerModel, reviewerThinking] = process.argv.slice(2);
const read = file => fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : {};
const readOptional = file => { try { return file ? read(file) : {}; } catch { return {}; } };
const globalSettings = read(globalPath);
const target = targetPath === globalPath ? globalSettings : read(targetPath);
const before = JSON.stringify(target);

// Project override objects replace their global counterparts. Preserve the
// existing setup behavior by filling missing fields before explicit choices.
if (scope === 'Project') {
  const globals = globalSettings.subagents?.agentOverrides;
  const projects = target.subagents?.agentOverrides;
  if (globals && projects) {
    for (const [name, override] of Object.entries(projects)) {
      const global = globals[name];
      if (!global || typeof global !== 'object' || !override || typeof override !== 'object') continue;
      for (const [key, value] of Object.entries(global)) {
        if (!(key in override)) override[key] = value;
      }
    }
  }
}

const choices = {
  worker: { model: workerModel, thinking: workerThinking },
  reviewer: { model: reviewerModel, thinking: reviewerThinking },
};
if (scope === 'Project') {
  for (const [name, fields] of Object.entries(choices)) {
    if (!Object.values(fields).some(choice => choice !== 'keep')) continue;
    const projectOverride = target.subagents?.agentOverrides?.[name];
    const globalOverride = globalSettings.subagents?.agentOverrides?.[name];
    if (projectOverride === undefined && globalOverride && typeof globalOverride === 'object') {
      target.subagents ??= {};
      target.subagents.agentOverrides ??= {};
      target.subagents.agentOverrides[name] = { ...globalOverride };
    }
  }
}
for (const [name, fields] of Object.entries(choices)) {
  for (const [field, choice] of Object.entries(fields)) {
    if (choice === 'keep') continue;
    target.subagents ??= {};
    target.subagents.agentOverrides ??= {};
    const override = target.subagents.agentOverrides[name] ??= {};
    if (choice === 'inherit') delete override[field];
    else override[field] = choice;
  }
}

const effective = name => {
  const projectSettings = scope === 'Project' ? target : readOptional(projectPath);
  const projectOverride = projectSettings.subagents?.agentOverrides?.[name];
  const globalOverride = (targetPath === globalPath ? target : globalSettings).subagents?.agentOverrides?.[name];
  const override = projectOverride ?? globalOverride;
  return {
    model: override?.model ?? 'inherits parent model',
    thinking: override?.thinking ?? 'default',
    source: projectOverride ? 'project .pi/settings.json' : globalOverride ? '~/.pi/agent/settings.json' : 'builtin default',
  };
};
const changed = JSON.stringify(target) !== before;

if (action === 'preview') {
  console.log(`Subagent settings target: ${targetPath}`);
  for (const name of ['worker', 'reviewer']) {
    const value = effective(name);
    console.log(`  ${name}: ${value.model} (thinking: ${value.thinking}) — ${value.source}`);
  }
  console.log(`  settings write: ${changed ? 'yes' : 'no'}`);
  console.log('  resulting subagents.agentOverrides:');
  for (const line of JSON.stringify(target.subagents?.agentOverrides ?? {}, null, 2).split('\n')) {
    console.log(`    ${line}`);
  }
  process.exit(0);
}
if (!changed) process.exit(0);
fs.mkdirSync(path.dirname(targetPath), { recursive: true });
const mode = fs.existsSync(targetPath) ? fs.statSync(targetPath).mode & 0o777 : 0o600;
const temp = path.join(path.dirname(targetPath), `.${path.basename(targetPath)}.tmp-${process.pid}`);
try {
  fs.writeFileSync(temp, JSON.stringify(target, null, 2) + '\n', { flag: 'wx', mode });
  fs.chmodSync(temp, mode);
  fs.renameSync(temp, targetPath);
} catch (error) {
  try { fs.unlinkSync(temp); } catch {}
  throw error;
}
console.log(`Subagent settings: updated ${targetPath}`);
EOF
}

# A project .pi/settings.json subagents.agentOverrides.<name> object replaces the
# global one wholesale; an entry like {"tools":"inherit"} would silently drop the
# globally configured model. Fill missing fields from the global settings.
harmonize_subagent_models() {
  if model_update_requested; then
    if [ "$SKILL_SCOPE" = Project ]; then
      refuse_symlink_ancestors ".pi/settings.json"
    elif mcp_config_has_symlink_ancestor "$SUBAGENT_SETTINGS_PATH"; then
      die "refusing to update Pi settings through the symlink: $MCP_SYMLINK_PATH; external installs already performed remain installed"
    fi
    subagent_model_settings apply || die "failed to update subagent model settings in $SUBAGENT_SETTINGS_PATH; rerun setup to converge"
    return
  fi
  [ "$SKILL_SCOPE" = Project ] || return 0
  local settings="$PROJECT/.pi/settings.json" user="$HOME/.pi/agent/settings.json"
  [ -f "$settings" ] || return 0
  [ -f "$user" ] || return 0
  node - "$user" "$settings" <<'EOF' || die "failed to merge subagent model settings into $settings; fix its JSON and rerun setup to converge"
const fs = require('fs');
const [userPath, projectPath] = process.argv.slice(2);
const user = JSON.parse(fs.readFileSync(userPath, 'utf8'));
const project = JSON.parse(fs.readFileSync(projectPath, 'utf8'));
const globalOverrides = user.subagents?.agentOverrides;
const projectOverrides = project.subagents?.agentOverrides;
if (!globalOverrides || !projectOverrides) process.exit(0);
const filled = [];
for (const [name, override] of Object.entries(projectOverrides)) {
  const global = globalOverrides[name];
  if (!global || typeof global !== 'object' || !override || typeof override !== 'object') continue;
  for (const [key, value] of Object.entries(global)) {
    if (!(key in override)) { override[key] = value; filled.push(`${name}.${key}`); }
  }
}
if (filled.length) {
  fs.writeFileSync(projectPath, JSON.stringify(project, null, 2) + '\n');
  console.log(`Subagent settings: copied global ${filled.join(', ')} into .pi/settings.json`);
}
EOF
}

resolve_agent_models() {
  # prints NAME<TAB>MODEL<TAB>THINKING<TAB>SOURCE per line for worker and reviewer
  local project_settings=""
  [ -n "$PROJECT" ] && project_settings="$PROJECT/.pi/settings.json"
  node - "$project_settings" "$HOME/.pi/agent/settings.json" <<'EOF'
const fs = require('fs');
const [projectPath, userPath] = process.argv.slice(2);
const read = p => { try { return p ? JSON.parse(fs.readFileSync(p, 'utf8')) : {}; } catch { return {}; } };
const project = read(projectPath);
const user = read(userPath);
for (const name of ['worker', 'reviewer']) {
  const po = project.subagents?.agentOverrides?.[name];
  const uo = user.subagents?.agentOverrides?.[name];
  const active = po ?? uo;
  console.log([
    name,
    active?.model ?? 'inherits parent model',
    active?.thinking ?? 'default',
    po ? 'project .pi/settings.json' : uo ? '~/.pi/agent/settings.json' : 'builtin default',
  ].join('\t'));
}
EOF
}

print_setup_overview() {
  echo
  echo "Subagent models in effect:"
  resolve_agent_models | while IFS=$(printf '\t') read -r name model thinking source; do
    printf '  %s: %s (thinking: %s) — %s\n' "$name" "$model" "$thinking" "$source"
  done
  echo "Change them in the project .pi/settings.json, globally in ~/.pi/agent/settings.json (subagents.agentOverrides.<name>), or with /subagents inside pi."
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

- Every validation unit receives one test obligation: `new-test`, `existing-check`, or `no-new-test`; related tasks may share a validation unit, and focused TDD is required only for `new-test` work.
- Review is adaptive and orchestrator-owned: low-risk work uses parent diff inspection; normal-risk work gets one candidate review; high-risk or dependency-defining work gets immediate plus candidate review.
- Plans and tickets reference exact feature sources; this file defines stable repository-wide scope.
- Scoped authority: glossaries own terminology; ADRs own accepted architectural constraints; specifications own behavior; plans/tickets own execution decomposition. No scope silently overrides another; reconcile owner decisions into the affected artifacts before dependent work proceeds.
- Stop before implementation when authoritative sources conflict.

### Review ground rules

- Priority: agreed feature, then correctness, then proven risk. Written conventions are binding; taste never blocks. Name the applicable instruction, style, lint, or contract source; if none exists, say so rather than inventing conventions.
- Findings need a named requirement or written rule, a problem this change caused or worsened, reachability through real callers/inputs/environment, material impact, and a proportionate response.
- Security requires a touched boundary (untrusted/external input, credentials, auth, dependency changes), named asset, realistic attacker, and actual attack path. Stories needing stolen secrets, broken TLS, malicious admins, or generic hardening are not findings. No boundary touched: `security: n/a`; missing security facts: `unverified`, never invent a threat model. Trusted internal callers and the user's own local files are not hostile by default.
- Test requests are findings: name a real scenario or drop them. Coverage percentage is not a reason.
- Disposition before repair: parent rejects failed gates in one line, authorizes small in-scope fixes, or hands large/out-of-scope fixes to the human. Reviewers never start fixes or re-reviews.
- Reviews end when criteria, real risks, and written rules are covered: `pass or fix-first`, then stop. One fix pass, one delta recheck; unresolved findings go to the human, never round three. Candidate review checks integration effects, not settled findings again.
- Paste the full reviewer contract from `orchestrate-implementation` into every fresh reviewer prompt, with criteria, conventions, and real-use context; file links alone do not deliver it.
- After each task: restate it, compare the result, choose `accept / fix / hand back / ask`. Extra ideas get one line, not code. Smallest safe change; one behavior and, for `new-test`, one failing test first. Dependencies and abstractions need a job today. No extra ledgers or sign-off artifacts.

### Routing and authority

EOF
  printf '%s\n' "- Read \`$NS_ARTIFACTS\` for the project artifact mapping and load the \`planning-contract\` skill for artifact classification and planning handoffs; read \`$NS_TRACKER\` and \`$NS_DOMAIN\` when their scope applies. Preserve established project conventions."
  if [ "$TRACKER_PROFILE" = epiq ]; then
    cat <<'EOF'
- When the tracker is Epiq, follow the Epiq workflow guidance and use `epiq_*` MCP tools for board operations; never use the `epiq` CLI or edit Epiq state files directly. Setup configures the MCP server but never initializes an Epiq board or project.
EOF
  fi
  cat <<'EOF'
- Use `shape-design` for unresolved behavior/design choices, `write-implementation-plan` for approved multi-step work, and `orchestrate-implementation` to execute approved work. Do not turn a trivial edit into a planning exercise.
- Default orchestrated execution to `supervised`: builtin `worker` may implement and validate, but candidate assembly, integration, and publication retain explicit approval gates.
- Route implementation to builtin `worker` and, when required by the selected policy, independent review to a fresh read-only builtin `reviewer`; confirm both are executable before dispatch and record the resolved names in the run manifest.
- Keep one writer per worktree. Use `pi-subagents` for spawned-child lifecycle; named persistent `pi-intercom` peers are read-only advisors, not implementation or review agents.
- Use `systematic-debugging` for unexpected failures and `verification-before-completion` before success claims; match evidence to the exact change and report skipped checks.
- Use `merge-worktree` for target integration and `make-release` for releases. Local integration does not authorize pushing; opening a PR does not authorize merging; release or publication requires its own approved plan.
- Stop on conflicting authoritative sources, unclear ownership, failed required gates, or missing required tooling. Never silently switch execution modes to bypass a blocker.

### Documentation map

EOF
  if [ "$DOMAIN_LAYOUT" = "Multiple contexts" ]; then
    printf '%s\n' "- \`$NS_DOMAIN\`: this repository's context-layout declaration."
    cat <<'EOF'
- Per-context `CONTEXT.md` files: canonical vocabulary for their package or context. No single root `CONTEXT.md` is canonical here.
- `CONTEXT-MAP.md`, when present: the map of real contexts and their glossaries; read it before recording vocabulary or new contexts.
EOF
    printf '%s\n' "- \`$NS_ADR\`: accepted architecture decisions." "- \`$NS_AGENTS/\`: workflow, tracker, and artifact-map configuration." "- \`$NS_SPECS\` or the configured tracker: feature behavior and acceptance."
    cat <<'EOF'
- implementation plans/tickets: execution entry points and explicit source references.
EOF
  else
    cat <<'EOF'
- `CONTEXT.md`: canonical domain vocabulary for the whole repository.
EOF
    printf '%s\n' "- \`$NS_ADR\`: accepted architecture decisions." "- \`$NS_AGENTS/\`: workflow, tracker, and artifact-map configuration." "- \`$NS_SPECS\` or the configured tracker: feature behavior and acceptance."
    cat <<'EOF'
- implementation plans/tickets: execution entry points and explicit source references.
EOF
  fi
}

render_tracker_doc() {
  echo "# Issue tracker"
  echo
  echo "Tracker: $TRACKER."
  echo
  if [ "$TRACKER_PROFILE" = epiq ]; then
    cat <<'EOF'
Tickets are tracked on the project's Epiq board through the `epiq_*` MCP tools.
Follow the Epiq workflow guidance for board operations; do not use the `epiq` CLI or edit Epiq state files directly.
The MCP server is configured by setup, but setup never initializes an Epiq board or project; do that explicitly when the project is ready.
Sync is explicit: call `epiq_sync` when you need to pull or publish board state.
EOF
  elif [ "$TRACKER" = "GitHub Issues" ]; then
    echo "Tickets are GitHub issues in this repository. Use the GitHub CLI (gh) to read and manage them."
  elif [ "$TRACKER" = "Local Markdown" ]; then
    echo "Tickets are Markdown files under $NS_TICKETS."
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

EOF
    echo "Cross-cutting decisions live in $NS_ADR."
  else
    cat <<'EOF'
Layout: single context.

- CONTEXT.md: canonical domain vocabulary for the whole repository.
EOF
    echo "- $NS_ADR: accepted architecture decisions."
  fi
}

render_artifacts_doc() {
  cat <<'EOF'
# Artifact mapping

Mapping: generated defaults. This file is declarative documentation, not executable configuration.

EOF
  echo "- $NS_RESEARCH: investigations, design studies, and probe reports."
  echo "- $NS_ADR: accepted architectural decisions."
  echo "- $NS_SPECS: behavioral contracts."
  echo "- $NS_PLANS: execution maps."
  echo "- $NS_TICKETS: local work items."
  echo "- $NS_AGENTS/: workflow configuration, including the tracker ($NS_TRACKER) and the context layout ($NS_DOMAIN)."
  echo "- CONTEXT.md: canonical domain vocabulary per the context layout declared in $NS_DOMAIN."
  cat <<'EOF'

Explicit project mappings recorded here override these defaults. Planning artifact and handoff semantics are owned by the `planning-contract` skill from `legout/skills`.

Setup never moves existing documents and never fabricates glossaries, ADRs, or placeholder folders to match this map. A misplaced document is evidence of misclassification, not a mapping rule; resolve conflicts explicitly with the owner.
EOF
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

artifacts_doc_is_owned() {
  local doc="$1"
  render_artifacts_doc | cmp -s - "$doc" && return 0
  {
    echo "# Artifact mapping"
    echo
    echo "Mapping: generated defaults. This file is declarative documentation, not executable configuration."
  } | cmp -s - "$doc" && return 0
  return 1
}

artifacts_doc_requires_replace() {
  local doc="$1"
  [ -f "$doc" ] || return 1
  artifacts_doc_is_owned "$doc" && return 1
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
  '' | *[!0-7]*) m=$(stat -f %Lp "$1" 2>/dev/null || true) ;;
  esac
  case "$m" in
  '' | *[!0-7]*) m=644 ;;
  esac
  echo "$m"
}

stat_sig() {
  local s
  s=$(stat -c '%s:%Y' "$1" 2>/dev/null || true)
  case "$s" in
  '' | *[!0-9:]*) s=$(stat -f '%z:%m' "$1" 2>/dev/null || true) ;;
  esac
  case "$s" in
  '' | *[!0-9:]*) s= ;;
  esac
  echo "$s:$(file_mode "$1")"
}

mcp_config_preview_action() {
  [ -n "$MCP_CONFIG_PATH" ] || return 0
  if ! command -v node >/dev/null 2>&1; then
    echo "requires node to render"
  elif [ ! -e "$MCP_CONFIG_PATH" ]; then
    echo "new file"
  elif mcp_config_merge | cmp -s - "$MCP_CONFIG_PATH"; then
    echo "unchanged"
  else
    echo "merged (existing entries preserved)"
  fi
}

print_preview() {
  local inst_doc="$PROJECT/$INSTRUCTION_FILE"
  local artifacts_doc="$PROJECT/$NS_ARTIFACTS"
  local tracker_doc="$PROJECT/$NS_TRACKER"
  local domain_doc="$PROJECT/$NS_DOMAIN"
  echo "=== Preview ==="
  echo "Skill scope: $SKILL_SCOPE"
  if [ -n "$PROJECT" ]; then
    echo "Project: $PROJECT"
  else
    echo "Project: none (--skip-project)"
  fi
  echo "--- $OPERATION commands (run only after approval) ---"
  render_install_lines
  echo
  require_prereqs report
  echo
  echo "--- subagent model settings ---"
  if command -v node >/dev/null 2>&1; then
    subagent_model_settings preview || echo "Subagent settings preview unavailable; fix invalid settings JSON before apply."
  else
    echo "Subagent settings preview unavailable until node is installed."
  fi
  if [ -n "$MCP_CONFIG_PATH" ]; then
    echo
    echo "--- MCP config: $MCP_CONFIG_PATH ($(mcp_config_preview_action)) ---"
    if command -v node >/dev/null 2>&1; then
      mcp_config_merge
    else
      echo "MCP config preview unavailable until node is installed."
    fi
  fi
  echo
  if "$MIGRATE_NAMESPACE"; then
    echo "--- namespace migration (docs/ -> project/, run only after approval) ---"
    if [ ${#MIGRATE_MOVES[@]} -gt 0 ]; then
      local move
      for move in ${MIGRATE_MOVES[@]+"${MIGRATE_MOVES[@]}"}; do
        echo "  $move"
      done
    else
      echo "  no legacy docs/ artifact directories; nothing to move"
    fi
    echo
  fi
  if "$BIN_LINK"; then
    echo "--- command symlink (created only after approval) ---"
    echo "  $BIN_LINK_PATH -> $ROOT/setup.sh"
    bin_link_path_warning
    echo
  fi
  echo "--- prompt commands (copied to $(prompt_dest_dir)) ---"
  for pf in $(package_prompt_files); do
    echo "  ${pf##*/}"
  done
  if [ -n "$PROJECT" ]; then
    echo
    if [ -f "$inst_doc" ]; then
      echo "--- $INSTRUCTION_FILE (managed block updated; all bytes outside the markers are preserved byte-for-byte) ---"
    else
      echo "--- $INSTRUCTION_FILE (new file) ---"
    fi
    render_instruction_file
    echo "--- $NS_ARTIFACTS ($(preview_doc_action "$artifacts_doc")) ---"
    render_artifacts_doc
    echo "--- $NS_TRACKER ($(preview_doc_action "$tracker_doc")) ---"
    render_tracker_doc
    echo "--- $NS_DOMAIN ($(preview_doc_action "$domain_doc")) ---"
    render_domain_doc
  fi
  echo "=== End preview ==="
}

preview_doc_action() {
  local approved=false
  if "$MIGRATE_NAMESPACE"; then
    approved=true
  fi
  if [ "$1" = "$PROJECT/$NS_ARTIFACTS" ] && artifacts_doc_requires_replace "$1"; then
    approved="$ARTIFACTS_CUSTOM_APPROVED"
    if "$REPLACE_CUSTOM" || "$MIGRATE_NAMESPACE" || "$approved"; then
      echo "custom content (replacement explicitly approved)"
    else
      echo "custom content (requires --replace-custom)"
    fi
  elif [ "$1" = "$PROJECT/$NS_TRACKER" ] && tracker_doc_requires_replace "$1"; then
    approved="$TRACKER_CUSTOM_APPROVED"
    if "$REPLACE_CUSTOM" || "$MIGRATE_NAMESPACE" || "$approved"; then
      echo "custom content (replacement explicitly approved)"
    else
      echo "custom content (requires --replace-custom)"
    fi
  elif [ "$1" = "$PROJECT/$NS_DOMAIN" ] && domain_doc_requires_replace "$1"; then
    approved="$DOMAIN_CUSTOM_APPROVED"
    if "$REPLACE_CUSTOM" || "$MIGRATE_NAMESPACE" || "$approved"; then
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
  local staged="$PROJECT/$rel"
  refuse_symlink_ancestors "$rel"
  T_REL[$idx]=$rel
  T_STAGE[$idx]=$stage
  # With --migrate-namespace the managed doc may still live at its legacy
  # docs/ path; it is moved there before writing, so stage its current state.
  if [ ! -f "$staged" ] && "$MIGRATE_NAMESPACE" && [ "${rel%%/*}" = project ] &&
    [ -f "$PROJECT/docs/${rel#*/}" ]; then
    staged="$PROJECT/docs/${rel#*/}"
  fi
  if [ -f "$staged" ]; then
    T_EXIST[$idx]=yes
    T_SIG[$idx]=$(stat_sig "$staged")
    T_MODE[$idx]=$(file_mode "$staged")
  else
    T_EXIST[$idx]=no
    T_SIG[$idx]=""
    T_MODE[$idx]=644
  fi
}

stage_mcp_config() {
  [ -n "$MCP_CONFIG_PATH" ] || return 0
  validate_mcp_config
  MCP_CONFIG_STAGE="$ORCH_WORK/mcp-config"
  mcp_config_merge >"$MCP_CONFIG_STAGE" || die "failed to stage MCP config $MCP_CONFIG_PATH (nothing has been modified)"
  if [ -f "$MCP_CONFIG_PATH" ]; then
    MCP_CONFIG_EXIST=yes
    MCP_CONFIG_SIG=$(stat_sig "$MCP_CONFIG_PATH")
    MCP_CONFIG_MODE=$(file_mode "$MCP_CONFIG_PATH")
    if cmp -s "$MCP_CONFIG_STAGE" "$MCP_CONFIG_PATH"; then
      MCP_CONFIG_ACTION=unchanged
    else
      MCP_CONFIG_ACTION=updated
    fi
  else
    MCP_CONFIG_EXIST=no
    MCP_CONFIG_SIG=
    MCP_CONFIG_MODE=644
    MCP_CONFIG_ACTION=created
  fi
  chmod "$MCP_CONFIG_MODE" "$MCP_CONFIG_STAGE" || die "failed to stage MCP config $MCP_CONFIG_PATH (nothing has been modified)"
}

stage_files() {
  validate_project_outputs
  ORCH_WORK=$(mktemp -d "${TMPDIR:-/tmp}/pi-orchestrator-setup.XXXXXX")
  trap 'test -z "${ORCH_WORK:-}" || rm -rf "$ORCH_WORK"' EXIT
  stage_mcp_config
  [ -n "$PROJECT" ] || return 0
  render_instruction_file >"$ORCH_WORK/instruction"
  render_artifacts_doc >"$ORCH_WORK/artifacts"
  render_tracker_doc >"$ORCH_WORK/tracker"
  render_domain_doc >"$ORCH_WORK/domain"
  T_REL=()
  T_STAGE=()
  T_EXIST=()
  T_SIG=()
  T_MODE=()
  T_ACTION=()
  prepare_target 1 "$NS_ARTIFACTS" artifacts
  prepare_target 2 "$NS_TRACKER" tracker
  prepare_target 3 "$NS_DOMAIN" domain
  prepare_target 4 "$INSTRUCTION_FILE" instruction
  local idx
  for idx in 1 2 3 4; do
    chmod "${T_MODE[$idx]}" "$ORCH_WORK/${T_STAGE[$idx]}" || die "failed to stage $ORCH_WORK/${T_STAGE[$idx]} (nothing has been modified)"
  done
}

concurrent_change_error() {
  echo "error: destination changed concurrently or is no longer a regular file: $1; rerun setup to converge" >&2
}

install_mcp_config() {
  [ -n "$MCP_CONFIG_PATH" ] || return 0
  local dir tmp
  dir=$(dirname "$MCP_CONFIG_PATH")
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir" || die "MCP config directory creation failed: $dir. Rerun setup to converge."
  fi
  refuse_mcp_symlink_ancestors "$MCP_CONFIG_PATH"
  if [ "$MCP_CONFIG_EXIST" = yes ]; then
    if [ ! -f "$MCP_CONFIG_PATH" ] || [ "$(stat_sig "$MCP_CONFIG_PATH")" != "$MCP_CONFIG_SIG" ]; then
      concurrent_change_error "$MCP_CONFIG_PATH"
      return 1
    fi
  elif [ -e "$MCP_CONFIG_PATH" ] || [ -L "$MCP_CONFIG_PATH" ]; then
    concurrent_change_error "$MCP_CONFIG_PATH"
    return 1
  fi
  if [ "$MCP_CONFIG_ACTION" = unchanged ]; then
    return 0
  fi
  tmp=$(mktemp "$dir/.pi-orchestrator-mcp.XXXXXX") || return 1
  if ! cat "$MCP_CONFIG_STAGE" >"$tmp" || ! chmod "$MCP_CONFIG_MODE" "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  refuse_mcp_symlink_ancestors "$MCP_CONFIG_PATH"
  if ! mv -f "$tmp" "$MCP_CONFIG_PATH"; then
    rm -f "$tmp"
    return 1
  fi
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
  if [ "$had" = yes ] && cmp -s "$ORCH_WORK/$stage" "$dest"; then
    T_ACTION[$idx]=unchanged
    return 0
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
  refuse_symlink_ancestors "$PROJECT_NS"
  refuse_symlink_ancestors "$NS_AGENTS"
  create_project_dir "$PROJECT_NS" || handle_directory_failure "$PROJECT/$PROJECT_NS"
  create_project_dir "$NS_AGENTS" || handle_directory_failure "$PROJECT/$NS_AGENTS"
  install_doc "$PROJECT/$NS_ARTIFACTS" artifacts 1 || handle_write_failure "$?" 1
  install_doc "$PROJECT/$NS_TRACKER" tracker 2 || handle_write_failure "$?" 2
  install_doc "$PROJECT/$NS_DOMAIN" domain 3 || handle_write_failure "$?" 3
  install_doc "$PROJECT/$INSTRUCTION_FILE" instruction 4 || handle_write_failure "$?" 4
}

migrate_legacy_namespace() {
  "$MIGRATE_NAMESPACE" || return 0
  if [ ${#MIGRATE_MOVES[@]} -eq 0 ]; then
    echo "Namespace migration: no legacy docs/ artifact directories remain; nothing to move."
    return 0
  fi
  local rel use_git
  if git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1; then
    use_git=true
  else
    use_git=false
  fi
  [ -d "$PROJECT/project" ] || mkdir "$PROJECT/project" ||
    die "namespace migration failed: cannot create $PROJECT/project; rerun setup to converge."
  for rel in ${MIGRATE_DIRS[@]+"${MIGRATE_DIRS[@]}"}; do
    [ -e "$PROJECT/docs/$rel" ] || [ -L "$PROJECT/docs/$rel" ] || continue
    if "$use_git" && git -C "$PROJECT" ls-files --error-unmatch "docs/$rel" >/dev/null 2>&1; then
      git -C "$PROJECT" mv "docs/$rel" "project/$rel" ||
        die "namespace migration failed for docs/$rel; rerun setup to converge. External installs already performed remain installed."
    else
      mv "$PROJECT/docs/$rel" "$PROJECT/project/$rel" ||
        die "namespace migration failed for docs/$rel; rerun setup to converge. External installs already performed remain installed."
    fi
    echo "Namespace migration: moved docs/$rel -> project/$rel"
  done
  STEPS_DONE="${STEPS_DONE:+$STEPS_DONE; }namespace migration (${#MIGRATE_MOVES[@]} directories)"
}

exec_install() {
  # usage: exec_install DESCRIPTION CMD...
  local desc="$1"
  shift
  local failure="external installation failed: $desc. No project files were changed. External steps already completed: ${STEPS_DONE:-none}."
  if [ "$OPERATION" = update ]; then
    failure="external update failed: $desc. Managed config was not written; the failing updater may have partially changed its own dependency files. External steps already completed: ${STEPS_DONE:-none}."
  fi
  if [ "$SKILL_SCOPE" = Project ]; then
    (cd "$PROJECT" && "$@") || die "$failure"
  else
    "$@" || die "$failure"
  fi
  STEPS_DONE="${STEPS_DONE:+$STEPS_DONE; }$desc"
}

run_installs() {
  STEPS_DONE=
  local package
  if [ "$OPERATION" = update ]; then
    if [ ${#SKILL_ARGS[@]} -gt 0 ]; then
      exec_install "npx skills update (${#UPDATE_SKILLS[@]} installed skills)" ${SKILL_ARGS[@]+"${SKILL_ARGS[@]}"}
    fi
    for package in ${UPDATE_PI_PACKAGES[@]+"${UPDATE_PI_PACKAGES[@]}"}; do
      if [ "$SKILL_SCOPE" = Project ]; then
        exec_install "pi update $package" pi update "$package"
      else
        (cd "$HOME" && exec_install "pi update $package" pi update "$package")
      fi
    done
  else
    exec_install "npx skills add legout/skills (${#LEGOUT_SKILLS[@]} skills)" ${SKILL_ARGS[@]+"${SKILL_ARGS[@]}"}
    local scope_flag=""
    [ "$SKILL_SCOPE" = Project ] && scope_flag="--local"
    local desc="pi install${scope_flag:+ $scope_flag}"
    exec_install "$desc npm:pi-subagents" pi install $scope_flag npm:pi-subagents
    exec_install "$desc npm:pi-intercom" pi install $scope_flag npm:pi-intercom
    if [ "$TRACKER_PROFILE" = epiq ]; then
      exec_install "$desc npm:pi-mcp-adapter" pi install $scope_flag npm:pi-mcp-adapter
    fi
  fi
}

install_prompts() {
  local dest f base copied=0 unchanged=0
  dest=$(prompt_dest_dir)
  # Recheck destination kind after external installs (same boundary as project writes).
  validate_prompt_outputs
  mkdir -p "$dest" || die "failed to create prompt-command directory: $dest; rerun setup to converge"
  for f in $(package_prompt_files); do
    base=${f##*/}
    if [ -f "$dest/$base" ] && cmp -s "$f" "$dest/$base"; then
      unchanged=$((unchanged + 1))
      continue
    fi
    cp "$f" "$dest/$base" || die "failed to install prompt command $base to $dest; rerun setup to converge"
    copied=$((copied + 1))
  done
  echo "Prompt commands: $copied updated, $unchanged unchanged -> $dest"
}

apply_phase() {
  print_preview
  echo
  if ! "$ASSUME_YES"; then
    if [ "$OPERATION" = update ]; then
      printf 'Run the listed updates and refresh changed managed configuration? [y/N] '
    elif [ -n "$PROJECT" ]; then
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
  stage_files
  run_installs
  [ -z "$STEPS_DONE" ] || POST_INSTALL=true
  migrate_legacy_namespace
  install_mcp_config || die "MCP config write failed; rerun setup to converge."
  install_prompts
  install_bin_link
  harmonize_subagent_models
  if [ -n "$PROJECT" ]; then
    write_project_files
  fi
  echo
  if [ "$OPERATION" = update ]; then
    echo "Update complete ($SKILL_SCOPE skill scope)."
  else
    echo "Setup complete ($SKILL_SCOPE skill scope)."
  fi
  if [ -n "$PROJECT" ]; then
    echo "Project files in $PROJECT:"
    echo "  $INSTRUCTION_FILE: managed block ${T_ACTION[4]:-written}"
    echo "  $NS_ARTIFACTS: ${T_ACTION[1]:-written}"
    echo "  $NS_TRACKER: ${T_ACTION[2]:-written}"
    echo "  $NS_DOMAIN: ${T_ACTION[3]:-written}"
  fi
  if [ -n "$MCP_CONFIG_PATH" ]; then
    echo "  Epiq MCP config: $MCP_CONFIG_PATH (${MCP_CONFIG_ACTION:-written})"
  fi
  print_setup_overview
}

suggested_command() {
  local cmd="./setup.sh" tflag tdesc
  if [ -n "$PROJECT" ]; then
    cmd="$cmd --project $(printf '%q' "$PROJECT")"
  else
    cmd="$cmd --skip-project"
    [ "$TRACKER_PROFILE" = epiq ] && cmd="$cmd --tracker epiq"
  fi
  if [ -n "$PROJECT" ]; then
    cmd="$cmd --instruction-file ${INSTRUCTION_FILE:-AGENTS.md}"
    case "${TRACKER:-GitHub Issues}" in
    "GitHub Issues") tflag=github ;;
    "Epiq") tflag=epiq ;;
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
    if tracker_doc_requires_replace "$PROJECT/$NS_TRACKER" || domain_doc_requires_replace "$PROJECT/$NS_DOMAIN" || artifacts_doc_requires_replace "$PROJECT/$NS_ARTIFACTS"; then
      cmd="$cmd --replace-custom"
    fi
  fi
  if [ "${SKILL_SCOPE:-Global}" = Project ]; then
    cmd="$cmd --skill-scope project"
  else
    cmd="$cmd --skill-scope global"
  fi
  [ "$OPERATION" != update ] || cmd="$cmd --update"
  if "$MIGRATE_NAMESPACE"; then
    cmd="$cmd --migrate-namespace"
  fi
  if "$BIN_LINK"; then
    cmd="$cmd --bin-link"
  fi
  cmd="$cmd --worker-model $(printf '%q' "$WORKER_MODEL_CHOICE")"
  cmd="$cmd --reviewer-model $(printf '%q' "$REVIEWER_MODEL_CHOICE")"
  cmd="$cmd --worker-thinking $WORKER_THINKING_CHOICE"
  cmd="$cmd --reviewer-thinking $REVIEWER_THINKING_CHOICE"
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
  echo "Choices (--instruction-file / --tracker / --domain-layout / --skill-scope / subagent model flags):"
  if [ -n "$PROJECT" ]; then
    echo "  instruction-file: ${INSTRUCTION_FILE:-?} [$INSTRUCTION_STATUS] $INSTRUCTION_NOTE"
    echo "  tracker: ${TRACKER:-?} [$TRACKER_STATUS] $TRACKER_NOTE"
    echo "  domain-layout: ${DOMAIN_LAYOUT:-?} [$LAYOUT_STATUS] $LAYOUT_NOTE"
  else
    if [ "$TRACKER_PROFILE" = epiq ]; then
      echo "  tracker: Epiq [$TRACKER_STATUS] $TRACKER_NOTE"
    else
      echo "  instruction-file / tracker / domain-layout: not applicable without --project"
    fi
  fi
  echo "  skill-scope: ${SKILL_SCOPE:-?} [$SCOPE_STATUS] $SCOPE_NOTE"
  echo "  operation: $OPERATION"
  if "$MIGRATE_NAMESPACE"; then
    echo "  namespace migration: requested"
    if [ ${#MIGRATE_MOVES[@]} -gt 0 ]; then
      printf '    %s\n' ${MIGRATE_MOVES[@]+"${MIGRATE_MOVES[@]}"}
    else
      echo "    no legacy docs/ artifact directories; nothing to move"
    fi
  fi
  if [ "$OPERATION" = update ]; then
    echo "  existing installation: $_UPDATE_STATUS $_UPDATE_NOTE"
    echo "    skills to update: ${UPDATE_SKILLS[*]:-none}"
    echo "    Pi packages to update: ${UPDATE_PI_PACKAGES[*]:-none}"
    echo "    missing skills skipped: ${UPDATE_SKILL_MISSING[*]:-none}"
    echo "    missing Pi packages skipped: ${UPDATE_PI_MISSING[*]:-none}"
    echo "    pinned Pi packages skipped: ${UPDATE_PINNED[*]:-none}"
  fi
  if "$MODEL_FLAGS_EXPLICIT"; then
    echo "  subagent models: explicit"
  else
    echo "  subagent models: keep existing [safe default]"
  fi
  echo "    worker: model=$WORKER_MODEL_CHOICE thinking=$WORKER_THINKING_CHOICE"
  echo "    reviewer: model=$REVIEWER_MODEL_CHOICE thinking=$REVIEWER_THINKING_CHOICE"
  echo "    settings target: $SUBAGENT_SETTINGS_PATH"
  if command -v node >/dev/null 2>&1; then
    resolve_agent_models | while IFS=$(printf '\t') read -r name model thinking source; do
      printf '    current %s: %s (thinking: %s) — %s\n' "$name" "$model" "$thinking" "$source"
    done
  else
    echo "    current values: unavailable until node is installed"
  fi
  echo "  prompt-command destination: $(prompt_dest_dir)"
  if "$BIN_LINK"; then
    echo "  command symlink: $BIN_LINK_PATH -> $ROOT/setup.sh"
  fi
  if [ -n "$MCP_CONFIG_PATH" ]; then
    echo "  Epiq MCP config: $MCP_CONFIG_PATH [$MCP_CONFIG_STATUS] $MCP_CONFIG_NOTE"
  fi
  if [ -n "$PROJECT" ]; then
    echo "Generated docs:"
    if artifacts_doc_requires_replace "$PROJECT/$NS_ARTIFACTS"; then
      echo "  $NS_ARTIFACTS: UNRESOLVED unrecognized custom content; pass --replace-custom only after explicit approval"
    else
      echo "  $NS_ARTIFACTS: owned/generated configuration"
    fi
    if tracker_doc_requires_replace "$PROJECT/$NS_TRACKER"; then
      echo "  $NS_TRACKER: UNRESOLVED unrecognized custom content; pass --replace-custom only after explicit approval"
    else
      echo "  $NS_TRACKER: owned/generated configuration"
    fi
    if domain_doc_requires_replace "$PROJECT/$NS_DOMAIN"; then
      echo "  $NS_DOMAIN: UNRESOLVED unrecognized custom content; pass --replace-custom only after explicit approval"
    else
      echo "  $NS_DOMAIN: owned/generated configuration"
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
