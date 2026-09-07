# Implementation orchestration

The language used to distinguish evidence, requirements, execution work, and authority in the planning and implementation process.

## Language

**Research note**: An investigation or design study recording evidence, alternatives, and uncertainty. It is not a commitment to implement its recommendations.

**Specification**: A behavioral contract defining scope, constraints, and observable acceptance criteria.
_Avoid_: Design study (when referring to committed behavior).

**Architecture decision record (ADR)**: A record of a consequential choice and the trade-offs explaining it. It is not a substitute for behavioral acceptance criteria.

**Implementation plan**: An execution map connecting bounded tasks, dependencies, ownership, and verification to their behavioral source.

**Task**: A bounded, independently reviewable unit of implementation with prerequisites and completion evidence. A task can depend on another task; reviewability does not imply parallelizability.

**Ticket**: A tracker representation of a task, not a second independent definition of its scope.

**Orchestrator**: The authority coordinating task dispatch, evidence, independent review, and acceptance within the owner's approved scope.

**Implementer**: The role responsible for changing and validating the assigned task's owned work.

**Independent reviewer**: A separate role assessing the exact implementation evidence without becoming its author or final acceptance authority.

**Handoff**: The bounded source references, authority, prerequisites, and evidence passed between planning or execution roles.
