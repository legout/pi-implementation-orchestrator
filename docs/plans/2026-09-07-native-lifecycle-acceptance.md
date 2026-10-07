# Native managed-worker lifecycle acceptance

Status: open. The durable handoff/recovery implementation is published; this is the one remaining live runtime check from the archived orchestration plan.

## Goal

Prove the shipped `orchestrate-implementation` recovery contract through the native Pi subagent protocol, without using a real project, CLI fallback, push, PR, deploy, or release.

## Source and scope

- Archived source plan: [`2026-09-07-orchestrator-skill-contracts.md`](archive/2026-09-07-orchestrator-skill-contracts.md), especially former Task S2.
- Runtime fixture: `../../skills/skills/workflow/orchestrate-implementation/evals/fixtures/managed-lifecycle.md`.
- Target skill revision: `../../skills` `main` at `57d3a7e`.
- Required agents: preflight capability discovery, one builtin `worker`, and fresh read-only builtin `reviewer` review.
- All Git refs and worker/fix/review/candidate worktrees must stay in a disposable temporary setup, with every checkout registered beneath `$run_root/worktrees/repo/`. Handoff patches and reports must remain outside disposable worker worktrees and retain exact paths.

## Procedure

- [ ] Read the current Pi-subagents runtime/version and discover executable agent capabilities. Record the exact runtime facts and native request shapes.
- [ ] Resolve the exact worker/reviewer model and thinking pairs from run/lane, project, global, then spec defaults; verify both are executable before agent creation and record each source. Run the fixture end-to-end in a disposable Git repository: verify the selected allocator will place the worker beneath `$run_root/worktrees/repo/`, pin a collision-checked named base, launch a small managed worker from that `baseRef`, verify its actual registered path and effective pair before edits, allow normal child finalization, move the parent `HEAD`, reconstruct and review the lane under the same root from its durable patch/digest, launch a fresh fix worker from the same base, replay the complete replacement patch, and record a registered candidate handoff under the root.
- [ ] Record run IDs, report/artifact availability, worker and reconstructed SHAs/trees, review verdicts, cleanup state, preserved/removed worktrees, and any exact blocker. Do not treat a provider or tooling failure as success.
- [ ] If the run passes, change the fixture from `PENDING` to a dated verified status, update the sanitized evidence, rerun the skills checks, and push. If blocked, retain the evidence and replace this procedure with the exact owner-actionable blocker rather than inventing a fallback.

## Acceptance

The plan closes only when the native run proves the exact shared root for worker/fix/review/candidate worktrees, exact role model/thinking settings, worker finalization, parent-`HEAD` movement, byte-preserving patch replay, fresh fix/review, candidate registration, and cleanup evidence. Offline tests and prose evaluation do not substitute for this run.
