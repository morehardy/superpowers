#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/package-codex-plugin.sh"

FAILURES=0
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
  echo "  [PASS] $1"
}

fail() {
  echo "  [FAIL] $1"
  FAILURES=$((FAILURES + 1))
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label"
    echo "    expected to find: $needle"
  fi
}

assert_not_matches() {
  local haystack="$1"
  local pattern="$2"
  local label="$3"

  if printf '%s' "$haystack" | grep -Eq -- "$pattern"; then
    fail "$label"
    echo "    did not expect to match: $pattern"
  else
    pass "$label"
  fi
}

assert_equals() {
  local actual="$1"
  local expected="$2"
  local label="$3"

  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

write_metadata_fixture() {
  local destination="$1"
  local skill

  while IFS= read -r skill; do
    mkdir -p "$destination/skills/$skill/agents"
    {
      echo "interface:"
      echo "  display_name: \"$skill\""
      echo "  short_description: \"Fixture metadata for $skill\""
    } > "$destination/skills/$skill/agents/openai.yaml"
  done < <(find "$REPO_ROOT/skills" -mindepth 1 -maxdepth 1 -type d -print | sed 's#.*/##' | sort)
}

list_archive() {
  unzip -Z1 "$1" | sed 's#/$##' | LC_ALL=C sort
}

read_archive_file() {
  unzip -p "$1" "$2"
}

echo "Codex package script contract tests"

metadata_source="$TEST_ROOT/metadata-source"
archive="$TEST_ROOT/superpowers.zip"
extracted="$TEST_ROOT/extracted"
write_metadata_fixture "$metadata_source"

if output="$("$SCRIPT_UNDER_TEST" --allow-dirty --metadata-source "$metadata_source" --output "$archive" 2>&1)"; then
  pass "package script exits successfully"
else
  fail "package script exits successfully"
  printf '%s\n' "$output" | sed 's/^/      /'
fi

archive_exists=0
if [[ -f "$archive" ]]; then
  archive_exists=1
  pass "package script writes zip archive"
else
  fail "package script writes zip archive"
fi

assert_contains "$output" "Archive:" "reports archive path"
assert_contains "$output" "Version:" "reports version"
assert_contains "$output" "Entries:" "reports entry count"
assert_contains "$output" "Skills:" "reports skill count"
assert_contains "$output" "SHA-256:" "reports archive checksum"

archive_paths=""
if [[ "$archive_exists" -eq 1 ]]; then
  mkdir -p "$extracted"
  unzip -q "$archive" -d "$extracted"
  archive_paths="$(list_archive "$archive")"
fi

FORBIDDEN_ARCHIVE_PATHS='(^tests/|^docs/|^hooks/|^scripts/|^package\.json$|^AGENTS\.md$|^CODE_OF_CONDUCT\.md$|^CLAUDE\.md$|^GEMINI\.md$|^RELEASE-NOTES\.md$|^\.claude-plugin/|^\.cursor-plugin/|^\.kimi-plugin/|^\.opencode/|^\.pi/)'
assert_not_matches "$archive_paths" "$FORBIDDEN_ARCHIVE_PATHS" "archive excludes source-only and non-Codex paths"

assert_contains "$archive_paths" ".codex-plugin/plugin.json" "archive includes Codex manifest"
assert_contains "$archive_paths" "README.md" "archive includes README"
assert_contains "$archive_paths" "LICENSE" "archive includes LICENSE"
assert_contains "$archive_paths" "assets/app-icon.png" "archive includes assets"
assert_contains "$archive_paths" "skills/brainstorming/SKILL.md" "archive includes skills"

if [[ "$archive_exists" -eq 1 ]]; then
  manifest_summary="$(
    read_archive_file "$archive" .codex-plugin/plugin.json |
      python3 -c 'import json,sys; data=json.load(sys.stdin); print("\t".join([data["name"], data["version"], data["skills"], str(data.get("hooks"))]))'
  )"
  assert_equals "$manifest_summary" "superpowers	6.1.1	./skills/	{}" "archive manifest has expected Codex fields"
else
  fail "archive manifest has expected Codex fields"
fi

if [[ "$archive_exists" -eq 1 ]]; then
  skill_count="$(find "$extracted/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  metadata_count="$(find "$extracted/skills" -path '*/agents/openai.yaml' -type f | wc -l | tr -d ' ')"
  assert_equals "$metadata_count" "$skill_count" "every packaged skill has agents/openai.yaml"
else
  fail "every packaged skill has agents/openai.yaml"
fi

incomplete_metadata="$TEST_ROOT/incomplete-metadata"
mkdir -p "$incomplete_metadata/skills/brainstorming/agents"
cp "$metadata_source/skills/brainstorming/agents/openai.yaml" \
  "$incomplete_metadata/skills/brainstorming/agents/openai.yaml"

set +e
missing_output="$("$SCRIPT_UNDER_TEST" --allow-dirty --metadata-source "$incomplete_metadata" --output "$TEST_ROOT/missing.zip" 2>&1)"
missing_status=$?
set -e
if [[ "$missing_status" -ne 0 ]]; then
  pass "package script rejects incomplete metadata source"
else
  fail "package script rejects incomplete metadata source"
fi
if printf '%s' "$missing_output" | grep -Eq 'metadata source is incomplete|Missing OpenAI agent metadata'; then
  pass "incomplete metadata reports clear error"
else
  fail "incomplete metadata reports clear error"
  printf '%s\n' "$missing_output" | sed 's/^/      /'
fi

set +e
missing_arg_output="$("$SCRIPT_UNDER_TEST" --allow-dirty --output "$TEST_ROOT/no-metadata.zip" 2>&1)"
missing_arg_status=$?
set -e
if [[ "$missing_arg_status" -ne 0 ]]; then
  pass "package script requires explicit --metadata-source"
else
  fail "package script requires explicit --metadata-source"
fi
assert_contains "$missing_arg_output" "Missing required --metadata-source PATH" "missing metadata source reports required flag"

if [[ "$FAILURES" -eq 0 ]]; then
  echo "Codex package script looks good"
else
  echo "$FAILURES Codex package script contract test(s) failed"
  exit 1
fi
