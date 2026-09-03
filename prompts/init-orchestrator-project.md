---
description: Reconfigure this project's pi-implementation-orchestrator workflow docs
---

Update this project's orchestrator configuration. Inspect the repository first; install nothing.

## Steps

1. Read the current instruction file (`AGENTS.md` and/or `CLAUDE.md`) and `docs/agents/issue-tracker.md`, `docs/agents/domain.md` if present.
2. Ask the user only the choices that are unresolved, using the same defaults as `./setup.sh`:
   - Instruction file: if both `CLAUDE.md` and `AGENTS.md` exist, ask which is authoritative; if exactly one exists, use it; if neither, ask, defaulting to `AGENTS.md`.
   - Issue tracker: if `git remote get-url origin` points at github.com, default to GitHub Issues; otherwise default to Local Markdown; "Other" requires one descriptive line from the user.
   - Domain layout: Single context unless monorepo signals exist (`pnpm-workspace.yaml`, `"workspaces"` in `package.json`, or `packages/*/src`); with signals, ask, defaulting to Single context.
3. Update only the managed block between these exact markers in the chosen instruction file:

   ```text
   <!-- pi-implementation-orchestrator:start -->
   <!-- pi-implementation-orchestrator:end -->
   ```

   and regenerate `docs/agents/issue-tracker.md` and `docs/agents/domain.md` from the chosen values.
4. Preserve all user content outside the managed block byte-for-byte, except for one separating newline. If the file contains zero or one start marker and zero or one end marker (matched), the block may be appended or replaced; any other marker count is ambiguous — report it and edit nothing.
5. Do not install packages or skills. `./setup.sh` owns installation; this prompt only updates project documentation.

The managed block must read:

```markdown
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
```

`setup.sh` in the pi-implementation-orchestrator repository is the canonical source for this block.
