---
status: accepted
---

# Keep planning semantics in one distributed skill contract

The owner approved that `legout/skills` own a shared planning artifact and handoff contract, distributed with the skills that consume it. The installer owns the target project's path mapping and short routing instructions, not a separate copy of the planning procedures. This preserves independent skill installation while avoiding conflicting lifecycle rules across installed projects.

## Alternatives and consequences

- Expanding every generated `AGENTS.md` would duplicate procedures and make fixes depend on updating each project.
- Giving each skill its own complete contract would allow semantics to drift between shaping, planning, and execution.
- Replacing the stack with one upstream workflow would discard existing project-specific approval and orchestration boundaries without directly solving artifact classification.

The shared contract must remain reachable after selected-skill installation, including project scope. A link into a sibling skill directory that is absent after installation is not sufficient. The owner selected a dedicated contract-bearing skill, installed explicitly with its consumers, and `docs/agents/artifacts.md` as the protected project path mapping. Consumers installed alone must report a missing contract rather than silently proceeding. The implementation must verify distribution in isolated global and project installs before acceptance.

Existing configured paths must be retained or explicitly migrated. No automatic relocation of user-authored documents is authorized.

Related: [audit](../research/2026-09-07-planning-workflow-audit.md), [approved specification](../specs/planning-artifact-contract.md).
