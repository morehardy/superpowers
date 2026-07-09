# Codex-Only Superpowers

This is a personal Codex-focused fork of Superpowers.

## Scope

- Keep Codex plugin metadata, core skills, and Codex tool mapping.
- Do not maintain Claude Code, Cursor, Gemini, OpenCode, Copilot, or Droid plugin entrypoints.
- Prefer Codex tool names in new guidance:
  - task tracking: `update_plan`
  - subagents: `spawn_agent`, `wait_agent`, `close_agent`
  - shell: `exec_command`
  - file edits: `apply_patch`

## Working Rules

- Keep skills general-purpose and useful across coding projects.
- Avoid adding third-party runtime dependencies unless they are already required by a kept test fixture.
- When changing skill behavior, verify the affected flow with a realistic Codex session when possible.
- Keep this fork lean: remove platform compatibility files as soon as they stop serving Codex.

