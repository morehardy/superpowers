# Brainstorming External Design Challenge

Date: 2026-05-15
Status: Approved design

## Context

The `brainstorming` skill currently turns an idea into an approved design, writes
the design spec, runs a local spec self-review, asks the user to review the spec,
and then transitions to `writing-plans`.

This Codex-only fork should keep Codex plugin metadata and Codex workflow tools,
but the brainstorming flow can still call the local `claude` CLI as an external
reviewer. This is a command-line design challenge step, not a Claude Code plugin
entrypoint or cross-harness compatibility layer.

## Goals

- Add an independent external design challenge after the written spec exists.
- Keep the existing `Spec self-review` step unchanged.
- Give the external reviewer enough explicit context to challenge the design
  without relying on hidden chat transcript state.
- Require the main session to accept, revise, or rebut each substantive issue.
- Pause and ask the user what to do if the `claude` CLI review cannot run.

## Non-Goals

- Do not replace the existing `Spec self-review` checklist.
- Do not reintroduce Claude Code plugin entrypoints or maintain Claude-specific
  harness documentation.
- Do not pass Codex tool mapping or Codex-only project constraints inside the
  external review packet.
- Do not add automated tests for skill prose unless the repository grows an
  existing pattern for skill text validation.

## Workflow

The brainstorming terminal flow becomes:

1. Explore project context.
2. Offer visual companion if visual questions are expected.
3. Ask clarifying questions.
4. Propose approaches.
5. Present and validate the design with the user.
6. Write the design doc.
7. Run existing spec self-review and fix issues inline.
8. Run external design challenge with `claude` CLI.
9. Ask the user to review the written spec.
10. Transition to `writing-plans` after user approval.

The new step sits between `Spec self-review` and `User reviews written spec`.
It is a gate for design quality, not implementation.

## Review Packet

Before calling `claude`, the main session prepares a structured review packet
containing:

- The spec file path.
- The current spec content.
- User-confirmed key decisions.
- Approaches considered and not selected, with reasons.
- The design's success criteria.
- Review focus areas: scope, ambiguity, over-engineering, missing error
  handling, and risks for later implementation planning.

The packet intentionally excludes Codex tool mapping and Codex-only fork
constraints. Those remain instructions for the main session, not design-review
inputs for the external reviewer.

## Claude CLI Review

Add a new prompt template:

`skills/brainstorming/design-challenge-reviewer-prompt.md`

The template should instruct the external reviewer to challenge the design and
return structured output:

- `Status: Approved | Issues Found`
- Blocking issues that must be resolved before user spec review.
- Design challenges that deserve an explicit accept-or-rebut response.
- Advisory suggestions that do not block progression.

The reviewer should only flag issues that can materially affect design quality
or implementation planning. Minor wording preferences and stylistic edits should
not block approval.

## Handling Review Results

For each substantive external review item, the main session must do one of:

- Accept the issue, revise the spec, then rerun spec self-review. Rerun the
  external challenge when the accepted change materially alters the design.
- Rebut the issue in the conversation with a concrete reason, leaving the spec
  unchanged.
- Ask the user when the feedback exposes a product or scope decision that the
  main session should not decide alone.

If `claude` is not installed, times out, returns a non-zero exit code, or
otherwise fails, the main session must pause and ask the user whether to retry,
skip the external challenge, or choose another review path.

## Files To Change

- `skills/brainstorming/SKILL.md`
  - Add the `External design challenge` checklist item.
  - Update the DOT process flow to include the new node.
  - Add an `External Design Challenge` section under `After the Design`.
- `skills/brainstorming/design-challenge-reviewer-prompt.md`
  - Add the prompt template, packet shape, reviewer calibration, and output
    format.

## Verification

- Check that the checklist, process flow, and `After the Design` prose all place
  the new gate between `Spec self-review` and user spec review.
- Check that the new prompt template describes a CLI reviewer task without
  adding a Claude Code plugin entrypoint.
- Check that the review packet does not include Codex tool mapping or Codex-only
  project constraints.
- Use this request as a realistic walkthrough: design approval, spec writing,
  spec self-review, `claude` CLI challenge, user spec review, then
  `writing-plans`.
- Run the existing brainstorm-server tests after implementation to confirm the
  visual companion test fixture was not affected.

## Test Impact

The current automated tests cover the visual brainstorming companion server and
websocket behavior. They do not assert `SKILL.md` workflow prose. This change
does not require test file updates. Existing tests should still be run after the
implementation as a regression check.
