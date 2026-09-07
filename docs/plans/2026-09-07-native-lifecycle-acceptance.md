# Native managed-worker lifecycle acceptance

Status: open. The durable handoff/recovery implementation is published; this is the one remaining live runtime check from the archived orchestration plan.

## Goal

Prove the shipped `orchestrate-implementation` recovery contract through the native Pi subagent protocol, without using a real project, CLI fallback, push, PR, deploy, or release.

## Source and scope

- Archived source plan: [`2026-09-07-orchestrator-skill-contracts.md`](archive/2026-09-07-orchestrator-skill-contracts.md), especially former Task S2.
- Runtime fixture: `../../skills/skills/workflow/orchestrate-implementation/evals/fixtures/managed-lifecycle.md`.
- Target skill revision: `../../skills` `main` at `57d3a7e`.
- Required agents: preflight capability discovery, one native `implementer`, and fresh read-only `code-reviewer` review.
- All Git refs, worktrees, patches, and artifacts must stay inside a disposable temporary repository.

## Procedure

- [ ] Read the current Pi-subagents runtime/version and discover executable agent capabilities. Record the exact runtime facts and native request shapes.
- [ ] Run the fixture end-to-end in a disposable Git repository: pin a collision-checked named base, launch a small managed worker from that `baseRef`, allow normal child finalization, move the parent `HEAD`, reconstruct and review the lane from its durable patch/digest, launch a fresh fix worker from the same base, replay the complete replacement patch, and record a registered candidate handoff.
- [ ] Record run IDs, report/artifact availability, worker and reconstructed SHAs/trees, review verdicts, cleanup state, preserved/removed worktrees, and any exact blocker. Do not treat a provider or tooling failure as success.
- [ ] If the run passes, change the fixture from `PENDING` to a dated verified status, update the sanitized evidence, rerun the skills checks, and push. If blocked, retain the evidence and replace this procedure with the exact owner-actionable blocker rather than inventing a fallback.

## Acceptance

The plan closes only when the native run proves worker finalization, parent-`HEAD` movement, exact patch replay, fresh fix/review, candidate registration, and cleanup evidence. Offline tests and prose evaluation do not substitute for this run.
