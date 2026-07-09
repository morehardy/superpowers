---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → External Implementation Audit → Detect environment → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

**Before presenting options, verify tests pass:**

```bash
# Run project's test suite
npm test / cargo test / pytest / go test ./...
```

**If tests fail:**
```
Tests failing (<N> failures). Must fix before completing:

[Show failures]

Cannot proceed with merge/PR until tests pass.
```

Stop. Don't proceed to Step 2.

**If tests pass:** Continue to Step 2.

### Step 2: External Implementation Audit

**Before presenting options, audit the completed implementation with the local `claude` CLI.** This gate runs after local tests pass and before environment detection or the finishing menu.

This audit covers the final repository state against the implementation plan, source spec when available, and latest test evidence. It is a final readiness gate; it does not replace local tests or per-task reviews.

1. **Identify the audit scope.**
   - Use the implementation plan path from the current execution context.
   - Use the source spec path from the plan or session context when it is known.
   - Determine the implementation range with `git rev-parse` or the base/head range already used for code review.
   - If the implementation plan cannot be identified, ask the user for the plan path before invoking `claude`. If the user confirms there was no plan, write `Not identified` for the plan and focus the audit on the available requirements, diff, and test evidence.
2. **Prepare an audit packet** as an ephemeral Markdown file. Use this exact section structure:

   ```markdown
   # External Implementation Audit Packet

   ## Repository Root
   [absolute path]

   ## Git Range
   Base: [sha]
   Head: [sha]

   ## Implementation Plan
   [path or "Not identified"]

   ## Source Spec
   [path or "Not identified"]

   ## Latest Test Evidence
   Command: [command]
   Result: [short passing summary]

   ## Implementation Goal
   [short goal]

   ## Review Focus Areas
   - plan and spec alignment
   - missing requirements
   - unintended scope
   - regression risk
   - test coverage and evidence
   - code quality issues that materially affect readiness
   - repository mutation check
   ```

3. **Resolve the reviewer prompt path.** Resolve `implementation-audit-reviewer-prompt.md` relative to this loaded `SKILL.md` file, store the absolute path in `reviewer_prompt`, and verify it is readable before running `claude`.
4. **Run the audit** with `exec_command`, invoking the local `claude` CLI in non-interactive mode from the repository root. Use this command shape:

   ```bash
   reviewer_prompt="/absolute/path/to/skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md"
   packet="/absolute/path/to/populated-implementation-audit-packet.md"
   repo_root="/absolute/path/to/repo"
   test -r "$reviewer_prompt" || { echo "Reviewer prompt unreadable: $reviewer_prompt" >&2; exit 1; }
   test -s "$packet" || { echo "Audit packet missing or empty: $packet" >&2; exit 1; }
   cd "$repo_root" && claude --bare --print --no-session-persistence --permission-mode plan --output-format text \
     --append-system-prompt "$(cat "$reviewer_prompt")" \
     < "$packet"
   ```

   Do not pass `--tools ""` for this audit. The external reviewer should be able to inspect the repository. The reviewer prompt requires read-only behavior and forbids edits, staging, commits, pushes, branch changes, dependency installation, and generated-artifact rewrites.
5. **Validate the output shape.** Treat the audit as unusable if it is missing a `Status:` line, missing `Critical:`, `Important:`, `Minor:`, `Advisory:`, `Plan Alignment:`, `Test Evidence:`, or `Summary:` section headings, or has unstructured text that prevents identifying findings by severity. Valid status values are `Approved` and `Issues Found`. `Approved` is inconsistent if either `Critical` or `Important` contains an item other than `None`. `Issues Found` is inconsistent if all issue sections are `None` or empty. Extra blank lines or Markdown heading markers do not matter if the required labels and section contents are identifiable.
6. **Handle Critical and Important findings before moving on.**
   - Accept: fix the implementation, rerun relevant tests, and rerun the external implementation audit.
   - Rebut: explain with concrete code, diff, or test evidence why the finding does not require a change.
   - Escalate: ask the user when feedback exposes a product, scope, or plan interpretation decision the main session should not decide alone.
7. **Treat Minor and Advisory findings as non-blocking.** Apply them opportunistically, mention them briefly, or ignore them when they do not affect readiness.
8. **Avoid silent infinite loops.** A rebutted item is considered handled and does not by itself require another external audit. If accepted changes trigger two total external audit reruns for the same implementation and unresolved Critical or Important findings remain, escalate to the user instead of continuing to revise and rerun indefinitely. Failed runs caused by missing `claude`, timeout, non-zero exit, or unusable output do not count toward this rerun limit.
9. **Handle `claude` failures explicitly.** If `claude` is missing, times out, exits non-zero, or returns unusable output, pause and ask the user whether to retry, skip the external implementation audit, or choose another review path. If the user chooses to skip, explicitly record in the conversation that the external implementation audit was waived by the user. A waived audit is waived, not passed.
10. **Check for unexpected mutation if needed.** If the audit output or command behavior suggests the reviewer may have changed files, run `git status --short` and inspect any changes before continuing. Never revert user changes without explicit permission.

**If the audit passes or the user explicitly waives it:** Continue to Step 3.

### Step 3: Detect Environment

**Determine workspace state before presenting options:**

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
```

This determines which menu to show and how cleanup works:

| State | Menu | Cleanup |
|-------|------|---------|
| `GIT_DIR == GIT_COMMON` (normal repo) | Standard 4 options | No worktree to clean up |
| `GIT_DIR != GIT_COMMON`, named branch | Standard 4 options | Provenance-based (see Step 6) |
| `GIT_DIR != GIT_COMMON`, detached HEAD | Reduced 3 options (no merge) | No cleanup (externally managed) |

### Step 4: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 5: Present Options

**Normal repo and named-branch worktree — present exactly these 4 options:**

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Detached HEAD — present exactly these 3 options:**

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)
3. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

### Step 6: Execute Choice

#### Option 1: Merge Locally

```bash
# Get main repo root for CWD safety
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"

# Merge first — verify success before removing anything
git checkout <base-branch>
git pull
git merge <feature-branch>

# Verify tests on merged result
<test command>

# Only after merge succeeds: cleanup worktree (Step 6), then delete branch
```

Then: Cleanup worktree (Step 6), then delete branch:

```bash
git branch -d <feature-branch>
```

#### Option 2: Push and Create PR

```bash
# Push branch
git push -u origin <feature-branch>
```

**Do NOT clean up worktree** — user needs it alive to iterate on PR feedback.

#### Option 3: Keep As-Is

Report: "Keeping branch <name>. Worktree preserved at <path>."

**Don't cleanup worktree.**

#### Option 4: Discard

**Confirm first:**
```
This will permanently delete:
- Branch <name>
- All commits: <commit-list>
- Worktree at <path>

Type 'discard' to confirm.
```

Wait for exact confirmation.

If confirmed:
```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
```

Then: Cleanup worktree (Step 6), then force-delete branch:
```bash
git branch -D <feature-branch>
```

### Step 7: Cleanup Workspace

**Only runs for Options 1 and 4.** Options 2 and 3 always preserve the worktree.

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

**If `GIT_DIR == GIT_COMMON`:** Normal repo, no worktree to clean up. Done.

**If worktree path is under `.worktrees/` or `worktrees/`:** Superpowers created this worktree — we own cleanup.

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git worktree remove "$WORKTREE_PATH"
git worktree prune  # Self-healing: clean up any stale registrations
```

**Otherwise:** The host environment (harness) owns this workspace. Do NOT remove it. If your platform provides a workspace-exit tool, use it. Otherwise, leave the workspace in place.

## Quick Reference

| Option | Merge | Push | Keep Worktree | Cleanup Branch |
|--------|-------|------|---------------|----------------|
| 1. Merge locally | yes | - | - | yes |
| 2. Create PR | - | yes | yes | - |
| 3. Keep as-is | - | - | yes | - |
| 4. Discard | - | - | - | yes (force) |

## Common Mistakes

**Skipping test verification**
- **Problem:** Merge broken code, create failing PR
- **Fix:** Always verify tests before offering options

**Open-ended questions**
- **Problem:** "What should I do next?" is ambiguous
- **Fix:** Present exactly 4 structured options (or 3 for detached HEAD)

**Cleaning up worktree for Option 2**
- **Problem:** Remove worktree user needs for PR iteration
- **Fix:** Only cleanup for Options 1 and 4

**Deleting branch before removing worktree**
- **Problem:** `git branch -d` fails because worktree still references the branch
- **Fix:** Merge first, remove worktree, then delete branch

**Running git worktree remove from inside the worktree**
- **Problem:** Command fails silently when CWD is inside the worktree being removed
- **Fix:** Always `cd` to main repo root before `git worktree remove`

**Cleaning up harness-owned worktrees**
- **Problem:** Removing a worktree the harness created causes phantom state
- **Fix:** Only clean up worktrees under `.worktrees/` or `worktrees/`

**No confirmation for discard**
- **Problem:** Accidentally delete work
- **Fix:** Require typed "discard" confirmation

## Red Flags

**Never:**
- Proceed with failing tests
- Merge without verifying tests on result
- Delete work without confirmation
- Force-push without explicit request
- Remove a worktree before confirming merge success
- Clean up worktrees you didn't create (provenance check)
- Run `git worktree remove` from inside the worktree

**Always:**
- Verify tests before offering options
- Detect environment before presenting menu
- Present exactly 4 options (or 3 for detached HEAD)
- Get typed confirmation for Option 4
- Clean up worktree for Options 1 & 4 only
- `cd` to main repo root before worktree removal
- Run `git worktree prune` after removal
