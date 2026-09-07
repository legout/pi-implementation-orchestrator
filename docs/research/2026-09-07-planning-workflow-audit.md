# Planning workflow audit

Status: research findings; not implementation authorization.

## Question and evidence boundary

Why does the installed planning stack produce inconsistent document placement and omit domain/decision records? This audit combines the installer and skill sources with the owner-supplied featherBI session `01a07ce1-8d7e-7062-a48e-2d7a84d87466`, dated 2026-09-07 (file timestamp prefix `2026-09-07T17-19-11-742Z`). Transcript citations below are 1-based JSONL line numbers and message IDs. The private session is not copied into this repository. Its 542 entries were analyzed programmatically and through a read-only scout; the scout reported a linear parent chain, not alternative session branches.

This is evidence about one recorded session, not a census of deployed repositories or proof of their current filesystem state. Tool requests, successful tool results, user approvals, and assistant claims are distinct evidence.

## Observations

1. **Concrete plans were requested, not imposed.** At L46 (`275f3eb1`), the owner requested “plan and refine this project” into “concret implementation plans.” At L416 (`2b9f0d31`), the owner said “plans look good. approved.” L429 (`4b29ccdc`) confirms successful approval-status edits to five plans and the runtime contract. Five plans alone are not evidence of overplanning.
2. **Two documents were real behavioral specifications.** The dashboard specification write at L106 (`9eed9d03`) and runtime-contract write at L332 (`e5f4f733`) contain behavioral boundaries and acceptance examples. The recorded flow separated written review from implementation authorization. These should remain specifications.
3. **A feasibility report was filed as a specification.** L285 (`fa6d75a9`) writes `docs/specs/browser-feasibility-report.md`. Its opening explicitly says “This is experiment evidence, not a production implementation or a general performance guarantee.” The content distinguishes evidence from commitment; the directory does not. The proposed default is `docs/research/`, with links from the relevant specification.
4. **Domain and decision capture lacked a checkpoint.** No inspected `write`/`edit` targets create a `CONTEXT.md` or ADR. The session resolves concepts and choices, including table-query ownership at L368–370 and browser scope at L276–281. These warrant vocabulary/decision assessment, not automatic ADR creation. A temporary browser-support scope choice need not satisfy the existing ADR criteria.
5. **Approval gates often worked.** The session repeatedly distinguished probe approval, written specification review, plan approval, and production execution. The fix should retain those boundaries rather than add redundant approval rounds for every file.
6. **An execution incident is separate.** Near L523–542 the parent investigated staged changes differing from the reported implementation handoff and blocked progression. The transcript ends during that investigation. It does not establish the root cause or final outcome. Do not use this planning change to introduce an unverified worktree-freezing mechanism or claim the incident resolved.

## Source-level causes

- `setup.sh`, `render_workflow_block`: lists specification and ADR destinations, but not a research destination or explicit plan destination. Its source-precedence chain conflates architectural constraints, behavioral requirements, and execution instructions.
- `setup.sh`, `render_domain_doc`: declares glossary ownership, but setup intentionally creates configuration rather than fictional domain content. The missing piece is a later capture checkpoint, not placeholder creation during installation.
- `legout/skills`, `workflow/shape-design/SKILL.md`: invokes domain modeling only when already changing a glossary or recording an ADR. No mandatory assessment connects resolved terms/choices to this handoff.
- `research/SKILL.md`: uses an existing or “sensible” location; this permits research to inherit an inappropriate specs directory.
- `workflow/write-implementation-plan/SKILL.md`: already recommends compact execution maps and tickets as the plan rather than duplicated full plans. Preserve this; clarify dependencies and readiness.
- `workflow/orchestrate-implementation/SKILL.md`: accepts diverse source documents but needs an explicit evidence-versus-approved-behavior intake check.
- Installer tests verify rendering and setup safety; they cannot alone establish that agents follow the complete planning lifecycle.

The installed and sibling-source copies of shape-design, domain-modeling, write-implementation-plan, and orchestrate-implementation matched at the preceding audit. This does not establish which exact skill revision every historical session loaded.

## Recommendation

Adopt a shared artifact/handoff contract, explicit domain/decision assessment, scope-bound approval, and compact dependency-based work items. Keep research separate from approved behavior. Preserve small-change shortcuts, lazy meaningful glossary creation, selective ADRs, independent review, and publication gates.

See the [proposed specification](../specs/planning-artifact-contract.md) and [proposed ownership decision](../adr/0001-shared-planning-contract.md). Neither is accepted merely because this research note exists.
