# Agent guidance

## Scope and conventions

This package owns `setup.sh`, prompt templates, and their tests/docs; runtime skills live in `../skills/`. `docs/design.md` and `README.md` document the supported setup contract; `CONTEXT.md` owns terminology. Shell scripts use Bash with `set -euo pipefail`; tests use isolated temporary homes and stub installers. Preserve approval, path-safety, byte-preservation, and publication gates. Do not alter unrelated work in the sibling repository.

## Ground rules

- Priority: agreed feature, then correctness, then proven risk. Written conventions are binding and violations are must-fix; unwritten taste never blocks. Name the requirement or rule, not a guessed convention.
- A finding must name a requirement/rule this change violates, show what it caused or worsened, a reachable scenario through real callers/inputs/environment, material impact, and a proportionate response.
- Security review requires a touched boundary: untrusted/external input, credentials, auth, or dependency changes. Name the asset, realistic attacker, and actual attack path. Stolen-secret, broken-TLS, malicious-admin, and generic-hardening stories are not findings. Untouched boundary: `security: n/a`; missing security facts: `unverified`, not an invented threat model. This is a local installer, not a network service; user-owned projects are trusted. Its documented filesystem-safety and install-approval guarantees remain binding correctness requirements.
- Test requests are findings too: name a real scenario or drop them. Coverage percentage and unreachable states are not reasons. Use existing focused checks when sufficient; one failing test first for new behavior without coverage. New dependencies/abstractions need a job today.
- Disposition before repair: the parent rejects failed gates in one line, authorizes small in-scope fixes, or hands large/out-of-scope fixes to the human. Reviewers return findings, never start repairs or re-reviews.
- Put the complete gates, criteria, conventions, and real-use context directly in every fresh reviewer prompt; a link to this file is insufficient. Review ends when criteria, real risks, and written rules are covered: `pass` or `fix-first`, then stop. One fix pass, one delta-only recheck; unresolved findings go to the human. No third round or re-opening settled findings at candidate review.
- After each task: restate the approved task, compare the result, choose `accept / fix / hand back / ask`. Extra ideas get one line, not code. No new evidence ledgers, lifecycle, or sign-off artifacts.

## Verification

Run the relevant cases in `tests/setup_test.sh` for generated-contract changes, then the shell suites documented in `README.md` before completion. Runtime skill checks belong in `../skills/tests/`. Distinguish prompt-contract tests from live model evaluations; neither proves the other.
