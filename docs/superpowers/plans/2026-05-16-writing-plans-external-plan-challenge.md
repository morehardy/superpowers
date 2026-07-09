# Writing Plans External Plan Challenge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `claude` CLI external plan-challenge gate to `writing-plans` after plan self-review and before execution handoff.

**Architecture:** This is a prose-only skill workflow change. `skills/writing-plans/plan-challenge-reviewer-prompt.md` owns the external reviewer policy, and `skills/writing-plans/SKILL.md` owns when and how the main session invokes that policy. The prompt file is created before the skill references it, satisfying the one-time bootstrap boundary in the approved spec.

**Tech Stack:** Markdown skill files, shell verification with `rg`, existing Node-based brainstorm-server tests, existing Codex shell integration-script checks.

---

## File Structure

- `skills/writing-plans/plan-challenge-reviewer-prompt.md`
  - New prompt template for the local `claude` CLI reviewer.
  - Contains the authoritative plan-review policy from the approved spec.
  - Defines packet expectations, reviewer role, focus areas, calibration, output format, and main-session follow-up.
- `skills/writing-plans/SKILL.md`
  - Existing skill workflow documentation.
  - Add `External Plan Challenge` between `Self-Review` and `Execution Handoff`.
  - Define packet shape, execution-mode defaults, plan/spec size handling, pinned `claude` command shape, output validation, failure paths, advisory handling, and rerun limits.
- `tests/brainstorm-server/*`
  - No source changes.
  - Run the existing npm test suite as regression coverage for the adjacent brainstorming tooling.
- `tests/codex/test-sdd-integration-script-behavior.sh`
  - No source changes.
  - Run the existing shell test to make sure Codex integration-script behavior still passes.
- `tests/codex/test-subagent-driven-development-integration.sh`
  - No source changes.
  - Run without `RUN_CODEX_INTEGRATION=1`; expected result is a safe skip unless explicitly enabled.

---

### Task 1: Add Plan Challenge Reviewer Prompt

**Files:**
- Create: `skills/writing-plans/plan-challenge-reviewer-prompt.md`

- [ ] **Step 1: Verify the prompt file is not already present**

Run:

```bash
test ! -e skills/writing-plans/plan-challenge-reviewer-prompt.md
```

Expected: command exits 0 with no output. If it exits 1, inspect the existing file and reconcile it with the approved spec before continuing.

- [ ] **Step 2: Create the prompt template**

Apply this patch:

```diff
*** Begin Patch
*** Add File: skills/writing-plans/plan-challenge-reviewer-prompt.md
+# Plan Challenge Reviewer Prompt Template
+
+Use this template when running the local `claude` CLI to challenge a written
+implementation plan.
+
+**Purpose:** Challenge the implementation plan before the user reviews or
+executes it. Look for plan defects that would cause an implementer to build the
+wrong thing, get stuck, skip verification, or make brittle changes.
+
+**Run after:** The implementation plan is written and the main session's plan
+self-review has passed.
+
+**Run with:** The local `claude` CLI in isolated, non-interactive mode.
+
+## Review Packet
+
+Expect a Markdown packet with these sections:
+
+- Plan file path
+- Current plan content
+- Source spec file path
+- Source spec content
+- Confirmed planning inputs
+- Execution assumption: `subagent-driven`, `inline`, or `both`
+- Review focus areas
+
+The reviewer has no tool access and cannot inspect the workspace. Review the
+text in the packet only. Do not claim that files exist or commands pass; instead
+check whether paths are concrete, commands are plausible from the stated working
+directory, and verification expectations are explicit.
+
+## Reviewer Role
+
+You are an external plan challenger. Stress-test the plan; do not rewrite it,
+execute it, or bikeshed wording.
+
+Challenge the plan for:
+
+| Category | What to Look For |
+| --- | --- |
+| Spec coverage | Every source-spec requirement maps to a plan task, and the plan does not add unrelated scope |
+| Task decomposition | Each task has a clear boundary, explicit file set, and steps small enough for a worker to execute without guessing |
+| Dependency order | Earlier tasks create files, APIs, fixtures, or decisions that later tasks rely on |
+| TDD correctness | Implementation tasks put failing tests before code, name the exact command to run, state the expected failure, then state the expected pass |
+| Exact file paths | Files, commands, and references use concrete repository paths instead of invented or unresolved names |
+| Command validity | Commands are runnable from the stated working directory and have concrete expected output |
+| Expected output clarity | Verification steps say what pass and fail look like, not just that the command should be run |
+| Placeholder content | The plan has no `TBD`, `TODO`, `FIXME`, unresolved bracket variables, "similar to previous task", or vague instructions such as "add appropriate handling" |
+| Implementation risks | The plan names ordering, integration, testing, or review risks that could make execution brittle |
+
+When the execution assumption is `subagent-driven`, check whether each task has
+enough task-local context, clear ownership, and handoff artifacts for a fresh
+worker. When it is `inline`, check whether the plan has sensible checkpoint
+boundaries and verification commands for the current session. When it is `both`,
+label mode-specific findings as `subagent-driven`, `inline`, or `both`.
+
+## Calibration
+
+Only flag issues that can materially affect implementation. Minor wording
+preferences, style edits, and nice-to-have improvements are advisory only.
+
+Approve the plan if remaining concerns are small enough for execution to handle
+safely.
+
+## Output Format
+
+## Plan Challenge Review
+
+**Status:** Approved | Issues Found
+
+If a section has no items, write `None` under that section.
+
+**Blocking Issues:**
+- Task or section: specific issue - why it must be resolved before execution handoff
+
+**Challenges:**
+- Task or section: challenge - what the main session should accept, rebut, or ask the user to decide
+
+**Advisory:**
+- Suggestion - why it may help, without blocking progression
+
+**Summary:**
+One short paragraph describing the plan's readiness for user review or
+execution.
+
+## Main Session Follow-Up
+
+The main session must handle every blocking issue and challenge before asking
+the user to review or execute the plan:
+
+- Accept: revise the plan, rerun plan self-review, and rerun this external
+  challenge if the plan materially changed.
+- Rebut: explain in the conversation why the plan stays unchanged.
+- Escalate: ask the user when feedback exposes a product, scope, or execution
+  decision the main session should not decide alone.
*** End Patch
```

- [ ] **Step 3: Verify the prompt preserves the approved policy**

Run:

```bash
rg -n -F \
  -e '# Plan Challenge Reviewer Prompt Template' \
  -e 'Expect a Markdown packet with these sections:' \
  -e 'Execution assumption: `subagent-driven`, `inline`, or `both`' \
  -e '| Spec coverage | Every source-spec requirement maps to a plan task, and the plan does not add unrelated scope |' \
  -e '| TDD correctness | Implementation tasks put failing tests before code, name the exact command to run, state the expected failure, then state the expected pass |' \
  -e 'The reviewer has no tool access and cannot inspect the workspace.' \
  -e '**Status:** Approved | Issues Found' \
  -e 'The main session must handle every blocking issue and challenge before asking' \
  skills/writing-plans/plan-challenge-reviewer-prompt.md
```

Expected: each pattern is present in `skills/writing-plans/plan-challenge-reviewer-prompt.md`.

- [ ] **Step 4: Commit the prompt template**

Run:

```bash
git add skills/writing-plans/plan-challenge-reviewer-prompt.md
git commit -m "docs: add plan challenge reviewer prompt"
```

Expected: commit succeeds and reports one created file.

---

### Task 2: Add External Plan Challenge To Writing Plans

**Files:**
- Modify: `skills/writing-plans/SKILL.md:122-152`

- [ ] **Step 1: Inspect the insertion point**

Run:

```bash
rg -n -F \
  -e '## Self-Review' \
  -e 'If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.' \
  -e '## Execution Handoff' \
  -e 'After saving the plan, offer execution choice:' \
  skills/writing-plans/SKILL.md
```

Expected: output shows `Self-Review` immediately before `Execution Handoff`, and the handoff text still says `After saving the plan, offer execution choice:`.

- [ ] **Step 2: Insert the external challenge gate and update handoff wording**

Apply this patch:

```diff
*** Begin Patch
*** Update File: skills/writing-plans/SKILL.md
@@
 If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.
 
+## External Plan Challenge
+
+After plan self-review passes, challenge the written implementation plan with the local `claude` CLI before asking the user to review or execute the plan.
+
+This gate does not apply retroactively to the implementation plan that first creates `skills/writing-plans/plan-challenge-reviewer-prompt.md`. After that prompt exists, every future `writing-plans` invocation must run this gate unless the user explicitly waives it after a `claude` failure.
+
+1. **Check plan size.** Send the current plan content in full. If the plan exceeds 20,000 words as measured by `wc -w`, pause before invoking `claude` and ask the user whether to split the plan, proceed with an oversized review attempt, or choose another review path. Do not silently excerpt the plan being challenged.
+2. **Prepare a review packet** as an ephemeral Markdown file. Use this exact section structure:
+
+   ```markdown
+   # External Plan Challenge Packet
+
+   ## Plan File Path
+   [path]
+
+   ## Current Plan Content
+   [full plan content]
+
+   ## Source Spec File Path
+   [path]
+
+   ## Source Spec Content
+   [full spec content or documented excerpt]
+
+   ## Confirmed Planning Inputs
+   - Decision: [short decision summary]
+     Source: [source spec section, direct user statement, or explicit planning constraint]
+
+   ## Execution Assumption
+   subagent-driven | inline | both
+
+   ## Review Focus Areas
+   - spec coverage
+   - task decomposition
+   - dependency order
+   - TDD correctness
+   - exact file paths
+   - command validity
+   - expected output clarity
+   - placeholder content
+   - implementation risks
+   ```
+
+3. **Populate source spec content deliberately.** Use the full source spec by default. If the spec exceeds 20,000 words as measured by `wc -w`, include the goals, workflow, requirements, files, verification, and test-impact sections, then list omitted sections by heading.
+4. **Populate confirmed planning inputs only from confirmed sources.** Include decisions from the approved source spec, explicit user constraints stated during planning, and any execution mode the user selected before the plan challenge runs. Do not invent implied user decisions.
+5. **Set the execution assumption.** Use `both` unless the user explicitly chose or requested `subagent-driven` or `inline` before the plan challenge runs.
+6. **Resolve the reviewer prompt path.** Resolve `plan-challenge-reviewer-prompt.md` relative to this loaded `SKILL.md` file, store the absolute path in `reviewer_prompt`, and verify it is readable before running `claude`.
+7. **Run the challenge** with `exec_command`, invoking the local `claude` CLI in isolated, non-interactive mode from a neutral temp directory. Use this command shape:
+
+   ```bash
+   reviewer_prompt="/absolute/path/to/skills/writing-plans/plan-challenge-reviewer-prompt.md"
+   packet="/absolute/path/to/populated-plan-review-packet.md"
+   test -r "$reviewer_prompt" || { echo "Reviewer prompt unreadable: $reviewer_prompt" >&2; exit 1; }
+   test -s "$packet" || { echo "Review packet missing or empty: $packet" >&2; exit 1; }
+   cd /tmp && claude --bare --print --no-session-persistence --permission-mode plan --tools "" --output-format text \
+     --append-system-prompt "$(cat "$reviewer_prompt")" \
+     < "$packet"
+   ```
+
+   The `--tools ""` flag is intentional: the external reviewer should operate in isolated review-only mode and should not inspect or mutate the workspace.
+8. **Validate the output shape.** Treat the review as unusable if it is missing a `Status:` line, missing `Blocking Issues:`, `Challenges:`, `Advisory:`, or `Summary:` section headings, or has unstructured text that prevents identifying blocking issues, challenges, and advisory notes. Valid status values are `Approved` and `Issues Found`. `Approved` is inconsistent if either `Blocking Issues` or `Challenges` contains an item other than `None`. `Issues Found` is inconsistent if both `Blocking Issues` and `Challenges` are `None` or empty. Extra blank lines or Markdown heading markers do not matter if the required labels and section contents are identifiable.
+9. **Handle every substantive item before moving on:**
+   - Accept: revise the plan, rerun plan self-review, and rerun the external challenge if the accepted change materially alters the plan.
+   - Rebut: explain in the conversation why the plan stays unchanged.
+   - Escalate: ask the user when feedback exposes a product, scope, or execution decision the main session should not decide alone.
+10. **Treat advisory items as non-blocking.** Apply them opportunistically, mention them briefly, or ignore them when they do not affect plan readiness.
+11. **Use the material-change rule.** A plan change materially alters the plan when it changes task count, task boundaries, dependency order, target files, commands, expected test outcomes, acceptance criteria, or execution strategy. Minor wording edits, typo fixes, or clarifications that do not change what an implementer would do do not require a fresh external challenge.
+12. **Avoid silent infinite loops.** A rebutted item is considered handled and does not by itself require another external challenge. If accepted changes trigger two total external challenge reruns for the same plan and unresolved substantive issues remain, escalate to the user instead of continuing to revise and rerun indefinitely. Failed runs caused by missing `claude`, timeout, non-zero exit, or unusable output do not count toward this rerun limit.
+13. **Handle `claude` failures explicitly.** If `claude` is missing, times out, exits non-zero, or returns unusable output, pause and ask the user whether to retry, skip the external challenge, or choose another review path. If the user chooses to skip, explicitly record in the conversation that the external challenge was waived by the user. Do not describe a waived challenge as passed.
+
 ## Execution Handoff
 
-After saving the plan, offer execution choice:
+After saving the plan, passing plan self-review, and passing the external plan challenge or recording a user-approved waiver, offer execution choice:
*** End Patch
```

- [ ] **Step 3: Verify the gate is placed before execution handoff**

Run:

```bash
rg -n -F \
  -e '## Self-Review' \
  -e '## External Plan Challenge' \
  -e '## Execution Handoff' \
  -e 'After plan self-review passes, challenge the written implementation plan with the local `claude` CLI' \
  -e 'This gate does not apply retroactively to the implementation plan that first creates' \
  -e 'After saving the plan, passing plan self-review, and passing the external plan challenge or recording a user-approved waiver' \
  skills/writing-plans/SKILL.md
```

Expected: output shows `External Plan Challenge` between `Self-Review` and `Execution Handoff`, and the handoff wording requires self-review plus either a passed external challenge or a user-approved waiver.

- [ ] **Step 4: Verify packet structure and command shape**

Run:

```bash
rg -n -F \
  -e '# External Plan Challenge Packet' \
  -e '## Confirmed Planning Inputs' \
  -e 'Source: [source spec section, direct user statement, or explicit planning constraint]' \
  -e '## Execution Assumption' \
  -e 'reviewer_prompt="/absolute/path/to/skills/writing-plans/plan-challenge-reviewer-prompt.md"' \
  -e 'claude --bare --print --no-session-persistence --permission-mode plan --tools "" --output-format text' \
  -e 'The `--tools ""` flag is intentional' \
  skills/writing-plans/SKILL.md
```

Expected: output includes the packet headings, confirmed-input format, pinned `claude` command shape, and `--tools ""` rationale.

- [ ] **Step 5: Verify handling rules**

Run:

```bash
rg -n -F \
  -e 'Validate the output shape.' \
  -e 'Valid status values are `Approved` and `Issues Found`.' \
  -e 'Handle every substantive item before moving on:' \
  -e 'Treat advisory items as non-blocking.' \
  -e 'Use the material-change rule.' \
  -e 'Avoid silent infinite loops.' \
  -e 'Handle `claude` failures explicitly.' \
  -e 'Do not describe a waived challenge as passed.' \
  skills/writing-plans/SKILL.md
```

Expected: output includes the output-validation, accept/rebut/escalate, advisory, material-change, rerun-limit, and waiver rules.

- [ ] **Step 6: Commit the skill workflow update**

Run:

```bash
git add skills/writing-plans/SKILL.md
git commit -m "feat: add writing-plans external challenge gate"
```

Expected: commit succeeds and reports one modified file.

---

### Task 3: Verify The Workflow Documentation

**Files:**
- Inspect: `skills/writing-plans/SKILL.md`
- Inspect: `skills/writing-plans/plan-challenge-reviewer-prompt.md`
- Test: `tests/brainstorm-server/package.json`
- Test: `tests/codex/test-sdd-integration-script-behavior.sh`
- Test: `tests/codex/test-subagent-driven-development-integration.sh`

- [ ] **Step 1: Check prompt and skill stay aligned**

Run:

```bash
rg -n -F \
  -e 'spec coverage' \
  -e 'task decomposition' \
  -e 'dependency order' \
  -e 'TDD correctness' \
  -e 'exact file paths' \
  -e 'command validity' \
  -e 'expected output clarity' \
  -e 'placeholder content' \
  -e 'implementation risks' \
  skills/writing-plans/SKILL.md \
  skills/writing-plans/plan-challenge-reviewer-prompt.md
```

Expected: both files contain the plan-review focus areas from the spec.

- [ ] **Step 2: Check the prompt file preserves the authoritative policy**

Run:

```bash
rg -n -F \
  -e 'The reviewer has no tool access and cannot inspect the workspace.' \
  -e 'You are an external plan challenger. Stress-test the plan' \
  -e 'Only flag issues that can materially affect implementation.' \
  -e 'If a section has no items, write `None` under that section.' \
  -e 'The main session must handle every blocking issue and challenge before asking' \
  skills/writing-plans/plan-challenge-reviewer-prompt.md
```

Expected: output confirms the prompt keeps the authoritative policy text from the approved spec.

- [ ] **Step 3: Run the brainstorm-server regression suite**

Run:

```bash
npm test --prefix tests/brainstorm-server
```

Expected: both `server.test.js` and `ws-protocol.test.js` pass.

- [ ] **Step 4: Run the Codex integration script behavior test**

Run:

```bash
bash tests/codex/test-sdd-integration-script-behavior.sh
```

Expected: the script exits 0 and reports all behavior checks as `PASS`.

- [ ] **Step 5: Run the opt-in Codex integration wrapper in default skip mode**

Run:

```bash
bash tests/codex/test-subagent-driven-development-integration.sh
```

Expected: output includes:

```text
SKIP: set RUN_CODEX_INTEGRATION=1 to run the real Codex end-to-end test.
```

Expected: command exits 0.

- [ ] **Step 6: Inspect final diff**

Run:

```bash
git diff --stat HEAD~2..HEAD
git status --short
```

Expected: the diff stat includes only:

```text
skills/writing-plans/SKILL.md
skills/writing-plans/plan-challenge-reviewer-prompt.md
```

Expected `git status --short`: no output.

---

### Task 4: Final Manual Smoke Check

**Files:**
- Inspect: `skills/writing-plans/SKILL.md`
- Inspect: `skills/writing-plans/plan-challenge-reviewer-prompt.md`

- [ ] **Step 1: Simulate the future `writing-plans` flow in prose**

Read `skills/writing-plans/SKILL.md` from `## Self-Review` through `## Execution Handoff`.

Expected flow:

```text
Self-Review
External Plan Challenge
Execution Handoff
```

Expected behavior:

```text
The agent writes and self-reviews a plan, prepares an External Plan Challenge Packet, runs claude with plan-challenge-reviewer-prompt.md, handles blocking issues and challenges, records any user-approved waiver, and only then offers Subagent-Driven or Inline Execution.
```

- [ ] **Step 2: Confirm the one-time bootstrap requirement was satisfied**

Run:

```bash
test -r skills/writing-plans/plan-challenge-reviewer-prompt.md
```

Expected: command exits 0 with no output.

- [ ] **Step 3: Confirm future invocations have no missing prompt dependency**

Run:

```bash
rg -n -F \
  -e 'Resolve `plan-challenge-reviewer-prompt.md` relative to this loaded `SKILL.md` file' \
  -e 'test -r "$reviewer_prompt"' \
  skills/writing-plans/SKILL.md
```

Expected: output shows the future skill invocation resolves and checks the prompt path before invoking `claude`.

- [ ] **Step 4: Commit any manual smoke-check corrections**

If Task 4 reveals no changes, do not create a commit. If it reveals corrections, apply the minimal fix and run:

```bash
git add skills/writing-plans/SKILL.md skills/writing-plans/plan-challenge-reviewer-prompt.md
git commit -m "fix: tighten writing-plans challenge workflow"
```

Expected when no corrections are needed: no command is run for this step.

Expected when corrections are needed: commit succeeds and includes only the corrected skill files.
