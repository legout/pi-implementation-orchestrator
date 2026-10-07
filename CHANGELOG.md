# Changelog

## Unreleased

- Dispatch now enforces one visible sibling worktree root per checkout across Pi, Herdr, and Paseo, blocking any backend whose allocator/config cannot honor it before writer launch; model/path preflight never substitutes an allocator or model. Setup asks for worker/reviewer model and thinking values, showing effective values or the spec defaults (`zai/glm-5.3`/`high`; `openai-codex/gpt-6.1-sol`/`high`).
- The `new-test` validation obligation is now independence-first rather than test-first: one focused test at the cheapest stable public seam with expected values derived independently of the implementation under test (spec, acceptance criteria, or another oracle); failing-test-first is retained only for bug repros and behavior pinning before refactors. The generated Agent-workflow block (including new reviewer failure modes for generated tests), README, and design docs state the new semantics; the sibling `legout/skills` repo lands the matching skill-text changes in its own changelog entry.

- README now states the repository's role explicitly — the Pi distribution of the legout implementation stack, not a runtime orchestrator — and documents harness portability: the planning skills are pi-free and installable via the Agent Skills CLI to other agents, while `setup.sh`, the package manifest, lifecycle prompts, and settings wiring stay pi-only.

- Generated workflow guidance now permits explicit `herdr-pane` and `paseo` run/lane overrides while retaining default builtin Pi workers/reviewers and all approval gates; Herdr/Paseo dependencies remain separately managed.

- Added `--bin-link`: creates `~/.local/bin/pi-orchestrator-init` as an approval-gated symlink to the pi-managed clone's `setup.sh` (refused from checkouts/tarballs, collision-safe, no-op on rerun).

## 0.3.0 - 2026-09-17

- Changed the default planning-artifact namespace from `docs/` to `project/` (`project/research|adr|specs|plans|tickets/`, `project/agents/`) so delivery artifacts no longer collide with product documentation. Existing installations with legacy `docs/` artifact directories keep their namespace automatically; setup never migrates or duplicates artifacts.
- Added explicit `--migrate-namespace` migration: previewed, approval-gated moves of legacy `docs/` artifact directories to `project/` (git-aware), with managed docs regenerated at the new namespace and user content preserved; interrupted migrations converge on rerun.
- Added approval-gated `--update` support, including Pi prompt recognition of `update`/`upgrade` input, selected-scope installation checks, `npx skills update`/`pi update` for installed components, safe skips for missing or pinned dependencies, and byte-preserving managed-file refreshes.
- Added optional, scope-aware `worker`/`reviewer` model and thinking selection. Existing global overrides are preserved by default; explicit choices update only selected fields and are shown in inspect/dry-run output before approval.
- Added first-class Epiq tracker setup with conditional `pi-mcp-adapter` installation and safe, scope-selected `epiq-mcp` configuration merging for `.mcp.json` or `~/.config/mcp/mcp.json`.
- Documented direct setup without the prompt: invoking the installed package copy's `setup.sh` and a pinned-tarball curl bootstrap usable for first initialization.

## 0.2.0 - 2026-09-15

- Project-scope setup fills missing `model`/`thinking` fields in `.pi/settings.json` `subagents.agentOverrides` from the global `~/.pi/agent/settings.json`, so a partial project override (e.g. `{"tools":"inherit"}`) no longer shadows the configured worker model.
- Every apply ends with an overview of the effective `worker`/`reviewer` models, their source, and where to change them (project `.pi/settings.json`, global `~/.pi/agent/settings.json`, or `/subagents` inside pi).
- Documentation and the generated instruction block now reflect the current `legout/skills` proportional assurance policy: validation-unit obligations, tracer-bullet slices, and low/normal/high-risk review mapping.
