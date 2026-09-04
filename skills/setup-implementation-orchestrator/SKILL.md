---
name: setup-implementation-orchestrator
description: Use when the user explicitly asks to install or configure pi-implementation-orchestrator for a new or existing project.
disable-model-invocation: true
---

# Setup Implementation Orchestrator

The setup workflow behind the `/setup-implementation-orchestrator` prompt. The prompt loads this skill, which handles both new-project setup and reconfiguration of an existing project. Installing the package is passive: it only loads the package's prompt and skills. All installation and project configuration happens here, through `setup.sh`, only after the user explicitly requests setup and approves the exact changes.

## Contract

- Locate this skill's own directory, then resolve the package's `setup.sh` at `../../setup.sh` (two levels up from this SKILL.md). Verify that file exists before doing anything else; if you cannot find it, ask the user for the package/clone location instead of guessing.
- Never edit project files yourself and never bypass `setup.sh`: every install and every write goes through exactly one `setup.sh` invocation per phase. You gather choices and approval; `setup.sh` does the work.
- Never run setup, install packages, or touch any project without explicit user request and explicit approval of the previewed changes.
- Run `setup.sh` with Bash. It requires no stdin input when every choice is passed as an explicit flag.

## Steps

1. **Collect inputs.** Read the user's request for the planning profile (`matt`, `superpowers`, or `both`) and the target project path (or an explicit decision to skip project setup with `--skip-project`). Ask for any that are missing; do not assume them. The target may be a new project directory or an existing project that should be updated.
2. **Resolve choices.** When a project is given, inspect it first, then ask the user only the choices that are unresolved and convert every answer into an explicit flag so `setup.sh` never prompts:
   - Instruction file: `--instruction-file AGENTS.md` or `--instruction-file CLAUDE.md`. If both files exist, ask which is authoritative; if exactly one exists, use it; if neither, ask, defaulting to `AGENTS.md`.
   - Issue tracker: `--tracker github` (GitHub Issues, default when `git remote get-url origin` points at github.com), `--tracker local` (local Markdown, default otherwise), or `--tracker other` with `--tracker-description "<one line>"` (required, non-empty).
   - Domain layout: `--domain-layout single` (default) or `--domain-layout multi` (offer only with monorepo signals: `pnpm-workspace.yaml`, `"workspaces"` in `package.json`, or `packages/*/src`).
3. **Dry run first.** Build the exact command and run it with `--dry-run` added:

   ```bash
   bash <package-root>/setup.sh --planning <matt|superpowers|both> --project <path> \
     --instruction-file <AGENTS.md|CLAUDE.md> --tracker <github|local|other> \
     [--tracker-description "<text>"] --domain-layout <single|multi> --dry-run
   ```

   Use `--skip-project` instead of `--project` when the user explicitly skips project setup. `--dry-run` prints every install command and the full project preview while writing nothing.
4. **Get explicit approval.** Show the complete preview (install commands, managed block, generated docs) and ask the user to approve it. If the user declines or changes a choice, stop or rebuild the command and repeat the dry run. Never proceed to mutation without approval.
5. **Execute.** Only after approval, run the exact same command with `--dry-run` removed and `--yes` added. Do not change any other flag between the preview and the execution.
6. **Report.** Summarize the installed skills (including `orchestrate-implementation`, `merge-worktree`, `make-release`, and `resolving-merge-conflicts`) and Pi packages, and the project files written (`AGENTS.md`/`CLAUDE.md` managed block, `docs/agents/issue-tracker.md`, `docs/agents/domain.md`). If anything failed, report the exact error and the state actually written. For future changes, invoke this same skill again; it is the only project setup/reconfiguration entrypoint.

## Reminders

- `setup.sh --help` lists all flags; pass every choice explicitly so the run is deterministic.
- Reruns are idempotent: the managed block between `pi-implementation-orchestrator` markers is replaced and surrounding content is preserved byte-for-byte.
- This skill never pushes, merges, deploys, publishes, or authenticates GitHub.
