# Planning artifact and handoff contract

Status: approved for implementation planning. Owner explicitly selected “Approve shared skill” and `docs/agents/artifacts.md` in the planning decision questionnaire. Approval covers this behavioral contract, dedicated shared-skill distribution, and the protected project mapping; it does not authorize installation, migration, commits, or publication. Execution of the resulting task plan remains a separate handoff.

Sources: [session-backed audit](../research/2026-09-07-planning-workflow-audit.md), [terminology](../../CONTEXT.md), [accepted ownership ADR](../adr/0001-shared-planning-contract.md). This proposal changes planning semantics described in `../design.md`; existing behavior remains in force until adoption.

## Goal

Make document classification, domain capture, approvals, and execution decomposition consistent across the installer and independently distributed skills without requiring every task to produce every document.

## Scope and non-goals

Covers setup guidance and the research, shaping, domain-modeling, prototype handoff, planning, and orchestration skills in `legout/skills`. Existing repository documents remain intact; this is not permission to migrate featherBI or alter installed global/project skill copies.

No new scheduler, mandatory issue tracker, mandatory ADR per question, placeholder domain glossary, monolithic plan template, automatic publishing, or redesign of runtime worktree recovery. Independent implementer/reviewer roles and existing integration/publication authority gates remain unchanged.

## Artifact classification and paths

Default destinations are `docs/research/` for investigations/design studies/probe reports, `docs/adr/` for architectural decisions, `docs/specs/` for behavioral contracts, `docs/plans/` for execution maps, and `docs/tickets/` for local work items. Workflow configuration remains in `docs/agents/`.

Single-context vocabulary belongs in root `CONTEXT.md`. Explicit multi-context configuration uses real owning context glossaries; unresolved ownership blocks vocabulary mutation, not permission to invent a global glossary.

Explicit project mappings override defaults. Conflicting configuration and established paths require an owner decision. A research document already misplaced under specs is evidence of misclassification, not an established rule to copy. Setup must preview any mapping changes and preserve its existing approval, idempotence, and custom-content protections.

Directory membership never grants approval. Mixed documents should be separated into evidence, behavior, and rationale with links; moving or rewriting existing content requires approval. Empty folders or fictional content are not required during setup.

## Shaping and capture checkpoint

Before handing a shaped change to planning or implementation, assess and report:

1. **Vocabulary:** resolved new/changed terms are captured in the owning glossary. No new terms is a valid outcome. Missing confirmed vocabulary is not silently skipped.
2. **Decisions:** assess consequential choices using all existing ADR criteria: costly to reverse, surprising without context, and based on real alternatives. Record a qualifying approved choice or present its proposed ADR for approval. Otherwise report that no ADR is warranted; do not create an ADR solely because a question was asked.
3. **Behavior:** identify the scope, non-goals, acceptance criteria, and approved source.
4. **Uncertainty:** unresolved material decisions block the next execution handoff. Research and probes can continue within their authorized scope.

Capture can happen during discussion; the checkpoint catches omissions. It need not create another standalone checklist document. Its result belongs with the shaped design or execution handoff.

## Approval and scoped authority

Research is evidence, even when the owner accepts its findings. Specifications and plans identify whether they are proposed or approved, with a reference to the owner's approval and the exact scope/revision approved. Do not invent approval from a file's location, an assistant-written status, or an unrelated “yes.” A single explicit owner approval may cover multiple named artifacts and actions; do not require redundant prompts.

Glossaries own terminology; ADRs own accepted architectural constraints; specifications own behavior; plans/tickets own execution decomposition. None silently overrides conflicts in another scope. Current owner decisions are authoritative but must be reconciled into affected artifacts before dependent work proceeds.

A material behavior/interface/scope change invalidates readiness of affected tasks until the source and decomposition are reconciled and approved. Unaffected tasks need not be reapproved. Cosmetic edits do not require a new behavioral approval.

Probe approval does not authorize keeping probe code or implementing the product. Planning approval does not inherently authorize writers. Integration and publication retain separate gates.

## Work size and decomposition

An understood bounded change may use an explicitly approved issue or short design with acceptance criteria instead of a separate spec and plan. The capture checkpoint still applies proportionately.

Substantial work uses a linked behavioral source and the smallest execution map exposing dependencies, ownership, requirement coverage, and global validation. A task names its source criteria, owned surfaces, consumed/produced interfaces, prerequisites, test obligation, completion evidence, and non-goals. It must be understandable to a fresh implementer without accumulated chat.

For a small feature, tasks can live in one compact plan. When tracker coordination is required, tickets own the task bodies and a thin overview links to them. Do not maintain duplicate editable task definitions. Sequential work uses bounded tasks as well; shared context belongs in the linked source, not duplicated full plans.

Parallel execution requires satisfied dependencies, stable consumed interfaces, and non-conflicting ownership. Distinct ticket files alone do not justify parallel writers. Contract-defining tasks must be accepted before dependent tasks consume them.

## Execution readiness

Before dispatching an implementer, the orchestrator checks the approved behavioral source (or bounded-change equivalent), capture-checkpoint result, requirement coverage, unresolved decisions, prerequisite evidence, owned surfaces, assigned validation, and execution authority.

Research alone, a draft spec, an ADR without behavioral acceptance, or a materially changed unapproved source cannot satisfy readiness. Report the specific missing prerequisite and route back to its owning skill. Preserve existing baseline checks, clean-worktree checks, durable handoffs, fresh independent review, and integration gates; this contract adds planning readiness rather than replacing runtime checks.

## Distribution and existing projects

Planning semantics have one canonical owner in `legout/skills`; installer output supplies a short link/routing summary and project mapping. All affected consumers must receive a reachable contract after selected-skill installation. A dedicated `planning-contract` skill is installed explicitly alongside its consumers; standalone consumers must detect its absence and request installation, not assume automatic dependency resolution. The installer-managed project mapping lives in `docs/agents/artifacts.md`, linked from the root instructions. Distribution verification remains an implementation gate; no nonexistent installer capability is assumed.

Record the contract version and available installed skill revision/provenance at handoff. If exact provenance is unavailable, say so rather than claiming a reproducible installation. Do not expand this into a general package lock system.

Rerunning setup can update its managed guidance and mapping after preview/approval. It must not move existing specs, manufacture ADRs, rewrite user notes, or silently refresh installed skills outside the approved installation operation. Historical documents may be mapped and classified without bulk rewriting; material ambiguities are resolved before their next execution use.

## Acceptance scenarios

- **AC-01 — Classification:** A feasibility report explicitly reporting experiment evidence is saved under research by default, linked from the spec, and never treated as implementation authorization. Genuine behavioral contracts stay in specs.
- **AC-02 — First vocabulary:** A single-context project's first resolved domain terms produce a meaningful glossary before execution handoff. Setup alone does not fabricate terms.
- **AC-03 — Multiple contexts:** A configured multi-context project with unresolved ownership asks for ownership and does not create a root glossary.
- **AC-04 — Selective decisions:** A qualifying approved architectural trade-off is captured as an ADR; a trivial or temporary scope choice can explicitly require no ADR.
- **AC-05 — Approval:** Research acceptance, an unrelated affirmative reply, or a draft spec cannot authorize writers. A clear approval covering named scope is recorded without repeated ceremonial approval.
- **AC-06 — Source change:** A material interface decision discovered during planning returns to shaping, updates the relevant source, and blocks affected tasks until reconciliation/approval.
- **AC-07 — Small change:** An approved bounded issue with acceptance criteria can execute without a separate spec or full plan, while preserving proportionate capture and validation.
- **AC-08 — Task storage:** Tracker tasks have one canonical body; overview links and requirement coverage do not duplicate it. Sequential tasks receive bounded context; independent ready tasks may run concurrently.
- **AC-09 — Readiness:** Research-only inputs, unresolved decisions, missing behavioral criteria, and unmet dependencies produce specific pre-dispatch blockers.
- **AC-10 — Installation/migration:** Global and project selected-skill installations resolve contract references. Setup reruns remain approval-gated and idempotent; existing user documents are unchanged without explicit migration approval. Provenance gaps are reported honestly.
- **AC-11 — Behavioral verification:** Scenario evaluations inspect generated artifacts, source links, approval evidence, and whether writers were dispatched. Static phrase assertions alone cannot count as end-to-end behavior proof. Include positive and negative controls; use synthetic session-derived scenarios without private data.
- **AC-12 — Safety preservation:** Existing setup safety suites and execution approval/review boundaries remain intact. Planning changes do not claim to repair the separate featherBI handoff incident.

## Approved decisions and next gate

The owner approved the dedicated shared contract skill and the setup-managed `docs/agents/artifacts.md` mapping. Implementation and T4 acceptance are complete; the execution record is preserved in the [archived implementation plan](../plans/archive/2026-09-07-planning-artifact-contract.md).
