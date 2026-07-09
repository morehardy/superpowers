# Codex v6 Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Synchronize this Codex-only Superpowers fork with upstream v6.1.1 skill improvements while preserving local external review gates and removing non-Codex platforms.

**Architecture:** Start a clean integration branch from the pinned upstream v6.1.1 commit, then restore the local Codex-only repository boundary and local review gates from the current fork. Treat packaging, platform boundary, SDD helper behavior, worktree policy, and external review gates as tested contracts.

**Tech Stack:** Git, shell scripts, Python 3 for JSON/text rewrites, Node.js 18+ for brainstorm-server tests, Codex agent tools, local `claude` CLI reviewer backend.

---

## Global Constraints

- Upstream commit: `d884ae04edebef577e82ff7c4e143debd0bbec99`.
- Default restore branch: `backup/codex-only-before-v6-sync`; if it exists, append `-YYYYMMDD-HHMMSS`.
- Default integration branch: `codex/sync-v6-codex-only`; if it exists, append `-YYYYMMDD-HHMMSS`.
- Active platform after sync: Codex only.
- Keep only these root script files: `scripts/package-codex-plugin.sh`.
- Keep only these test roots: `tests/brainstorm-server/` and `tests/codex/`.
- Keep only these top-level skills: `brainstorming`, `dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`, `receiving-code-review`, `requesting-code-review`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `using-superpowers`, `verification-before-completion`, `writing-plans`.
- Preserve three local external review gates:
  - `skills/brainstorming/design-challenge-reviewer-prompt.md`
  - `skills/writing-plans/plan-challenge-reviewer-prompt.md`
  - `skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md`
- `.codex-plugin/plugin.json` must include exact empty object `"hooks": {}`.
- `scripts/package-codex-plugin.sh` must require explicit `--metadata-source PATH`; no default metadata source is allowed.
- Lowercase `claude` CLI references are allowed only as an external reviewer backend, not as Claude Code platform support.

## Shared Execution State

Task 1 writes `.superpowers/codex-v6-sync/refs.env`. Before every later task, run:

```bash
set -a
. .superpowers/codex-v6-sync/refs.env
set +a
printf '%s\n' "$RESTORE_REF" "$INTEGRATION_BRANCH" "$UPSTREAM_COMMIT"
```

Expected: prints the actual restore branch, integration branch, and `d884ae04edebef577e82ff7c4e143debd0bbec99`.

### Controller-Only Preflight For Task 6

Before dispatching Task 6 to a subagent, the controller must create `.superpowers/codex-v6-sync/model-alias-check.md`.

- Inline/controller action: inspect the current Codex `spawn_agent` tool metadata.
- If `spawn_agent` exposes a `model` parameter and the active model list includes `gpt-5.4` and `gpt-5.5`, write:

```text
Outcome: A
spawn_agent exposes a model parameter and the available model list includes gpt-5.4 and gpt-5.5.
```

- If `spawn_agent` does not expose a `model` parameter, write:

```text
Outcome: B
spawn_agent does not expose a model parameter.
Record: Codex spawn_agent model selection unavailable
```

- If `spawn_agent` exposes a `model` parameter but either alias is absent, write:

```text
Outcome: C
spawn_agent exposes a model parameter but gpt-5.4 or gpt-5.5 is absent.
Stop and ask the user to choose replacement model names before continuing Task 6.
```

Task 6 workers must not infer or inspect model aliases themselves. They must run:

```bash
test -s .superpowers/codex-v6-sync/model-alias-check.md
rg -n "^Outcome: [AB]$" .superpowers/codex-v6-sync/model-alias-check.md
```

Expected: both commands exit `0`. `Outcome: C` blocks Task 6.

## Task 1: Create Integration Branch And Capture Upstream Snapshot

**Files:**
- Create untracked: `.superpowers/codex-v6-sync/refs.env`
- Create untracked: `.superpowers/codex-v6-sync/upstream-files.txt`
- Create untracked: `.superpowers/codex-v6-sync/upstream-skill-headings.txt`

- [ ] **Step 1: Define refs without overwriting existing branches**

```bash
set -euo pipefail
UPSTREAM_COMMIT="d884ae04edebef577e82ff7c4e143debd0bbec99"
stamp="$(date -u +%Y%m%d-%H%M%S)"
RESTORE_REF="backup/codex-only-before-v6-sync"
INTEGRATION_BRANCH="codex/sync-v6-codex-only"
mkdir -p .superpowers/codex-v6-sync

if git show-ref --verify --quiet "refs/heads/$RESTORE_REF"; then
  RESTORE_REF="${RESTORE_REF}-${stamp}"
fi
if git show-ref --verify --quiet "refs/heads/$INTEGRATION_BRANCH"; then
  INTEGRATION_BRANCH="${INTEGRATION_BRANCH}-${stamp}"
fi

cat > .superpowers/codex-v6-sync/refs.env <<EOF
UPSTREAM_COMMIT=$UPSTREAM_COMMIT
RESTORE_REF=$RESTORE_REF
INTEGRATION_BRANCH=$INTEGRATION_BRANCH
EOF
cat .superpowers/codex-v6-sync/refs.env
```

Expected: prints three shell assignments.

- [ ] **Step 2: Create restore branch and verify upstream**

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
git branch "$RESTORE_REF" main
git fetch origin --prune
git rev-parse --verify "$UPSTREAM_COMMIT^{commit}"
```

Expected: `git rev-parse` prints `d884ae04edebef577e82ff7c4e143debd0bbec99`.

- [ ] **Step 3: Capture upstream snapshot and workflow anchors**

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
git ls-tree -r --name-only "$UPSTREAM_COMMIT" skills scripts tests .codex-plugin \
  > .superpowers/codex-v6-sync/upstream-files.txt

: > .superpowers/codex-v6-sync/upstream-skill-headings.txt
for file in \
  skills/using-superpowers/SKILL.md \
  skills/subagent-driven-development/SKILL.md \
  skills/brainstorming/SKILL.md \
  skills/writing-plans/SKILL.md \
  skills/finishing-a-development-branch/SKILL.md
do
  {
    printf '## %s\n' "$file"
    git show "$UPSTREAM_COMMIT:$file" | rg -n '^#{1,3} ' || true
    printf '\n'
  } >> .superpowers/codex-v6-sync/upstream-skill-headings.txt
done
```

Expected: snapshot file contains `skills/using-superpowers/SKILL.md`; headings file has five `## skills/...` sections.

- [ ] **Step 4: Verify required upstream workflow boundaries**

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
git show "$UPSTREAM_COMMIT:skills/brainstorming/SKILL.md" | rg -i 'self-review|user review'
git show "$UPSTREAM_COMMIT:skills/writing-plans/SKILL.md" | rg -i 'self-review|execution handoff'
git show "$UPSTREAM_COMMIT:skills/finishing-a-development-branch/SKILL.md" | rg -i 'verify tests|detect environment|present options'
```

Expected: all three commands exit `0`. If a regex fails but manual inspection confirms the same workflow boundary exists under different wording, document the exact heading and line in `.superpowers/codex-v6-sync/upstream-skill-headings.txt` and continue; if the boundary is absent, stop and escalate.

- [ ] **Step 5: Create integration branch**

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
git switch -c "$INTEGRATION_BRANCH" "$UPSTREAM_COMMIT"
git status --short --branch
```

Expected: branch line starts with `## codex/sync-v6-codex-only` or the timestamped branch name; working tree is clean.

## Task 2: Restore Codex-Only Repository Boundary

**Files:**
- Restore: `AGENTS.md`, `README.md`, `.gitignore`
- Restore: `docs/superpowers/specs/`, `docs/superpowers/plans/`
- Restore: three external reviewer prompt files
- Remove: non-Codex platform roots, docs, tests, and skills
- Create untracked: `.superpowers/codex-v6-sync/removed-test-audit.md`

- [ ] **Step 1: Remove non-Codex platform roots and files**

```bash
git rm -r --ignore-unmatch \
  .claude-plugin .cursor-plugin .kimi-plugin .opencode .pi .github hooks \
  docs/README.kimi.md docs/README.opencode.md docs/porting-to-a-new-harness.md docs/windows \
  CLAUDE.md GEMINI.md CODE_OF_CONDUCT.md RELEASE-NOTES.md gemini-extension.json \
  package.json .version-bump.json .pre-commit-config.yaml .gitmodules
```

Expected: exits `0`.

- [ ] **Step 2: Audit and remove upstream test roots**

```bash
mkdir -p .superpowers/codex-v6-sync
cat > .superpowers/codex-v6-sync/removed-test-audit.md <<'EOF'
# Removed Upstream Test Audit

- tests/antigravity: removed platform behavior.
- tests/claude-code/test-sdd-workspace.sh: retained SDD helper behavior; port to tests/codex/test-sdd-workspace.sh.
- tests/claude-code/test-worktree-path-policy.sh: retained worktree policy; port to tests/codex/test-worktree-path-policy.sh.
- tests/claude-code/* other files: Claude Code harness behavior; removed.
- tests/codex-plugin-sync: multi-repo package sync; removed in favor of scripts/package-codex-plugin.sh.
- tests/explicit-skill-requests: Claude Code prompt harness; removed.
- tests/hooks: hook wrappers; removed.
- tests/kimi, tests/opencode, tests/pi: removed platform behavior.
- tests/shell-lint: broad upstream harness; replaced by focused bash -n and Codex tests.
EOF

find tests -mindepth 1 -maxdepth 1 ! -name brainstorm-server ! -name codex -print0 \
  | xargs -0 git rm -r --ignore-unmatch
```

Expected: only `tests/brainstorm-server` and `tests/codex` remain under `tests/`.

- [ ] **Step 3: Remove root scripts except Codex package script**

```bash
if [ -d scripts ]; then
  find scripts -mindepth 1 -maxdepth 1 ! -name package-codex-plugin.sh -print0 \
    | xargs -0 git rm -r --ignore-unmatch
fi
```

Expected: `git ls-files scripts` prints only `scripts/package-codex-plugin.sh` or nothing before Task 4 restores it.

- [ ] **Step 4: Remove skill directories outside the retained set**

```bash
keep="$(mktemp)"
cat > "$keep" <<'EOF'
brainstorming
dispatching-parallel-agents
executing-plans
finishing-a-development-branch
receiving-code-review
requesting-code-review
subagent-driven-development
systematic-debugging
test-driven-development
using-git-worktrees
using-superpowers
verification-before-completion
writing-plans
EOF
for dir in skills/*; do
  [ -d "$dir" ] || continue
  name="${dir#skills/}"
  if ! rg -qx "$name" "$keep"; then
    git rm -r --ignore-unmatch "$dir"
  fi
done
rm -f "$keep"
```

Expected: top-level `skills/` contains exactly the 13 retained names.

- [ ] **Step 5: Restore local fork docs, identity, Codex tests, and reviewer prompts**

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
git rm -r --ignore-unmatch docs/superpowers/specs docs/superpowers/plans
git checkout "$RESTORE_REF" -- docs/superpowers/specs docs/superpowers/plans
git checkout "$RESTORE_REF" -- \
  AGENTS.md README.md .gitignore \
  tests/codex/test-sdd-integration-script-behavior.sh \
  tests/codex/test-subagent-driven-development-integration.sh \
  skills/brainstorming/design-challenge-reviewer-prompt.md \
  skills/writing-plans/plan-challenge-reviewer-prompt.md \
  skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md
```

Expected: restored docs include `docs/superpowers/specs/2026-07-09-codex-v6-sync-design.md` and this plan file; all three reviewer prompt files exist.

- [ ] **Step 6: Commit boundary**

```bash
git add -A
git commit -m "chore: restore codex-only repository boundary"
```

Expected: commit succeeds.

## Task 3: Define Codex Boundary, Packaging, SDD Workspace, And Worktree Tests

**Files:**
- Modify: `tests/codex/test-marketplace-manifest.sh`
- Modify: `tests/codex/test-package-codex-plugin.sh`
- Create: `tests/codex/test-platform-boundary.sh`
- Create: `tests/codex/test-sdd-workspace.sh`
- Create: `tests/codex/test-worktree-path-policy.sh`

- [ ] **Step 1: Rewrite marketplace manifest test**

Replace `tests/codex/test-marketplace-manifest.sh` so it loads `.agents/plugins/marketplace.json` with Python and asserts:

```text
manifest["name"] == "superpowers-dev"
len(manifest["plugins"]) == 1
plugin["name"] == "superpowers"
plugin["source"] == {"source": "url", "url": "./"}
plugin["policy"]["installation"] == "AVAILABLE"
plugin["category"] == "Developer Tools"
```

Expected success output: `Codex marketplace manifest looks good`.

- [ ] **Step 2: Create platform boundary test**

Create `tests/codex/test-platform-boundary.sh` with these assertions:

```text
- The removed paths do not exist: .claude-plugin, .cursor-plugin, .kimi-plugin, .opencode, .pi, .github, hooks, CLAUDE.md, GEMINI.md, CODE_OF_CONDUCT.md, RELEASE-NOTES.md, docs/README.kimi.md, docs/README.opencode.md, docs/porting-to-a-new-harness.md, docs/windows, gemini-extension.json, root package.json.
- Top-level skill directories exactly equal the 13 retained names in Global Constraints.
- Top-level test directories exactly equal brainstorm-server and codex.
- Scan README.md, AGENTS.md, skills, and tests, excluding tests/codex/test-platform-boundary.sh, for non-Codex platform names.
- Allow only exact lines containing local external reviewer backend references, explicit removed-platform statements, or prompt filenames for the three reviewer gates.
```

Use a Python allowlist instead of generic words such as `removed` or `non-Codex`; unexpected output must fail with `Unexpected active non-Codex platform reference remains.`

Expected success output: `Codex-only platform boundary looks good`.

- [ ] **Step 3: Create SDD workspace helper test**

Port retained behavior from upstream `tests/claude-code/test-sdd-workspace.sh` into `tests/codex/test-sdd-workspace.sh`. The test must create a temp git repo and assert:

```text
sdd-workspace prints <repo-root>/.superpowers/sdd
.superpowers/sdd/.gitignore contains *
workspace artifacts are invisible to git status
git add -A does not stage workspace artifacts
task-brief writes under .superpowers/sdd
review-package writes under .superpowers/sdd
linked worktree gets a distinct .superpowers/sdd workspace
linked worktree workspace is invisible to git status
```

Expected success output: `STATUS: PASSED`.

- [ ] **Step 4: Create worktree path policy test**

Create `tests/codex/test-worktree-path-policy.sh` to assert:

```text
skills/using-git-worktrees/SKILL.md does not mention ~/.config/superpowers/worktrees, "global legacy", or "Global path".
skills/using-git-worktrees/SKILL.md contains: default to `.worktrees/` at the project root
skills/finishing-a-development-branch/SKILL.md does not mention ~/.config/superpowers/worktrees
skills/finishing-a-development-branch/SKILL.md contains: `.worktrees/` or `worktrees/`
```

Do not run this test in Task 5; run it after Task 9 and in final verification, because it depends on both `using-git-worktrees` and `finishing-a-development-branch`.

- [ ] **Step 5: Rewrite Codex package test**

Replace `tests/codex/test-package-codex-plugin.sh` so it:

```text
- Creates a temp metadata source with skills/<skill>/agents/openai.yaml for every retained skill.
- Runs scripts/package-codex-plugin.sh --allow-dirty --metadata-source "$metadata_source" --output "$archive".
- Unzips archive and asserts it contains .codex-plugin/plugin.json, README.md, LICENSE, assets, and skills.
- Fails if archive contains tests, docs, hooks, root scripts, package.json, or non-Codex plugin directories.
- Asserts packaged manifest has name superpowers, version 6.1.1, skills ./skills/, and hooks {}.
- Asserts every packaged skill has agents/openai.yaml.
- Creates incomplete metadata and asserts the package script fails with "metadata source is incomplete" or "Missing OpenAI agent metadata".
```

Expected success output: `Codex package script looks good`.

- [ ] **Step 6: Run defining tests**

```bash
bash tests/codex/test-marketplace-manifest.sh
bash tests/codex/test-platform-boundary.sh
bash tests/codex/test-sdd-workspace.sh
bash tests/codex/test-package-codex-plugin.sh
```

Expected: at least one command may fail before implementation. `test-platform-boundary.sh` may already pass after Task 2 pruning. If all commands pass, create `.superpowers/codex-v6-sync/preimplementation-test-pass-audit.md` explaining which existing file satisfies each assertion and whether that file survives later tasks.

- [ ] **Step 7: Commit tests**

```bash
chmod +x tests/codex/test-marketplace-manifest.sh tests/codex/test-platform-boundary.sh tests/codex/test-sdd-workspace.sh tests/codex/test-worktree-path-policy.sh tests/codex/test-package-codex-plugin.sh
git add tests/codex/test-marketplace-manifest.sh tests/codex/test-platform-boundary.sh tests/codex/test-sdd-workspace.sh tests/codex/test-worktree-path-policy.sh tests/codex/test-package-codex-plugin.sh
git commit -m "test: define codex-only sync contracts"
```

Expected: commit succeeds.

## Task 4: Implement Codex Manifest, Marketplace, And Package Script

**Files:**
- Modify: `.codex-plugin/plugin.json`
- Modify: `.agents/plugins/marketplace.json`
- Modify: `scripts/package-codex-plugin.sh`

- [ ] **Step 1: Update Codex plugin manifest**

```bash
python3 - <<'PY'
import json
from pathlib import Path

path = Path(".codex-plugin/plugin.json")
data = json.loads(path.read_text(encoding="utf-8"))
data["name"] = "superpowers"
data["version"] = "6.1.1"
data["description"] = "Codex-only Superpowers fork: planning, TDD, debugging, review, and delivery workflows."
data["skills"] = "./skills/"
data["hooks"] = {}
interface = data.setdefault("interface", {})
interface["displayName"] = "Superpowers"
interface["shortDescription"] = "Codex-only planning, TDD, debugging, review, and delivery workflows"
interface["category"] = "Developer Tools"
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
```

Expected: manifest keeps upstream author/repository metadata while setting exact `"hooks": {}`.

- [ ] **Step 2: Set marketplace manifest**

Edit `.agents/plugins/marketplace.json` to exactly:

```json
{
  "name": "superpowers-dev",
  "interface": {
    "displayName": "Superpowers Dev"
  },
  "plugins": [
    {
      "name": "superpowers",
      "source": {
        "source": "url",
        "url": "./"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    }
  ]
}
```

- [ ] **Step 3: Implement package script contract**

Restore upstream script when present:

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
if git cat-file -e "$UPSTREAM_COMMIT:scripts/package-codex-plugin.sh" 2>/dev/null; then
  git checkout "$UPSTREAM_COMMIT" -- scripts/package-codex-plugin.sh
else
  mkdir -p scripts
  printf '#!/usr/bin/env bash\nset -euo pipefail\n' > scripts/package-codex-plugin.sh
fi
chmod +x scripts/package-codex-plugin.sh
```

Then edit `scripts/package-codex-plugin.sh` so it:

```text
- Supports --output PATH, --metadata-source PATH, --ref REF, --allow-dirty, --keep-stage, -h, --help.
- Requires --metadata-source PATH; fails with "Missing required --metadata-source PATH" when omitted.
- Accepts only a metadata directory; no default metadata lookup and no generated metadata.
- Archives only .codex-plugin, LICENSE, README.md, assets, and skills from the selected git ref.
- Reads version from staged .codex-plugin/plugin.json using python3.
- Copies metadata from PATH/skills/<skill-name>/agents/openai.yaml into every staged skill.
- Fails with "Missing OpenAI agent metadata for skill: <skill>" and "metadata source is incomplete" when any retained skill lacks metadata.
- Writes a deterministic zip archive.
- Rejects archive paths matching docs, tests, hooks, scripts, package.json, AGENTS.md, CODE_OF_CONDUCT.md, non-Codex plugin dirs, or other source-only paths.
- Prints Archive, Version, Entries, Skills, and SHA-256.
```

- [ ] **Step 4: Verify and commit packaging**

```bash
bash -n scripts/package-codex-plugin.sh
bash tests/codex/test-marketplace-manifest.sh
bash tests/codex/test-package-codex-plugin.sh
git add .codex-plugin/plugin.json .agents/plugins/marketplace.json scripts/package-codex-plugin.sh
git commit -m "feat: add codex-only portal packaging"
```

Expected: both tests pass and commit succeeds.

## Task 5: Merge `using-superpowers` And Non-Core Codex Tool Mapping

**Files:**
- Modify: `skills/using-superpowers/SKILL.md`
- Modify: `skills/using-superpowers/references/codex-tools.md`
- Modify: retained non-core skill `SKILL.md` files if active instructions use old tool names
- Remove: non-Codex `skills/using-superpowers/references/*`

- [ ] **Step 1: Remove non-Codex tool references**

```bash
git rm --ignore-unmatch \
  skills/using-superpowers/references/antigravity-tools.md \
  skills/using-superpowers/references/copilot-tools.md \
  skills/using-superpowers/references/gemini-tools.md \
  skills/using-superpowers/references/pi-tools.md
```

Expected: command exits `0`.

- [ ] **Step 2: Replace `using-superpowers/SKILL.md`**

Use upstream concise structure as base, then replace the full file content with Codex-only content containing:

```text
- frontmatter name/description from upstream v6
- <SUBAGENT-STOP>
- <EXTREMELY-IMPORTANT>
- ## The Rule
- ## Skill Priority
- ## Red Flags
- ## Platform Adaptation
  - references/codex-tools.md
  - update_plan
  - spawn_agent
  - wait_agent
  - close_agent
  - exec_command
  - apply_patch
  - no other platform mapping files
- ## User Instructions
```

Implementation instruction: use `apply_patch` or the editor to replace the entire file. Do not leave the old Graphviz flowchart or multi-platform adaptation.

- [ ] **Step 3: Restore Codex tool mapping reference**

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
git checkout "$RESTORE_REF" -- skills/using-superpowers/references/codex-tools.md
rg -n "close_agent" skills/using-superpowers/references/codex-tools.md || \
  printf '\n| finished spawned agent | `close_agent` |\n' >> skills/using-superpowers/references/codex-tools.md
```

Expected: `close_agent` appears in the Codex tool mapping.

- [ ] **Step 4: Clean active instructions in non-core retained skills**

Scan:

```bash
rg -n "Task tool|TodoWrite|Bash|Read, Write, Edit|Claude Code|Cursor|Gemini|OpenCode|Copilot|Kimi|Antigravity|Pi|Droid|\\.claude|\\.cursor|\\.opencode|\\.kimi|\\.pi" \
  skills/dispatching-parallel-agents \
  skills/executing-plans \
  skills/receiving-code-review \
  skills/requesting-code-review \
  skills/systematic-debugging \
  skills/test-driven-development \
  skills/using-git-worktrees \
  skills/verification-before-completion || true
```

Decision rule: replace tool names only in paragraphs marked as active instructions, constraints, required tool usage, or workflow steps. Do not rewrite code-fenced historical examples or files under `docs/superpowers/`.

Required replacements:

```text
TodoWrite -> update_plan
Task tool / dispatch a subagent -> spawn_agent
collect task result -> wait_agent
close completed subagent -> close_agent
Bash -> exec_command
manual file edits -> apply_patch
```

Then run the same `rg` scan and fail if matches remain in active skill instructions.

- [ ] **Step 5: Verify and commit**

```bash
rg -n "Graphviz|digraph skill_flow" skills/using-superpowers/SKILL.md && exit 1 || true
rg -n "update_plan|spawn_agent|wait_agent|close_agent|exec_command|apply_patch" skills/using-superpowers/SKILL.md
bash tests/codex/test-platform-boundary.sh
git add skills/using-superpowers skills/dispatching-parallel-agents skills/executing-plans skills/receiving-code-review skills/requesting-code-review skills/systematic-debugging skills/test-driven-development skills/using-git-worktrees skills/verification-before-completion tests/codex/test-platform-boundary.sh
git commit -m "docs: align skills with codex-only tool mapping"
```

Expected: boundary test passes and commit succeeds. Do not run `test-worktree-path-policy.sh` here; it is deferred until Task 9 and final verification because it also depends on the finishing skill.

## Task 6: Merge SDD v6 Task-Review Flow

**Files:**
- Modify: `skills/subagent-driven-development/`
- Modify: `tests/codex/test-sdd-integration-script-behavior.sh`
- Modify: `tests/codex/test-subagent-driven-development-integration.sh`
- Verify: `tests/codex/test-sdd-workspace.sh`

- [ ] **Step 1: Verify model preflight exists**

```bash
test -s .superpowers/codex-v6-sync/model-alias-check.md
rg -n "^Outcome: [AB]$" .superpowers/codex-v6-sync/model-alias-check.md
```

Expected: both commands exit `0`. If missing, return to the controller-only preflight before starting this task.

- [ ] **Step 2: Restore upstream SDD directory and remove obsolete prompt files**

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
rm -rf skills/subagent-driven-development
git checkout "$UPSTREAM_COMMIT" -- skills/subagent-driven-development
git rm --ignore-unmatch \
  skills/subagent-driven-development/spec-reviewer-prompt.md \
  skills/subagent-driven-development/code-quality-reviewer-prompt.md
chmod +x skills/subagent-driven-development/scripts/task-brief \
  skills/subagent-driven-development/scripts/review-package \
  skills/subagent-driven-development/scripts/sdd-workspace
```

Expected: `task-reviewer-prompt.md` and `scripts/sdd-workspace` exist; old two-reviewer files do not exist.

- [ ] **Step 3: Apply Codex tool and model wording**

Edit `skills/subagent-driven-development/SKILL.md` and `skills/subagent-driven-development/implementer-prompt.md` so active controller and implementer instructions use:

```text
spawn_agent
wait_agent
close_agent
update_plan
exec_command
apply_patch
gpt-5.4 for implementer/fixer when model selection is available
gpt-5.5 for task reviewer/final reviewer when model selection is available
Codex spawn_agent model selection unavailable when model-alias-check.md has Outcome: B
pause and ask user when model-alias-check.md has Outcome: C
```

Decision rule: rewrite current workflow examples and active instructions; do not preserve old `Task`, `TodoWrite`, or two-reviewer prompt names in active text.

Verification:

```bash
unexpected_sdd_tools="$(
  rg -n "Task tool|TodoWrite|Read, Write, Edit|Claude Code|Cursor|Gemini|OpenCode|Copilot|Kimi|Antigravity|Pi|Droid|spec-reviewer-prompt.md|code-quality-reviewer-prompt.md" \
    skills/subagent-driven-development tests/codex/test-sdd-integration-script-behavior.sh tests/codex/test-subagent-driven-development-integration.sh || true
)"
test -z "$unexpected_sdd_tools" || { printf '%s\n' "$unexpected_sdd_tools"; exit 1; }
rg -n "spawn_agent|wait_agent|close_agent|update_plan|exec_command|apply_patch|task-reviewer-prompt.md|\\.superpowers/sdd" skills/subagent-driven-development
```

Expected: old active tool/prompt references are absent; new Codex and SDD workspace strings appear.

- [ ] **Step 4: Update SDD tests and verify**

Update Codex SDD tests so fake transcript checks require:

```text
subagent-driven-development
task reviewer
.superpowers/sdd
tests pass: yes
```

Forbidden strings:

```text
spec-reviewer-prompt.md
code-quality-reviewer-prompt.md
```

Run:

```bash
bash -n skills/subagent-driven-development/scripts/task-brief
bash -n skills/subagent-driven-development/scripts/review-package
bash -n skills/subagent-driven-development/scripts/sdd-workspace
bash tests/codex/test-sdd-integration-script-behavior.sh
bash tests/codex/test-sdd-workspace.sh
bash tests/codex/test-subagent-driven-development-integration.sh
```

Expected: syntax checks pass; SDD wrapper and workspace tests print `STATUS: PASSED`; the opt-in real integration test exits `0` by skipping unless `RUN_CODEX_INTEGRATION=1`.

- [ ] **Step 5: Commit SDD merge**

```bash
git add skills/subagent-driven-development tests/codex/test-sdd-integration-script-behavior.sh tests/codex/test-subagent-driven-development-integration.sh tests/codex/test-sdd-workspace.sh
git commit -m "feat: adopt codex sdd task-review flow"
```

Expected: commit succeeds.

## Task 7: Merge Brainstorming v6 Companion And External Design Challenge

**Files:**
- Modify: `skills/brainstorming/SKILL.md`
- Modify: `skills/brainstorming/visual-companion.md`
- Modify: `skills/brainstorming/scripts/`
- Restore: `skills/brainstorming/design-challenge-reviewer-prompt.md`
- Modify: `tests/brainstorm-server/branding.test.js`

- [ ] **Step 1: Restore upstream brainstorming and local prompt**

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
rm -rf skills/brainstorming
git checkout "$UPSTREAM_COMMIT" -- skills/brainstorming
git checkout "$RESTORE_REF" -- skills/brainstorming/design-challenge-reviewer-prompt.md
```

Expected: upstream scripts exist and local prompt exists.

- [ ] **Step 2: Insert External Design Challenge**

Edit `skills/brainstorming/SKILL.md` so workflow order is:

```text
Spec self-review
External design challenge
User reviews written spec
Transition to implementation
```

Insert the External Design Challenge section immediately after `**Spec Self-Review:**` and before `**User Review Gate:**`. It must name:

```text
skills/brainstorming/design-challenge-reviewer-prompt.md
claude --bare --print --no-session-persistence --permission-mode plan --tools "" --output-format text
retry, skip, alternative review path
waived, not passed
```

If the Graphviz flow uses upstream labels, replace the graph block with one that routes `Spec self-review` to `External design challenge`, accepted changes back to self-review, and approved/rebutted output to user review.

- [ ] **Step 3: Make visual companion Codex skill-launched**

In `skills/brainstorming/visual-companion.md`, replace platform-specific launch instructions with:

```text
The visual companion is skill-launched, not hook-launched. Start it only after the just-in-time offer is accepted, using exec_command:
skills/brainstorming/scripts/start-server.sh --project-dir /path/to/project --open
Do not add SessionStart hooks, plugin auto-launchers, or other platform launchers for this fork.
```

Run:

```bash
rg -in "SessionStart|hook-launched|plugin auto-launch|Claude Code:|Copilot CLI:|Other environments:" skills/brainstorming/SKILL.md skills/brainstorming/visual-companion.md && exit 1 || true
```

Expected: no matches. Lowercase `claude` references are allowed only in the external reviewer gate.

- [ ] **Step 4: Patch brainstorm test fixture**

Patch `tests/brainstorm-server/branding.test.js` so `PACKAGE_VERSION` reads from `.codex-plugin/plugin.json` instead of root `package.json`. Preserve the same rendered version assertion.

If a direct string replacement fails, manually locate the `PACKAGE_VERSION` declaration and change only that declaration.

- [ ] **Step 5: Install dependencies, test, and commit**

```bash
cd tests/brainstorm-server
if [ ! -d node_modules ]; then npm install; fi
npm test
cd ../..
git add skills/brainstorming tests/brainstorm-server
git commit -m "feat: adopt secure codex brainstorming companion"
```

Expected: `npm test` exits `0`; commit succeeds.

## Task 8: Merge Writing-Plans v6 Structure And External Plan Challenge

**Files:**
- Modify: `skills/writing-plans/SKILL.md`
- Restore: `skills/writing-plans/plan-challenge-reviewer-prompt.md`

- [ ] **Step 1: Restore upstream writing-plans and local prompt**

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
git checkout "$UPSTREAM_COMMIT" -- skills/writing-plans
git checkout "$RESTORE_REF" -- skills/writing-plans/plan-challenge-reviewer-prompt.md
```

Expected: both files exist.

- [ ] **Step 2: Insert local External Plan Challenge**

Pre-check:

```bash
rg -n "^## Self-Review|^## Execution Handoff" skills/writing-plans/SKILL.md
git show "$RESTORE_REF:skills/writing-plans/SKILL.md" | rg -n "^## External Plan Challenge"
```

Expected: all anchors print. If an anchor is renamed but the same boundary exists, manually insert the section at that boundary and document the heading in the commit message.

Insert the `## External Plan Challenge` section from `RESTORE_REF:skills/writing-plans/SKILL.md` after self-review and before execution handoff. Keep upstream v6 sections:

```text
Task Right-Sizing
Global Constraints
Plan Document Header
Task Structure with Interfaces
Self-Review
External Plan Challenge
Execution Handoff
```

- [ ] **Step 3: Verify and commit**

```bash
rg -n "Task Right-Sizing|Global Constraints|Interfaces|External Plan Challenge|plan-challenge-reviewer-prompt.md|waived, not passed" skills/writing-plans/SKILL.md
git add skills/writing-plans
git commit -m "feat: merge codex writing-plans challenge flow"
```

Expected: required strings print; commit succeeds.

## Task 9: Merge Finishing Safety And External Implementation Audit

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md`
- Restore: `skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md`
- Verify: `tests/codex/test-worktree-path-policy.sh`

- [ ] **Step 1: Restore upstream finishing and local audit prompt**

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
git checkout "$UPSTREAM_COMMIT" -- skills/finishing-a-development-branch/SKILL.md
git checkout "$RESTORE_REF" -- skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md
```

Expected: both files exist.

- [ ] **Step 2: Insert local External Implementation Audit**

Pre-check:

```bash
rg -n "Verify Tests|Detect Environment|Present Options|Cleanup Workspace|\\.worktrees|worktrees" skills/finishing-a-development-branch/SKILL.md
git show "$RESTORE_REF:skills/finishing-a-development-branch/SKILL.md" | rg -n "External Implementation Audit"
```

Expected: anchors print. If wording differs but the same boundary exists, manually insert the audit section after local test verification and before environment detection.

Final active order:

```text
Verify tests
External Implementation Audit
Detect environment
Determine base branch
Present options
Execute choice
Cleanup workspace
```

The audit section must name:

```text
skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md
Repository Root
Git Range
Implementation Plan
Source Spec
Latest Test Evidence
Implementation Goal
retry, skip, alternative review path
waived, not passed
```

- [ ] **Step 3: Verify finishing safety and worktree policy**

```bash
if rg -n "gh pr create|github.com" skills/finishing-a-development-branch/SKILL.md; then
  echo "hardcoded forge flow remains" >&2
  exit 1
fi
rg -n "External Implementation Audit|implementation-audit-reviewer-prompt.md|Detect Environment|\\.worktrees|worktrees" skills/finishing-a-development-branch/SKILL.md
bash tests/codex/test-worktree-path-policy.sh
```

Expected: no hardcoded forge flow; required strings print; worktree path policy test prints `STATUS: PASSED`.

- [ ] **Step 4: Commit finishing merge**

```bash
git add skills/finishing-a-development-branch tests/codex/test-worktree-path-policy.sh
git commit -m "feat: merge codex finishing audit flow"
```

Expected: commit succeeds.

## Task 10: Audit External Prompts And Update Docs

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Inspect/modify: three reviewer prompt files and host skills

- [ ] **Step 1: Audit prompt references and packet fields**

```bash
rg -n "design-challenge-reviewer-prompt.md" skills/brainstorming/SKILL.md
rg -n "plan-challenge-reviewer-prompt.md" skills/writing-plans/SKILL.md
rg -n "implementation-audit-reviewer-prompt.md" skills/finishing-a-development-branch/SKILL.md
rg -n "Spec File Path|Current Spec Content|User-Confirmed|Approaches|Design Success Criteria|Review Focus Areas" skills/brainstorming/SKILL.md skills/brainstorming/design-challenge-reviewer-prompt.md
rg -n "Plan File Path|Current Plan Content|Source Spec|Execution Assumption|Review Focus Areas" skills/writing-plans/SKILL.md skills/writing-plans/plan-challenge-reviewer-prompt.md
rg -n "Repository Root|Git Range|Implementation Plan|Latest Test Evidence|Implementation Goal|Review Focus Areas" skills/finishing-a-development-branch/SKILL.md skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md
```

Expected: each command prints matching lines from both host skill and prompt where applicable. Fix wording conflicts without weakening reviewer behavior.

- [ ] **Step 2: Audit failure handling language**

```bash
rg -n "retry|skip|alternative|waived|not passed|unusable output|times out|exits non-zero" \
  skills/brainstorming/SKILL.md skills/brainstorming/design-challenge-reviewer-prompt.md \
  skills/writing-plans/SKILL.md skills/writing-plans/plan-challenge-reviewer-prompt.md \
  skills/finishing-a-development-branch/SKILL.md skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md
```

Expected: all three gates and prompts have compatible failure/waiver semantics.

- [ ] **Step 3: Update README**

Ensure `README.md` includes:

```text
Codex-only fork
.agents/plugins/marketplace.json
scripts/package-codex-plugin.sh
non-Codex platform entrypoints and tests are removed
SDD task review
.superpowers/sdd
--metadata-source PATH
cd tests/brainstorm-server && npm test
bash tests/codex/test-platform-boundary.sh
bash tests/codex/test-sdd-integration-script-behavior.sh
bash tests/codex/test-sdd-workspace.sh
bash tests/codex/test-worktree-path-policy.sh
bash tests/codex/test-marketplace-manifest.sh
bash tests/codex/test-package-codex-plugin.sh
```

Also state that lowercase `claude` CLI references are an external reviewer backend, not Claude Code platform support.

- [ ] **Step 4: Update AGENTS SDD wording deterministically**

```bash
python3 - <<'PY'
from pathlib import Path

path = Path("AGENTS.md")
text = path.read_text(encoding="utf-8")
sentence = "- SDD uses one task reviewer that returns both spec-compliance and task-quality verdicts, plus a final whole-branch review."
old_markers = [
    "two-stage review",
    "spec reviewer",
    "code-quality reviewer",
    "code-quality-reviewer-prompt.md",
    "spec-reviewer-prompt.md",
]
lines = [line for line in text.splitlines() if not any(marker in line for marker in old_markers)]
text = "\n".join(lines) + "\n"
if sentence not in text:
    anchor = "## Working Rules\n"
    if anchor not in text:
        raise SystemExit("AGENTS.md is missing ## Working Rules")
    text = text.replace(anchor, anchor + "\n" + sentence + "\n", 1)
path.write_text(text, encoding="utf-8")
PY
```

Expected: old two-reviewer wording is absent and the new SDD sentence exists.

- [ ] **Step 5: Commit docs and prompt audit**

```bash
git add README.md AGENTS.md skills/brainstorming skills/writing-plans skills/finishing-a-development-branch
git commit -m "docs: document codex v6 sync workflow"
```

Expected: commit succeeds.

## Task 11: Final Verification And User Review Gate

**Files:**
- Verify: whole repository

- [ ] **Step 1: Run complete Codex test suite**

```bash
bash tests/codex/test-platform-boundary.sh
bash tests/codex/test-sdd-integration-script-behavior.sh
bash tests/codex/test-sdd-workspace.sh
bash tests/codex/test-worktree-path-policy.sh
bash tests/codex/test-marketplace-manifest.sh
bash tests/codex/test-package-codex-plugin.sh
bash tests/codex/test-subagent-driven-development-integration.sh
```

Expected:

```text
test-platform-boundary.sh exits 0
test-sdd-integration-script-behavior.sh prints STATUS: PASSED
test-sdd-workspace.sh prints STATUS: PASSED
test-worktree-path-policy.sh prints STATUS: PASSED
test-marketplace-manifest.sh exits 0
test-package-codex-plugin.sh exits 0
test-subagent-driven-development-integration.sh exits 0 by skipping unless RUN_CODEX_INTEGRATION=1
```

- [ ] **Step 2: Run brainstorm tests**

```bash
cd tests/brainstorm-server
if [ ! -d node_modules ]; then npm install; fi
npm test
cd ../..
```

Expected: `npm test` exits `0`.

- [ ] **Step 3: Verify final tracked file boundary**

```bash
unexpected_tracked="$(git ls-files | rg -v '^(\.agents/plugins/marketplace\.json|\.codex-plugin/plugin\.json|AGENTS\.md|README\.md|LICENSE|\.gitignore|assets/.*|docs/superpowers/(specs|plans)/.*|skills/.*|tests/(brainstorm-server|codex)/.*|scripts/package-codex-plugin\.sh)$' || true)"
if [ -n "$unexpected_tracked" ]; then
  printf '%s\n' "$unexpected_tracked" >&2
  echo "tracked path outside Codex-only boundary" >&2
  exit 1
fi

if git ls-files | rg '^(\.claude-plugin|\.cursor-plugin|\.kimi-plugin|\.opencode|\.pi|\.github|hooks|docs/windows|tests/(antigravity|claude-code|kimi|opencode|pi|hooks|shell-lint|skill-triggering|subagent-driven-dev|explicit-skill-requests)|skills/writing-skills|package\.json|CLAUDE\.md|GEMINI\.md|CODE_OF_CONDUCT\.md|RELEASE-NOTES\.md|gemini-extension\.json)'; then
  echo "unexpected tracked path remains" >&2
  exit 1
fi
```

Expected: both checks print nothing and exit `0`.

- [ ] **Step 4: Inspect final diff**

```bash
set -a; . .superpowers/codex-v6-sync/refs.env; set +a
git log --oneline "$RESTORE_REF"..HEAD
git diff --stat "$RESTORE_REF"..HEAD
git status --short --branch
```

Expected: log shows task commits, diff stat contains only Codex v6 sync changes and Codex-only pruning, working tree is clean on `INTEGRATION_BRANCH`. Any surprising file outside the repository boundary blocks review.

- [ ] **Step 5: Stop for user review and finishing audit**

Do not fast-forward or replace local `main`. Present the final diff summary to the user. The branch can only replace local `main` after:

```text
- user reviews the final diff
- all verification commands pass
- finishing-a-development-branch external implementation audit passes or the user explicitly waives it
```

Expected: sync work is ready for user review, not merged.
