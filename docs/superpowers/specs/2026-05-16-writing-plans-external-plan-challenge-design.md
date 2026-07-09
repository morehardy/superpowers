# Writing Plans External Plan Challenge

Date: 2026-05-16
Status: Approved design

## Context

The `writing-plans` skill currently turns an approved design spec into a
detailed implementation plan, runs a local plan self-review, saves the plan, and
then asks the user to choose an execution path.

The `brainstorming` skill already uses the local `claude` CLI as an external
challenge step after spec self-review. The plan-writing flow should use the
same command-line review pattern after the plan is written, but the reviewer
must challenge implementation-plan quality rather than design quality.

## Goals

- Add an independent external plan challenge after the implementation plan is
  written and self-reviewed.
- Reuse the existing `claude` CLI pattern from the brainstorming external design
  challenge.
- Keep the existing `Self-Review` checklist unchanged.
- Require the main session to accept, revise, rebut, or escalate every
  substantive external review item.
- Modify the plan until there are no unresolved blocking issues or challenges
  before asking the user to review or execute it.
- Treat malformed or contradictory `claude` review output as an external review
  failure instead of silently passing the gate.
- Pause and ask the user what to do if the `claude` CLI review cannot run.
- Make any user-approved skip of the external challenge explicit in the
  conversation; a skip waives the gate but is not the same as a passed challenge.

## Non-Goals

- Do not reuse the design-challenge prompt directly; plan review checks a
  different artifact and needs plan-specific criteria.
- Do not replace the existing `Self-Review` checklist.
- Do not introduce a subagent-based reviewer for this gate.
- Do not reintroduce Claude Code plugin entrypoints or cross-harness
  compatibility files.
- Do not add automated tests for skill prose unless the repository grows an
  existing pattern for validating skill text.

## Workflow

The `writing-plans` flow becomes:

1. Map file structure and responsibilities.
2. Write the implementation plan to
   `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`.
3. Run existing plan self-review and fix issues inline.
4. Run external plan challenge with the local `claude` CLI.
5. Validate that the external review output has the expected structured
   sections and a consistent status.
6. Accept, revise, rebut, or escalate every substantive item.
7. If accepted changes materially alter the plan, rerun plan self-review and
   rerun the external plan challenge.
8. Once there are no unresolved blocking issues or challenges, offer execution
   options to the user.

The new gate sits between `Self-Review` and `Execution Handoff`. It is a gate
for plan readiness, not implementation.

## Review Packet

Before calling `claude`, the main session prepares a structured review packet
containing:

- The plan file path.
- The current plan content.
- The source spec file path.
- The current source spec content. Use the full spec by default; if the spec
  exceeds 20,000 words as measured by `wc -w`, include the goals, workflow,
  requirements, files, verification, and test-impact sections, then list any
  omitted sections by heading.
- Confirmed planning inputs that shape the plan. This includes decisions from
  the approved source spec, explicit user constraints stated during planning,
  and any execution mode the user selected before the plan challenge runs. The
  main session must not invent implied user decisions for this field.
- Execution assumptions, including whether the plan is intended for
  subagent-driven execution, inline execution, or both. These terms refer to
  the two execution options in the `writing-plans` skill's `Execution Handoff`
  section: subagent-driven means fresh implementation and reviewer subagents per
  task; inline execution means the current session executes the plan with
  checkpoints. Because `writing-plans` normally creates the plan before asking
  the user to choose an execution path, the default packet value is `both`
  unless the user explicitly chose or requested one execution mode before the
  plan challenge runs.
- Review focus areas: spec coverage, task decomposition, dependency order, TDD
  correctness, exact file paths, command validity, expected output clarity,
  placeholder content, and implementation risks.

The packet should reuse the temporary stdin-file pattern from the brainstorming
design challenge, but the packet content must stay focused on plan readiness.
It should not include unrelated environment details, Codex tool mapping, or
hidden chat transcript state.

The packet should use this Markdown section structure so the skill instructions
and reviewer prompt agree:

```markdown
# External Plan Challenge Packet

## Plan File Path
[path]

## Current Plan Content
[full plan content]

## Source Spec File Path
[path]

## Source Spec Content
[full spec content or documented excerpt]

## Confirmed Planning Inputs
- Decision: [short decision summary]
  Source: [source spec section, direct user statement, or explicit planning constraint]

## Execution Assumption
subagent-driven | inline | both

## Review Focus Areas
- [focus area]
```

The reviewer prompt should use the execution assumption when challenging the
plan. For subagent-driven execution, the reviewer should look for task-local
context, clear file ownership, and handoff artifacts that a fresh worker can
use. For inline execution, the reviewer should look for checkpoint boundaries
and commands that let the current session verify progress safely. When the
execution assumption is `both`, the reviewer should label mode-specific issues
as `subagent-driven`, `inline`, or `both` so the main session can resolve or
rebut them without reopening unrelated concerns.

## Claude CLI Review

Add a new prompt template:

`skills/writing-plans/plan-challenge-reviewer-prompt.md`

The implementation of this feature must create the prompt file before the
`writing-plans` skill references it in its external challenge instructions.
After this feature lands, every future invocation of the `writing-plans`
external plan challenge must verify that the prompt file exists and is readable
before invoking `claude`.

This feature has a one-time bootstrap boundary: the new external plan challenge
gate does not apply retroactively to the implementation plan that creates the
gate, because `plan-challenge-reviewer-prompt.md` does not exist until that
implementation runs. The implementation plan for this feature should still
include the full prompt content and verification steps so the first future use
of `writing-plans` can run the gate normally.

The template should instruct the external reviewer to challenge the plan and
return structured output:

- `Status: Approved | Issues Found`
- Blocking issues that must be resolved before execution handoff.
- Plan challenges that deserve an explicit accept-or-rebut response.
- Advisory suggestions that do not block progression.

The reviewer should only flag issues that can materially affect implementation:
missing spec requirements, vague steps, invalid ordering, impossible commands,
undefined files or symbols, weak test/fail/pass loops, excessive scope, or task
decomposition that would make execution brittle. Minor wording preferences and
stylistic edits should not block approval.

The prompt template should define each plan-review focus area in implementation
terms:

- Spec coverage: every requirement in the source spec maps to at least one plan
  task, and the plan does not add unrelated scope.
- Task decomposition: each task has a clear boundary, an explicit file set, and
  steps small enough for a worker to execute without guessing.
- Dependency order: earlier tasks create files, APIs, fixtures, or decisions
  that later tasks rely on.
- TDD correctness: implementation tasks put failing tests before code, name the
  exact command to run, state the expected failure, then state the expected pass.
- Exact file paths: files, commands, and references use concrete repository
  paths instead of invented or unresolved names.
- Command validity: commands are runnable from the stated working directory and
  have concrete expected output.
- Expected output clarity: verification steps say what pass and fail look like,
  not just that the command should be run.
- Placeholder content: the plan has no `TBD`, `TODO`, `FIXME`, unresolved
  bracket variables, "similar to previous task", or vague instructions such as
  "add appropriate handling."
- Implementation risks: the plan names ordering, integration, testing, or
  review risks that could make execution brittle.

The implementation plan for this change must include the full intended content
of `skills/writing-plans/plan-challenge-reviewer-prompt.md`, including these
focus-area definitions. The prompt file should not be invented separately during
implementation. Verification must compare the prompt file against the focus
areas in this spec.

The prompt file should contain this policy content. This code block is the
authoritative source of truth for the prompt's review behavior; surrounding
narrative explains why it exists. Wording changes are acceptable only when they
preserve the same review behavior:

```markdown
# Plan Challenge Reviewer Prompt Template

Use this template when running the local `claude` CLI to challenge a written
implementation plan.

**Purpose:** Challenge the implementation plan before the user reviews or
executes it. Look for plan defects that would cause an implementer to build the
wrong thing, get stuck, skip verification, or make brittle changes.

**Run after:** The implementation plan is written and the main session's plan
self-review has passed.

**Run with:** The local `claude` CLI in isolated, non-interactive mode.

## Review Packet

Expect a Markdown packet with these sections:

- Plan file path
- Current plan content
- Source spec file path
- Source spec content
- Confirmed planning inputs
- Execution assumption: `subagent-driven`, `inline`, or `both`
- Review focus areas

The reviewer has no tool access and cannot inspect the workspace. Review the
text in the packet only. Do not claim that files exist or commands pass; instead
check whether paths are concrete, commands are plausible from the stated working
directory, and verification expectations are explicit.

## Reviewer Role

You are an external plan challenger. Stress-test the plan; do not rewrite it,
execute it, or bikeshed wording.

Challenge the plan for:

| Category | What to Look For |
| --- | --- |
| Spec coverage | Every source-spec requirement maps to a plan task, and the plan does not add unrelated scope |
| Task decomposition | Each task has a clear boundary, explicit file set, and steps small enough for a worker to execute without guessing |
| Dependency order | Earlier tasks create files, APIs, fixtures, or decisions that later tasks rely on |
| TDD correctness | Implementation tasks put failing tests before code, name the exact command to run, state the expected failure, then state the expected pass |
| Exact file paths | Files, commands, and references use concrete repository paths instead of invented or unresolved names |
| Command validity | Commands are runnable from the stated working directory and have concrete expected output |
| Expected output clarity | Verification steps say what pass and fail look like, not just that the command should be run |
| Placeholder content | The plan has no `TBD`, `TODO`, `FIXME`, unresolved bracket variables, "similar to previous task", or vague instructions such as "add appropriate handling" |
| Implementation risks | The plan names ordering, integration, testing, or review risks that could make execution brittle |

When the execution assumption is `subagent-driven`, check whether each task has
enough task-local context, clear ownership, and handoff artifacts for a fresh
worker. When it is `inline`, check whether the plan has sensible checkpoint
boundaries and verification commands for the current session. When it is `both`,
label mode-specific findings as `subagent-driven`, `inline`, or `both`.

## Calibration

Only flag issues that can materially affect implementation. Minor wording
preferences, style edits, and nice-to-have improvements are advisory only.

Approve the plan if remaining concerns are small enough for execution to handle
safely.

## Output Format

## Plan Challenge Review

**Status:** Approved | Issues Found

If a section has no items, write `None` under that section.

**Blocking Issues:**
- Task or section: specific issue - why it must be resolved before execution handoff

**Challenges:**
- Task or section: challenge - what the main session should accept, rebut, or ask the user to decide

**Advisory:**
- Suggestion - why it may help, without blocking progression

**Summary:**
One short paragraph describing the plan's readiness for user review or
execution.

## Main Session Follow-Up

The main session must handle every blocking issue and challenge before asking
the user to review or execute the plan:

- Accept: revise the plan, rerun plan self-review, and rerun this external
  challenge if the plan materially changed.
- Rebut: explain in the conversation why the plan stays unchanged.
- Escalate: ask the user when feedback exposes a product, scope, or execution
  decision the main session should not decide alone.
```

The `claude` invocation should follow this pinned command shape, adapted only
for absolute paths and the temporary packet filename:

```bash
reviewer_prompt="/absolute/path/to/skills/writing-plans/plan-challenge-reviewer-prompt.md"
packet="/absolute/path/to/populated-plan-review-packet.md"
test -r "$reviewer_prompt" || { echo "Reviewer prompt unreadable: $reviewer_prompt" >&2; exit 1; }
test -s "$packet" || { echo "Review packet missing or empty: $packet" >&2; exit 1; }
cd /tmp && claude --bare --print --no-session-persistence --permission-mode plan --tools "" --output-format text \
  --append-system-prompt "$(cat "$reviewer_prompt")" \
  < "$packet"
```

The `--tools ""` flag is intentional: the external reviewer should operate in
isolated review-only mode and should not inspect or mutate the workspace.

## Handling Review Results

For each substantive external review item, the main session must do one of:

- Accept the issue, revise the plan, rerun plan self-review, and rerun the
  external challenge if the accepted change materially alters the plan.
- Rebut the issue in the conversation with a concrete reason, leaving the plan
  unchanged.
- Ask the user when the feedback exposes a product, scope, or implementation
  strategy decision that the main session should not decide alone.

The main session must not offer execution options while unresolved blocking
issues or challenges remain.

A plan change materially alters the plan when it changes task count, task
boundaries, dependency order, target files, commands, expected test outcomes,
acceptance criteria, or execution strategy. Minor wording edits, typo fixes, or
clarifications that do not change what an implementer would do do not require a
fresh external challenge.

If `claude` is not installed, times out, returns a non-zero exit code, or
otherwise fails, the main session must pause and ask the user whether to retry,
skip the external challenge, or choose another review path.

The current plan content should be sent in full. If the plan exceeds 20,000
words as measured by `wc -w`, the main session must pause before invoking
`claude` and ask the user whether to split the plan, proceed with an oversized
review attempt, or choose another review path. The main session must not
silently excerpt the plan being challenged.

If `claude` exits successfully but returns unusable output, the main session
must also treat the review as failed and pause for user direction. Unusable
output includes a missing `Status`, missing required sections, contradictory
status and issue content, or unstructured text that does not let the main
session identify blocking issues, challenges, and advisory notes.

The minimum output validation is intentionally simple:

- Required text: a `Status:` line, plus `Blocking Issues:`, `Challenges:`,
  `Advisory:`, and `Summary:` section headings.
- Valid status values: `Approved` or `Issues Found`.
- `Approved` is inconsistent if either `Blocking Issues` or `Challenges`
  contains an item other than `None`.
- `Issues Found` is inconsistent if both `Blocking Issues` and `Challenges`
  are `None` or empty.
- Formatting differences such as extra blank lines or additional Markdown
  heading markers do not matter if the required labels and section contents are
  identifiable.

If the user chooses to skip after a failed or unusable external challenge, the
main session may proceed only by explicitly recording in the conversation that
the external challenge was waived by the user. It must not describe the external
challenge as passed.

Advisory items do not require accept, rebut, or escalation. The main session may
apply them opportunistically, mention them briefly, or ignore them when they do
not affect plan readiness.

The review loop must not run silently forever. A rebutted item is considered
handled and does not by itself require another external challenge. If accepted
changes trigger two total external challenge reruns for the same plan and
unresolved substantive issues remain, the main session must escalate to the user
instead of continuing to revise and rerun indefinitely. Failed runs caused by
missing `claude`, timeout, non-zero exit, or unusable output do not count toward
this rerun limit; they follow the failure path that asks the user whether to
retry, skip, or choose another review path.

## Files To Change

- `skills/writing-plans/SKILL.md`
  - Add the external plan challenge requirement after `Self-Review`.
  - Add a concrete `claude` CLI command shape matching the brainstorming
    design-challenge style.
  - Require the main session to verify that
    `skills/writing-plans/plan-challenge-reviewer-prompt.md` exists and is
    readable before invoking `claude`.
  - Update `Execution Handoff` so it happens only after self-review and the
    external plan challenge pass.
- `skills/writing-plans/plan-challenge-reviewer-prompt.md`
  - Add the prompt template, packet shape, reviewer calibration, output format,
    and main-session follow-up rules.

## Verification

- Check that `skills/writing-plans/SKILL.md` places the new gate between
  `Self-Review` and `Execution Handoff`.
- Check that the new prompt is plan-specific and does not directly reuse the
  design-challenge criteria.
- Check that the command shape uses the local `claude` CLI in isolated,
  non-interactive mode with a temporary stdin packet and a prompt path resolved
  relative to the loaded skill.
- Check that the follow-up rules require the plan to be modified and challenged
  again until no unresolved blocking issues or challenges remain.
- Check that malformed or contradictory successful `claude` output is treated
  as a review failure.
- Check that user-approved skips are recorded as waived external challenges,
  not passed external challenges.
- Check that the prompt file contains the focus-area definitions from this spec.
- Check that the prompt file preserves the inline prompt policy content from
  this spec.
- Check that this feature's one-time implementation includes manual
  verification of the new `SKILL.md` instructions and prompt file, since the new
  gate does not apply retroactively to the plan that creates it.

## Manual Smoke Test

Use this request as a realistic manual walkthrough: design approval, spec
writing, spec self-review, external design challenge, user spec review, then
`writing-plans` for implementation planning.

## Test Impact

The repository's current automated tests cover the brainstorming visual
companion server and Codex subagent integration scripts. They do not assert
`SKILL.md` workflow prose. This change does not require test file updates.
Existing tests should still be run after implementation as a regression check
because this change touches skill workflow documentation.
