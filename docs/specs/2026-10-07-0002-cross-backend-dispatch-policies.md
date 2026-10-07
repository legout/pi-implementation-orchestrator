# Cross-backend worktree and model policy

**Status:** Approved behavioral source, revision 1. Implementation is not authorized.

**Planning contract:** version 1. Installed provenance: local copy; exact catalog revision unknown.

**Owner approval:** The user approved this written specification on 2026-10-07. Approval covers revision 1 and its shared sibling worktree root, cross-backend model resolution, and setup behavior only. No implementation, migration, or publication authority was granted.

## Purpose

Make worktree placement and worker/reviewer model selection consistent when a run uses `pi-subagents`, Paseo, or a Herdr pane, without changing backend routing or silently substituting a different path, model, or thinking level.

## Scope and decisions

1. Use one visible, external worktree tree per project checkout: `<repo-parent>/worktrees/<repo-name>/`. Each checkout gets its own tree; separate clones do not share worktrees.
2. Put worker, fix, parent review/reconstruction, and candidate worktrees under that project tree. Backend-specific leaf names are allowed, but each leaf must be unique and map to its run/lane in the manifest.
3. If a selected backend cannot allocate within the expected tree, pause before launching a worker. Do not silently fall back to another location or allocator.
4. Use the existing Pi global `worker` and `reviewer` model/thinking settings as cross-backend defaults. Explicit project values override global values; explicit run/lane values override both.
5. Interactive setup and reconfiguration ask for the worker and reviewer model/thinking choices. Show the current effective value as the default; when unset, offer the user’s stated initial defaults. Dispatch itself is non-interactive.
6. Preserve current backend selection and review-routing policy. This feature chooses the role’s model for the selected backend; it does not change which backend is selected.

## Worktree location and ownership

Resolve the canonical Git top-level directory and derive the shared project root from its parent and repository basename:

```text
<canonical-repo-parent>/worktrees/<repo-basename>/
```

This path is outside the active checkout and is not hidden. It needs no `.gitignore` entry. Reject a path that resolves inside the checkout or Pi extension auto-discovery. Resolve and validate symlinks and existing path components before allocating anything.

Every worktree created for the run—including worker/fix, parent-owned review/reconstruction, and candidate checkouts—must be registered beneath this project root. A backend may retain its own safe leaf naming scheme; the orchestrator manifest is the authoritative mapping from worktree path to run, lane, role, and attempt. Preserve the existing pinned-base, unique branch/path, handoff, reconstruction, review, and cleanup requirements.

Do not move existing worktrees. A continuation on another backend must use the existing durable handoff procedure: resolve the old writer, verify the pinned base and complete patch, then allocate a new worktree under the shared root and replay the patch. Resume an existing workspace in place only when its original backend, path, identity, and exclusive ownership are verified.

### Backend allocation requirements

- **Pi-subagents:** Keep the selected allocator. Its worktree provider must place the managed worktree under the shared project root. `worktreeBaseDir` can direct the native allocator to a base directory but selects native allocation and conflicts with explicit Worktrunk selection; do not set it in a way that silently changes an explicitly selected provider. If the selected provider cannot honor the root, pause.
- **Herdr pane:** The parent allocates the registered worktree beneath the shared project root and gives that exact path to a fresh, identity-verified pane session.
- **Paseo:** The daemon must allocate its managed workspace beneath the shared project root. `worktreeSlug` alone is not proof of the parent directory. Verify a supported root configuration before workspace/agent creation; if the daemon cannot honor the path or access the same repository, pause without launching an agent.

Before mutation, the selected adapter must establish that it can honor the target root. Verify the returned worktree path before granting the worker write authority. A path mismatch is a blocked lane, not a reason to continue elsewhere.

## Model selection and setup

The role defaults when no effective value is configured are:

- Worker: `zai/glm-5.3` with `high` thinking.
- Reviewer: `openai-codex/gpt-6.1-sol` with `high` thinking.

At each interactive setup/reconfigure, ask for both roles’ model and thinking values in the existing grouped choice round. For a new global setup, show the defaults above. For an existing installation, show the currently effective values. For project setup, show the inherited global values and allow an explicit project override. Non-interactive callers may supply the existing model/thinking flags; explicit flags satisfy the questions.

Persist choices using the existing `subagents.agentOverrides.worker` and `.reviewer` model/thinking fields—do not create a second source of truth. Respect Pi’s project-over-global behavior and shallow override semantics: a project role value wins; absent project values fall back to the global/default resolution. When setup materializes a project override, preserve its other fields and fill any fields required to keep the effective model/thinking consistent with the selected values.

Resolve model and thinking per role before dispatch, in this order:

1. explicit run/lane selection;
2. explicit project role setting;
3. global role setting;
4. the defaults in this specification.

Because Pi project override objects replace global role objects rather than deep-merge them, the orchestrator must pass the resolved pair explicitly to the child. When setup writes a project override, preserve its other fields and materialize the resolved model/thinking fields needed to keep Pi and the other backends aligned. Record each selected value, its source, and the backend-specific effective value in the existing run manifest. Pass the worker pair to the worker and the reviewer pair to the reviewer, independently of backend. Each adapter must map the model and thinking level exactly (for example, to Paseo’s provider/model plus supported `thinkingOptionId`). Do not infer provider aliases or silently drop an unsupported thinking setting. If the selected backend cannot run the exact pair, pause before creating the agent.

## Failure behavior

- Missing or inaccessible sibling root, unsafe resolved path, path collision, or backend/root mismatch: stop before worker launch and preserve any existing worktree or artifact; do not allocate elsewhere.
- Remote Paseo daemon cannot access the canonical repository/root or cannot be configured to use it: pause before workspace/agent creation.
- Explicit Pi allocator configuration conflicts with the required root: preserve the selected allocator and pause; do not silently switch to native or Worktrunk.
- Model unavailable, provider identity mismatched, or requested thinking level unsupported: pause before agent creation; do not substitute a model or downgrade thinking.
- Existing run/lane path or branch is occupied: preserve it and allocate a distinct attempt only after verifying ownership and the recorded handoff state.

## Data flow and manifest

1. Setup reads current global and project role settings, asks for model/thinking choices, previews the exact settings changes, and applies them only after the existing approval gate.
2. At run intake, the orchestrator resolves the canonical repository root, shared worktree root, backend, and effective worker/reviewer model pairs.
3. Backend preflight proves root and model compatibility before any writer is launched.
4. The manifest records the canonical root, actual worktree paths, backend/workspace/session identifiers, resolved model/thinking values and sources, and any blocked reason.
5. Work proceeds through the existing handoff, parent reconstruction, review, candidate assembly, and separate integration/publication gates.

## Acceptance criteria

- For a checkout at `/path/to/repo`, all newly allocated worker, fix, review/reconstruction, and candidate worktrees are registered beneath `/path/to/worktrees/repo/`; no worktree is created inside `/path/to/repo/`.
- The common root is stable for repeated runs in that checkout, while distinct clones resolve independently.
- Each accepted lane’s manifest maps its run/lane/attempt to the exact backend-returned path; no path is inferred from a worker report alone.
- A backend that cannot prove it will use the expected root is blocked before it launches a writer; no off-root fallback occurs.
- Setup asks for worker/reviewer model and thinking on each interactive setup/reconfigure, with current effective values or the stated initial defaults shown; explicit command-line values remain non-interactive.
- Global settings are defaults, explicit project role settings override them, and explicit run/lane selections override both. Other settings fields are preserved.
- Each selected backend receives the exact resolved role model and thinking level, or dispatch is blocked before agent creation.
- Backend routing, parent acceptance, review policy, and publication gates remain unchanged.

## Verification design

Use focused checks for the actual contracts:

- temporary Git repositories verify root derivation, registration beneath the root, unique retry paths, and refusal for unsafe or off-root locations;
- setup tests verify new-install defaults, prompted/reconfigure choices, global/project precedence, explicit flags, and preservation of unrelated settings;
- backend conformance checks verify the prospective path and effective model/thinking before agent creation, including the no-launch refusal path;
- a disposable end-to-end check per supported backend confirms the returned path and launch configuration. A backend that cannot provide that evidence is reported as unsupported under this policy.

These checks establish configuration and routing, not model quality. No broad model benchmark or duplicate test suite is required.

## Non-goals

- Worktrees inside the source checkout or adding them to `.gitignore`.
- Sharing one worktree between writers, moving existing worktrees, or treating a live worktree as the recovery artifact.
- Silently changing a selected backend, Pi worktree allocator, provider/model, or thinking level.
- Changing reviewer backend routing, review policy, acceptance authority, or publication permissions.
- Model-quality evaluation or automatic model/provider fallback.

## Capture checkpoint

- **Vocabulary:** No glossary change is required; existing terms `worktree`, `run`, `lane`, `backend`, and `manifest` are sufficient.
- **Decisions:** No ADR is warranted. The sibling-root policy does not migrate existing state, is reversible for future runs, and its rationale and behavior are captured here; model precedence reuses existing settings.
- **Behavior:** Revision 1 is the approved behavioral source for the shared-root and model/setup changes. Implementation is not authorized.
- **Uncertainty:** Paseo’s ability to target the exact root and each Pi allocator’s ability to preserve its selection while honoring it are conformance gates. Unsupported configurations block dispatch rather than weaken the requirement.
