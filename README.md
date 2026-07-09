# Superpowers for Codex

This is a personal Codex-only fork of Superpowers: a compact set of coding-agent skills for planning, TDD, debugging, review, and delivery workflows.

The upstream project supports many agent harnesses. This fork intentionally keeps only the Codex plugin manifest, Codex tool mapping, shared skill content, and the small visual brainstorming companion.

## What Is Kept

- `.codex-plugin/plugin.json` - Codex plugin metadata.
- `.agents/plugins/marketplace.json` - Local Codex marketplace entry for this development checkout.
- `skills/` - Core workflow skills.
- `skills/using-superpowers/references/codex-tools.md` - Codex tool mapping.
- `scripts/package-codex-plugin.sh` - Portal archive packaging for the Codex plugin.
- `assets/` - Plugin icon assets.
- `tests/brainstorm-server/` - Tests for the visual brainstorming companion server.
- `tests/codex/` - Codex-only contract tests for platform boundary, packaging, SDD, and worktree policy.

## What Was Removed

The non-Codex platform entrypoints and tests are removed.

- Claude Code, Cursor, Gemini, OpenCode, Copilot, and Droid entrypoints.
- Cross-platform hook wrappers.
- Non-Codex install docs and historical platform design docs.
- Harness-specific test suites that require non-Codex CLIs.
- The `writing-skills` meta-skill and Anthropic-oriented skill-writing references.

Lowercase `claude` CLI references are an external reviewer backend, not Claude Code platform support.

## Basic Workflow

1. **using-superpowers** - Establishes the rule that relevant skills are loaded before acting.
2. **brainstorming** - Turns rough ideas into approved designs before implementation.
3. **using-git-worktrees** - Creates or verifies an isolated workspace when needed.
4. **writing-plans** - Produces detailed implementation plans with exact files, commands, and verification.
5. **subagent-driven-development** or **executing-plans** - Implements the plan.
   - SDD task review uses one reviewer for both spec-compliance and task-quality verdicts.
   - SDD uses one task reviewer that returns both spec-compliance and task-quality verdicts, plus a final whole-branch review.
   - SDD handoff artifacts live under `.superpowers/sdd`.
6. **test-driven-development** - Enforces red/green/refactor for feature work and bug fixes.
7. **requesting-code-review** and **receiving-code-review** - Review and respond to feedback.
8. **verification-before-completion** and **finishing-a-development-branch** - Prove the work is complete and decide how to finish.

## Codex Tool Mapping

The skills may still use workflow terms from their original form. In this fork, map them to Codex tools:

| Skill term | Codex tool |
| --- | --- |
| `TodoWrite` | `update_plan` |
| `Task` / subagent dispatch | `spawn_agent` |
| task result | `wait_agent` |
| close completed agent | `close_agent` |
| shell command | `exec_command` |
| file edit | `apply_patch` |

See `skills/using-superpowers/references/codex-tools.md` for details.

## Testing

Run the Codex contract tests:

```bash
bash tests/codex/test-platform-boundary.sh
bash tests/codex/test-sdd-integration-script-behavior.sh
bash tests/codex/test-sdd-workspace.sh
bash tests/codex/test-worktree-path-policy.sh
bash tests/codex/test-marketplace-manifest.sh
bash tests/codex/test-package-codex-plugin.sh
```

Run the visual brainstorming companion tests:

```bash
cd tests/brainstorm-server
npm test
```

That test fixture has its own `package.json` and `package-lock.json`.

The Codex subagent-driven-development integration test is opt-in because it
runs a real Codex session and can take a while:

```bash
RUN_CODEX_INTEGRATION=1 bash tests/codex/test-subagent-driven-development-integration.sh
```

The script launches Codex with `--sandbox workspace-write` by default so the
throwaway fixture can create files and commits. To override that, set
`CODEX_INTEGRATION_SANDBOX=workspace-write` or
`CODEX_INTEGRATION_SANDBOX=danger-full-access`. Without
`RUN_CODEX_INTEGRATION=1`, the script exits with an explicit skip.

The wrapper behavior has a fast fake-Codex test:

```bash
bash tests/codex/test-sdd-integration-script-behavior.sh
```

## Packaging

Build a portal upload archive with an explicit metadata source:

```bash
scripts/package-codex-plugin.sh --metadata-source PATH --output superpowers.zip
```

`--metadata-source PATH` must be a directory containing `skills/<skill>/agents/openai.yaml` for every packaged skill. The archive includes only `.codex-plugin/`, `README.md`, `LICENSE`, `assets/`, and `skills/`.

## Installation

Install or load this repository as a Codex plugin using the local plugin flow you prefer. The plugin manifest lives at `.codex-plugin/plugin.json` and points Codex at `./skills/`.

## License

MIT License. Original project by Jesse Vincent and contributors.
