# Finishing Implementation Audit

Date: 2026-05-16
Status: Approved design

## Context

This Codex-only Superpowers fork already has external `claude` CLI challenge
gates for design specs and implementation plans. Those gates review intended
work before implementation begins.

After implementation, the current completion path relies on local tests,
subagent reviews when the subagent-driven flow is used, and the
`finishing-a-development-branch` workflow. There is no single external audit
that reviews the final repository state against the approved plan and spec
before the user is offered merge, PR, keep, or discard options.

## Goals

- Add a final external implementation audit to `finishing-a-development-branch`.
- Run the audit after local tests pass and before the finishing menu is shown.
- Cover both subagent-driven and inline execution paths by placing the gate in
  the shared finishing workflow.
- Use the local `claude` CLI as an external reviewer that may inspect the
  repository, not only a prebuilt text packet.
- Check whether the final implementation aligns with the implementation plan
  and source spec, and whether it introduces material issues.
- Require Critical and Important audit findings to be fixed, technically
  rebutted, or escalated to the user before continuing.
- Treat Minor and Advisory findings as non-blocking, while still recording or
  summarizing them.
- Make any user-approved skip explicit as a waived audit, not a passed audit.

## Non-Goals

- Do not replace local test verification. Tests still run first and must pass.
- Do not replace per-task subagent spec or code-quality reviews.
- Do not add Claude Code, Cursor, Gemini, OpenCode, Copilot, or Droid
  entrypoints.
- Do not add new runtime dependencies.
- Do not block finishing on Minor or Advisory feedback.
- Do not silently grant mutation authority to the external reviewer.

## Decisions

- The audit gate lives in `skills/finishing-a-development-branch/SKILL.md`.
- The reviewer policy lives in
  `skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md`.
- The audit runs after Step 1 test verification succeeds and before environment
  detection and completion options.
- The `claude` CLI is allowed to inspect the repository. The command should not
  use `--tools ""`, because this audit depends on repository access.
- The reviewer must be instructed to operate read-only. The main session should
  inspect repository status after the audit if there is any sign that the
  reviewer mutated files.
- Critical and Important findings are blocking. Minor and Advisory findings are
  non-blocking.

## Workflow

The `finishing-a-development-branch` workflow becomes:

1. Verify the project's test suite passes.
2. Run the external implementation audit.
3. If the audit passes, continue to environment detection.
4. Present the existing merge, PR, keep, or discard options.
5. Execute the selected finishing path.

If the audit returns Critical or Important findings:

- Accept valid findings by fixing the implementation.
- Rerun the relevant tests.
- Rerun the external implementation audit.
- Rebut invalid findings with concrete code, diff, or test evidence.
- Escalate findings that expose a product, scope, or plan interpretation
  decision the main session should not decide alone.

If accepted changes trigger two total audit reruns for the same implementation
and blocking findings remain, stop and ask the user how to proceed instead of
continuing to revise and rerun indefinitely.

## Audit Inputs

Before invoking `claude`, the main session prepares a concise Markdown audit
packet. The packet should include:

- Repository root.
- Base SHA and head SHA for the implementation range.
- Implementation plan file path.
- Source spec file path, when it can be identified from the plan or session
  context.
- Latest test command and a concise summary of the passing output.
- User-confirmed implementation goal.
- Review focus areas.

The packet should not need to include full file contents, because the reviewer
may inspect the repository. It should give the reviewer enough context to know
what to inspect and which range to compare.

Use this packet structure:

```markdown
# External Implementation Audit Packet

## Repository Root
[absolute path]

## Git Range
Base: [sha]
Head: [sha]

## Implementation Plan
[path]

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

## Claude CLI Invocation

The implementation should verify that the prompt file is readable and the audit
packet exists before invoking `claude`.

The command shape should run from the repository root, allow repository
inspection, and preserve the established non-interactive style:

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

Do not pass `--tools ""` for this audit. The external reviewer should be able
to read files and inspect diffs. The prompt must instruct the reviewer not to
edit files, run mutating commands, commit, stage, push, or change branches.

## Reviewer Prompt Requirements

Add
`skills/finishing-a-development-branch/implementation-audit-reviewer-prompt.md`.

The prompt should tell the external reviewer to inspect the repository and
challenge the final implementation for:

- Plan and spec alignment.
- Missing requirements.
- Unplanned or excessive scope.
- Implementation bugs or regressions.
- Test gaps or weak test evidence.
- Code quality issues that materially affect readiness.
- Any sign that generated files, lockfiles, or metadata changed unexpectedly.

The reviewer should return structured output:

```markdown
## Implementation Audit Review

**Status:** Approved | Issues Found

**Critical:**
- [issue or None]

**Important:**
- [issue or None]

**Minor:**
- [issue or None]

**Advisory:**
- [suggestion or None]

**Plan Alignment:**
[short assessment]

**Test Evidence:**
[short assessment]

**Summary:**
[short readiness assessment]
```

Critical means the implementation is unsafe or materially wrong. Important
means the implementation should not proceed to finishing without a fix or
explicit rebuttal. Minor and Advisory items do not block finishing.

## Output Validation And Failure Handling

The main session must treat the audit output as unusable if it is missing:

- A `Status:` line.
- `Critical`, `Important`, `Minor`, `Advisory`, `Plan Alignment`,
  `Test Evidence`, or `Summary` sections.
- A consistent status.

`Approved` is inconsistent if Critical or Important contains anything other
than `None`. `Issues Found` is inconsistent if all issue sections are `None` or
empty.

If `claude` is missing, times out, exits non-zero, or returns unusable output,
pause and ask the user whether to retry, skip the external audit, or choose
another review path. If the user chooses to skip, explicitly record that the
external implementation audit was waived by the user. Do not describe a waived
audit as passed.

## Testing And Verification

Implementation verification should stay lean:

- Use `rg` to confirm `skills/finishing-a-development-branch/SKILL.md`
  contains the new gate after test verification and before completion options.
- Use `rg` to confirm the skill text documents Critical and Important as
  blocking, Minor and Advisory as non-blocking, user-approved skip handling,
  audit rerun limits, and the prompt path.
- Use `rg` to confirm the new prompt file contains the audit focus areas and
  required output sections.
- Run `npm test` in `tests/brainstorm-server`.
- Run `bash tests/codex/test-sdd-integration-script-behavior.sh`.
- Run `bash tests/codex/test-subagent-driven-development-integration.sh` and
  expect a safe skip unless `RUN_CODEX_INTEGRATION=1` is set.
- If the local `claude` CLI is available, perform a read-only dry-run audit
  against the current repository to validate the command shape. If it is not
  available, record that limitation instead of claiming the audit command was
  verified.
