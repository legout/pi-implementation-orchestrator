# Planning artifact contract — implementation plan

Status: implementation and T4 acceptance complete. Deterministic, isolated distribution, and native semantic checks passed; the source-provenance checker still reports upstream branch drift in five adopted source groups. No publication or real-project migration was performed.

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

- [x] Add a failing contract-presence/reference check to the existing suite.
- [x] Write one compact normative contract, including all default paths and safe handling of missing or conflicting mappings. Mapping is declarative documentation, never an executable configuration file.
- [x] Document explicit installation alongside consumers, including standalone installation instructions. Do not assume the skills CLI resolves dependencies.
- [x] Specify available revision provenance versus an explicit unknown value; avoid a lockfile system.
- [x] Run skills/source checks and get independent interface review before dependent tasks begin.

Done: the canonical contract is discoverable, locally linked, source-valid, and sufficient for consumers without copying its procedure into every skill.

## T2 — Enforce handoffs in existing skills

Repository: `../skills`. Depends on T1.

Files: `skills/tools-and-research/research/SKILL.md`; `skills/workflow/{shape-design,domain-modeling,prototype-question,write-implementation-plan,orchestrate-implementation}/SKILL.md`; relevant existing references under those skills, including `orchestrate-implementation/references/manifest-and-briefs.md`; `tests/skills_test.sh`; create `tests/fixtures/planning-contract-scenarios.json`.

Consumes: T1 contract and map location. Produces: consistent artifact classification, explicit capture/readiness handoffs and synthetic behavioral scenarios.

Obligation: `new-test` for changed routing. Static tests establish wiring only, not agent compliance.

- [x] Add failing checks for required consumer references and synthetic positive/negative scenarios mapped to AC-01–AC-09.
- [x] Route research/probe findings to research; preserve real specs and approval boundaries.
- [x] Add the shaping vocabulary/decision checkpoint, with meaningful lazy glossary creation and selective ADR capture.
- [x] Require approved behavioral sources or bounded equivalents for planning/execution; return material new decisions to shaping.
- [x] Keep tasks compact, dependencies explicit, and ticket bodies canonical. Record source scope/approval, checkpoint outcome, contract provenance, prerequisite evidence, and readiness in existing briefs/manifests rather than a second state system.
- [x] Remove contradictory blanket precedence rules in affected current guidance; retain historical documents as history. Preserve independent review and runtime safety checks.
- [x] Run skills tests and independent review of the complete handoff changes.

Done: affected consumers load the contract, fail explicitly if missing, and expose enough evidence to distinguish research, approved behavior, and execution authority.

## T3 — Install contract and render protected project mapping

Repository: this installer. Depends on T1 interface review.

Files: `setup.sh`, `tests/setup_test.sh`, `tests/setup_runner_test.sh`, `prompts/setup-implementation-orchestrator.md`, `README.md`, `docs/design.md`.

Consumes: `planning-contract` skill name and agreed artifact defaults. Produces: explicit installation of that additional skill and a protected `docs/agents/artifacts.md` mapping linked from the managed root block.

Obligation: `new-test` for installer behavior. Reuse existing staging, validation, ownership, preview, and rerun mechanisms; do not add a second writer pipeline.

- [x] Add failing cases for new-map creation, legacy project without a map, configured mappings, idempotence, dry-run/inspect purity, custom-content refusal/approval, symlink/wrong-kind destinations, and late write failure.
- [x] Extend exact skill-list expectations to include the contract, keeping global/project scopes and explicit names.
- [x] Render defaults plus references to existing domain/tracker configuration. Do not silently reset approved custom mappings or infer a research path from a misplaced spec.
- [x] Integrate the third managed document into staging, validation, ownership, custom-content approval, preview, and partial-failure reporting. Existing project documents must not be moved.
- [x] Update short root guidance to load the contract/map and replace blanket precedence with scoped authority; preserve the word budget and context ownership rules.
- [x] Update prompt discovery/custom-content wording for all managed documents. Update runner mutation probes whose copied-output assumptions change.
- [x] Run both shell suites and independent review, including installation-before-write and no-unapproved-mutation cases.

Done: default and existing projects receive deterministic, protected routing without fabricated glossary/ADR content or automatic document migration.

## T4 — Verify installation and real planning behavior

Repositories: both. Depends on reviewed T2 and T3.

Files: T2 scenario fixture; sanitized verification report under `docs/research/2026-09-07-planning-contract-verification.md`. Do not store raw private transcript content or credentials.

Obligation: `new-test` behavioral/distribution acceptance; use the native harness for model-driven scenarios. Offline success alone cannot close this task.

- [x] Run all deterministic checks on the exact candidate revisions.
- [x] Verify selected-skill distribution using isolated HOME/project directories and the local candidate skills source, with global and project scope. Discover supported CLI syntax before running; never install into the real user's skill directories. Include consumer-without-contract refusal and consumer-with-contract success.
- [x] Validate the synthetic scenario fixture structure: all nine AC identifiers and 21 positive/negative controls are present with expected evidence.
- [x] Run the synthetic scenarios through a fresh native semantic evaluator: inspect actual paths/content, glossary/ADR outcomes, owner approval evidence, source reconciliation, task dependencies, and writer-dispatch or refusal evidence. Include trivial-change success and research-only refusal controls; record the sanitized evidence report.
- [x] Verify references after installation rather than only in the source checkout. Confirm custom maps and absent provenance are handled honestly.
- [x] Obtain fresh cumulative review; report unresolved failures and residual risks before requesting integration/publication authority.

Done: implementation, deterministic checks, isolated distribution, and native semantic acceptance evidence are recorded. The five unrelated upstream source drifts remain a separate maintenance decision; make no claim of repairing featherBI's unrelated handoff discrepancy.

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

## Execution record

- Skills T1: `ce95643324c50b292ba91bb47e7f2ad9baa03642` (`refs/heads/orchestrator/planning-contract/t1-head`).
- Skills T2 plus remediation: `44a45baf0fc07d0af1ec40dae605c397407ba299`, then `cd7674151f4f0a7a89c9558c78a633ea3b89837f` (`refs/heads/orchestrator/planning-contract/t2-fixed-head`); both received clean independent reviews.
- Installer T3: `548f88df98095ede96b74f1346fd1eb440165e0c` (`refs/heads/orchestrator/planning-contract/t3-head`); received clean independent review.
- Candidate trees were assembled from pinned baselines and their changed-file contents were verified byte-for-byte after applying to the live repositories.
- Passed: installer syntax checks, `bash tests/setup_test.sh`, `bash tests/setup_runner_test.sh`, package metadata assertion, `git diff --check`; skills syntax checks, `bash tests/skills_test.sh`, `bash tests/orchestrator_handoff_test.sh`, fixture validation, and `git diff --check`; LSP diagnostics for all changed files (0 findings).
- Passed: local `planning-contract` distribution smoke tests in isolated HOME/project directories for global and project scope; no real user skill directory was modified.
- Not clean: `scripts/check-skill-sources.sh` reports five upstream adopted-source branch drifts (humanizer, cursor/plugins, davidondrej/skills, awesome-copilot, archify); this is external provenance drift and was not changed by this implementation.
- Native semantic acceptance: PASS for all AC-01–AC-12 with no remaining acceptance gaps, recorded in `docs/research/2026-09-07-planning-contract-verification.md` and the fresh reviewer handoff. This is not a publication or real-project migration approval.
