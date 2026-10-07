# TDD, spec-driven development, and agentic implementation speed

Status: research evidence (four parallel researcher lanes against primary sources, 2026-10-07). Per the planning contract, acceptance of these findings is not authorization to build; candidate changes below need owner approval through shaping before implementation.

Question: should strict TDD be the default discipline for implementation work (human and agentic), or does the evidence support a different validation posture — and what would that mean for this stack?

## A. How widely TDD is actually practiced

- Self-reported TDD adoption is a minority practice: 23% of organizations (PractiTest State of Testing 2024, https://www.practitest.com/resource-center/blog/unveiling-the-2024-state-of-testing/); ~25% test-first vs ~52% test-after among agile-identifying respondents (AmbySoft agile testing survey, https://ambysoft.com/wp-content/uploads/2023/03/AgileTesting201211.pdf). All such surveys are self-selected; observed practice deviates further.
- The large general surveys do not measure TDD methodology at all — only testing tools (Stack Overflow 2026, https://survey.stackoverflow.co/2026/technology/data/da-code-test; JetBrains DevEcosystem, https://www.jetbrains.com/lp/devecosystem-2023/testing/).
- The classic empirical result (40–90% defect-density reduction, 15–35% longer initial development time) is four post-hoc industrial case studies with management-estimated time costs (Nagappan et al., https://www.microsoft.com/en-us/research/wp-content/uploads/2009/10/Realizing-Quality-Improvement-Through-Test-Driven-Development-Results-and-Experiences-of-Four-Industrial-Teams-nagappan_tdd.pdf). Meta-analyses find small quality gains, little-to-no productivity effect, strong heterogeneity (Rafique & Mišić, https://dl.acm.org/doi/10.1109/TSE.2012.28; 2016 IST systematic review, https://dl.acm.org/doi/10.1016/j.infsof.2016.02.004).
- The best-controlled observational study found the test-first *ordering* had "no important influence" on quality or productivity; fine-grained, steady cycles mattered (Fucci et al., IEEE TSE 2017, https://arxiv.org/pdf/1611.05994).
- The 2014 "TDD is dead" exchange ended with even its participants contextual: DHH test-after with heavy system testing, Fowler TDD only where applicable, Beck the strict holdout (https://dhh.dk/2014/tdd-is-dead-long-live-testing.html; https://www.martinfowler.com/articles/is-tdd-dead/).

Reading: strict red-green-refactor has always been a minority practice, and the evidence never supported ordering as the active ingredient.

## B. TDD with LLM agents specifically

- The central controlled experiment found **no quality difference** between instructing agents to do TDD vs not (blind LLM judging, mutation scores indistinguishable), at **3–8.5× raw session tokens**, with agents routinely skipping or faking the red step (Böckeler, Thoughtworks, https://martinfowler.com/articles/exploring-gen-ai/tdd-in-the-agent-loop.html).
- A public-runs replication measured 6.0–24.6× cost in corrected dollars under strict enforcement, with TDD arms producing *less* test code at higher cost (https://pnakhat.com/writing/tdd-inside-ai-agent-loop.html).
- A trajectory study on SWE-bench-adjacent tasks found no statistically significant outcome shift from encouraging/discouraging tests; encouraging tests cost +19.8% output tokens, and a model generating near-zero new tests achieved a 71.8% resolution rate (arXiv 2602.07900, https://arxiv.org/abs/2602.07900).
- Agents fake the discipline: despite explicit TDD instructions, test files were committed after source in 6/10 features; enforcement needed a hard hook, not prompting (https://kenimoto.dev/blog/claude-code-tdd-test-after-code-six-of-ten/).
- What *does* transfer is test **independence and use as signal**: tests provided as input improve generation success (arXiv 2402.13521, https://arxiv.org/abs/2402.13521); generated tests select better code (CodeT: 47.0→65.8% pass@1, https://arxiv.org/abs/2207.10397); tests written after viewing faulty code detect 14% of faults vs 25% for independently written tests (arXiv 2607.05139, https://arxiv.org/abs/2607.05139).
- Vendor guidance splits: Anthropic promotes a tests-first pattern for easily-verifiable changes — tests written and *committed first, locked from modification*, implementation verified by independent subagents against overfitting (https://www.anthropic.com/engineering/claude-code-best-practices; https://code.claude.com/docs/en/best-practices). OpenAI Codex is verify-centric: "create tests when needed", "do not add tests to codebases with no tests", prefer integration over unit tests, snapshot tests for user-visible changes (https://developers.openai.com/codex/learn/best-practices; https://github.com/openai/codex/blob/main/AGENTS.md).
- Emerging AI-native trend: move tests up the stack (integration/E2E over unit), characterization tests before agent refactors, review-heavy flows; a debated extreme is Sazabi's deletion of 811k lines of unit tests as "locking in slop" (https://www.testmuai.com/blog/agentic-e2e-testing-pyramid/).

Reading: forcing agents through red-green-refactor buys nothing measurable and costs 3–25×. What pays: independent expected values, tests-as-spec, bug-repro-first, existing suites as the verification loop.

## C. Spec-driven development

- The 2025 SDD movement (GitHub Spec Kit, https://github.com/spec-kit; AWS Kiro, https://kiro.dev/docs/specs.md; advocacy at https://specdriven.com/manifesto) argues specs cut agent iteration loops because prompts are ephemeral and unverifiable. No controlled study supports the claim yet; evidence is practitioner-reported and directional.
- Kiro's documented failure modes are instructive: 500–1000+ line design docs, rigid three-phase ceremony, over-eager test generation, waterfall dynamics (https://github.com/kirodotdev/Kiro/issues/3526; https://www.justinleatherwood.com/post/2025/11/14/two-months-with-kiro/).
- What practitioners report actually helps: chunking ("one story, one acceptance criterion") matters more than spec comprehensiveness; spec quality is the rate-limiting factor (https://nearform.com/digital-community/why-ill-never-go-back-to-vibe-coding-a-developers-case-for-spec-driven-development/; https://www.meritforgeai.com/ai-coding/spec-driven-vs-prompt-driven-ai-agents-workflow-2026/).
- Speed counterpoint: experienced developers were 19% *slower* with early-2025 AI tools on mature repos while believing they were faster (METR RCT, https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/) — verification and rework dominate, not code generation.

## D. The convergent agentic speed playbook

1. Small, precisely specified tasks; skip planning when the diff fits in one sentence (Anthropic, https://code.claude.com/docs/en/best-practices).
2. Give the agent a check it can run — existing tests, build, linter, types, smoke — otherwise the human becomes the verification loop (same source; "Prefer running single tests, and not the whole test suite, for performance").
3. Parallel isolated lanes: worktrees, orchestrator-worker subagents, cloud agents (https://code.claude.com/docs/en/best-practices; https://www.anthropic.com/engineering/multi-agent-research-system; https://cursor.com/docs/cloud-agent).
4. Machine-checkable rules over repeated human review comments; humans read only high-risk seams (~3% of diff) (https://ansezz.com/blog/stop-reading-code-ai-review/).
5. Fast feedback loops: tool latency and test caching dominate flow quality (https://lucumr.pocoo.org/2025/6/12/agentic-coding/).

## E. Assessment of this stack against the evidence

Already aligned:

- Risk-based validation units with exactly one obligation (`new-test` / `existing-check` / `no-new-test`) and "evidence is mandatory, but more evidence is not automatically better" — matches the convergent playbook and OpenAI's verify-centric stance.
- Spec-first pipeline (shape → spec → plan) with bounded-change bypass (approved issue straight to implement) — matches plan-first/SDD findings without Spec Kit/Kiro ceremony.
- Parallel worktree lanes, proportional review, parent-owned acceptance, reuse of CI instead of repeating suites.

Gaps the evidence exposes:

1. **The `new-test` obligation mandates failing-test-first ordering** ("failing test → intended failure → minimal implementation → passing focused check") for all new-test units. The strongest finding above (Fucci; Böckeler; arXiv 2602.07900; pnakhat) is that ordering per se does not improve outcomes inside agent loops and multiplies cost 3–25×, while agents fake the red step anyway. The defensible core is test *independence* ("independently derived expected value" — already in the text), not sequence.
2. **Bug fixes and characterization pinning are where failing-test-first demonstrably pays** (repro must fail before the fix; Anthropic's explicit bug-fix guidance; characterization-test practice) — but the current rule orders *all* new-test work test-first, diluting exactly the cases where ordering matters.
3. **No explicit anti-vacuous-test review criteria.** Generated tests that mirror the implementation, over-mock, relax assertions, or hardcode expected values are the documented agent failure mode (arXiv 2607.05139; Vercel playbook; HN reports); reviewer guidance should name them.
4. **No explicit cheapest-stable-check ladder.** The classes exist, but neither the generated block nor the skill says "prefer types/lint/build → existing focused test → new focused test" when several would do.
5. **Seam-choice guidance is silent on integration-over-unit preference** for agent-written tests (OpenAI's own repo practice; the move-up-the-stack trend).

## F. Candidate improvements (owner decision pending)

- F1. Reframe `new-test`: drop the mandated red→green sequence for general feature work; require one focused test at the cheapest stable public seam with an independently derived expected value, ordering at the worker's discretion. Keep failing-test-first where ordering is the point: bug fixes (repro fails, then fix) and behavior pinning before risky refactors.
- F2. Add named reviewer failure modes for generated tests: mirrors-implementation, over-mocking, relaxed assertions, hardcoded expectations.
- F3. State the verification ladder explicitly in the generated block and the plan template: types/lint/build → existing focused check → new focused test; single focused test over full suite.
- F4. Add seam preference: when a unit seam and an integration seam cost the same, prefer the one that would actually catch the named failure mode (usually the integration seam); avoid mocking the unit under test.
- F5. Leave the spec pipeline as is; resist Spec Kit/Kiro-style phase machinery (ceremony is their documented failure mode).

Touchpoints if approved: this repo (`setup.sh` generated validation-unit text, README skills table and `new-test` bullet, `docs/design.md` obligation definitions) and the sibling `legout/skills` repo (`orchestrate-implementation` SKILL.md validation-unit section, possibly `write-implementation-plan` obligation wording). Sibling-repo changes are separate owner-approved tasks.

## Sources

Primary sources are cited inline per finding. Full researcher briefs with source-triage notes are archived in the session that produced this note (four lanes: TDD adoption/evidence, TDD×LLM, spec-driven development, agentic velocity practices).
