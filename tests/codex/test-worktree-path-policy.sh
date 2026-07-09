#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

USING_SKILL="$REPO_ROOT/skills/using-git-worktrees/SKILL.md"
FINISHING_SKILL="$REPO_ROOT/skills/finishing-a-development-branch/SKILL.md"

FAILURES=0

pass() {
  echo "  [PASS] $1"
}

fail() {
  echo "  [FAIL] $1"
  FAILURES=$((FAILURES + 1))
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if grep -Fq "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label"
    echo "    expected to find: $pattern"
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if grep -Fq "$pattern" "$file"; then
    fail "$label"
    echo "    did not expect to find: $pattern"
  else
    pass "$label"
  fi
}

echo "=== Worktree Path Policy Test ==="
echo ""

assert_not_contains "$USING_SKILL" "~/.config/superpowers/worktrees" "using-git-worktrees does not mention old global path"
assert_not_contains "$USING_SKILL" "global legacy" "using-git-worktrees does not mention global legacy"
assert_not_contains "$USING_SKILL" "Global path" "using-git-worktrees has no Global path row"
assert_contains "$USING_SKILL" 'default to `.worktrees/` at the project root' "using-git-worktrees defaults to project-local .worktrees/"

assert_not_contains "$FINISHING_SKILL" "~/.config/superpowers/worktrees" "finishing skill does not mention old global path"
assert_contains "$FINISHING_SKILL" '`.worktrees/` or `worktrees/`' "finishing skill limits cleanup ownership to project-local worktrees"

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  echo "STATUS: FAILED ($FAILURES failures)"
  exit 1
fi

echo "STATUS: PASSED"
