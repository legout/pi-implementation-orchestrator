# Native Pi Package Installation Plan

> **Archived plan — completed/superseded.** The native package manifest and setup prompt shipped; later setup and planning-contract work superseded several details here. Its unchecked steps are historical, not an active backlog. See `docs/plans/README.md` for the current plan index.

> **For agentic workers:** Implement this as one cohesive change with one focused RED/GREEN cycle and one cumulative review.

**Goal:** Make the repository installable as a native Git-backed Pi package and provide a manually invoked setup skill that configures dependencies, planning skills, and a target project only after explicit user approval.

**Architecture:** Add an explicit `package.json` Pi manifest for `skills/` and `prompts/`. Add a manual `setup-implementation-orchestrator` skill that resolves the package-local `setup.sh`, gathers unresolved choices, performs a dry-run preview, asks approval, then calls deterministic non-interactive setup flags. Native `pi install` remains passive and never modifies projects or installs secondary packages by itself.

**Tech Stack:** Pi Git packages, Agent Skills, Bash 3.2-compatible shell, JSON manifest, shell tests.

## Global Constraints

- Primary install command: `pi install git:github.com/legout/pi-implementation-orchestrator`.
- Package installation loads resources only; it must not execute setup automatically.
- Setup runs only through explicit `/skill:setup-implementation-orchestrator` invocation or direct `setup.sh` use.
- Keep current interactive `setup.sh` behavior as the default.
- Add explicit non-interactive project-choice flags for the setup skill.
- Require a dry-run preview and user approval before the setup skill performs mutations.
- Keep upstream skill installation selected and global; keep project documentation local.
- Preserve adaptive review, focused test obligations, and durable-patch recovery.
- Add no runtime dependency.
- Verify installation with an isolated `PI_CODING_AGENT_DIR` before publishing.

---

### Task 1: Add native Pi package and manual setup skill

**Files:**
- Create: `package.json`
- Create: `skills/setup-implementation-orchestrator/SKILL.md`
- Modify: `setup.sh`
- Modify: `tests/setup_test.sh`
- Modify: `README.md`
- Modify: `docs/design.md`

**Interfaces:**
- Consumes: Pi package source, setup profile, project path, instruction/tracker/domain choices.
- Produces: installed Pi resources and an explicitly approved deterministic setup invocation.

- [ ] **Step 1: Add focused failing tests**

Extend `tests/setup_test.sh` with:

1. `test_pi_package_manifest` — parse `package.json` with Node and assert:
   - name `pi-implementation-orchestrator`;
   - keyword `pi-package`;
   - `pi.skills` contains `./skills`;
   - `pi.prompts` contains `./prompts`.
2. `test_setup_skill_contract` — assert the setup skill:
   - has `disable-model-invocation: true`;
   - references `../../setup.sh`;
   - requires `--dry-run` before actual setup;
   - requires explicit approval;
   - invokes actual setup with `--yes` and explicit choice flags.
3. `test_noninteractive_project_choices` — run `setup.sh` with explicit flags and no stdin, then verify the selected instruction file, tracker, and domain layout.

Run `bash tests/setup_test.sh` and verify RED because the manifest, skill, and flags do not exist.

- [ ] **Step 2: Add the Pi package manifest**

Create `package.json`:

```json
{
  "name": "pi-implementation-orchestrator",
  "version": "0.1.0",
  "description": "Plan with selected skills and execute with isolated Pi workers and adaptive review.",
  "license": "MIT",
  "repository": "https://github.com/legout/pi-implementation-orchestrator",
  "keywords": ["pi-package"],
  "pi": {
    "skills": ["./skills"],
    "prompts": ["./prompts"]
  }
}
```

- [ ] **Step 3: Add deterministic setup choice flags**

Extend `setup.sh` with:

```text
--instruction-file auto|AGENTS.md|CLAUDE.md
--tracker auto|github|local|other
--tracker-description TEXT
--domain-layout auto|single|multi
```

Defaults remain `auto`, which preserves current interactive behavior. Explicit values bypass only their corresponding question. Validate all values. `other` requires a non-empty tracker description.

Map explicit values to existing render values:

```text
github → GitHub Issues
local → Local Markdown
single → Single context
multi → Multiple contexts
```

Do not change `--dry-run`, confirmation, or selected-skill behavior.

- [ ] **Step 4: Add the manual setup skill**

Create `skills/setup-implementation-orchestrator/SKILL.md` with trigger-only metadata and `disable-model-invocation: true`.

The skill must:

1. resolve `../../setup.sh` relative to its own directory;
2. accept optional profile/project arguments, otherwise ask;
3. inspect the target project and ask only unresolved instruction/tracker/domain choices;
4. call `setup.sh` once with `--dry-run` and explicit flags;
5. show the preview and obtain explicit user approval;
6. call the same command without `--dry-run`, adding `--yes`;
7. report installed resources and project files;
8. never edit project files itself or bypass `setup.sh`.

- [ ] **Step 5: Update README and design**

Make native Pi installation the primary quick start:

```bash
pi install git:github.com/legout/pi-implementation-orchestrator
```

Then:

```text
/skill:setup-implementation-orchestrator
```

Document passive installation, explicit setup, update/remove commands, direct `setup.sh` as an alternative, and optional pinned refs.

- [ ] **Step 6: Run GREEN verification**

```bash
bash -n setup.sh tests/setup_test.sh
bash tests/setup_test.sh
node -e 'JSON.parse(require("fs").readFileSync("package.json"))'
uv run --with pyyaml ~/.agents/skills/skill-creator/scripts/quick_validate.py skills/orchestrate-implementation
uv run --with pyyaml ~/.agents/skills/skill-creator/scripts/quick_validate.py skills/setup-implementation-orchestrator
git diff --check
```

Expected: all commands pass.

- [ ] **Step 7: Verify local Pi package installation in isolation**

Use a temporary config directory:

```bash
TMP_PI=$(mktemp -d -t pi-orchestrator-package)
PI_CODING_AGENT_DIR="$TMP_PI" pi install "$PWD"
PI_CODING_AGENT_DIR="$TMP_PI" pi list
```

Verify the package is listed and no target project files were created. Remove only `TMP_PI` afterward.

- [ ] **Step 8: Commit and run one cumulative review**

Commit the complete feature. Review the exact feature diff once for package-manifest correctness, passive installation, setup-skill safety, flag compatibility, tests, and README accuracy. If blocked, send all accepted findings to one fix worker using durable-patch recovery.

- [ ] **Step 9: Integrate, push, and verify remote installation**

After clean review, integrate and rerun Step 6. Push `main`, wait for exact-head CI success, then test Git installation with another isolated `PI_CODING_AGENT_DIR`:

```bash
PI_CODING_AGENT_DIR="$TMP_PI" pi install git:github.com/legout/pi-implementation-orchestrator
PI_CODING_AGENT_DIR="$TMP_PI" pi list
```

Finally synchronize the machine-global skill only if its published copy changed.
