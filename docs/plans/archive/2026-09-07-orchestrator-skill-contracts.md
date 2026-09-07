# Implementation plan: durable orchestration and safe skill handoffs

> **Archived plan — implementation mostly landed.** Durable handoff/recovery, domain/prototype boundaries, and offline regression coverage shipped. The remaining native managed-worker lifecycle execution is narrowed into `docs/plans/2026-09-07-native-lifecycle-acceptance.md`. The original unchecked ledger is retained for traceability.

## Status and scope

**Archived implementation record.** Parent plan: [safe, faster setup](2026-09-07-orchestrator-safety-and-setup.md).

- **Goal:** close review findings 4–6 without depending on worker-worktree survival, bypassing production approval, or creating contradictory domain glossaries.
- **Source requirements:** parent acceptance criteria A4–A6 and A10. Existing skill sources are in the sibling `../skills` repository, reviewed at main `75db0c4`.
- **Working directory:** all task paths and commands below are relative to `../skills`, not the installer checkout. Verify repo/cwd/HEAD and instructions before mutation.
- **Architecture:** `pi-subagents` retains ownership of child allocation, lifecycle, artifacts, and cleanup. The orchestrator owns durable review material, parent-owned review/candidate checkouts, acceptance, and candidate assembly. `merge-worktree` owns integration into the target branch.
- **Runtime evidence:** the audit inspected installed `pi-subagents` 0.66.0. Its managed workers can lose their worktree and branch on completion; `baseRef` accepts supported named refs, not raw commit SHAs. Revalidate these facts against the actual runtime used for implementation and record its version. Do not assume an undocumented retention flag or change upstream Pi as part of this plan.
- **Non-goals:** a new scheduler, new runtime package dependency, automatic publishing, arbitrary historical artifact repair, or unrelated catalog cleanup. Do not modify installed global skill copies.
- **Writer order:** one sequential writer owns S1–S3 because they share `tests/skills_test.sh`. Only the separate installer-repository lane may write concurrently.

## Proposed lifecycle contract

### Durable input and base

Before mutation dispatch, create an owned, collision-checked named base branch such as `refs/heads/orchestrator/<run>/base/<lane>` at the approved lane base. Record both its name and resolved SHA. Use the named ref for managed allocation and require it still resolves to that SHA on every recovery. Never reuse a moved branch or silently fall back to the parent's current HEAD.

Record the brief, source refs, runtime handoff/patch path, patch digest, worker-reported commit/tree and cleanliness, and later reconstructed review/candidate refs in the existing manifest. Distinguish worker provenance from the SHAs actually reviewed. Keep pins until all consumers are terminal and durable handoff is secured; delete only explicitly owned temporary refs during authorized cleanup.

### Completed-lane review

Treat the runtime's captured patch as the durable replay payload, not the worker path. Inspect handoff status and capture/cleanup warnings before proceeding. Missing, partial, inconsistent, or dirty/uncommitted results are blockers, not successful lanes merely because the child exited.

When a worker worktree no longer exists:

1. Create a **parent-owned registered review worktree**, outside extension auto-discovery and the active source checkout, at the verified named base.
2. Verify artifact identity/digest; apply the full binary-capable patch with `git apply --check` and `git apply --index`. Never substitute fuzzy patching or silently omit files.
3. Verify the reconstructed staged tree against the expected clean worker tree; record the newly materialized tree and review commit. Worker reports are supporting evidence, not a substitute for inspecting the artifact and reconstructed diff.
4. Run focused checks on that exact tree and dispatch a fresh read-only reviewer against its explicit base/head. Reviewers do not get mutation worktrees or assemble changes.
5. Advance `lastReviewedSha` only on the reconstructed branch whose range was reviewed. If reconstruction/fix replay changes history, reset its review boundary to the pinned base and review the full replacement range. Never copy a clean verdict from a different branch or tree.

Parent-owned review/candidate checkouts are a deliberate exception to the current blanket prohibition on manual worktrees. They are not nested child worktrees, are not a second child allocator, and never become concurrent shared-writer locations. Managed mutation children remain managed by `pi-subagents`.

### Fixes and candidate assembly

- Resume a worker only when both runtime resumability and its owned worktree are valid. Do not launch a replacement while the old writer may still be active.
- Otherwise allocate a fresh managed fix worker from the verified named base, replay the prior full handoff patch, then apply the accepted findings. Require a fresh complete patch/tree and revalidate/re-review it.
- A fix patch captured relative to the original base **replaces** the prior full lane patch; it is not an incremental patch to apply on top of the previous lane result.
- Once lanes are accepted, assemble their reconstructed reviewed commits in a separate, explicitly registered candidate worktree, in dependency order. `supervised` still pauses before assembly; `autonomous` may assemble accepted lanes but does not gain target-integration or publication permission.
- Final checks and fresh review use the exact candidate range/tree. Hand the registered candidate path, branch, base/head, validation, review evidence, and authorization state to `merge-worktree`; do not hand it a deleted worker path.
- A dependent worker consumes a verified, reviewed upstream base/interface, not merely a prose report. If this requires candidate assembly in supervised mode, obtain that permission first.
- `plan-only` creates no refs, worktrees, patches, or source commits; only its normal planning artifacts.

## Task S1 — Make the documented lifecycle replayable

**Files to modify:**

- `skills/workflow/orchestrate-implementation/SKILL.md`
- `skills/workflow/orchestrate-implementation/references/pi-dispatch.md`
- `skills/workflow/orchestrate-implementation/references/manifest-and-briefs.md`
- `skills/workflow/orchestrate-implementation/references/review-and-recovery.md`
- `skills/workflow/merge-worktree/SKILL.md` (candidate input contract only)
- `tests/skills_test.sh`

**Files to add:** `tests/orchestrator_handoff_test.sh`.

**Prerequisites:** parent A4 approved; runtime behavior checked. One writer owns this task and S2 sequentially.

**Obligation:** `new-test` — lifecycle/recovery behavior is currently unproven and contractually inconsistent.

- [ ] Red: create a temporary-Git fixture that makes a base, commits a lane change, captures its full binary patch/tree, removes the worker worktree/branch, and moves the parent HEAD. Demonstrate that the old worker-path/current-HEAD recipe cannot satisfy the review/base assertions.
- [ ] Implement the proposed contract in the existing skill and references. Include one concise command example for base pinning, exact patch replay, reconstructed review, and candidate handoff; no calls to nonexistent retention APIs.
- [ ] Separate worker SHA provenance, materialized review SHA/tree, lane review boundary, and candidate SHA/tree in manifests and briefs. Define reset behavior after a full-patch fix replay.
- [ ] Replace unconditional worker-path review and “cherry-pick worker commits only” language with reviewable reconstructed commits. Amend the manual-worktree prohibition only for owned review/candidate checkouts.
- [ ] Ensure dependent task bases contain accepted upstream changes and preserve supervised/autonomous/plan-only differences.
- [ ] Green: execute the new recipe in the fixture. Verify the pinned base, tree equality, focused check result, full-patch replacement after a fix, candidate review range, and registered candidate handoff.
- [ ] Include additions/deletions, a small binary change, mode changes, and a symlink in the patch fixture. Corrupt the patch or move the named base and assert refusal; preserve artifacts on failure. No remote operations or LLM calls in this offline test.
- [ ] Update static contract checks so contradictory legacy wording fails rather than merely requiring a few positive keywords.

**Commands:**

```bash
bash -n tests/orchestrator_handoff_test.sh
bash tests/orchestrator_handoff_test.sh
bash tests/skills_test.sh
git diff --check
```

**Done:** documented recovery succeeds without the original worker branch/path, and validation is bound to the actual reconstructed tree rather than current HEAD.

## Task S2 — Verify the real Pi boundary and wire regression coverage

**Files to modify:**

- `.github/workflows/test.yml`
- `skills/workflow/orchestrate-implementation/evals/evals.json`
- `skills/workflow/orchestrate-implementation/references/pi-dispatch.md`

**Files to add:**

- `skills/workflow/orchestrate-implementation/evals/fixtures/managed-lifecycle.md`

**Prerequisites:** S1. **Obligation:** `new-test` — real runtime behavior must agree with the offline recipe.

- [ ] Run the offline handoff test in the normal skills CI job. Syntax-check the scripts individually.
- [ ] Preserve the existing plan-only/conflict evals, but add an explicit lifecycle acceptance fixture that actually permits the relevant orchestration skill and native tools. Do not describe “do not use an orchestration skill” prose scenarios as execution coverage.
- [ ] In a disposable Git repository, use the native `subagent` protocol with a small managed worker, fresh context, supported named baseRef, and declared report output. No alternative CLI/foreground fallback if the lane fails. Discover available agents/capabilities before launch.
- [ ] Allow normal child finalization; consume the actual handoff artifact and recorded cleanup state. Exercise review, a fresh fix worker after the parent HEAD moves, and final registered-candidate handoff. Keep all commits/refs/worktrees inside that disposable test repository; no push, PR, deploy, or release.
- [ ] Record runtime version, native request shapes, terminal run IDs, artifact availability, removed/preserved worktree status, base/ref/tree checks, review verdicts, and cleanup evidence. Report setup/provider failures as blocked live validation, never as success or a reason to switch modes.
- [ ] Document the verified runtime capabilities and refusal behavior for missing patch/base/review prerequisites. Do not import private runtime modules into production skills or invent an automatic version handshake in Markdown.

**Commands:**

```bash
bash tests/skills_test.sh
bash tests/orchestrator_handoff_test.sh
python3 -m json.tool skills/workflow/orchestrate-implementation/evals/evals.json >/dev/null
git diff --check
```

The live acceptance fixture is run through native Pi tools, not a guessed shell command. It may require configured model credentials and explicit disposable-repo execution permission. A green offline suite alone does not close this task; retain and report the live evidence or its exact blocker.

**Done:** both deterministic replay checks and one actual native worker → cleanup → review → fresh fix → candidate lifecycle are evidenced. Installer README records the same tested runtime boundary.

## Task S3 — Restore prototype and domain handoff boundaries

**Files to modify:**

- `skills/workflow/prototype-question/references/ui.md`
- `skills/workflow/prototype-question/SKILL.md` only if needed to keep its closeout contract unambiguous
- `skills/workflow/domain-modeling/SKILL.md`
- `skills/workflow/domain-modeling/references/context-format.md`
- `tests/skills_test.sh`
- `tests/routing_prompts.json`

**Files to add:** `tests/fixtures/orchestrator-skill-handoffs.json`.

**Prerequisites:** parent Task 4's domain configuration contract agreed. Use the same sequential skills-repository writer; do not overlap S1–S2 edits to shared tests. If S2's live check is blocked and no worker remains active, S3 may proceed while that validation blocker stays recorded.

**Obligation:** `new-test` — approval and glossary-ownership boundaries need regression cases.

- [ ] Red: add fixtures for a user selecting a UI variant without requesting production work; an explicit production request still awaiting design handoff; multi-context configuration without a map; a real existing context map; conflicting single/multi evidence; and an unconfigured ordinary single-context repository.
- [ ] Replace the UI reference's instruction to implement production code with verdict preservation and return to `shape-design`. Keep prototype cleanup bounded to the experiment; no production promotion until the design is reclassified/approved and handed to the normal implementation route. Reconcile its default variant count with the parent skill's one-probe exception.
- [ ] Domain discovery: read `docs/agents/domain.md` when present. Respect explicit `multiple contexts`; inspect an existing `CONTEXT-MAP.md` and actual package/context glossaries, or ask which real context owns the term. Do not create root `CONTEXT.md` just because the map is absent.
- [ ] If configuration is absent, preserve existing behavior: use an existing map; otherwise use a root glossary or create one lazily. If explicit configuration and existing evidence conflict, surface the owner decision instead of silently rewriting either source.
- [ ] Keep context maps/glossaries lazy and meaningful. The installer does not invent domain names or write placeholder glossaries. Capture a map through domain-modeling when actual context ownership is known.
- [ ] Add static negative/positive checks for these exact contract boundaries and expand routing examples. Keep scenario inputs and expected behavior separate; label static assertions as static, not behavioral proof.
- [ ] Exercise the fixtures through skill-guided read-only evaluation (with production mutations forbidden for the test), recording decisions/handoffs. At least the prototype-choice and missing-map cases must demonstrate the expected stop/return behavior.
- [ ] Green: run commands below; compare with parent single/multi generated previews before accepting either repository.

**Commands:**

```bash
bash tests/skills_test.sh
python3 -m json.tool tests/fixtures/orchestrator-skill-handoffs.json >/dev/null
python3 -m json.tool tests/routing_prompts.json >/dev/null
git diff --check
```

**Done:** selecting a UI design does not skip production gates; multi-context setup no longer routes the first domain term into a contradictory global glossary.

## Final gate and coordination

- [ ] Each acceptance criterion A4–A6 has source changes, regression checks, and the specified live/skill evidence or a clearly reported blocker.
- [ ] Review all modified references, not only SKILL.md. Preserve applicable provenance headers; do not rewrite pinned upstream provenance merely because adapted local wording changes.
- [ ] No runtime skill copies/tests were added to the installer repository. No production engine or upstream Pi change was introduced.
- [ ] Parent-owned review/candidate resources are removed only when clean, owned, and no longer needed; preserve failed/uncertain artifacts for recovery. Never broadly delete worktrees/refs.
- [ ] Installer documentation and generated instructions use these same contracts. Coordinate publication of `legout/skills` before claiming remote setup installs the fixes.
- [ ] Separate publication authorization still applies in both repositories. Return commit/diff evidence to the parent orchestrator; passing tests are not permission to push or merge.

**Residual risks:** offline fixtures model Git/artifact operations but do not prove model compliance; live evaluation is provider/runtime-dependent. Review/pin ownership adds small explicit bookkeeping, not a durable scheduler. Unversioned external installation remains a separate reproducibility concern; document rather than silently choosing release pins in this fix.
