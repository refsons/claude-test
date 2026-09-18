#!/usr/bin/env bash
# Generates .claude/agents/*.md from a shared prompt body + Claude-specific frontmatter.
# The shared body under agents-shared/ is the single source of truth for agent content.
# Never hand-edit files under .claude/agents/ — they're generated output.
#
# Convention: if a body file's first line is exactly "<!-- include-core -->",
# the shared agents-shared/_core/diamond-principles.md is spliced in right after
# that marker (and the marker line itself is stripped from the output).
set -euo pipefail

SHARED_DIR="agents-shared"
CORE_FILE="agents-shared/_core/diamond-principles.md"
FRONTMATTER_DIR="agents-claude"
OUT_DIR=".claude/agents"

mkdir -p "$OUT_DIR"

for body_file in "$SHARED_DIR"/*.md "$SHARED_DIR"/specialists/*.md; do
  [[ -f "$body_file" ]] || continue
  agent_name="$(basename "$body_file" .md)"
  fm_file="$FRONTMATTER_DIR/${agent_name}.frontmatter.yaml"

  if [[ ! -f "$fm_file" ]]; then
    echo "WARN: no frontmatter for '$agent_name' (expected $fm_file) — skipping" >&2
    continue
  fi

  out_file="$OUT_DIR/${agent_name}.md"
  {
    echo "---"
    cat "$fm_file"
    echo "---"
    echo

    first_line="$(head -n1 "$body_file")"
    if [[ "$first_line" == "<!-- include-core -->" ]]; then
      cat "$CORE_FILE"
      echo
      tail -n +2 "$body_file"
    else
      cat "$body_file"
    fi
  } > "$out_file"

  echo "Generated $out_file"
done
