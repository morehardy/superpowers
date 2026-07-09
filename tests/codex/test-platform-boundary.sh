#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

python3 - "$REPO_ROOT" <<'PY'
import os
import re
import sys
from pathlib import Path

repo = Path(sys.argv[1])

removed_paths = [
    ".claude-plugin",
    ".cursor-plugin",
    ".kimi-plugin",
    ".opencode",
    ".pi",
    ".github",
    "hooks",
    "CLAUDE.md",
    "GEMINI.md",
    "CODE_OF_CONDUCT.md",
    "RELEASE-NOTES.md",
    "docs/README.kimi.md",
    "docs/README.opencode.md",
    "docs/porting-to-a-new-harness.md",
    "docs/windows",
    "gemini-extension.json",
    "package.json",
]
for rel in removed_paths:
    path = repo / rel
    if path.exists():
        raise AssertionError(f"removed path still exists: {rel}")

expected_skills = [
    "brainstorming",
    "dispatching-parallel-agents",
    "executing-plans",
    "finishing-a-development-branch",
    "receiving-code-review",
    "requesting-code-review",
    "subagent-driven-development",
    "systematic-debugging",
    "test-driven-development",
    "using-git-worktrees",
    "using-superpowers",
    "verification-before-completion",
    "writing-plans",
]
actual_skills = sorted(
    path.name for path in (repo / "skills").iterdir() if path.is_dir()
)
if actual_skills != expected_skills:
    raise AssertionError(
        "top-level skill directories differ:\n"
        f"expected: {expected_skills}\n"
        f"actual:   {actual_skills}"
    )

actual_tests = sorted(
    path.name for path in (repo / "tests").iterdir() if path.is_dir()
)
if actual_tests != ["brainstorm-server", "codex"]:
    raise AssertionError(
        "top-level test directories differ:\n"
        "expected: ['brainstorm-server', 'codex']\n"
        f"actual:   {actual_tests}"
    )

scan_roots = [
    repo / "README.md",
    repo / "AGENTS.md",
    repo / "skills",
    repo / "tests",
]
excluded = {
    repo / "tests" / "codex" / "test-platform-boundary.sh",
}

platform_pattern = re.compile(
    r"(\bClaude Code\b|\bClaude\b|\bclaude\b|\bCursor\b|\bGemini\b|"
    r"\bOpenCode\b|\bCopilot\b|\bKimi\b|\bAntigravity\b|\bDroid\b|"
    r"(?<![A-Za-z])Pi(?![A-Za-z])|"
    r"\.claude\b|\.cursor\b|\.opencode\b|\.kimi\b|\.pi\b)"
)

external_prompt_files = {
    repo / "skills" / "brainstorming" / "design-challenge-reviewer-prompt.md",
    repo / "skills" / "writing-plans" / "plan-challenge-reviewer-prompt.md",
    repo / "skills" / "finishing-a-development-branch" / "implementation-audit-reviewer-prompt.md",
}

external_reviewer_host_skills = {
    repo / "skills" / "brainstorming" / "SKILL.md",
    repo / "skills" / "writing-plans" / "SKILL.md",
    repo / "skills" / "finishing-a-development-branch" / "SKILL.md",
}

explicit_removed_lines = {
    "AGENTS.md": [
        "- Do not maintain Claude Code, Cursor, Gemini, OpenCode, Copilot, or Droid plugin entrypoints.",
    ],
    "README.md": [
        "- Claude Code, Cursor, Gemini, OpenCode, Copilot, and Droid entrypoints.",
        "Lowercase `claude` CLI references are an external reviewer backend, not Claude Code platform support.",
    ],
}

package_test_allowed_fragments = [
    "FORBIDDEN_ARCHIVE_PATHS",
    "forbidden_archive_paths",
    "CLAUDE.md",
    "GEMINI.md",
    ".claude-plugin",
    ".cursor-plugin",
    ".kimi-plugin",
    ".opencode",
    ".pi",
]

prompt_filename_fragments = [
    "design-challenge-reviewer-prompt.md",
    "plan-challenge-reviewer-prompt.md",
    "implementation-audit-reviewer-prompt.md",
]

def allowed(rel: str, path: Path, line: str) -> bool:
    if path in external_prompt_files and "`claude` CLI" in line:
        return True
    if path in external_prompt_files and "invoking `claude`" in line:
        return True
    if path in external_prompt_files and "claude --bare --print --no-session-persistence" in line:
        return True

    if path in external_reviewer_host_skills and "`claude`" in line:
        return True
    if path in external_reviewer_host_skills and "claude --bare --print --no-session-persistence" in line:
        return True

    if line in explicit_removed_lines.get(rel, []):
        return True

    if rel == "tests/codex/test-package-codex-plugin.sh":
        return any(fragment in line for fragment in package_test_allowed_fragments)

    if any(fragment in line for fragment in prompt_filename_fragments):
        return True

    return False

violations = []
for root in scan_roots:
    paths = [root] if root.is_file() else [
        path for path in root.rglob("*") if path.is_file()
    ]
    for path in paths:
        if path in excluded:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        rel = path.relative_to(repo).as_posix()
        for line_no, line in enumerate(text.splitlines(), 1):
            if not platform_pattern.search(line):
                continue
            if allowed(rel, path, line):
                continue
            violations.append(f"{rel}:{line_no}: {line}")

if violations:
    print("\n".join(violations), file=sys.stderr)
    raise SystemExit("Unexpected active non-Codex platform reference remains.")

print("Codex-only platform boundary looks good")
PY
