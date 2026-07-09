#!/usr/bin/env bash
# Integration Test: Codex subagent-driven-development workflow
#
# This is an opt-in end-to-end test. It runs a real Codex session against a
# throwaway project and verifies that the plan produces working code, tests,
# and multiple commits.
#
# Usage:
#   RUN_CODEX_INTEGRATION=1 bash tests/codex/test-subagent-driven-development-integration.sh
#
# Optional:
#   CODEX_BIN=/path/to/codex
#   CODEX_INTEGRATION_SANDBOX=workspace-write
#   CODEX_TIMEOUT_SECONDS=1800
#   CODEX_INTEGRATION_KEEP=1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CODEX_BIN="${CODEX_BIN:-codex}"
CODEX_INTEGRATION_SANDBOX="${CODEX_INTEGRATION_SANDBOX:-workspace-write}"
CODEX_TIMEOUT_SECONDS="${CODEX_TIMEOUT_SECONDS:-1800}"
RUN_CODEX_INTEGRATION="${RUN_CODEX_INTEGRATION:-0}"
KEEP_PROJECT="${CODEX_INTEGRATION_KEEP:-0}"

echo "========================================"
echo " Codex Integration Test: SDD workflow"
echo "========================================"
echo ""

if [[ "$RUN_CODEX_INTEGRATION" != "1" ]]; then
  echo "SKIP: set RUN_CODEX_INTEGRATION=1 to run the real Codex end-to-end test."
  exit 0
fi

if ! command -v "$CODEX_BIN" >/dev/null 2>&1; then
  echo "SKIP: Codex CLI not found: $CODEX_BIN"
  exit 0
fi

case "$CODEX_INTEGRATION_SANDBOX" in
  workspace-write|danger-full-access)
    ;;
  *)
    echo "FAIL: Codex integration requires a writable sandbox."
    echo "Set CODEX_INTEGRATION_SANDBOX=workspace-write or CODEX_INTEGRATION_SANDBOX=danger-full-access."
    echo "Current CODEX_INTEGRATION_SANDBOX: $CODEX_INTEGRATION_SANDBOX"
    exit 1
    ;;
esac

probe_codex_cli() {
  local output_file
  local status
  output_file="$(mktemp "${TMPDIR:-/tmp}/superpowers-codex-probe.XXXXXX")"

  set +e
  "$CODEX_BIN" --version >"$output_file" 2>&1 &
  local probe_pid=$!

  local timed_out=1
  for _ in {1..100}; do
    if ! kill -0 "$probe_pid" 2>/dev/null; then
      timed_out=0
      break
    fi
    sleep 0.1
  done

  if [[ "$timed_out" -eq 1 ]]; then
    kill "$probe_pid" 2>/dev/null || true
    wait "$probe_pid" 2>/dev/null || true
    set -e
    echo "FAIL: Codex CLI preflight timed out while running: $CODEX_BIN --version"
    echo "Try CODEX_BIN=/path/to/a/working/codex or reinstall Codex."
    rm -f "$output_file"
    exit 1
  fi

  wait "$probe_pid"
  status=$?
  set -e

  if [[ "$status" -ne 0 ]]; then
    echo "FAIL: Codex CLI preflight failed while running: $CODEX_BIN --version"
    echo ""
    cat "$output_file"
    echo ""

    if grep -q "ENOENT" "$output_file" && grep -q "vendor/.*codex/codex" "$output_file"; then
      echo "Detected a broken @openai/codex npm install: the Node wrapper exists,"
      echo "but the platform-native Codex binary is missing from the optional package."
      echo ""
      echo "Try one of:"
      echo "  npm install -g @openai/codex@latest"
      echo "  CODEX_BIN=/absolute/path/to/a/working/codex RUN_CODEX_INTEGRATION=1 bash $0"
    fi

    rm -f "$output_file"
    exit 1
  fi

  rm -f "$output_file"
}

probe_codex_cli

run_with_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$CODEX_TIMEOUT_SECONDS" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$CODEX_TIMEOUT_SECONDS" "$@"
  else
    "$@"
  fi
}

TEST_PROJECT="$(mktemp -d "${TMPDIR:-/tmp}/superpowers-codex-sdd.XXXXXX")"
OUTPUT_FILE="$TEST_PROJECT/codex-output.txt"

cleanup() {
  if [[ "$KEEP_PROJECT" != "1" && -n "${TEST_PROJECT:-}" && -d "$TEST_PROJECT" ]]; then
    rm -rf "$TEST_PROJECT"
  else
    echo "Keeping test project: $TEST_PROJECT"
  fi
}
trap cleanup EXIT

echo "Test project: $TEST_PROJECT"
echo "Plugin checkout: $REPO_ROOT"
echo ""

cd "$TEST_PROJECT"

cat > package.json <<'JSON'
{
  "name": "codex-sdd-integration-fixture",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node test/math.test.js"
  }
}
JSON

mkdir -p src test docs/superpowers/plans

cat > docs/superpowers/plans/implementation-plan.md <<'PLAN'
# Test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a tiny math module with tests.

**Architecture:** Keep all exports in `src/math.js`. Tests live in `test/math.test.js` and use Node's built-in test runner.

**Tech Stack:** Node.js ESM, `assert/strict`.

---

### Task 1: Create Add Function

**Files:**
- Create: `src/math.js`
- Create: `test/math.test.js`

- [ ] **Step 1: Write the failing add tests**

```javascript
import assert from 'node:assert/strict';
import { add } from '../src/math.js';

assert.equal(add(2, 3), 5);
assert.equal(add(0, 0), 0);
assert.equal(add(-1, 1), 0);
console.log('math tests passed');
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test`
Expected: FAIL because `src/math.js` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```javascript
export function add(a, b) {
  return a + b;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/math.js test/math.test.js
git commit -m "feat: add addition"
```

### Task 2: Create Multiply Function

**Files:**
- Modify: `src/math.js`
- Modify: `test/math.test.js`

- [ ] **Step 1: Write the failing multiply tests**

Add this to `test/math.test.js`:

```javascript
import { multiply } from '../src/math.js';

assert.equal(multiply(2, 3), 6);
assert.equal(multiply(0, 5), 0);
assert.equal(multiply(-2, 3), -6);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test`
Expected: FAIL because `multiply` is not exported yet.

- [ ] **Step 3: Write minimal implementation**

Add this to `src/math.js`:

```javascript
export function multiply(a, b) {
  return a * b;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/math.js test/math.test.js
git commit -m "feat: add multiplication"
```
PLAN

git init --quiet
git config user.email "codex-test@example.com"
git config user.name "Codex Integration Test"
git add .
git commit -m "Initial fixture" --quiet

PROMPT="Use the local Superpowers skills from $REPO_ROOT.

First read $REPO_ROOT/skills/using-superpowers/SKILL.md, then execute docs/superpowers/plans/implementation-plan.md using superpowers:subagent-driven-development.

Use Codex-native tools when the skills mention legacy names:
- update_plan for task tracking
- spawn_agent / wait_agent / close_agent for subagents

Follow the plan exactly. Do not add extra math functions. Run the specified tests and commit each task.

At the end, print a block starting with CODEX_SDD_INTEGRATION_SUMMARY and include:
- skill used
- whether subagents were dispatched
- whether the task reviewer was used
- whether .superpowers/sdd was used for handoff artifacts
- whether tests pass
- final commit count"

echo "Running Codex integration. This can take a while..."
echo "Codex sandbox: $CODEX_INTEGRATION_SANDBOX"
echo ""

cd "$TEST_PROJECT"
if ! run_with_timeout "$CODEX_BIN" exec --sandbox "$CODEX_INTEGRATION_SANDBOX" --cd "$TEST_PROJECT" "$PROMPT" 2>&1 | tee "$OUTPUT_FILE"; then
  echo ""
  echo "FAIL: Codex execution failed. Output saved to: $OUTPUT_FILE"
  exit 1
fi

echo ""
echo "Analyzing Codex integration result..."
echo ""

failed=0

check_pass() {
  echo "  PASS: $1"
}

check_fail() {
  echo "  FAIL: $1"
  failed=$((failed + 1))
}

if [[ -f "$TEST_PROJECT/src/math.js" ]]; then
  check_pass "src/math.js exists"
else
  check_fail "src/math.js exists"
fi

if grep -q "export function add" "$TEST_PROJECT/src/math.js" 2>/dev/null; then
  check_pass "add function exported"
else
  check_fail "add function exported"
fi

if grep -q "export function multiply" "$TEST_PROJECT/src/math.js" 2>/dev/null; then
  check_pass "multiply function exported"
else
  check_fail "multiply function exported"
fi

if [[ -f "$TEST_PROJECT/test/math.test.js" ]]; then
  check_pass "test/math.test.js exists"
else
  check_fail "test/math.test.js exists"
fi

if [[ ! -f "$TEST_PROJECT/test/math.test.js" ]]; then
  check_fail "fixture tests pass"
elif npm test > "$TEST_PROJECT/final-test-output.txt" 2>&1; then
  if grep -q 'math tests passed' "$TEST_PROJECT/final-test-output.txt"; then
    check_pass "fixture tests pass"
  else
    check_fail "fixture tests pass"
    echo "Test marker was not printed:"
    cat "$TEST_PROJECT/final-test-output.txt"
  fi
else
  check_fail "fixture tests pass"
  cat "$TEST_PROJECT/final-test-output.txt"
fi

commit_count="$(git -C "$TEST_PROJECT" log --oneline | wc -l | tr -d ' ')"
if [[ "$commit_count" -ge 3 ]]; then
  check_pass "multiple commits created ($commit_count total)"
else
  check_fail "multiple commits created (got $commit_count, expected >= 3)"
fi

if grep -q "CODEX_SDD_INTEGRATION_SUMMARY" "$OUTPUT_FILE"; then
  check_pass "Codex printed integration summary"
else
  check_fail "Codex printed integration summary"
fi

if grep -qi "subagent" "$OUTPUT_FILE"; then
  check_pass "output mentions subagent workflow"
else
  check_fail "output mentions subagent workflow"
fi

if grep -qi "task reviewer" "$OUTPUT_FILE"; then
  check_pass "output mentions task reviewer"
else
  check_fail "output mentions task reviewer"
fi

if grep -q ".superpowers/sdd" "$OUTPUT_FILE"; then
  check_pass "output mentions .superpowers/sdd workspace"
else
  check_fail "output mentions .superpowers/sdd workspace"
fi

if grep -qi "tests pass: yes" "$OUTPUT_FILE"; then
  check_pass "output reports tests pass: yes"
else
  check_fail "output reports tests pass: yes"
fi

if grep -q "export function divide\|export function power\|export function subtract" "$TEST_PROJECT/src/math.js" 2>/dev/null; then
  check_fail "no extra math functions were added"
else
  check_pass "no extra math functions were added"
fi

echo ""
if [[ "$failed" -eq 0 ]]; then
  echo "STATUS: PASSED"
  exit 0
else
  echo "STATUS: FAILED ($failed checks failed)"
  echo "Output saved to: $OUTPUT_FILE"
  exit 1
fi
