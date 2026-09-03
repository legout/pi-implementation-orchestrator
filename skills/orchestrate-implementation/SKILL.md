---
name: orchestrate-implementation
description: Use when implementing a project or feature from ADRs, specifications, issues, or plans, especially when work spans multiple tasks, reviewers, worktrees, repositories, or Pi sessions.
---

# Orchestrate Implementation

## Overview

The current session is the orchestrator. Keep user intent, scope, authority, routing, integration, and final acceptance here. Delegate bounded evidence gathering and implementation; do not turn a collection of chat sessions into an implicit scheduler.

**REQUIRED SUB-SKILL:** Use `pi-subagents` for child lifecycle, fresh contexts, managed worktrees, artifacts, missions, review, and recovery.

Use `pi-intercom` only for explicitly named, persistent read-only peers or visible cross-project peers. Spawned children use Pi's native supervisor channel for decisions and progress.

## Modes

Choose one mode from the request or configured default:

- **`plan-only`**: normalize inputs, create the manifest and task briefs, and make no source edits.
- **`supervised`** (default): run workers, validation, fresh review, and accepted fix/re-review cycles; pause before cherry-picking or publication.
- **`autonomous`**: run the same loop and cherry-pick accepted commits when clean; pause on conflicts, unresolved decisions, failed gates, missing required peers, push, PR merge, deploy, or release.

If the user does not specify a mode, use `supervised` and state that choice briefly.

## Intake and preflight

Read all supplied ADRs, specifications, issues, plans, and approved designs before dispatching a writer. Preserve them as source material. Extract:

- constraints, invariants, and non-goals;
- acceptance criteria and validation evidence;
- source seams and claimed files/contracts;
- task dependencies and integration order; and
- unresolved owner decisions.

Stop before mutation when inputs conflict or a material acceptance criterion is missing. Ask for the exact owner decision instead of selecting one silently.

Require a git repository for mutation modes. Verify repository, cwd, base ref, cleanliness, and worktree support before allocating writers. A non-git directory may use `plan-only`; it must not receive mutation-capable workers.

Normalize different plan formats with a read-only scout. Preserve the planner's source documents; do not require every planning skill to emit one new format.

## Run manifest

Create one compact run manifest in runtime-managed artifacts. Record:

- repository, cwd, base ref, and mode;
- source artifact references;
- normalized constraints, non-goals, and acceptance criteria;
- task IDs, dependency edges, lanes, and claimed files/contracts;
- worker, reviewer, simplifier, oracle, and peer configuration;
- validation commands and review-round cap;
- unresolved decisions and their owners;
- commit, cherry-pick, lane, and handoff state; and
- residual risks and artifact references.

Store large content in artifacts. Keep only paths and concise summaries in the manifest or mission state.

## Cold-start task brief

Give each worker one bounded brief containing:

1. goal;
2. repository, cwd, base ref, lane, and managed worktree;
3. allowed files/contracts and authority boundary;
4. relevant upstream interfaces and approved decisions;
5. acceptance criteria;
6. focused validation commands;
7. TDD requirement: failing test, minimal implementation, passing test, then refactor;
8. commit and report requirements; and
9. stop/escalate conditions.

Do not paste the complete plan or accumulated task history into worker prompts.

The worker report contains:

- status and commit IDs;
- changed files;
- TDD evidence: the test that failed before implementation and passed afterward;
- validation commands and results;
- open decisions and residual risks; and
- artifact and handoff references.

Workers do not expand scope, integrate other lanes, publish, or delegate further unless the orchestrator explicitly grants that authority.

## Roles and context

| Role | Context | Authority |
|---|---|---|
| Orchestrator | Parent | Routing, decisions, acceptance, integration |
| Scout/normalizer | Fresh | Read-only repository and input inspection |
| Worker | Fresh | Sole writer in one managed worktree; uses TDD |
| Reviewer | Fresh | Read-only review against the exact task diff |
| Simplifier | Fresh | Optional read-only complexity challenge |
| Oracle | Forked, exceptional | Advisory hard-decision escalation |

Profiles represent stable model, tool, thinking, context, or stance differences. Do not create a profile per task.

## Persistent intercom peers

Persistent peers are optional read-only consultants:

- `architecture-peer`: ADR and design consistency;
- `domain-peer`: product and domain ambiguity; and
- `quality-peer`: retained quality perspective before integration.

At configured checkpoints:

1. call `intercom({ action: "list" })`;
2. ask only live, explicitly configured peers bounded questions;
3. record advice as evidence in the manifest; and
4. use the configured missing-peer policy: `fresh-advisor` or `pause`.

Named peers must already be running or be opened separately as visible project panes. Do not claim that intercom created a clean session. Peers may not edit production code, commit, integrate, push, merge, deploy, or release.

Spawned children use `contact_supervisor` for blocking decisions or meaningful progress. The parent responds through `subagent_supervisor`. Do not route ordinary child lifecycle through generic intercom.

## Lane ownership

- Parallel mutation requires separate managed worktrees.
- One writer owns each worktree and source seam.
- Dependent tasks wait for upstream handoffs.
- Read-only children may share a checkout only when they cannot change project state.
- Each worker makes focused commits.
- The orchestrator cherry-picks only accepted commits.
- A conflict pauses integration; it never starts another writer against uncertain ownership.

Record a lane board before parallel mutation:

```text
Lane | repo/cwd | task decision | claimed files/contract | worktree | authority | next gate | handoff
```

## Native Pi dispatch recipe

For a coordinated wave, make exactly one top-level `subagent` call with `async: true` and a `workflowScript`.

- Use `runs.run` for dependent stages.
- Use `runs.all` for independent read-only work.
- Use `runs.lanes` for predeclared serial stages across independent lanes.
- Use stable keys and distinct managed output paths.
- Set fresh context for scouts, workers, reviewers, and validators.
- Set `worktree: true` on parallel mutation-capable children.
- Give every worker `skill: "tdd"` unless its selected profile already guarantees TDD; require red-green-refactor evidence in its report.
- Do not set hard tool budgets on mutation-capable workers.
- Return output references, commit IDs, and handoffs instead of copying full reports into later prompts.

A worker launch names the brief path, repo/cwd/ref, authority, claimed seam, validation, commit requirement, output, and escalation rules. A reviewer launch names the same brief, worker report, and exact diff package.

## Execution loop

1. Read source artifacts.
2. Preflight constraints, dependencies, conflicts, and repository state.
3. Consult configured persistent peers when useful.
4. Create the manifest, briefs, lane board, and gates.
5. Run fresh scouts for load-bearing context.
6. Dispatch workers in safe serial or parallel waves.
7. Run focused validation in each worker worktree.
8. Obtain a fresh task review against the exact diff.
9. Return valid blockers to the same writer for fix/re-review when its managed worktree still exists and the child is resumable; otherwise launch a fresh fix worker in a new managed worktree from the exact original base, apply the durable prior handoff patch, then apply accepted findings.
10. Cherry-pick accepted commits according to mode.
11. Run a fresh whole-branch review.
12. Run final typecheck, lint, tests, and project acceptance commands.
13. Keep push, PR merge, deploy, and release behind separate authority gates.

Cap review loops. Stop when no blocking fix remains, an owner decision is required, or the configured cap is reached. Do not loop for optional polish.

## Findings and recovery

Classify each finding against the exact reviewed head:

- **valid blocker**: fix and revalidate now;
- **valid non-blocker**: record or defer explicitly;
- **stale**: absent at current head;
- **invalid**: contradicted by source, tests, or approved scope;
- **speculative**: lacks a reachable failure or contract; or
- **out of scope/policy**: needs owner authority.

Treat `needs_attention` as a control signal, not proof of failure. Preserve stopped or failed worktrees and artifacts until ownership is clear. Do not launch a replacement while the original writer may still own the seam. Inspect exact head and focused logs before classifying a failed gate.

A completed child's managed worktree may be removed automatically before a later resume. Child cwd or session survival is never the recovery boundary; durable handoff patch paths recorded in the manifest are. If the managed worktree still exists and the child is resumable, resume the same writer; otherwise launch a fresh fix worker in a new managed worktree from the exact original base and apply the durable prior handoff patch before the accepted findings.

Escalate product, architecture, credential, merge, release, and publication choices instead of guessing.

## Completion evidence

Before accepting a run, verify:

- final diff contains only intended files;
- focused validation covers changed behavior;
- substantial changes have fresh review evidence;
- accepted findings were fixed and revalidated;
- every lane is terminal or blocked with a named next action;
- handoffs are durable before worktree cleanup; and
- skipped validation and residual risks are explicit.

Reviewer reports, CI checks, and receipts are evidence, not publication authority.

## Quick reference

| Situation | Action |
|---|---|
| Non-git directory | `plan-only`; no mutation workers |
| Conflicting sources | Stop before dispatch; request owner decision |
| Independent writers | Managed worktree per writer |
| Dependent tasks | Serial handoff with explicit interface |
| Spawned child question | Native supervisor channel |
| Persistent specialist | Named read-only intercom peer |
| Missing optional peer | Fresh advisor fallback |
| Missing required peer | Pause |
| Review blocker | Resumable writer with intact worktree fixes; otherwise fresh fix worker replays the durable prior handoff patch; fresh re-review |
| Integration conflict | Pause and preserve ownership |
| Push/merge/deploy/release | Separate authority gate |

## Common mistakes

- Treating intercom messages as durable state instead of using missions and artifacts.
- Calling persistent sessions "clean" despite retained history.
- Running parallel writers in one checkout.
- Giving every worker the whole plan and accumulated reports.
- Letting a reviewer or worker become the final scope or publication authority.
- Starting a replacement writer before failed-lane ownership is resolved.
- Assuming a completed child's worktree or cwd still exists at fix time; durable handoff patch paths, not child session survival, are the recovery boundary.
- Calling autonomous integration permission to publish.
