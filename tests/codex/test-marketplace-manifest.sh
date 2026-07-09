#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MARKETPLACE="$REPO_ROOT/.agents/plugins/marketplace.json"

python3 - "$MARKETPLACE" <<'PY'
import json
import sys
from pathlib import Path

marketplace_path = Path(sys.argv[1])
if not marketplace_path.exists():
    raise AssertionError(".agents/plugins/marketplace.json must exist")

manifest = json.loads(marketplace_path.read_text(encoding="utf-8"))

def assert_equal(actual, expected, label):
    if actual != expected:
        raise AssertionError(f"{label}: expected {expected!r}, got {actual!r}")

assert_equal(manifest.get("name"), "superpowers-dev", "marketplace name")

plugins = manifest.get("plugins")
if not isinstance(plugins, list):
    raise AssertionError("plugins must be a list")
assert_equal(len(plugins), 1, "plugin count")

plugin = plugins[0]
assert_equal(plugin.get("name"), "superpowers", "plugin name")
assert_equal(plugin.get("source"), {"source": "url", "url": "./"}, "plugin source")
assert_equal(plugin.get("policy", {}).get("installation"), "AVAILABLE", "installation policy")
assert_equal(plugin.get("category"), "Developer Tools", "plugin category")

print("Codex marketplace manifest looks good")
PY
