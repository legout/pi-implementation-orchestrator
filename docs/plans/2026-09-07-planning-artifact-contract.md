# Planning artifact contract — implementation plan

Status: proposed for execution approval. The specification and ownership/path decisions are approved; no implementation, install, commit, or publication is performed by writing this plan.

## Sources and scope

- [Approved specification](../specs/planning-artifact-contract.md), AC-01–AC-12.
- [Accepted ownership ADR](../adr/0001-shared-planning-contract.md).
- [Session-backed research](../research/2026-09-07-planning-workflow-audit.md).

Two repositories: this installer and sibling `../skills` (`legout/skills`). The latter was clean at `2fb47df952d69eb8e6673e4e6531bd4531d9ce80` during planning. This installer has prior uncommitted agent-routing edits and new planning documents. Preserve them; obtain an approved clean baseline before managed mutation worktrees are allocated. Do not stash, commit, or discard user work automatically.

Use preconfigured `implementer` for mutation and fresh read-only `code-reviewer` for independent review. One writer per owned worktree. No live project migration, installed-skill edits, package publication, or unrelated recovery changes.

## Dependency map and requirement coverage

T1 shared contract → T2 skill consumers and T3 installer (independent repositories after T1 interface review) → T4 distribution and behavioral verification.

- T1: AC-01–AC-09 semantics and AC-10 missing-contract behavior.
- T2: AC-01–AC-09 handoffs, AC-11 scenario fixtures.
- T3: AC-10 mapping/install safety, AC-12 setup regressions.
- T4: AC-01–AC-12 end-to-end evidence and non-regression.

T1 and T2 share the skills tests and must remain sequential. T2 and T3 may run concurrently only against the agreed contract name, mapping schema, and missing-contract behavior. T4 consumes their exact reviewed trees. No tracker duplication: task bodies below are canonical for this bounded change.

## T1 — Define and distribute the shared contract

Repository: `../skills`.

Files: create `skills/workflow/planning-contract/SKILL.md`; update `README.md`, `tests/skills_test.sh`, and catalog/provenance metadata only where the repository's discovery and source checks require it (inspect `sources.json` and `scripts/check-skill-sources.sh` first). Do not add false upstream attribution to a locally authored contract.

Consumes: approved specification and ADR. Produces: skill name `planning-contract`, contract version, default artifact paths, protected map location `docs/agents/artifacts.md`, scoped authority, capture checkpoint, approval/readiness rules, and missing-contract refusal semantics.

Obligation: `new-test` for the distribution/contract checks; Markdown parse/link review supplements tests.

- [ ] Add a failing contract-presence/reference check to the existing suite.
- [ ] Write one compact normative contract, including all default paths and safe handling of missing or conflicting mappings. Mapping is declarative documentation, never an executable configuration file.
- [ ] Document explicit installation alongside consumers, including standalone installation instructions. Do not assume the skills CLI resolves dependencies.
- [ ] Specify available revision provenance versus an explicit unknown value; avoid a lockfile system.
- [ ] Run skills/source checks and get independent interface review before dependent tasks begin.

Done: the canonical contract is discoverable, locally linked, source-valid, and sufficient for consumers without copying its procedure into every skill.

## T2 — Enforce handoffs in existing skills

Repository: `../skills`. Depends on T1.

Files: `skills/tools-and-research/research/SKILL.md`; `skills/workflow/{shape-design,domain-modeling,prototype-question,write-implementation-plan,orchestrate-implementation}/SKILL.md`; relevant existing references under those skills, including `orchestrate-implementation/references/manifest-and-briefs.md`; `tests/skills_test.sh`; create `tests/fixtures/planning-contract-scenarios.json`.

Consumes: T1 contract and map location. Produces: consistent artifact classification, explicit capture/readiness handoffs and synthetic behavioral scenarios.

Obligation: `new-test` for changed routing. Static tests establish wiring only, not agent compliance.

- [ ] Add failing checks for required consumer references and synthetic positive/negative scenarios mapped to AC-01–AC-09.
- [ ] Route research/probe findings to research; preserve real specs and approval boundaries.
- [ ] Add the shaping vocabulary/decision checkpoint, with meaningful lazy glossary creation and selective ADR capture.
- [ ] Require approved behavioral sources or bounded equivalents for planning/execution; return material new decisions to shaping.
- [ ] Keep tasks compact, dependencies explicit, and ticket bodies canonical. Record source scope/approval, checkpoint outcome, contract provenance, prerequisite evidence, and readiness in existing briefs/manifests rather than a second state system.
- [ ] Remove contradictory blanket precedence rules in affected current guidance; retain historical documents as history. Preserve independent review and runtime safety checks.
- [ ] Run skills tests and independent review of the complete handoff changes.

Done: affected consumers load the contract, fail explicitly if missing, and expose enough evidence to distinguish research, approved behavior, and execution authority.

## T3 — Install contract and render protected project mapping

Repository: this installer. Depends on T1 interface review.

Files: `setup.sh`, `tests/setup_test.sh`, `tests/setup_runner_test.sh`, `prompts/setup-implementation-orchestrator.md`, `README.md`, `docs/design.md`.

Consumes: `planning-contract` skill name and agreed artifact defaults. Produces: explicit installation of that additional skill and a protected `docs/agents/artifacts.md` mapping linked from the managed root block.

Obligation: `new-test` for installer behavior. Reuse existing staging, validation, ownership, preview, and rerun mechanisms; do not add a second writer pipeline.

- [ ] Add failing cases for new-map creation, legacy project without a map, configured mappings, idempotence, dry-run/inspect purity, custom-content refusal/approval, symlink/wrong-kind destinations, and late write failure.
- [ ] Extend exact skill-list expectations to include the contract, keeping global/project scopes and explicit names.
- [ ] Render defaults plus references to existing domain/tracker configuration. Do not silently reset approved custom mappings or infer a research path from a misplaced spec.
- [ ] Integrate the third managed document into staging, validation, ownership, custom-content approval, preview, and partial-failure reporting. Existing project documents must not be moved.
- [ ] Update short root guidance to load the contract/map and replace blanket precedence with scoped authority; preserve the word budget and context ownership rules.
- [ ] Update prompt discovery/custom-content wording for all managed documents. Update runner mutation probes whose copied-output assumptions change.
- [ ] Run both shell suites and independent review, including installation-before-write and no-unapproved-mutation cases.

Done: default and existing projects receive deterministic, protected routing without fabricated glossary/ADR content or automatic document migration.

## T4 — Verify installation and real planning behavior

Repositories: both. Depends on reviewed T2 and T3.

Files: T2 scenario fixture; this research note's linked evidence may be supplemented with a new sanitized verification report under `docs/research/`. Do not store raw private transcript content or credentials.

Obligation: `new-test` behavioral/distribution acceptance; use the native harness for model-driven scenarios. Offline success alone cannot close this task.

- [ ] Run all deterministic checks on the exact candidate revisions.
- [ ] Verify selected-skill distribution using isolated HOME/project directories and the local candidate skills source, with global and project scope. Discover supported CLI syntax before running; never install into the real user's skill directories. Include consumer-without-contract refusal and consumer-with-contract success.
- [ ] Run synthetic scenarios covering every AC: inspect actual paths/content, glossary/ADR outcomes, owner approval evidence, source reconciliation, task dependencies, and writer-dispatch or refusal evidence. Include trivial-change success and research-only refusal controls.
- [ ] Record runtime/model and candidate revisions, scenario inputs, results and evidence paths. A model/provider/tooling failure is blocked verification, not a pass or permission to switch execution modes.
- [ ] Verify references after installation rather than only in the source checkout. Confirm custom maps and absent provenance are handled honestly.
- [ ] Obtain fresh cumulative review; report unresolved failures and residual risks before requesting integration/publication authority.

Done: all ACs have concrete evidence. Report any blocked live validation separately; no claim of repairing featherBI's unrelated handoff discrepancy.

## Deterministic validation commands

Run syntax checks individually; `bash -n a.sh b.sh` does not check both.

Installer:

```bash
for f in setup.sh tests/setup_test.sh tests/setup_runner_test.sh; do bash -n "$f" || exit 1; done
bash tests/setup_test.sh
bash tests/setup_runner_test.sh
node -e 'const p=require("./package.json"); if (!p.pi.prompts.includes("./prompts") || p.pi.skills) process.exit(1)'
git diff --check
```

Skills (cwd `../skills`):

```bash
for f in tests/skills_test.sh tests/orchestrator_handoff_test.sh scripts/check-skill-sources.sh; do bash -n "$f" || exit 1; done
bash tests/skills_test.sh
bash tests/orchestrator_handoff_test.sh
bash scripts/check-skill-sources.sh
git diff --check
```

Run existing baselines before edits; separate pre-existing failures. Every new behavior assertion should first fail for its intended reason, then pass after the corresponding implementation. These commands do not replace T4 model-driven evaluations or distribution smoke tests.

## Execution gate

Owner approval of this plan and an approved clean-baseline strategy are required before dispatch. Release order is skills availability first, then installer consumption; source-checkout verification is not evidence that a remote release already includes the contract. No push, release, real-project setup rerun, or migration is implied by plan approval.
