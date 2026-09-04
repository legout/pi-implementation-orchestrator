---
description: Set up or update pi-implementation-orchestrator for a new or existing project
---

# Setup Implementation Orchestrator

Run the package's deterministic setup workflow for this request: `$@`.

1. Locate this package's `setup.sh`. Use `./setup.sh` when this is the package checkout; otherwise inspect `pi list` to find the installed `legout/pi-implementation-orchestrator` package. If it cannot be located, ask for the checkout/package path instead of guessing.
2. Read `setup.sh --help`. Resolve the requested planning profile (`matt`, `superpowers`, or `both`) and target project path, or an explicit choice to skip project configuration. Ask for missing values.
3. For a project, inspect existing `AGENTS.md`/`CLAUDE.md`, its origin remote, and monorepo signals. Ask only unresolved instruction-file, tracker, and domain-layout choices.
4. Pass every choice as an explicit flag and run exactly one preview with `--dry-run`. Show the complete install commands and project-file preview.
5. Require explicit approval. Then run the identical command with `--dry-run` removed and `--yes` added. Never edit project files or install skills outside `setup.sh`.
6. Report installed skills/packages and written project files. The setup script installs runtime skills from `legout/skills` with `npx skills`.
