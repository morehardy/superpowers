# Codex v6 Sync Design

Date: 2026-07-09
Status: Ready for user review

## Context

This repository is a personal Codex-only fork of Superpowers. The local `main`
branch diverged from upstream at `f2cbfbef` (`v5.1.0`). Local commits then
removed non-Codex platform entrypoints and added three external review gates:

- `brainstorming`: External Design Challenge
- `writing-plans`: External Plan Challenge
- `finishing-a-development-branch`: External Implementation Audit

The remote `origin/main` is at `d884ae0` (`v6.1.1`) and contains substantial
skill improvements, Codex packaging fixes, and multi-platform support. The
remote changes are valuable, but a direct merge would restore platform support
this fork intentionally removed.

## Goals

- Adopt the remote v6 skill behavior improvements that benefit Codex.
- Preserve the local external review gates and their `claude` CLI reviewer
  prompts.
- Preserve the Codex-only repository shape.
- Keep the fork lean by excluding other harness entrypoints, hooks, docs, and
  tests.
- Update Codex metadata and packaging so the plugin installs cleanly without
  SessionStart hook auto-discovery.
- Define concrete verification commands that prove the synchronized fork remains
  Codex-only and keeps the intended skill behavior.

## Non-Goals

- Do not make this repository multi-platform again.
- Do not restore Claude Code, Cursor, Gemini, OpenCode, Copilot, Kimi,
  Antigravity, Pi, or Droid plugin entrypoints.
- Do not restore cross-platform hook wrappers.
- Do not restore `writing-skills` or Anthropic-oriented skill-writing
  references.
- Do not implement the synchronization in this design step.
- Do not replace the local external review gates with upstream's lighter
  self-review-only flow.

## Recommended Integration Shape

Use upstream commit `d884ae04edebef577e82ff7c4e143debd0bbec99` (`v6.1.1`)
as the base for a new integration branch, then reapply the Codex-only boundary
and local review gates. The commands below show the nominal branch names; if
either branch already exists, use the collision rules in Migration Steps and
substitute the actual `RESTORE_REF` and `INTEGRATION_BRANCH` names everywhere:

```bash
git branch "$RESTORE_REF" main
git fetch origin --prune
git rev-parse --verify d884ae04edebef577e82ff7c4e143debd0bbec99^{commit}
git switch -c "$INTEGRATION_BRANCH" d884ae04edebef577e82ff7c4e143debd0bbec99
```

This approach starts from the complete remote v6.1.1 behavior, then removes
unwanted platforms. It avoids the highest-risk path: directly merging remote
v6.1.1 into the current local `main`, which would produce many delete/modify
and both-modified conflicts across platform metadata, hooks, README content,
tests, and core skills.

## Repository Boundary

The final repository should keep these top-level areas:

- `.agents/plugins/marketplace.json`
- `.codex-plugin/plugin.json`
- `AGENTS.md`
- `README.md`
- `LICENSE`
- `assets/`
- `docs/superpowers/specs/`
- `docs/superpowers/plans/`
- `skills/`
- `tests/brainstorm-server/`
- `tests/codex/`
- `scripts/package-codex-plugin.sh`

Under root `scripts/`, keep only `scripts/package-codex-plugin.sh`. Remove all
other upstream root scripts unless a later implementation plan explicitly
identifies a Codex-only need and adds matching tests.

Final top-level skill directories:

- `skills/brainstorming/`
- `skills/dispatching-parallel-agents/`
- `skills/executing-plans/`
- `skills/finishing-a-development-branch/`
- `skills/receiving-code-review/`
- `skills/requesting-code-review/`
- `skills/subagent-driven-development/`
- `skills/systematic-debugging/`
- `skills/test-driven-development/`
- `skills/using-git-worktrees/`
- `skills/using-superpowers/`
- `skills/verification-before-completion/`
- `skills/writing-plans/`

Any upstream skill directory not in this list is removed by default. For
retained skills outside the five core merge areas, use the upstream v6.1.1 file
as the base when it exists, apply Codex-only wording and tool-name cleanup, and
keep the local file when upstream does not provide a newer version.

Local-fork files restored from `RESTORE_REF`:

- `AGENTS.md`
- `README.md` as the starting point for the Codex-only README
- `docs/superpowers/specs/`
- `docs/superpowers/plans/`
- `skills/brainstorming/design-challenge-reviewer-prompt.md`
- `skills/writing-plans/plan-challenge-reviewer-prompt.md`
- `skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md`
- `tests/codex/test-sdd-integration-script-behavior.sh`
- `tests/codex/test-subagent-driven-development-integration.sh`

Files not listed here are either taken from the upstream v6.1.1 base, rewritten
from the design requirements, or removed by the repository boundary rules.

The final repository should remove or keep removed:

- `.claude-plugin/`
- `.cursor-plugin/`
- `.kimi-plugin/`
- `.opencode/`
- `.pi/`
- `.github/`
- `hooks/`
- `CLAUDE.md`
- `GEMINI.md`
- `CODE_OF_CONDUCT.md`
- `RELEASE-NOTES.md`
- `docs/README.kimi.md`
- `docs/README.opencode.md`
- `docs/porting-to-a-new-harness.md`
- `docs/windows/`
- `gemini-extension.json`
- root `package.json`
- non-Codex platform tests
- `skills/writing-skills/`
- non-Codex files under `skills/using-superpowers/references/`

Under `tests/`, keep only:

- `tests/brainstorm-server/`
- `tests/codex/`

All other upstream test directories are removed. If an upstream non-Codex test
contains coverage for behavior this fork keeps, port that coverage into
`tests/codex/` or `tests/brainstorm-server/` instead of keeping the original
platform-specific directory.

Default test disposition: remove tests outside `tests/brainstorm-server/` and
`tests/codex/`. Before removal, audit the test's assertion. Port it only when it
checks retained Codex plugin behavior, retained skill behavior, retained SDD
helper behavior, retained Codex packaging behavior, or retained brainstorm
server behavior and no equivalent retained test already covers that assertion.

Test audit checklist for each removed upstream test file:

1. Identify the behavior asserted by the test in one sentence.
2. Classify the behavior as removed platform behavior, retained Codex plugin
   behavior, retained skill behavior, retained SDD helper behavior, retained
   Codex packaging behavior, or retained brainstorm server behavior.
3. If it is removed platform behavior, delete the test with the removed feature.
4. If it is retained behavior, check whether `tests/codex/` or
   `tests/brainstorm-server/` already asserts the same behavioral property with
   the same inputs or an equivalent Codex-only fixture.
5. Port only retained behavior with no equivalent retained coverage.

`scripts/package-codex-plugin.sh` stays because Codex portal packaging is part
of the Codex distribution path. It must be rewritten to package only the
Codex-only artifact set and must not require `CODE_OF_CONDUCT.md`,
`package.json`, hooks, docs, tests, or non-Codex platform metadata.

`.agents/plugins/marketplace.json` stays. It is the Codex marketplace manifest
for this fork, and `tests/codex/test-marketplace-manifest.sh` must validate its
Codex-only content.

Historical design artifacts under `docs/superpowers/specs/` and
`docs/superpowers/plans/` stay as project history, but the retained history is
the local fork's history, not upstream's full v6 history. During integration,
delete upstream's `docs/superpowers/specs/` and `docs/superpowers/plans/` on the
integration branch, then restore those directories from `RESTORE_REF`. These
docs are not active installation, plugin, or skill instructions. The
platform-boundary scan therefore targets active surfaces only: `README.md`,
`AGENTS.md`, `skills/`, and `tests/`.

## Skill Integration

### using-superpowers

Adopt upstream's compressed bootstrap as the base because it reduces per-session
token cost. "Compressed bootstrap" means the upstream v6.1.1
`skills/using-superpowers/SKILL.md` shape that removed the Graphviz flowchart
and verbose per-platform loading walkthrough while keeping the rule, red flags,
skill priority, and user-instruction precedence. Use
`d884ae04edebef577e82ff7c4e143debd0bbec99:skills/using-superpowers/SKILL.md`
as the file-level base, then reintroduce this fork's Codex-only platform
adaptation:

- task tracking maps to `update_plan`
- subagent dispatch maps to `spawn_agent`
- subagent result collection maps to `wait_agent`
- finished subagents should be closed with `close_agent`
- shell commands map to `exec_command`
- manual file edits map to `apply_patch`
- skills load natively by reading and following their `SKILL.md` content

Keep `skills/using-superpowers/references/codex-tools.md`. Delete
non-Codex references such as `antigravity-tools.md`, `pi-tools.md`,
`copilot-tools.md`, and `gemini-tools.md`.

The final `skills/using-superpowers/SKILL.md` must satisfy these concrete
checks:

- keeps upstream v6's concise prose structure rather than reintroducing the old
  Graphviz flowchart
- includes the `EXTREMELY-IMPORTANT`, `SUBAGENT-STOP`, rule, red-flags, skill
  priority, and user-instruction precedence sections
- includes a Codex-only platform adaptation section that names
  `references/codex-tools.md`
- includes the Codex tool names `update_plan`, `spawn_agent`, `wait_agent`,
  `close_agent`, `exec_command`, and `apply_patch`
- does not mention Pi, Antigravity, Gemini, Copilot, Cursor, OpenCode, Kimi, or
  Claude Code as supported harnesses
- does not reference non-Codex tool-mapping files

Merge procedure for `skills/using-superpowers/SKILL.md`:

1. Start from upstream v6.1.1's file.
2. If upstream has a distinct `Platform Adaptation` section, replace that entire
   section with a Codex-only section that points to `references/codex-tools.md`
   and lists the Codex tool names above.
3. If upstream does not have a distinct platform section, reconstruct the final
   file using these sections, in this order:
   - frontmatter
   - `SUBAGENT-STOP`
   - `EXTREMELY-IMPORTANT`
   - `The Rule`
   - `Skill Priority`
   - `Red Flags`
   - `Platform Adaptation` with only Codex content
   - `User Instructions`
4. Use upstream wording for the retained sections when present. Use the local
   fork's Codex wording only for the Codex platform adaptation.
5. If any required retained section is absent from upstream and cannot be
   reconstructed from `RESTORE_REF` without reintroducing the old flowchart or
   multi-platform guidance, stop and escalate before implementing.

### Skill File Merge Rules

The five core skill areas use these file-level merge rules:

| Skill area | Upstream base | Local restore | Required merge action |
| --- | --- | --- | --- |
| `using-superpowers` | `d884ae04edebef577e82ff7c4e143debd0bbec99:skills/using-superpowers/SKILL.md` | `backup/codex-only-before-v6-sync:skills/using-superpowers/references/codex-tools.md` | Keep upstream's compressed structure, replace multi-harness platform adaptation with the Codex-only adaptation and codex-tools reference described above, and delete non-Codex reference files. |
| `subagent-driven-development` | Entire upstream `skills/subagent-driven-development/` directory at `d884ae04edebef577e82ff7c4e143debd0bbec99` | none of the old two-reviewer prompt files | Keep upstream `task-reviewer-prompt.md`, `implementer-prompt.md`, and `scripts/`; do not restore `spec-reviewer-prompt.md` or `code-quality-reviewer-prompt.md`; adapt tool names and model policy to Codex. |
| `brainstorming` | Entire upstream `skills/brainstorming/` directory at `d884ae04edebef577e82ff7c4e143debd0bbec99` | `backup/codex-only-before-v6-sync:skills/brainstorming/design-challenge-reviewer-prompt.md` | Keep upstream visual companion scripts and just-in-time companion flow; insert the External Design Challenge after spec self-review and before the user review gate. |
| `writing-plans` | `d884ae04edebef577e82ff7c4e143debd0bbec99:skills/writing-plans/SKILL.md` | `backup/codex-only-before-v6-sync:skills/writing-plans/plan-challenge-reviewer-prompt.md` | Keep upstream Task Right-Sizing, Global Constraints, and Interfaces sections; insert the External Plan Challenge after plan self-review and before Execution Handoff. |
| `finishing-a-development-branch` | `d884ae04edebef577e82ff7c4e143debd0bbec99:skills/finishing-a-development-branch/SKILL.md` | `backup/codex-only-before-v6-sync:skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md` | Keep upstream forge-neutral and worktree cleanup safety improvements; insert the External Implementation Audit after local test verification and before environment detection or finishing options. |

These insertion points are authoritative. If an upstream section name has moved,
place the external gate at the same workflow boundary described in this table
rather than choosing a new location.

During the upstream snapshot step, confirm that each required workflow boundary
exists in the upstream skill text:

- brainstorming: spec self-review before user review
- writing-plans: plan self-review before execution handoff
- finishing-a-development-branch: local test verification before environment
  detection or finishing options

If a boundary is absent or no longer distinguishable, stop and escalate before
merging that skill.

### subagent-driven-development

Adopt upstream v6's task-review architecture:

- replace the old per-task two-reviewer flow with one `task-reviewer-prompt.md`
  that returns both spec-compliance and task-quality verdicts
- keep a final whole-branch review after all tasks
- use `scripts/task-brief` to write task-local context into
  `.superpowers/sdd/`
- use `scripts/review-package` to write review diffs into `.superpowers/sdd/`
- use `scripts/sdd-workspace` to keep SDD scratch files out of `.git/` and out
  of commits
- keep implementer reports in files and require TDD RED/GREEN evidence when
  TDD applies
- include a `Model Selection` section in the SDD controller instructions:
  - if the available `spawn_agent` tool schema exposes a `model` parameter, the
    controller must pass an explicit model on every implementer, fixer, task
    reviewer, and final reviewer dispatch
  - default implementer and fixer model: `gpt-5.4`
  - default task reviewer and final whole-branch reviewer model: `gpt-5.5`
  - if the available `spawn_agent` tool schema does not expose a `model`
    parameter, the controller must not invent one and must record
    `Codex spawn_agent model selection unavailable` in the SDD progress ledger
  - if `spawn_agent` exposes a `model` parameter but `gpt-5.4` or `gpt-5.5` is
    unavailable in the active model list, the controller must pause before
    starting SDD and ask the user to choose replacement model names; it must not
    guess aliases

Codex adaptation must replace upstream generic or other-harness tool names with
Codex-native names in the instructions and examples:

- `spawn_agent`
- `wait_agent`
- `close_agent`
- `update_plan`
- `exec_command`
- `apply_patch`

Delete obsolete SDD prompt files:

- `skills/subagent-driven-development/spec-reviewer-prompt.md`
- `skills/subagent-driven-development/code-quality-reviewer-prompt.md`

### brainstorming

Adopt upstream's visual companion security and lifecycle improvements:

- per-session key for HTTP and WebSocket requests
- tab-scoped cookie flow
- path containment checks
- symlink and dotfile rejection
- no-store and deny-framing headers
- owner-only token files
- resilient reconnect UI
- paused overlay when the server is unavailable
- 4-hour idle timeout
- safer `stop-server.sh` ownership checks
- version fallback to `.codex-plugin/plugin.json`
- just-in-time visual companion offer instead of an upfront offer

Preserve the local External Design Challenge:

- it runs after spec self-review
- it runs before asking the user to review the spec
- it uses `skills/brainstorming/design-challenge-reviewer-prompt.md`
- it uses the local brainstorming packet shape: spec file path, current spec
  content, user-confirmed key decisions, approaches considered and rejected,
  design success criteria, and design review focus areas
- it invokes the local `claude` CLI in isolated, non-interactive mode
- it passes a structured packet on stdin
- it uses `--tools ""` so the external reviewer cannot inspect or mutate the
  repository
- every substantive item is accepted, rebutted, or escalated before continuing
- if the `claude` CLI is missing, times out, exits non-zero, or returns
  unusable output, the main session must pause and ask the user whether to
  retry, skip, or use an alternative review path
- if the user skips the external challenge, the main session must record the
  gate as waived, not passed

The external reviewer is an independent review backend, not platform support
for Claude Code.

The visual companion has no SessionStart or hook dependency in this fork. It is
retained as a skill-launched local companion: when the `brainstorming` skill's
just-in-time offer is accepted, the agent starts
`skills/brainstorming/scripts/start-server.sh` with `exec_command` according to
`skills/brainstorming/visual-companion.md`. Codex does not need a plugin hook or
launcher for this feature.

All retained files under `skills/brainstorming/` must describe companion startup
as skill-driven and `exec_command`-driven. They must not describe the companion
as `sessionStart`, hook, plugin auto-launch, or other harness-launch behavior.

### writing-plans

Adopt upstream's plan-structure improvements:

- `Task Right-Sizing`
- `Global Constraints`
- per-task `Interfaces`

Preserve the local External Plan Challenge:

- it runs after plan self-review
- it runs before execution handoff
- it uses `skills/writing-plans/plan-challenge-reviewer-prompt.md`
- it uses the local writing-plans packet shape already defined by that skill:
  plan file path, current plan content, source spec path and content, confirmed
  planning inputs, execution assumption, and plan review focus areas
- it validates structured reviewer output
- accepted material changes trigger another self-review and external challenge
- if the `claude` CLI is missing, times out, exits non-zero, or returns
  unusable output, the main session must pause and ask the user whether to
  retry, skip, or use an alternative review path
- if skipped, the gate is recorded as waived, not passed

The plan format should support upstream v6 SDD by ensuring each task has enough
local context for a fresh implementer and reviewer.

### finishing-a-development-branch

Adopt upstream's safety improvements:

- remove hardcoded `gh pr create` instructions
- detect remote platform before suggesting PR or MR steps
- only clean up Superpowers-owned project-local worktrees under `.worktrees/`
  or `worktrees/`
- do not use the old global worktree directory fallback

Preserve the local External Implementation Audit:

- it runs after local tests pass
- it runs before presenting finishing options
- it uses
  `skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md`
- it uses the local finishing packet shape already defined by that skill:
  repository root, git range, implementation plan, source spec, latest test
  evidence, implementation goal, and audit focus areas
- it gives the external reviewer read-only repository access
- Critical and Important findings block finishing until fixed, rebutted, or
  escalated
- Minor and Advisory findings remain non-blocking
- if the `claude` CLI is missing, times out, exits non-zero, or returns
  unusable output, the main session must pause and ask the user whether to
  retry, skip, or use an alternative review path
- if the user skips the external audit, the main session must record the gate as
  waived, not passed

## Codex Metadata And Packaging

Update `.codex-plugin/plugin.json` to the v6.1.1 version while keeping this
fork's Codex-only description. The manifest must include:

```json
"hooks": {}
```

This exact empty object is required. Without it, Codex can auto-discover
repository hook metadata and re-register a SessionStart hook that this fork does
not want.

`.agents/plugins/marketplace.json` should point to this repository root as a
Codex marketplace source and use the Codex category naming expected by the
current Codex plugin flow.

Use upstream v6.1.1's `scripts/package-codex-plugin.sh` as the rewrite
baseline, then remove assumptions that conflict with this fork's Codex-only
boundary. Package verification should assert that archives exclude:

- source-only scripts except the packaged helper scripts under `skills/`
- tests
- docs
- non-Codex plugin directories
- hooks
- platform-specific root files
- package metadata for other harnesses

The archive should include:

- `.codex-plugin/plugin.json`
- `assets/`
- `skills/`
- `README.md`
- `LICENSE`
- OpenAI skill metadata copied only from the required `--metadata-source`
  directory

The package script test must use a synthetic metadata source in the test
fixture. The package script itself must not depend on root `package.json` or
non-Codex platform files.

Each synthetic `openai.yaml` file must include enough YAML content to prove the
file is copied, not merely created as an empty placeholder. Minimum content:
`name: <skill-name>` and `description: Synthetic metadata for <skill-name>`.

OpenAI skill metadata is required for Codex portal packages, but this fork does
not store that metadata in `skills/`. `scripts/package-codex-plugin.sh` must
require an explicit `--metadata-source PATH` argument. `PATH` must be a
directory outside or inside the working tree containing one
`skills/<skill-name>/agents/openai.yaml` file for every final top-level skill
directory kept under `skills/`. The maintainer who runs production packaging is
responsible for producing this directory, normally by extracting the prior
official Codex package or by preparing a maintainer-owned metadata directory
with the same path shape. The repository does not generate or vendor this
metadata. The script must not guess a default path. During packaging, the script
copies each metadata file into the staged archive under the matching skill
directory. If any kept skill is missing metadata, the script must fail with a
clear error. The Codex package test must generate a synthetic metadata source
with this exact path shape and call the script with
`--metadata-source "$fixture_dir"`.

`--metadata-source` is the sole metadata ingestion path. The package script must
not generate OpenAI metadata, read it from another default location, or merge
multiple metadata sources.

Production packaging is gated on the maintainer providing a current
`--metadata-source` directory. If the Codex portal changes the metadata format,
the packaging workflow must stop and the package script/test must be updated in
a separate change before publishing.

## Documentation

`README.md` should stay Codex-only. It should describe:

- this fork's purpose
- kept files and directories
- removed platform support
- basic skill workflow
- Codex tool mapping
- testing commands
- local plugin installation or marketplace packaging notes

It should not describe installation for other harnesses.

`AGENTS.md` should remain the local contributor contract for this fork and
continue to prefer Codex tool names.

Use the current local fork's `AGENTS.md` as the source of truth. Do not merge
upstream's multi-platform contributor guidance into it. Add an upstream change
only when it is Codex-specific, compatible with this fork's scope, and does not
reintroduce non-Codex platform workflow.

After restoring `AGENTS.md`, search it for obsolete SDD wording such as
`two-stage review`, `spec reviewer`, `code-quality reviewer`, and
`code-quality-reviewer-prompt.md`. Update any active guidance that contradicts
the new task-reviewer SDD flow.

Use the current local fork's `README.md` as the source of truth. Add targeted
notes for retained v6 Codex packaging, marketplace, SDD, and test changes, but
do not extract broad upstream README prose about multi-harness installation,
commercial/community content, or upstream contribution workflow.

Minimum README updates after the sync:

- state that this is a Codex-only fork
- list the kept repository areas, including `.agents/plugins/marketplace.json`
  and `scripts/package-codex-plugin.sh`
- state that non-Codex platform entrypoints and tests are removed
- mention that SDD now uses task review plus `.superpowers/sdd/` workspace
  artifacts
- document the `--metadata-source PATH` requirement for Codex portal packaging
- list the verification commands from this spec

## Tests And Verification

The implementation should run the focused Codex-only suite:

```bash
cd tests/brainstorm-server && npm test
bash tests/codex/test-sdd-integration-script-behavior.sh
bash tests/codex/test-marketplace-manifest.sh
bash tests/codex/test-package-codex-plugin.sh
```

Before running `tests/brainstorm-server`, use Node.js 18 or newer and run
`npm install` in `tests/brainstorm-server` if `node_modules/` is absent. If a
brainstorm-server test failure reproduces unchanged on a clean checkout of
`d884ae04edebef577e82ff7c4e143debd0bbec99`, treat it as upstream or local
environment drift and escalate instead of rewriting retained fork behavior.

Expected outcomes:

- `npm test` in `tests/brainstorm-server` exits `0`.
- `test-sdd-integration-script-behavior.sh` exits `0` and prints
  `STATUS: PASSED`.
- `test-marketplace-manifest.sh` exits `0`.
- `test-package-codex-plugin.sh` exits `0` and verifies the archive excludes
  source-only and non-Codex paths.

`tests/brainstorm-server/` starts as the upstream v6.1.1 directory already
present on the integration branch. Patch those tests in place only where needed
to fit this fork's pruned repository. If a brainstorm test references a
non-Codex platform path or a deleted root file, rewrite the fixture to use
Codex-only paths. Do not delete a brainstorm behavior test merely because
pruning made its fixture stale. The test package may keep its own `package.json`
and `package-lock.json`; no root `package.json` is allowed. Coverage from other
upstream test directories is imported into `tests/brainstorm-server/` only after
the test audit identifies retained brainstorm behavior that upstream's retained
brainstorm tests do not already cover.

Rewritten brainstorm fixtures must assert the same behavioral property as the
upstream test: authentication, path containment, symlink rejection, dotfile
rejection, owner-only token files, reconnect behavior, idle lifecycle, or safe
shutdown. A fixture rewrite that only changes strings to make the test pass
without preserving the behavioral assertion is not acceptable.

If an upstream brainstorm test only covers a removed platform integration, such
as a removed hook path or removed harness launcher, delete that test with the
removed feature. Do not invent a Codex-shaped equivalent unless the same
security or lifecycle behavior exists in the retained Codex-only companion.

Decision rule for stale brainstorm fixtures:

- If the assertion is about retained server security or lifecycle behavior, keep
  the test and replace deleted repository paths with fixture-owned temporary
  paths under the test's `TEST_ROOT`, or with retained paths under
  `skills/brainstorming/scripts/` when the script itself is under test.
- If the assertion is about retained Codex package version fallback, use
  `.codex-plugin/plugin.json` as the fixture path.
- If the assertion is about a removed hook, removed launcher, or removed
  platform package path, delete the test with the removed feature.
- Do not use `.claude-plugin/`, `hooks/`, `.pi/`, `.opencode/`, `.kimi-plugin/`,
  or other removed-platform paths as substitutes in retained brainstorm tests.

The implementation should also run a static platform-boundary scan:

```bash
rg -in "Claude Code|Claude|Cursor|Gemini|OpenCode|Copilot|Kimi|Antigravity|Pi|Droid|\\.claude|\\.cursor|\\.opencode|\\.kimi|\\.pi" README.md AGENTS.md skills tests
```

Allowed matches:

- references to the local `claude` CLI as an external reviewer
- historical design documents if the implementation intentionally keeps them
- explicit statements that non-Codex platforms were removed

Unexpected matches in active skill instructions, plugin metadata, tests, or
README installation guidance must be removed or rewritten.

Expected scan outcome: no unexpected matches in active README installation
guidance, plugin metadata, skill tool instructions, or tests. The implementation
must list any allowed matches in its final verification notes.

## Migration Steps

1. Choose branch names without overwriting existing work:
   - default `RESTORE_REF`: `backup/codex-only-before-v6-sync`
   - default `INTEGRATION_BRANCH`: `codex/sync-v6-codex-only`
   - if either branch already exists, do not force-update it
   - for a collision, append `-YYYYMMDD-HHMMSS` to create a new branch name and
     use that actual name everywhere this design says `RESTORE_REF` or
     `INTEGRATION_BRANCH`
   - create `RESTORE_REF` from the current local `main`
2. Fetch origin and verify
   `d884ae04edebef577e82ff7c4e143debd0bbec99` exists. If it does not exist,
   stop and ask the user whether to fetch a different remote, update the design
   to a new upstream commit, or abort the sync.
   Capture an upstream snapshot before editing:
   - `git ls-tree -r --name-only d884ae04edebef577e82ff7c4e143debd0bbec99 skills scripts tests .codex-plugin`
   - key section headings from each upstream core `SKILL.md`
   Use this snapshot as implementation-plan context so the merge is based on
   inspected upstream content.
3. Create `INTEGRATION_BRANCH` from
   `d884ae04edebef577e82ff7c4e143debd0bbec99`.
4. Remove non-Codex repository entrypoints and platform tests.
5. Delete upstream `docs/superpowers/specs/` and `docs/superpowers/plans/`,
   then restore those directories from `RESTORE_REF`.
6. Restore `README.md` and `AGENTS.md` from `RESTORE_REF`; update `README.md`
   only where this design requires new Codex v6 packaging or verification notes.
   Search restored `AGENTS.md` for obsolete SDD wording listed in the
   Documentation section and update active guidance that contradicts task
   reviewer SDD.
7. Adapt `.codex-plugin/plugin.json` to combine upstream v6.1.1 metadata with
   this fork's Codex-only description and `hooks: {}`. The final `hooks` value
   must be exactly the empty object; no hook entries are preserved.
8. Merge the five core skill areas:
   - `using-superpowers`
   - `subagent-driven-development`
   - `brainstorming`
   - `writing-plans`
   - `finishing-a-development-branch`
9. Restore the three external review prompt files from `RESTORE_REF` and
   restore their gate instructions into the merged skills.
   Before each restore operation, verify the backup branch exists:
   `git rev-parse --verify "$RESTORE_REF^{commit}"`.
10. Audit the restored external review prompt files against the merged skill
   instructions. Acceptance criteria for this audit:
   - each skill references the correct local prompt file path
   - each prompt's expected packet shape matches the invoking skill text
   - each gate describes the same retry, skip, alternative-path, and waiver
     behavior
   - prompt wording conflicts introduced by the upstream v6 merge are resolved
     without weakening the prompt's review behavior
   Concrete audit procedure:
   - grep each merged `SKILL.md` for its prompt filename
   - compare the packet fields listed in the skill against the prompt's expected
     input description
   - compare the failure-handling paragraph across all three gates for the same
     retry, skip, alternative-path, and waiver semantics
   - run the platform-boundary scan against the prompt files and host skills
11. Audit the upstream test delta, then update Codex, SDD, external-review
   prompt, and brainstorm tests to match the new v6 flow and this fork's
   Codex-only review gates. Split this into separate implementation-plan tasks
   if the audit shows independent test groups.
12. Rewrite Codex portal packaging and tests for the Codex-only artifact set.
    First verify whether the upstream baseline exists with:
    `git show d884ae04edebef577e82ff7c4e143debd0bbec99:scripts/package-codex-plugin.sh`.
    If it exists, rewrite that file. If it does not exist, implement the script
    from the archive-content and `--metadata-source` rules in this spec.
13. Run the platform-boundary scan and remove or rewrite unexpected active
    platform references.
14. Run verification commands and fix any regressions. Steps 10 through 14 are a
    fix-verify loop: if tests expose a mismatch in skill text, prompt
    references, packaging behavior, or repository boundary, update the relevant
    earlier task and rerun the affected checks.
    The loop exits when all verification commands pass. If a failing command
    reveals a conflict between this design and upstream v6.1.1 behavior, stop
    and escalate that design conflict to the user instead of continuing to
    guess.
    Test failures for retained behavior must be fixed by updating the retained
    skill, script, fixture, or test. Tests may be removed only when their
    supporting feature or platform is explicitly removed by this design.
    If the same verification command fails for the same underlying reason after
    two fix attempts, stop and escalate the remaining failure to the user with
    the command, failing output summary, attempted fixes, and the design rule in
    conflict.
15. Compare the final file list against the repository boundary above.
16. Fast-forward or replace local `main` only after the integration branch
    passes all verification commands, the final diff has been reviewed by the
    user, and any `finishing-a-development-branch` external implementation audit
    required by this fork has passed or been explicitly waived.
    For this sync's first audit, use the restored and prompt-audited
    implementation audit prompt on the integration branch. If the user chooses
    to waive this bootstrapping audit, record it as waived, not passed.

## Risks

- Upstream SDD changed the review model significantly. Codex tests that assert
  the old two-reviewer flow must be rewritten instead of kept.
- Upstream `using-superpowers` is intentionally multi-harness. It must be
  Codex-only after integration or it will contradict this fork's scope.
- SDD model names `gpt-5.4` and `gpt-5.5` are Codex proxy aliases. Future Codex
  releases may rename them. They were present in the active Codex
  `spawn_agent` tool metadata during design review, but implementation must
  verify they are still present before preserving the explicit model policy.
  The model rule is static skill guidance based on the active Codex tool
  metadata available to the implementing agent; it is not a separate runtime
  introspection API requirement.
- Upstream Codex packaging may assume files this fork removes. The package
  script and package tests must agree with the final repository boundary.
- The external review gates reference the local `claude` CLI. Documentation
  must clearly frame this as a reviewer backend, not restored Claude Code
  platform support.
- Historical docs may contain non-Codex platform names, but they are retained
  only as project history under `docs/superpowers/` and are excluded from the
  active platform-boundary scan.
- External review prompt files must be audited against their surrounding
  upstream-v6-updated skill instructions. The implementation must preserve each
  prompt's review behavior, update wording that conflicts with the merged skill
  flow, and verify that every skill references the correct local prompt file and
  describes compatible failure handling.

This design intentionally keeps the synchronization as one implementation
project because the repository boundary, skill instructions, Codex manifest, and
tests must agree before the fork is usable. Implementation planning may split
the work into independent tasks, but all tasks share one acceptance boundary:
the final branch must be a coherent Codex-only v6 sync.

## Acceptance Criteria

- The final branch contains upstream v6 SDD, writing-plans, brainstorming
  companion, and Codex metadata improvements.
- The three external review gates remain present and ordered correctly.
- Active plugin entrypoints are Codex-only.
- Active skill tool guidance uses Codex tool names.
- `.codex-plugin/plugin.json` includes `"hooks": {}`.
- Non-Codex platform directories and tests are absent.
- Codex and brainstorm verification commands pass, or any intentionally removed
  tests are removed with their supporting feature.
- A platform-boundary scan has no unexpected active-platform references.
- The exact verification commands in this spec pass with the expected outcomes.
- `scripts/package-codex-plugin.sh` requires external OpenAI metadata in the
  documented `skills/<skill-name>/agents/openai.yaml` shape and fails clearly
  when metadata is incomplete.
- Only `tests/brainstorm-server/` and `tests/codex/` remain under `tests/`;
  retained behavior coverage from other upstream test directories is ported into
  those two directories only when no retained test already asserts the same
  behavioral property with the same inputs or an equivalent Codex-only fixture.
