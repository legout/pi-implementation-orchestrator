# Implementation plans

This directory contains active implementation work only. Completed and superseded plan snapshots live under [`archive/`](archive/).

## Active

- [`2026-09-07-native-lifecycle-acceptance.md`](2026-09-07-native-lifecycle-acceptance.md) — run the remaining native Pi managed-worker lifecycle acceptance in a disposable Git repository.

## Archived plans

| Plan | Disposition | Evidence or successor |
|---|---|---|
| `2026-09-07-planning-artifact-contract.md` | Complete | Published implementation; all AC-01–AC-12 accepted. |
| `2026-09-07-orchestrator-safety-and-setup.md` | Implemented | Installer safety/setup work shipped; native lifecycle is the active successor. |
| `2026-09-07-orchestrator-skill-contracts.md` | Mostly implemented | Offline handoff/domain coverage shipped; native lifecycle narrowed to the active plan. |
| `2026-09-04-legout-planning-stack.md` | Complete | Consolidated `legout/skills` stack shipped. |
| `2026-09-03-adaptive-review-testing.md` | Complete | Test obligations and adaptive review guidance shipped. |
| `2026-09-03-native-pi-package.md` | Superseded/completed | Package/setup surface shipped; later setup contracts superseded its details. |
| `2026-09-03-initial-release.md` | Superseded | Profile-based design replaced by the consolidated stack. |

Archived files are retained for traceability. Their historical unchecked steps are not current work items.

## Separate maintenance

The skills source checker reports five upstream adopted-source branch drifts. Those are provenance-maintenance decisions, not implementation-plan work and are intentionally not changed by the planning-contract release.
