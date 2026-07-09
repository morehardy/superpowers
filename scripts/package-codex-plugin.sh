#!/usr/bin/env bash
#
# Package the Superpowers Codex plugin as a rootless zip archive for portal upload.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REF="HEAD"
OUTPUT=""
METADATA_SOURCE=""
ALLOW_DIRTY=0
KEEP_STAGE=0

usage() {
  cat <<'EOF'
Usage:
  scripts/package-codex-plugin.sh [options]

Options:
  --output PATH            Write zip archive to PATH.
                           Default: ../_tmp/sup-codex-packaging/superpowers-VERSION.zip
  --metadata-source PATH   Required metadata directory containing skills/<skill>/agents/openai.yaml.
  --ref REF                Git ref to package. Default: HEAD.
  --allow-dirty            Permit a dirty working tree. The archive still uses --ref.
  --keep-stage             Print and keep the temporary staging directory.
  -h, --help               Show this help.

The archive is rootless and contains only .codex-plugin/, LICENSE, README.md,
assets/, and skills/. Source-only files, tests, docs, hooks, scripts, and
non-Codex plugin entrypoints are intentionally not shipped.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ $# -ge 2 ]] || die "--output requires a path"
      OUTPUT="$2"
      shift 2
      ;;
    --metadata-source)
      [[ $# -ge 2 ]] || die "--metadata-source requires a path"
      METADATA_SOURCE="$2"
      shift 2
      ;;
    --ref)
      [[ $# -ge 2 ]] || die "--ref requires a value"
      REF="$2"
      shift 2
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    --keep-stage)
      KEEP_STAGE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

command -v git >/dev/null || die "git not found in PATH"
command -v python3 >/dev/null || die "python3 not found in PATH"
command -v zip >/dev/null || die "zip not found in PATH"
command -v unzip >/dev/null || die "unzip not found in PATH"
command -v shasum >/dev/null || die "shasum not found in PATH"
command -v tar >/dev/null || die "tar not found in PATH"

git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null ||
  die "repo root is not a git checkout: $REPO_ROOT"
git -C "$REPO_ROOT" rev-parse --verify "$REF^{commit}" >/dev/null ||
  die "git ref does not resolve to a commit: $REF"

if [[ -z "$METADATA_SOURCE" ]]; then
  die "Missing required --metadata-source PATH"
fi
if [[ ! -d "$METADATA_SOURCE" ]]; then
  die "metadata source must be a directory: $METADATA_SOURCE"
fi
METADATA_SOURCE="$(cd "$METADATA_SOURCE" && pwd)"

if [[ "$ALLOW_DIRTY" -ne 1 ]]; then
  dirty_status="$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all)"
  if [[ -n "$dirty_status" ]]; then
    echo "Working tree has uncommitted changes:" >&2
    printf '%s\n' "$dirty_status" | sed 's/^/  /' >&2
    die "commit or stash changes first, or pass --allow-dirty to package $REF anyway"
  fi
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/superpowers-codex-package.XXXXXX")"
STAGE="$WORK_DIR/payload"
ARCHIVE_LIST="$WORK_DIR/archive-list"

cleanup() {
  if [[ "$KEEP_STAGE" -eq 1 ]]; then
    echo "Keeping staging directory: $WORK_DIR" >&2
  else
    rm -rf "$WORK_DIR"
  fi
}
trap cleanup EXIT

mkdir -p "$STAGE"

git -C "$REPO_ROOT" archive --format=tar "$REF" -- \
  .codex-plugin \
  LICENSE \
  README.md \
  assets \
  skills \
  | tar -xf - -C "$STAGE"

VERSION="$(
  python3 - "$STAGE/.codex-plugin/plugin.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get("version", ""))
PY
)"
[[ -n "$VERSION" ]] || die "could not read version from .codex-plugin/plugin.json"

if [[ -z "$OUTPUT" ]]; then
  OUTPUT="$REPO_ROOT/../_tmp/sup-codex-packaging/superpowers-$VERSION.zip"
fi
mkdir -p "$(dirname "$OUTPUT")"
OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"

missing_metadata=0
while IFS= read -r skill_dir; do
  skill_name="${skill_dir##*/}"
  metadata_file="$METADATA_SOURCE/skills/$skill_name/agents/openai.yaml"

  if [[ ! -f "$metadata_file" ]]; then
    echo "Missing OpenAI agent metadata for skill: $skill_name" >&2
    missing_metadata=1
    continue
  fi

  mkdir -p "$skill_dir/agents"
  cp "$metadata_file" "$skill_dir/agents/openai.yaml"
done < <(find "$STAGE/skills" -mindepth 1 -maxdepth 1 -type d -print | sort)

if [[ "$missing_metadata" -ne 0 ]]; then
  die "metadata source is incomplete"
fi

skill_count="$(find "$STAGE/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
metadata_count="$(find "$STAGE/skills" -path '*/agents/openai.yaml' -type f | wc -l | tr -d ' ')"
[[ "$skill_count" == "$metadata_count" ]] ||
  die "metadata count mismatch: $metadata_count metadata files for $skill_count skills"

(
  cd "$STAGE"
  {
    find . -mindepth 1 -type d | sed 's#^\./##' | LC_ALL=C sort
    find . -mindepth 1 -type f | sed 's#^\./##' | LC_ALL=C sort
  } > "$ARCHIVE_LIST"
)

TZ=UTC find "$STAGE" -exec touch -t 198001010000 {} +
(
  cd "$STAGE"
  rm -f "$OUTPUT"
  COPYFILE_DISABLE=1 zip -X -q - -@ < "$ARCHIVE_LIST" > "$OUTPUT"
)

if command -v xattr >/dev/null 2>&1; then
  xattr -c "$OUTPUT" 2>/dev/null || true
fi

archive_paths="$(unzip -Z1 "$OUTPUT" | sed 's#/$##')"
unexpected_paths="$(
  printf '%s\n' "$archive_paths" |
    grep -E '(^docs(/|$)|^tests(/|$)|^hooks(/|$)|^scripts(/|$)|^package\.json$|^AGENTS\.md$|^CODE_OF_CONDUCT\.md$|^CLAUDE\.md$|^GEMINI\.md$|^RELEASE-NOTES\.md$|^\.claude-plugin(/|$)|^\.cursor-plugin(/|$)|^\.kimi-plugin(/|$)|^\.opencode(/|$)|^\.pi(/|$))' || true
)"
if [[ -n "$unexpected_paths" ]]; then
  printf '%s\n' "$unexpected_paths" | sed 's/^/  /' >&2
  die "archive contains source-only paths"
fi

entry_count="$(printf '%s\n' "$archive_paths" | wc -l | tr -d ' ')"
checksum="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"

echo "Archive: $OUTPUT"
echo "Version: $VERSION"
echo "Entries: $entry_count"
echo "Skills: $skill_count"
echo "SHA-256: $checksum"
