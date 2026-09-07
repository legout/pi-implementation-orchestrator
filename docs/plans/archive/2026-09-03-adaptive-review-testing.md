# Adaptive Review and Focused Testing Implementation Plan

> **Archived plan — completed.** The adaptive test-obligation/review policy shipped in the skills and installer history; the unchecked steps below are the original execution ledger, not an active backlog. See `docs/plans/README.md` for the current plan index.

> **For agentic workers:** Implement this as one cohesive change. Use one fresh worker, one cumulative review of the complete diff, and a fresh re-review only if blocking fixes are required.

**Goal:** Reduce implementation latency by requiring new tests and immediate reviews only where risk justifies them, while preserving focused evidence, cumulative review, and final integration safety.

**Architecture:** Every task receives an explicit test obligation (`new-test`, `existing-check`, or `no-new-test`) and review disposition (`immediate` or `pending`). The default review policy becomes `adaptive`: high-risk or dependency-defining tasks receive immediate review, while low-risk changes accumulate behind a `lastReviewedSha` boundary and receive one exact-range review at a wave or integration boundary.

**Tech Stack:** Markdown Agent Skill, Bash-generated project instructions, shell regression tests.

## Global Constraints

- Do not require new tests for every task.
- New behavior and regression-prone logic still require focused TDD.
- Every task still requires explicit validation evidence appropriate to its risk.
- Default review policy is `adaptive`, not per-task.
- High-risk and dependency-defining tasks receive immediate review.
- Low-risk changes may queue for cumulative wave review.
- Every pending change must be reviewed before main-branch integration or publication.
- Review the exact range `lastReviewedSha..HEAD` and advance the boundary only after a clean verdict.
- Use one fix worker for the accepted findings from a cumulative review.
- Preserve the managed-worktree durable-patch recovery contract.
- Update the packaged skill, installer-generated project guidance, init prompt, README, design, and machine-global skill consistently.

---

### Task 1: Implement adaptive review and focused test obligations

**Files:**
- Modify: `tests/setup_test.sh`
- Modify: `skills/orchestrate-implementation/SKILL.md`
- Modify: `skills/orchestrate-implementation/evals/evals.json`
- Modify: `setup.sh`
- Modify: `prompts/init-orchestrator-project.md`
- Modify: `README.md`
- Modify: `docs/design.md`
- After review: sync `skills/orchestrate-implementation/SKILL.md` to `~/.agents/skills/orchestrate-implementation/SKILL.md`

**Interfaces:**
- Consumes: task risk, existing coverage, dependency role, and pending review boundary.
- Produces: one test obligation and one review disposition per task, plus cumulative review evidence.

- [ ] **Step 1: Add one failing policy regression test**

Add `test_adaptive_review_and_test_policy` to `tests/setup_test.sh`. It must assert that the packaged skill contains:

```text
new-test
existing-check
no-new-test
adaptive
lastReviewedSha
```

It must also assert README and the generated project block say that focused TDD applies only when new behavioral coverage is required, and that low-risk changes may be batch-reviewed while high-risk changes receive immediate review.

Update the byte-exact expected managed block in `test_replacement_preserves_bytes` to the newly approved text.

- [ ] **Step 2: Run the focused test and verify RED**

```bash
bash tests/setup_test.sh
```

Expected: FAIL in `test_adaptive_review_and_test_policy` because the current skill has none of the new policy terms.

- [ ] **Step 3: Add explicit test obligations to the skill**

Add a `## Test obligations` section:

```markdown
Every task receives exactly one obligation during preflight:

- `new-test`: meaningful behavior, bug regression, branching/state, parsing/validation, security, permissions, money, destructive data handling, concurrency, public contracts, or behavior without existing coverage. Load `skill: "tdd"`; require failing test → minimal implementation → passing test → refactor.
- `existing-check`: existing tests already exercise the affected behavior. Add no redundant test; run and report the named focused checks.
- `no-new-test`: documentation, formatting, comments, static metadata, generated artifacts, typo correction, or another change where a new test proves little. Run the smallest meaningful lint, parse, build, diff, or manual validation.
```

Require each brief and report to state the assigned obligation, rationale, commands, and results. A worker may challenge the assignment after inspection but must report why; it may not silently skip validation.

Change the dispatch recipe so `skill: "tdd"` is supplied only for `new-test` tasks or when the worker profile itself is intentionally TDD-only.

- [ ] **Step 4: Add adaptive review policy to the skill**

Add `## Review policy` with four options:

- `adaptive` (default): immediate review for high-risk/dependency-defining work; queue low-risk work for wave review.
- `strict`: immediate task review plus final review.
- `wave`: review only completed waves plus final review.
- `final-only`: explicit opt-in for prototypes, mechanical work, or another owner-approved low-risk slice.

Immediate-review triggers:

```text
public API/schema/shared contract; security/auth/permissions/secrets; money/data-loss/migration; concurrency/distributed behavior; broad cross-cutting diff; weak or missing checks; worker uncertainty/scope expansion; integration conflict; a task whose contract will be consumed before the next wave review
```

For pending low-risk changes, store `lastReviewedSha` and review the exact cumulative range `lastReviewedSha..HEAD` at the end of a wave, before fan-in, when the diff becomes incoherent, or before integration/publication. After a clean verdict, advance `lastReviewedSha`. Send the complete accepted finding list to one fix worker, then revalidate and re-review the affected range.

- [ ] **Step 5: Refactor the execution and completion loops**

Replace unconditional per-task TDD and review steps with:

```text
classify task risk + test obligation
→ implement with appropriate evidence
→ immediate review or pending-review queue
→ cumulative review at boundary
→ one fix worker for accepted batch findings
→ final exact-range/whole-branch review before integration or publication
```

Keep durable handoff-patch recovery unchanged.

- [ ] **Step 6: Update generated project guidance and init prompt**

Replace the managed block's first two bullets with:

```markdown
- Every task declares one test obligation: `new-test`, `existing-check`, or `no-new-test`; focused TDD is required only for `new-test` work.
- Review is adaptive and orchestrator-owned: high-risk or dependency-defining changes are reviewed immediately; low-risk changes may be reviewed cumulatively at a wave boundary.
```

Apply the same canonical block to `prompts/init-orchestrator-project.md` and the byte-exact shell test fixture.

- [ ] **Step 7: Update README, design, and evaluation expectation**

Document:

- why evidence is mandatory but new tests are not;
- the three test obligations with examples;
- the four review policies;
- default adaptive review;
- cumulative `lastReviewedSha..HEAD` review;
- immediate-review triggers;
- one batch fix worker;
- final review before integration/publication.

Update evaluation id 3 to expect focused test obligations and adaptive batch review rather than universal TDD/per-task review.

- [ ] **Step 8: Run GREEN verification**

```bash
bash -n setup.sh tests/setup_test.sh
bash tests/setup_test.sh
uv run --with pyyaml ~/.agents/skills/skill-creator/scripts/quick_validate.py skills/orchestrate-implementation
git diff --check
```

Expected: all commands pass.

- [ ] **Step 9: Commit and run one cumulative review**

```bash
git add tests/setup_test.sh skills/orchestrate-implementation setup.sh \
  prompts/init-orchestrator-project.md README.md docs/design.md
git commit -m "feat: add adaptive review and testing"
```

Dispatch one fresh read-only reviewer over the complete feature diff. If blocked, send all accepted findings to one fresh fix worker using the durable patch recovery procedure, then run one focused re-review.

- [ ] **Step 10: Integrate, sync, publish, and verify**

After a clean review, apply the reviewed patch to `main`, rerun Step 8, and push. Verify GitHub Actions succeeds on the exact pushed commit. Then copy the reviewed packaged skill to the machine-global path and run `quick_validate.py` there.
