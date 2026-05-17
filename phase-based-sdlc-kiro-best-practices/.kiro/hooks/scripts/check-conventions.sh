#!/usr/bin/env bash
# Hook: Coding Standard Guard
# Trigger: Pre Tool Use (write)
# Purpose: Block writes violating naming conventions
# Exit code: 0 = pass (allow), non-zero = block
set -euo pipefail

TOOL_INPUT=$(cat)

FILE_PATH=$(echo "$TOOL_INPUT" | grep -oE '"path"\s*:\s*"[^"]*"' | head -1 | sed 's/"path"\s*:\s*"//;s/"$//')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Java: check PascalCase class naming
if echo "$FILE_PATH" | grep -qE '\.java$'; then
  FILENAME=$(basename "$FILE_PATH" .java)
  VALID=$(echo "$FILENAME" | grep -cE '^[A-Z][a-zA-Z0-9]*$' || true)
  if [ "$VALID" -eq 0 ]; then
    echo "BLOCKED: Java class must be PascalCase: $FILENAME"
    exit 1
  fi
fi

# SQL migration: check Flyway naming convention
if echo "$FILE_PATH" | grep -qE 'migration.*\.sql$'; then
  FILENAME=$(basename "$FILE_PATH")
  VALID=$(echo "$FILENAME" | grep -cE '^V[0-9]+__[a-z_]+\.sql$' || true)
  REPEAT=$(echo "$FILENAME" | grep -cE '^R__[a-z_]+\.sql$' || true)
  if [ "$VALID" -eq 0 ] && [ "$REPEAT" -eq 0 ]; then
    echo "BLOCKED: Flyway naming required: V{N}__{desc}.sql"
    echo "Got: $FILENAME"
    exit 1
  fi
fi

# React component: check PascalCase for .tsx files
if echo "$FILE_PATH" | grep -qE '\.tsx$'; then
  FILENAME=$(basename "$FILE_PATH" .tsx)
  VALID=$(echo "$FILENAME" | grep -cE '^[A-Z][a-zA-Z0-9]*$' || true)
  INDEX=$(echo "$FILENAME" | grep -cE '^index$' || true)
  HOOK=$(echo "$FILENAME" | grep -cE '^use[A-Z]' || true)
  if [ "$VALID" -eq 0 ] && [ "$INDEX" -eq 0 ] && [ "$HOOK" -eq 0 ]; then
    echo "BLOCKED: React component must be PascalCase: $FILENAME.tsx"
    exit 1
  fi
fi

exit 0
