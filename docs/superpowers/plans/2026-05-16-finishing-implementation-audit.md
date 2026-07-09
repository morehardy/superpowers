# Finishing Implementation Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `claude` CLI external implementation-audit gate to `finishing-a-development-branch` after local tests pass and before finishing options are shown.

**Architecture:** This is a prose-only skill workflow change. `skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md` owns the external reviewer policy, and `skills/finishing-a-development-branch/SKILL.md` owns when the main session invokes the audit and how it handles audit results. The gate sits in the shared finishing workflow so subagent-driven and inline execution both pass through the same final audit.

**Tech Stack:** Markdown skill files, shell verification with `rg`, existing Node-based brainstorm-server tests, existing Codex shell integration-script checks, optional local `claude` CLI dry-run verification.

---

## File Structure

- `skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md`
  - New prompt template for the local `claude` CLI implementation auditor.
  - Defines read-only repository inspection rules, review focus areas, output format, and severity calibration.
  - Allows the external reviewer to inspect the repository, unlike the plan challenge prompt which disables tools.
- `skills/finishing-a-development-branch/SKILL.md`
  - Existing finishing workflow documentation.
  - Add an `External Implementation Audit` step after test verification and before environment detection.
  - Update step numbering, core principle, common mistakes, and red flags so completion options are only shown after tests pass and the audit passes or is explicitly waived by the user.
- `tests/brainstorm-server/*`
  - No source changes.
  - Run the existing npm test suite as regression coverage for adjacent workflow tooling.
- `tests/codex/test-sdd-integration-script-behavior.sh`
  - No source changes.
  - Run the existing shell test to make sure Codex integration-script behavior still passes.
- `tests/codex/test-subagent-driven-development-integration.sh`
  - No source changes.
  - Run without `RUN_CODEX_INTEGRATION=1`; expected result is a safe skip unless explicitly enabled.

## Template Markers

The bracketed values inside the `External Implementation Audit Packet` patch are literal documentation template markers that must be copied into `skills/finishing-a-development-branch/SKILL.md`. They are not unresolved implementation-plan details.

## Patch Format

Patch blocks in this plan are for Codex `apply_patch`, not `git apply` or POSIX `patch`. If an `apply_patch` hunk fails because the target file changed, inspect the current file with `nl -ba`, then use `apply_patch` to make the equivalent focused edit against the current text. Do not use `sed -i`, shell redirection, or broad rewrite commands for manual file edits.

## Implementation Risks

- The `finishing-a-development-branch` step renumbering touches several cross-references; verification must inspect stale step references after the patch.
- The local `claude` CLI command shape can vary by installed version; verify available flags before editing the finishing workflow. Do not pin a model in the committed skill command unless model pinning is adopted for the repository's external challenge gates consistently.
- The external implementation audit intentionally allows repository inspection, so the reviewer prompt must strongly require read-only behavior and the finishing workflow must check for unexpected mutation if needed.

---

### Task 1: Add Implementation Audit Reviewer Prompt

**Files:**
- Create: `skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md`

- [ ] **Step 1: Verify the prompt file is not already present**

Run:

```bash
test ! -e skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md
```

Expected: command exits 0 with no output. If it exits 1, inspect the existing file and reconcile it with the approved spec before continuing.

- [ ] **Step 2: Run the pre-change prompt check**

Run:

```bash
rg -n -F '# Implementation Audit Reviewer Prompt Template' skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md
```

Expected: command exits non-zero because the prompt file does not exist yet.

- [ ] **Step 3: Create the prompt template**

Use `apply_patch` with this patch:

```diff
*** Begin Patch
*** Add File: skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md
+# Implementation Audit Reviewer Prompt Template
+
+Use this template when running the local `claude` CLI to audit a completed
+implementation before finishing options are shown.
+
+**Purpose:** Challenge the final repository state against the approved
+implementation plan, source spec, and latest test evidence. Look for defects
+that would make the work unsafe to merge, misleading to present as complete, or
+materially misaligned with the plan.
+
+**Run after:** The main session has implemented the plan and the project's local
+test verification has passed.
+
+**Run with:** The local `claude` CLI in non-interactive mode from the repository
+root. This audit may inspect the repository.
+
+## Review Packet
+
+Expect a Markdown packet with these sections:
+
+- Repository root
+- Git range
+- Implementation plan
+- Source spec
+- Latest test evidence
+- Implementation goal
+- Review focus areas
+
+The packet identifies the review scope. You may inspect files, diffs, and git
+metadata inside the repository to verify the implementation. Do not rely only on
+the main session's summary.
+
+## Read-Only Rules
+
+You are an external implementation auditor, not an implementer. Do not edit
+files, run mutating commands, stage files, commit, push, change branches, install
+dependencies, or rewrite generated artifacts. Avoid commands that are expected
+to modify the working tree. If you notice existing uncommitted changes, report
+whether they are inside the requested git range or look unrelated.
+
+Prefer read-only inspection commands such as:
+
+- `git status --short`
+- `git diff --stat <base>..<head>`
+- `git diff <base>..<head>`
+- `git show --stat <head>`
+- `rg`
+- `sed`
+- `ls`
+
+Do not claim tests pass from your own run unless you actually ran the exact
+command and read the output. If you do not run tests, evaluate the provided test
+evidence and inspect whether the changed tests plausibly cover the behavior.
+
+## Reviewer Role
+
+Stress-test the implementation. Do not rewrite it and do not bikeshed wording.
+Flag only issues that materially affect readiness.
+
+Review focus areas:
+
+| Category | What to Look For |
+| --- | --- |
+| Plan and spec alignment | The final diff implements the approved plan and source spec without skipping required behavior |
+| Missing requirements | Required files, workflow rules, failure paths, or verification steps absent from the implementation |
+| Unintended scope | Extra features, broad refactors, or platform entrypoints outside the approved Codex-only scope |
+| Regression risk | Changes that weaken existing finishing behavior, merge safety, cleanup rules, or user choice handling |
+| Test coverage and evidence | Verification commands and tests cover the changed workflow text and prompt content |
+| Code and prose quality | Skill text is clear, actionable, internally consistent, and uses concrete Codex tool guidance |
+| Repository mutation check | Generated files, lockfiles, metadata, or unrelated files changed unexpectedly |
+
+## Severity Calibration
+
+Critical means the implementation is unsafe, materially wrong, or likely to
+break the finishing workflow.
+
+Important means the implementation should not proceed to finishing without a
+fix or explicit technical rebuttal.
+
+Minor means the concern is useful but does not block finishing.
+
+Advisory means an optional improvement or observation that can be recorded
+without changing the work.
+
+Approve the implementation if Critical and Important are both `None`, even if
+Minor or Advisory contains non-blocking observations.
+
+## Output Format
+
+## Implementation Audit Review
+
+**Status:** Approved | Issues Found
+
+If a section has no items, write `None` under that section.
+
+**Critical:**
+- Specific issue, with file:line or diff reference when available, and why it blocks finishing
+
+**Important:**
+- Specific issue, with file:line or diff reference when available, and why it should be fixed or rebutted before finishing
+
+**Minor:**
+- Non-blocking issue, with file:line or diff reference when available
+
+**Advisory:**
+- Optional suggestion or observation
+
+**Plan Alignment:**
+One short paragraph assessing whether the implementation matches the plan and
+source spec.
+
+**Test Evidence:**
+One short paragraph assessing whether the latest test evidence and changed
+tests are adequate for the implementation.
+
+**Summary:**
+One short paragraph describing readiness for finishing options.
+
+## Main Session Follow-Up
+
+The main session must handle every Critical and Important item before showing
+finishing options:
+
+- Accept: fix the implementation, rerun relevant tests, and rerun this external
+  audit.
+- Rebut: explain with concrete code, diff, or test evidence why the finding does
+  not require a change.
+- Escalate: ask the user when the feedback exposes a product, scope, or plan
+  interpretation decision the main session should not decide alone.
*** End Patch
```

- [ ] **Step 4: Verify the prompt preserves the approved policy**

Run:

```bash
rg -n -F \
  -e '# Implementation Audit Reviewer Prompt Template' \
  -e 'This audit may inspect the repository.' \
  -e 'Do not edit files, run mutating commands, stage files, commit, push, change branches' \
  -e '| Plan and spec alignment | The final diff implements the approved plan and source spec without skipping required behavior |' \
  -e '| Repository mutation check | Generated files, lockfiles, metadata, or unrelated files changed unexpectedly |' \
  -e '**Status:** Approved | Issues Found' \
  -e '**Critical:**' \
  -e '**Important:**' \
  -e '**Plan Alignment:**' \
  -e '**Test Evidence:**' \
  -e 'The main session must handle every Critical and Important item before showing' \
  skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md
```

Expected: each pattern is present in `skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md`.

- [ ] **Step 5: Commit the prompt template**

Run:

```bash
git add skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md
git commit -m "docs: add implementation audit reviewer prompt"
```

Expected: commit succeeds and reports one created file.

---

### Task 2: Add External Implementation Audit To Finishing

**Files:**
- Modify: `skills/finishing-a-development-branch/SKILL.md:8-251`

- [ ] **Step 1: Run the pre-change finishing-gate check**

Run:

```bash
rg -n -F \
  -e 'External Implementation Audit' \
  -e 'implementation-audit-reviewer-prompt.md' \
  -e 'Critical and Important findings are blocking' \
  skills/finishing-a-development-branch/SKILL.md
```

Expected: command exits non-zero because the finishing skill does not contain the audit gate yet.

- [ ] **Step 2: Inspect the current insertion points**

Run:

```bash
rg -n -F \
  -e 'Verify tests → Detect environment → Present options → Execute choice → Clean up.' \
  -e '**If tests pass:** Continue to Step 2.' \
  -e '### Step 2: Detect Environment' \
  -e '### Step 6: Cleanup Workspace' \
  -e 'Always:' \
  skills/finishing-a-development-branch/SKILL.md
```

Expected: output shows the current core principle, test-pass handoff, environment step, cleanup step, and red-flags section.

- [ ] **Step 3: Verify the implementation-audit `claude` flags are available**

Run:

```bash
if command -v claude >/dev/null 2>&1; then
  claude --help | rg -n -F \
    -e '--bare' \
    -e '--print' \
    -e '--no-session-persistence' \
    -e '--permission-mode <mode>' \
    -e '--tools <tools...>' \
    -e '--output-format <format>' \
    -e '--append-system-prompt <prompt>'
else
  echo 'SKIP: claude CLI not available; flag availability not locally verified'
fi
```

Expected: if `claude` is available, each flag used by the implementation-audit command appears in `claude --help`. If `claude` is unavailable, the command exits 0 and prints the explicit skip line.

- [ ] **Step 4: Insert the audit gate and update numbering**

Use `apply_patch` with this patch:

````diff
*** Begin Patch
*** Update File: skills/finishing-a-development-branch/SKILL.md
@@
-**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.
+**Core principle:** Verify tests → Audit implementation → Detect environment → Present options → Execute choice → Clean up.
@@
-**If tests pass:** Continue to Step 2.
+**If tests pass:** Continue to Step 2.
 
-### Step 2: Detect Environment
+### Step 2: External Implementation Audit
+
+**Before presenting options, audit the completed implementation with the local `claude` CLI.** This gate runs after local tests pass and before environment detection or the finishing menu.
+
+This audit covers the final repository state against the implementation plan, source spec when available, and latest test evidence. It is a final readiness gate; it does not replace local tests or per-task reviews.
+
+1. **Identify the audit scope.**
+   - Use the implementation plan path from the current execution context.
+   - Use the source spec path from the plan or session context when it is known.
+   - Determine the implementation range with `git rev-parse` or the base/head range already used for code review.
+   - If the implementation plan cannot be identified, ask the user for the plan path before invoking `claude`. If the user confirms there was no plan, write `Not identified` for the plan and focus the audit on the available requirements, diff, and test evidence.
+2. **Prepare an audit packet** as an ephemeral Markdown file. Use this exact section structure:
+
+   ```markdown
+   # External Implementation Audit Packet
+
+   ## Repository Root
+   [absolute path]
+
+   ## Git Range
+   Base: [sha]
+   Head: [sha]
+
+   ## Implementation Plan
+   [path or "Not identified"]
+
+   ## Source Spec
+   [path or "Not identified"]
+
+   ## Latest Test Evidence
+   Command: [command]
+   Result: [short passing summary]
+
+   ## Implementation Goal
+   [short goal]
+
+   ## Review Focus Areas
+   - plan and spec alignment
+   - missing requirements
+   - unintended scope
+   - regression risk
+   - test coverage and evidence
+   - code quality issues that materially affect readiness
+   - repository mutation check
+   ```
+
+3. **Resolve the reviewer prompt path.** Resolve `implementation-audit-reviewer-prompt.md` relative to this loaded `SKILL.md` file, store the absolute path in `reviewer_prompt`, and verify it is readable before running `claude`.
+4. **Run the audit** with `exec_command`, invoking the local `claude` CLI in non-interactive mode from the repository root. Use this command shape:
+
+   ```bash
+   reviewer_prompt="/absolute/path/to/skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md"
+   packet="/absolute/path/to/populated-implementation-audit-packet.md"
+   repo_root="/absolute/path/to/repo"
+   test -r "$reviewer_prompt" || { echo "Reviewer prompt unreadable: $reviewer_prompt" >&2; exit 1; }
+   test -s "$packet" || { echo "Audit packet missing or empty: $packet" >&2; exit 1; }
+   cd "$repo_root" && claude --bare --print --no-session-persistence --permission-mode plan --output-format text \
+     --append-system-prompt "$(cat "$reviewer_prompt")" \
+     < "$packet"
+   ```
+
+   Do not pass `--tools ""` for this audit. The external reviewer should be able to inspect the repository. The reviewer prompt requires read-only behavior and forbids edits, staging, commits, pushes, branch changes, dependency installation, and generated-artifact rewrites.
+5. **Validate the output shape.** Treat the audit as unusable if it is missing a `Status:` line, missing `Critical:`, `Important:`, `Minor:`, `Advisory:`, `Plan Alignment:`, `Test Evidence:`, or `Summary:` section headings, or has unstructured text that prevents identifying findings by severity. Valid status values are `Approved` and `Issues Found`. `Approved` is inconsistent if either `Critical` or `Important` contains an item other than `None`. `Issues Found` is inconsistent if all issue sections are `None` or empty. Extra blank lines or Markdown heading markers do not matter if the required labels and section contents are identifiable.
+6. **Handle Critical and Important findings before moving on.**
+   - Accept: fix the implementation, rerun relevant tests, and rerun the external implementation audit.
+   - Rebut: explain with concrete code, diff, or test evidence why the finding does not require a change.
+   - Escalate: ask the user when feedback exposes a product, scope, or plan interpretation decision the main session should not decide alone.
+7. **Treat Minor and Advisory findings as non-blocking.** Apply them opportunistically, mention them briefly, or ignore them when they do not affect readiness.
+8. **Avoid silent infinite loops.** A rebutted item is considered handled and does not by itself require another external audit. If accepted changes trigger two total external audit reruns for the same implementation and unresolved Critical or Important findings remain, escalate to the user instead of continuing to revise and rerun indefinitely. Failed runs caused by missing `claude`, timeout, non-zero exit, or unusable output do not count toward this rerun limit.
+9. **Handle `claude` failures explicitly.** If `claude` is missing, times out, exits non-zero, or returns unusable output, pause and ask the user whether to retry, skip the external implementation audit, or choose another review path. If the user chooses to skip, explicitly record in the conversation that the external implementation audit was waived by the user. Do not describe a waived audit as passed.
+10. **Check for unexpected mutation if needed.** If the audit output or command behavior suggests the reviewer may have changed files, run `git status --short` and inspect any changes before continuing. Never revert user changes without explicit permission.
+
+**If the audit passes or the user explicitly waives it:** Continue to Step 3.
+
+### Step 3: Detect Environment
@@
-### Step 3: Determine Base Branch
+### Step 4: Determine Base Branch
@@
-### Step 4: Present Options
+### Step 5: Present Options
@@
-### Step 5: Execute Choice
+### Step 6: Execute Choice
@@
-# Only after merge succeeds: cleanup worktree (Step 6), then delete branch
+# Only after merge succeeds: cleanup worktree (Step 7), then delete branch
 ```
 
-Then: Cleanup worktree (Step 6), then delete branch:
+Then: Cleanup worktree (Step 7), then delete branch:
@@
-Then: Cleanup worktree (Step 6), then force-delete branch:
+Then: Cleanup worktree (Step 7), then force-delete branch:
@@
-### Step 6: Cleanup Workspace
+### Step 7: Cleanup Workspace
@@
 **Skipping test verification**
 - **Problem:** Merge broken code, create failing PR
 - **Fix:** Always verify tests before offering options
 
+**Skipping external implementation audit**
+- **Problem:** Present finishing options before an independent reviewer checks the final diff against the plan
+- **Fix:** After tests pass, run the `claude` implementation audit or record a user-approved waiver
+
 **Open-ended questions**
 - **Problem:** "What should I do next?" is ambiguous
 - **Fix:** Present exactly 4 structured options (or 3 for detached HEAD)
@@
 **Never:**
 - Proceed with failing tests
+- Present finishing options before the external implementation audit passes or is explicitly waived by the user
 - Merge without verifying tests on result
 - Delete work without confirmation
 - Force-push without explicit request
 - Remove a worktree before confirming merge success
 - Clean up worktrees you didn't create (provenance check)
 - Run `git worktree remove` from inside the worktree
@@
 **Always:**
 - Verify tests before offering options
+- Run the external implementation audit after tests pass and before detecting the finishing environment
+- Treat Critical and Important findings as blocking until fixed, rebutted, or escalated
+- Treat Minor and Advisory findings as non-blocking
+- Record user-approved audit skips as waived, not passed
 - Detect environment before presenting menu
 - Present exactly 4 options (or 3 for detached HEAD)
 - Get typed confirmation for Option 4
*** End Patch
````

- [ ] **Step 5: Verify the finishing skill contains the new gate**

Run:

```bash
rg -n -F \
  -e 'Verify tests → Audit implementation → Detect environment → Present options → Execute choice → Clean up.' \
  -e '### Step 2: External Implementation Audit' \
  -e 'implementation-audit-reviewer-prompt.md' \
  -e 'Do not pass `--tools ""` for this audit.' \
  -e 'Critical and Important findings' \
  -e 'Minor and Advisory findings as non-blocking' \
  -e 'Skipping external implementation audit' \
  -e 'external implementation audit was waived by the user' \
  -e 'two total external audit reruns' \
  -e '### Step 7: Cleanup Workspace' \
  skills/finishing-a-development-branch/SKILL.md
```

Expected: each pattern is present in `skills/finishing-a-development-branch/SKILL.md`.

- [ ] **Step 6: Verify stale step references were removed**

Run:

```bash
rg -n -F \
  -e 'cleanup worktree (Step 6)' \
  -e 'Cleanup worktree (Step 6)' \
  -e '### Step 2: Detect Environment' \
  skills/finishing-a-development-branch/SKILL.md
```

Expected: command exits non-zero with no matches.

Run:

```bash
rg -n 'Step [0-9]' skills/finishing-a-development-branch/SKILL.md
```

Expected: inspect every match and confirm the step numbering is internally consistent after adding the audit step: tests are Step 1, external implementation audit is Step 2, environment detection is Step 3, base branch detection is Step 4, options are Step 5, execution is Step 6, and cleanup is Step 7.

- [ ] **Step 7: Commit the finishing workflow update**

```bash
git add skills/finishing-a-development-branch/SKILL.md
git commit -m "docs: add finishing implementation audit gate"
```

Expected: commit succeeds and reports the finishing skill changed.

---

### Task 3: Verify The Workflow Change

**Files:**
- Verify: `skills/finishing-a-development-branch/SKILL.md`
- Verify: `skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md`
- Verify: `tests/brainstorm-server/*`
- Verify: `tests/codex/test-sdd-integration-script-behavior.sh`
- Verify: `tests/codex/test-subagent-driven-development-integration.sh`

- [ ] **Step 1: Verify the implementation matches the approved spec focus areas**

Run:

```bash
rg -n -F \
  -e 'plan and spec alignment' \
  -e 'missing requirements' \
  -e 'unintended scope' \
  -e 'regression risk' \
  -e 'test coverage and evidence' \
  -e 'code quality issues that materially affect readiness' \
  -e 'repository mutation check' \
  skills/finishing-a-development-branch/SKILL.md \
  skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md
```

Expected: each focus area appears in the finishing skill, the reviewer prompt, or both.

- [ ] **Step 2: Verify output validation and failure handling are documented**

Run:

```bash
rg -n -F \
  -e 'Status:` line' \
  -e 'Valid status values are `Approved` and `Issues Found`' \
  -e '`Approved` is inconsistent if either `Critical` or `Important` contains an item other than `None`' \
  -e 'If `claude` is missing, times out, exits non-zero, or returns unusable output' \
  -e 'retry, skip the external implementation audit, or choose another review path' \
  skills/finishing-a-development-branch/SKILL.md
```

Expected: each pattern is present in `skills/finishing-a-development-branch/SKILL.md`.

- [ ] **Step 3: Run brainstorm-server regression tests**

Run:

```bash
cd tests/brainstorm-server && npm test
```

Expected: npm test exits 0 and the Node test runner reports all brainstorm-server tests passing.

- [ ] **Step 4: Run Codex integration-script behavior test**

Run:

```bash
bash tests/codex/test-sdd-integration-script-behavior.sh
```

Expected: command exits 0 and reports the fake-Codex behavior checks passing.

- [ ] **Step 5: Run Codex subagent-driven integration test in default skip mode**

Run:

```bash
bash tests/codex/test-subagent-driven-development-integration.sh
```

Expected: command exits 0 and reports that the real Codex integration is skipped because `RUN_CODEX_INTEGRATION=1` is not set.

- [ ] **Step 6: Optionally validate the `claude` command shape when the CLI is available**

Run:

```bash
if command -v claude >/dev/null 2>&1; then
  reviewer_prompt="$PWD/skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md"
  packet="$(mktemp -t finishing-audit-dry-run.XXXXXX.md)"
  trap 'rm -f "$packet"' EXIT
  {
    echo '# External Implementation Audit Packet'
    echo
    echo '## Repository Root'
    pwd
    echo
    echo '## Git Range'
    echo "Base: $(git rev-parse HEAD~1)"
    echo "Head: $(git rev-parse HEAD)"
    echo
    echo '## Implementation Plan'
    echo 'docs/superpowers/plans/2026-05-16-finishing-implementation-audit.md'
    echo
    echo '## Source Spec'
    echo 'docs/superpowers/specs/2026-05-16-finishing-implementation-audit-design.md'
    echo
    echo '## Latest Test Evidence'
    echo 'Command: rg verification plus repository regression tests from this plan'
    echo 'Result: command-shape dry run only'
    echo
    echo '## Implementation Goal'
    echo 'Validate that the local claude CLI accepts the implementation audit prompt and packet shape.'
    echo
    echo '## Review Focus Areas'
    echo '- plan and spec alignment'
    echo '- missing requirements'
    echo '- unintended scope'
    echo '- regression risk'
    echo '- test coverage and evidence'
    echo '- code quality issues that materially affect readiness'
    echo '- repository mutation check'
  } > "$packet"
  test -r "$reviewer_prompt"
  test -s "$packet"
  claude --bare --print --no-session-persistence --permission-mode plan --output-format text \
    --append-system-prompt "$(cat "$reviewer_prompt")" \
    < "$packet"
else
  echo 'SKIP: claude CLI not available; command shape not dry-run verified'
fi
```

Expected: if `claude` is available, the command exits 0 and returns output containing `Implementation Audit Review`. If `claude` is unavailable, the command exits 0 and prints the explicit skip line.

- [ ] **Step 7: Inspect final repository state**

Run:

```bash
git status --short
```

Expected: there are no uncommitted changes from Task 1 or Task 2. If this plan file was saved but not committed before execution, it may still appear as an unrelated planning artifact. If the optional `claude` dry-run created unexpected repository changes, inspect them and do not revert user changes without explicit permission.
