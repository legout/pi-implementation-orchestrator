# Planning-contract verification record

Status: sanitized T4 evidence for the planning-artifact contract. No private transcript, credential, or real project path is included.

## Reviewed revisions

- `legout/skills` T1: `ce95643324c50b292ba91bb47e7f2ad9baa03642`.
- `legout/skills` T2 remediation: `cd7674151f4f0a7a89c9558c78a633ea3b89837f`.
- Installer T3: `548f88df98095ede96b74f1346fd1eb440165e0c`.

## Distribution smoke test

Using the local skills candidate source and disposable temporary `HOME` and project directories:

```text
HOME=<temporary> npx --yes skills add <candidate-skills> --skill planning-contract --global --agent pi --yes --copy
=> Installed 1 skill: planning-contract (copied) -> ~/.pi/agent/skills/planning-contract

(cd <temporary-project> && HOME=<temporary> npx --yes skills add <candidate-skills> --skill planning-contract --agent pi --yes --copy)
=> Installed 1 skill: planning-contract (copied) -> ./.pi/skills/planning-contract

(cd <temporary-consumer-only-project> && HOME=<temporary> npx --yes skills add <candidate-skills> --skill shape-design --agent pi --yes --copy)
=> Installed 1 skill: shape-design (copied) -> ./.pi/skills/shape-design
=> planning-contract is absent from the consumer-only installation
```

Assertions passed: global contract file exists, project contract file exists, consumer-only installation exists, and consumer-only installation does not contain `planning-contract`. No real user skill directory or project was modified.

## Semantic acceptance

A fresh read-only Pi `code-reviewer` evaluated every positive and negative control in `tests/fixtures/planning-contract-scenarios.json` against the actual contract and consumer instructions. The fixture contains nine acceptance groups and 21 controls. After reconciling three fixture mismatches (proposed specs remain unapproved, ticket planning has an approved source, and ready dispatch declares owned surfaces), AC-01 through AC-09 matched expected behavior.

The consumer-only result is intentionally not treated as permission to proceed: each consumer instruction requires detecting the missing `planning-contract` skill and refusing to continue on invented or inherited rules. The semantic evaluator verified that refusal rule for the affected consumers.

## Other checks

- Installer: syntax checks, `tests/setup_test.sh`, `tests/setup_runner_test.sh`, package metadata assertion, and `git diff --check` passed.
- Skills: syntax checks, `tests/skills_test.sh`, `tests/orchestrator_handoff_test.sh`, fixture validation, and `git diff --check` passed.
- LSP diagnostics for changed files: zero findings.
- `scripts/check-skill-sources.sh` remains non-clean because five unrelated adopted upstream branches moved: humanizer, cursor/plugins, davidondrej/skills, github/awesome-copilot, and archify. Their pins were not changed.

## Boundary

This record proves selected-skill distribution and semantic refusal guidance in disposable environments. It does not publish a package, migrate an existing project, or claim that the unrelated upstream source drift is resolved.
