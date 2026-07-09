---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring skill invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## The Rule

Invoke relevant or requested skills before any response or action, including clarifying questions, exploring the codebase, or checking files. If the selected skill turns out to be wrong for the situation, stop using it and continue with the right workflow.

Before entering plan mode, invoke the brainstorming skill first unless the current work already has an approved spec or the user explicitly directs otherwise.

Announce the skill and purpose in one short sentence, then follow the skill exactly. If a skill has a checklist, create an `update_plan` item for each checklist item.

## Skill Priority

When multiple skills apply, use process skills first because they define the approach. Implementation skills come after the approach is clear.

- "Let's build X" -> use superpowers:brainstorming first, then implementation skills.
- "Fix this bug" -> use superpowers:systematic-debugging first, then domain skills.
- "Execute this plan" -> use superpowers:subagent-driven-development when subagents are available, otherwise use superpowers:executing-plans.

## Red Flags

These thoughts mean STOP because you are rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes before clarifying questions. |
| "Let me explore the codebase first" | Skills tell you how to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you how to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read the current version. |
| "This doesn't count as a task" | Action is a task. Check for skills. |
| "I'll just do this one thing first" | Check before doing anything. |
| "I know what that means" | Knowing the concept is not the same as using the skill. |

## Platform Adaptation

This fork is Codex-only. Read `references/codex-tools.md` when a skill describes an action and you need the Codex-native tool name.

Use Codex-native tools in active guidance:

- Task tracking: `update_plan`
- Spawn subagent: `spawn_agent`
- Collect subagent result: `wait_agent`
- Close finished subagent: `close_agent`
- Shell command: `exec_command`
- Manual file edits: `apply_patch`

Do not add or maintain other platform mapping files in this fork.

## User Instructions

User instructions, including `AGENTS.md` and direct requests, take precedence over skills. Skills override default behavior only where they do not conflict with the user's explicit instructions.
