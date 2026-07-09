#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD_SCRIPTS="$REPO_ROOT/skills/subagent-driven-development/scripts"

FAILURES=0
TEST_ROOT=""

pass() {
  echo "  [PASS] $1"
}

fail() {
  echo "  [FAIL] $1"
  FAILURES=$((FAILURES + 1))
}

cleanup() {
  if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
    rm -rf "$TEST_ROOT"
  fi
}

main() {
  echo "=== Test: sdd-workspace ==="

  TEST_ROOT="$(mktemp -d)"
  trap cleanup EXIT

  git init -q -b main "$TEST_ROOT/repo"
  local repo
  repo="$(cd "$TEST_ROOT/repo" && git rev-parse --show-toplevel)"

  local dir
  dir="$(cd "$repo" && "$SDD_SCRIPTS/sdd-workspace")"
  if [[ "$dir" == "$repo/.superpowers/sdd" ]]; then
    pass "sdd-workspace prints <repo-root>/.superpowers/sdd"
  else
    fail "sdd-workspace prints <repo-root>/.superpowers/sdd"
    echo "    got: $dir"
  fi

  if [[ -f "$repo/.superpowers/sdd/.gitignore" && "$(cat "$repo/.superpowers/sdd/.gitignore")" == "*" ]]; then
    pass ".superpowers/sdd/.gitignore contains *"
  else
    fail ".superpowers/sdd/.gitignore contains *"
  fi

  printf 'artifact\n' > "$repo/.superpowers/sdd/artifact.md"
  local status
  status="$(cd "$repo" && git status --porcelain)"
  if [[ -z "$status" ]]; then
    pass "workspace artifacts are invisible to git status"
  else
    fail "workspace artifacts are invisible to git status"
    echo "    status: $status"
  fi

  (cd "$repo" && git add -A)
  local staged
  staged="$(cd "$repo" && git diff --cached --name-only)"
  if [[ -z "$staged" ]]; then
    pass "git add -A does not stage workspace artifacts"
  else
    fail "git add -A does not stage workspace artifacts"
    echo "    staged: $staged"
  fi

  apply_plan_fixture "$repo/plan.md"

  local brief_out brief_path
  brief_out="$(cd "$repo" && "$SDD_SCRIPTS/task-brief" plan.md 1)"
  brief_path="$(printf '%s\n' "$brief_out" | sed -n 's/^wrote \(.*\): [0-9][0-9]* lines$/\1/p')"
  case "$brief_path" in
    "$repo/.superpowers/sdd/"*) pass "task-brief writes under .superpowers/sdd" ;;
    *)
      fail "task-brief writes under .superpowers/sdd"
      echo "    got: $brief_path"
      ;;
  esac

  local git_id=(-c user.email=t@example.com -c user.name=t -c commit.gpgsign=false)
  (
    cd "$repo"
    git add plan.md
    git "${git_id[@]}" commit -qm c1
    printf 'change\n' > file.txt
    git add file.txt
    git "${git_id[@]}" commit -qm c2
  )

  local package_out package_path
  package_out="$(cd "$repo" && "$SDD_SCRIPTS/review-package" HEAD~1 HEAD)"
  package_path="$(printf '%s\n' "$package_out" | sed -n 's/^wrote \(.*\): [0-9].*$/\1/p')"
  case "$package_path" in
    "$repo/.superpowers/sdd/"*) pass "review-package writes under .superpowers/sdd" ;;
    *)
      fail "review-package writes under .superpowers/sdd"
      echo "    got: $package_path"
      ;;
  esac

  local worktree="$TEST_ROOT/worktree"
  (cd "$repo" && git worktree add -q "$worktree" -b wt-feature)
  local worktree_root worktree_dir
  worktree_root="$(cd "$worktree" && git rev-parse --show-toplevel)"
  worktree_dir="$(cd "$worktree" && "$SDD_SCRIPTS/sdd-workspace")"
  if [[ "$worktree_dir" == "$worktree_root/.superpowers/sdd" && "$worktree_dir" != "$dir" ]]; then
    pass "linked worktree gets a distinct .superpowers/sdd workspace"
  else
    fail "linked worktree gets a distinct .superpowers/sdd workspace"
    echo "    main: $dir"
    echo "    worktree: $worktree_dir"
  fi

  printf 'artifact\n' > "$worktree/.superpowers/sdd/artifact.md"
  local worktree_status
  worktree_status="$(cd "$worktree" && git status --porcelain)"
  if [[ -z "$worktree_status" ]]; then
    pass "linked worktree workspace is invisible to git status"
  else
    fail "linked worktree workspace is invisible to git status"
    echo "    status: $worktree_status"
  fi

  echo ""
  if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failures)"
    exit 1
  fi
  echo "STATUS: PASSED"
}

apply_plan_fixture() {
  local path="$1"
  {
    echo "# Plan"
    echo ""
    echo "## Task 1: First thing"
    echo ""
    echo "Do the first thing."
  } > "$path"
}

main "$@"
