# Brainstorming External Design Challenge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `claude` CLI design-challenge gate to the brainstorming workflow after spec self-review and before user spec review.

**Architecture:** This is a prose-only skill workflow change. `skills/brainstorming/SKILL.md` owns the mandatory flow, and a new prompt template owns the external reviewer instructions so the main skill stays readable.

**Tech Stack:** Markdown skill files, Graphviz DOT flow text, shell verification, existing brainstorm-server npm test suite for regression.

---

## File Structure

- `skills/brainstorming/SKILL.md`
  - Owns the required brainstorming checklist, DOT process flow, and post-design gates.
  - Add the external challenge as a hard workflow step between spec self-review and user spec review.
- `skills/brainstorming/design-challenge-reviewer-prompt.md`
  - New prompt template for the local `claude` CLI reviewer.
  - Defines the review packet, reviewer calibration, output format, and handoff back to the main session.
  - Does not mention project execution constraints; the reviewer only needs design context.
- `tests/brainstorm-server/*`
  - No source changes.
  - Run the existing npm test suite after implementation to catch accidental visual companion regressions.

---

### Task 1: Add External Challenge To Brainstorming Flow

**Files:**
- Modify: `skills/brainstorming/SKILL.md:20-66`

- [ ] **Step 1: Inspect the current checklist and flow**

Run:

```bash
rg -n -F \
  -e '7. **Spec self-review**' \
  -e '8. **User reviews written spec**' \
  -e '9. **Transition to implementation**' \
  -e '"Spec self-review\n(fix inline)" -> "User reviews spec?";' \
  skills/brainstorming/SKILL.md
```

Expected: output shows the current checklist ending with user spec review and transition to `writing-plans`, and the DOT flow routes `Spec self-review` directly to `User reviews spec?`.

- [ ] **Step 2: Update checklist numbering and DOT graph**

Apply this patch:

```diff
*** Begin Patch
*** Update File: skills/brainstorming/SKILL.md
@@
-7. **Spec self-review** — quick inline check for placeholders, contradictions, ambiguity, scope (see below)
-8. **User reviews written spec** — ask user to review the spec file before proceeding
-9. **Transition to implementation** — invoke writing-plans skill to create implementation plan
+7. **Spec self-review** — quick inline check for placeholders, contradictions, ambiguity, scope (see below)
+8. **External design challenge** — call the local `claude` CLI to challenge the written design before user review
+9. **User reviews written spec** — ask user to review the spec file before proceeding
+10. **Transition to implementation** — invoke writing-plans skill to create implementation plan
@@
     "Write design doc" [shape=box];
     "Spec self-review\n(fix inline)" [shape=box];
+    "External design challenge\n(claude CLI)" [shape=box];
+    "User chooses retry/skip/alternative" [shape=diamond];
     "User reviews spec?" [shape=diamond];
     "Invoke writing-plans skill" [shape=doublecircle];
@@
     "User approves design?" -> "Write design doc" [label="yes"];
     "Write design doc" -> "Spec self-review\n(fix inline)";
-    "Spec self-review\n(fix inline)" -> "User reviews spec?";
+    "Spec self-review\n(fix inline)" -> "External design challenge\n(claude CLI)";
+    "External design challenge\n(claude CLI)" -> "Spec self-review\n(fix inline)" [label="accepted changes"];
+    "External design challenge\n(claude CLI)" -> "User reviews spec?" [label="approved or rebutted"];
+    "External design challenge\n(claude CLI)" -> "User chooses retry/skip/alternative" [label="CLI unavailable"];
+    "User chooses retry/skip/alternative" -> "External design challenge\n(claude CLI)" [label="retry"];
+    "User chooses retry/skip/alternative" -> "User reviews spec?" [label="skip or alternative complete"];
     "User reviews spec?" -> "Write design doc" [label="changes requested"];
     "User reviews spec?" -> "Invoke writing-plans skill" [label="approved"];
 }
*** End Patch
```

- [ ] **Step 3: Verify checklist and flow order**

Run:

```bash
rg -n -F \
  -e '7. **Spec self-review**' \
  -e '8. **External design challenge**' \
  -e '9. **User reviews written spec**' \
  -e '10. **Transition to implementation**' \
  -e '"Spec self-review\n(fix inline)" -> "External design challenge\n(claude CLI)";' \
  -e '"External design challenge\n(claude CLI)" -> "User reviews spec?" [label="approved or rebutted"];' \
  skills/brainstorming/SKILL.md
```

Expected: output contains these checklist items:

```text
7. **Spec self-review**
8. **External design challenge**
9. **User reviews written spec**
10. **Transition to implementation**
```

Expected DOT edges include:

```text
"Spec self-review\n(fix inline)" -> "External design challenge\n(claude CLI)";
"External design challenge\n(claude CLI)" -> "User reviews spec?" [label="approved or rebutted"];
```

---

### Task 2: Document The External Design Challenge Gate

**Files:**
- Modify: `skills/brainstorming/SKILL.md:116-136`

- [ ] **Step 1: Insert the gate instructions after Spec Self-Review**

Apply this patch:

```diff
*** Begin Patch
*** Update File: skills/brainstorming/SKILL.md
@@
 Fix any issues inline. No need to re-review — just fix and move on.
  
+**External Design Challenge:**
+After spec self-review passes, challenge the written design with the local `claude` CLI before asking the user to review the spec.
+
+1. **Prepare a review packet** containing:
+   - Spec file path
+   - Current spec content
+   - User-confirmed key decisions
+   - Approaches considered and not selected, with reasons
+   - Design success criteria
+   - Review focus areas: scope, ambiguity, over-engineering, missing error handling, and risks for later implementation planning
+2. **Keep the packet limited to design context.** Do not add unrelated environment, platform, or tooling guidance.
+3. **Send the packet on stdin.** Write it to an ephemeral Markdown file such as `/tmp/brainstorming-design-review-packet.md`, or pipe equivalent content directly to the command. Do not create or commit a repo file for the packet.
+4. **Run the challenge** with `exec_command`, invoking the local `claude` CLI in non-interactive mode. Use this command shape:
+
+   ```bash
+   claude --print --permission-mode plan --output-format text \
+     --append-system-prompt "$(cat skills/brainstorming/design-challenge-reviewer-prompt.md)" \
+     < /tmp/brainstorming-design-review-packet.md
+   ```
+
+5. **Handle every substantive item** before moving on:
+   - Accept: revise the spec, rerun spec self-review, and rerun the external challenge if the design materially changed.
+   - Rebut: explain in the conversation why the spec stays unchanged.
+   - Escalate: ask the user when the feedback exposes a product or scope decision the main session should not decide alone.
+6. **If `claude` fails** because it is missing, times out, exits non-zero, or returns unusable output, pause and ask the user whether to retry, skip the external challenge, or choose another review path.
+
 **User Review Gate:**
-After the spec review loop passes, ask the user to review the written spec before proceeding:
+After the spec self-review and external design challenge pass, ask the user to review the written spec before proceeding:
*** End Patch
```

- [ ] **Step 2: Verify the gate is before user review**

Run:

```bash
rg -n -F \
  -e '**Spec Self-Review:**' \
  -e '**External Design Challenge:**' \
  -e 'Write it to an ephemeral Markdown file such as `/tmp/brainstorming-design-review-packet.md`' \
  -e 'claude --print --permission-mode plan --output-format text' \
  -e '**User Review Gate:**' \
  -e 'After the spec self-review and external design challenge pass' \
  -e '**Implementation:**' \
  skills/brainstorming/SKILL.md
```

Expected: output includes the spec self-review gate, the external design challenge gate, the temporary packet path, the concrete `claude --print` command shape, the user review gate, and the implementation section.

- [ ] **Step 3: Commit the workflow update**

Run:

```bash
git add skills/brainstorming/SKILL.md
git commit -m "feat: add brainstorming design challenge gate"
```

Expected: commit succeeds and reports one modified file.

---

### Task 3: Add The Claude CLI Reviewer Prompt Template

**Files:**
- Create: `skills/brainstorming/design-challenge-reviewer-prompt.md`

- [ ] **Step 1: Create the prompt template**

Apply this patch:

```diff
*** Begin Patch
*** Add File: skills/brainstorming/design-challenge-reviewer-prompt.md
+# Design Challenge Reviewer Prompt Template
+
+Use this template when running the local `claude` CLI to challenge a written brainstorming spec.
+
+**Purpose:** Challenge the design before the user reviews the written spec. Look for design risks that would materially affect implementation planning.
+
+**Run after:** The spec document is written and the main session's spec self-review has passed.
+
+**Run with:** `exec_command`, invoking the local `claude` CLI.
+
+## Review Packet
+
+Before invoking `claude`, prepare a packet with these fields:
+
+- Spec file path
+- Current spec content
+- User-confirmed key decisions
+- Approaches considered and not selected, with reasons
+- Design success criteria
+- Review focus areas: scope, ambiguity, over-engineering, missing error handling, and risks for later implementation planning
+
+## Reviewer Role
+
+You are an external design challenger. Your job is to stress-test the design, not to rewrite it or bikeshed wording.
+
+Challenge the design for:
+
+| Category | What to Look For |
+| --- | --- |
+| Scope | Multiple independent efforts hidden inside one spec, or a scope too large for one implementation plan |
+| Ambiguity | Requirements that could lead two implementers to build different behavior |
+| Missing decisions | Product, workflow, data, error, or review decisions that the main session must settle before planning |
+| Over-engineering | Abstractions, review loops, files, or commands that add ceremony without reducing real risk |
+| Error handling | Failure modes that would leave the workflow stuck, silent, or misleading |
+| Planning risk | Gaps that would make a later implementation plan vague, brittle, or untestable |
+
+## Calibration
+
+Only flag issues that can materially affect design quality or implementation planning. Minor wording preferences, style edits, and nice-to-have refinements are advisory only.
+
+Approve the design if the remaining concerns are small enough for implementation planning to handle safely.
+
+## Output Format
+
+## Design Challenge Review
+
+**Status:** Approved | Issues Found
+
+**Blocking Issues:**
+- Section or decision: specific issue - why it must be resolved before user spec review
+
+**Challenges:**
+- Section or decision: challenge - what the main session should accept, rebut, or ask the user to decide
+
+**Advisory:**
+- Suggestion - why it may help, without blocking progression
+
+**Summary:**
+One short paragraph describing the design's readiness for user review.
+
+## Main Session Follow-Up
+
+The main session must handle every blocking issue and challenge before asking the user to review the spec:
+
+- Accept: revise the spec, rerun spec self-review, and rerun this external challenge if the design materially changed.
+- Rebut: explain in the conversation why the spec stays unchanged.
+- Escalate: ask the user when the feedback exposes a product or scope decision the main session should not decide alone.
*** End Patch
```

- [ ] **Step 2: Verify the template exists and has the required sections**

Run:

```bash
rg -n "Design Challenge Reviewer|Review Packet|Reviewer Role|Output Format|Main Session Follow-Up" skills/brainstorming/design-challenge-reviewer-prompt.md
```

Expected: output includes all five section names.

- [ ] **Step 3: Commit the prompt template**

Run:

```bash
git add skills/brainstorming/design-challenge-reviewer-prompt.md
git commit -m "docs: add design challenge reviewer prompt"
```

Expected: commit succeeds and reports one new file.

---

### Task 4: Verify The Full Change

**Files:**
- Inspect: `skills/brainstorming/SKILL.md`
- Inspect: `skills/brainstorming/design-challenge-reviewer-prompt.md`
- Test: `tests/brainstorm-server/package.json`

- [ ] **Step 1: Check the workflow text is internally consistent**

Run:

```bash
rg -n "External design challenge|External Design Challenge|design-challenge-reviewer-prompt|User Review Gate|Spec Self-Review" skills/brainstorming/SKILL.md
```

Expected: output includes:

```text
External design challenge
External Design Challenge
design-challenge-reviewer-prompt.md
Spec Self-Review
User Review Gate
```

- [ ] **Step 2: Check the review packet stays design-focused**

Run:

```bash
rg -n "Codex-only|Codex tool|tool mapping" skills/brainstorming/design-challenge-reviewer-prompt.md
```

Expected: no output and exit code 1, because the prompt template should not include project execution constraints such as:

```text
Codex-only
Codex tool
tool mapping
```

Run:

```bash
rg -n -F \
  -e 'Spec file path' \
  -e 'Current spec content' \
  -e 'User-confirmed key decisions' \
  -e 'Approaches considered and not selected, with reasons' \
  -e 'Design success criteria' \
  -e 'Review focus areas: scope, ambiguity, over-engineering, missing error handling, and risks for later implementation planning' \
  skills/brainstorming/design-challenge-reviewer-prompt.md
```

Expected: output includes the packet list fields.

- [ ] **Step 3: Check the skill includes the concrete Claude CLI command**

Run:

```bash
rg -n -F \
  -e 'claude --print --permission-mode plan --output-format text' \
  -e '--append-system-prompt "$(cat skills/brainstorming/design-challenge-reviewer-prompt.md)"' \
  -e '< /tmp/brainstorming-design-review-packet.md' \
  skills/brainstorming/SKILL.md
```

Expected: output includes the non-interactive `claude --print` command shape, the `--append-system-prompt` reference to `skills/brainstorming/design-challenge-reviewer-prompt.md`, and the temporary packet stdin path.

- [ ] **Step 4: Run the existing brainstorm-server regression suite**

Run:

```bash
cd tests/brainstorm-server
npm test
```

Expected: npm test exits successfully with all brainstorm-server tests passing.

- [ ] **Step 5: Confirm working tree state**

Run:

```bash
git status --short
```

Expected: no uncommitted implementation changes remain. The plan document may be uncommitted if it was created before execution.
