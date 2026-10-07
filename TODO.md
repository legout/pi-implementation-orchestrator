# TODO

- [x] Use one external sibling worktree root per checkout (`<repo-parent>/worktrees/<repo-name>/`) for dispatcher and parent review/candidate worktrees; preserve the selected allocator or pause if it cannot honor the root. See [the spec](docs/specs/2026-10-07-0002-cross-backend-dispatch-policies.md).
- [x] Keep worker and reviewer model/thinking settings consistent across dispatchers. Ask for them during setup/reconfigure, using the current settings or defaults (worker `zai/glm-5.3` / `high`; reviewer `openai-codex/gpt-6.1-sol` / `high`); project/run overrides take precedence. See [the spec](docs/specs/2026-10-07-0002-cross-backend-dispatch-policies.md).
