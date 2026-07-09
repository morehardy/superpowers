#!/usr/bin/env bash
# Unit-level checks for the Codex SDD integration test wrapper.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/test-subagent-driven-development-integration.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/superpowers-codex-script-test.XXXXXX")"
FAILED=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

pass() {
  echo "PASS: $1"
}

fail() {
  echo "FAIL: $1"
  FAILED=$((FAILED + 1))
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if grep -q "$pattern" "$file"; then
    pass "$description"
  else
    fail "$description"
    echo "Expected pattern: $pattern"
    echo "Output:"
    sed -n '1,220p' "$file"
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if grep -q "$pattern" "$file"; then
    fail "$description"
    echo "Unexpected pattern: $pattern"
    echo "Output:"
    sed -n '1,220p' "$file"
  else
    pass "$description"
  fi
}

make_success_fake_codex() {
  local fake_codex="$1"

  cat > "$fake_codex" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--version" ]]; then
  echo "OpenAI Codex fake"
  exit 0
fi

if [[ "${1:-}" != "exec" ]]; then
  echo "unexpected fake codex command: $*" >&2
  exit 64
fi

shift
sandbox=""
workdir="$PWD"

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --sandbox)
      sandbox="${2:-}"
      shift 2
      ;;
    --cd)
      workdir="${2:-}"
      shift 2
      ;;
    --*)
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "$sandbox" != "workspace-write" ]]; then
  echo "fake codex expected --sandbox workspace-write, got '${sandbox:-unset}'" >&2
  exit 42
fi

cd "$workdir"
echo "sandbox: workspace-write"
echo "collab: SpawnAgent"

cat > src/math.js <<'JS'
export function add(a, b) {
  return a + b;
}
JS

cat > test/math.test.js <<'JS'
import assert from 'node:assert/strict';
import { add } from '../src/math.js';

assert.equal(add(2, 3), 5);
assert.equal(add(0, 0), 0);
assert.equal(add(-1, 1), 0);
console.log('math tests passed');
JS

git add src/math.js test/math.test.js
git commit -m "feat: add addition" --quiet

cat > src/math.js <<'JS'
export function add(a, b) {
  return a + b;
}

export function multiply(a, b) {
  return a * b;
}
JS

cat > test/math.test.js <<'JS'
import assert from 'node:assert/strict';
import { add, multiply } from '../src/math.js';

assert.equal(add(2, 3), 5);
assert.equal(add(0, 0), 0);
assert.equal(add(-1, 1), 0);
assert.equal(multiply(2, 3), 6);
assert.equal(multiply(0, 5), 0);
assert.equal(multiply(-2, 3), -6);
console.log('math tests passed');
JS

git add src/math.js test/math.test.js
git commit -m "feat: add multiplication" --quiet

cat <<'SUMMARY'
CODEX_SDD_INTEGRATION_SUMMARY
skill used: fake subagent-driven-development
subagents dispatched: yes
task reviewer: yes
workspace: .superpowers/sdd
tests pass: yes
final commit count: 2
SUMMARY
FAKE

  chmod +x "$fake_codex"
}

make_no_files_fake_codex() {
  local fake_codex="$1"

  cat > "$fake_codex" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--version" ]]; then
  echo "OpenAI Codex fake"
  exit 0
fi

if [[ "${1:-}" != "exec" ]]; then
  echo "unexpected fake codex command: $*" >&2
  exit 64
fi

echo "sandbox: workspace-write"
echo "collab: SpawnAgent"
cat <<'SUMMARY'
CODEX_SDD_INTEGRATION_SUMMARY
skill used: fake subagent-driven-development
subagents dispatched: yes
task reviewer: no
workspace: .superpowers/sdd
tests pass: no
final commit count: 0
SUMMARY
FAKE

  chmod +x "$fake_codex"
}

echo "Running Codex SDD integration wrapper behavior tests..."
echo ""

success_fake="$TMP_ROOT/fake-codex-success"
success_output="$TMP_ROOT/success-output.txt"
make_success_fake_codex "$success_fake"

if RUN_CODEX_INTEGRATION=1 CODEX_BIN="$success_fake" CODEX_TIMEOUT_SECONDS=30 bash "$TARGET_SCRIPT" >"$success_output" 2>&1; then
  assert_contains "$success_output" "STATUS: PASSED" "successful fake Codex run passes"
  assert_contains "$success_output" "subagent-driven-development" "successful fake output records SDD skill"
  assert_contains "$success_output" "task reviewer" "successful fake output records task reviewer"
  assert_contains "$success_output" ".superpowers/sdd" "successful fake output records SDD workspace"
  assert_contains "$success_output" "tests pass: yes" "successful fake output records passing tests"
else
  fail "successful fake Codex run passes"
  sed -n '1,260p' "$success_output"
fi

echo ""

no_files_fake="$TMP_ROOT/fake-codex-no-files"
no_files_output="$TMP_ROOT/no-files-output.txt"
make_no_files_fake_codex "$no_files_fake"

if RUN_CODEX_INTEGRATION=1 CODEX_BIN="$no_files_fake" CODEX_TIMEOUT_SECONDS=30 bash "$TARGET_SCRIPT" >"$no_files_output" 2>&1; then
  fail "fake Codex run without generated files fails"
  sed -n '1,260p' "$no_files_output"
else
  pass "fake Codex run without generated files fails"
fi

assert_contains "$no_files_output" "FAIL: fixture tests pass" "missing test file makes fixture tests fail"
assert_not_contains "$no_files_output" "PASS: fixture tests pass" "missing test file is not reported as passing tests"

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "STATUS: PASSED"
  exit 0
else
  echo "STATUS: FAILED ($FAILED checks failed)"
  exit 1
fi
