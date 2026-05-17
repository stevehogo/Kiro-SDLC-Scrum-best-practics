#!/usr/bin/env bash
# Hook: Sprint Status Sync
# Trigger: agentStop
# Purpose: Check for incomplete work markers and uncommitted changes
# Exit code: 0 = audit only, never blocks
set -euo pipefail

echo "Sprint status sync..."

INCOMPLETE=$(grep -rn "TODO\|FIXME\|HACK\|XXX\|SECURITY-TODO" src/ --include="*.java" --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l || true)

if [ "$INCOMPLETE" -gt 0 ]; then
  echo "WARNING: Found $INCOMPLETE TODO/FIXME/SECURITY-TODO markers."
  grep -rn "TODO\|FIXME\|SECURITY-TODO" src/ --include="*.java" --include="*.ts" --include="*.tsx" 2>/dev/null | head -10 || true
fi

if command -v git &> /dev/null; then
  CHANGES=$(git status --porcelain 2>/dev/null | wc -l || true)
  if [ "$CHANGES" -gt 0 ]; then
    echo "INFO: $CHANGES uncommitted file(s). Commit before marking Sprint items Done."
  fi
fi

echo "Status sync complete."
exit 0
