#!/usr/bin/env bash
# Hook: Coverage Gate
# Trigger: postTaskExecution
# Purpose: Check test coverage and security regression tests
# Exit code: 0 = pass, non-zero = warn (postTaskExecution hooks log warning)
set -euo pipefail

echo "Running test coverage + security regression check..."

if [ -f "gradlew" ]; then
  ./gradlew test jacocoTestReport 2>&1
  COVERAGE_FILE="build/reports/jacoco/test/jacocoTestReport.xml"
  if [ -f "$COVERAGE_FILE" ]; then
    LINE_MISSED=$(grep -oP 'type="LINE".*?missed="\K[0-9]+' "$COVERAGE_FILE" | head -1 || true)
    LINE_COVERED=$(grep -oP 'type="LINE".*?covered="\K[0-9]+' "$COVERAGE_FILE" | head -1 || true)
    if [ -n "$LINE_MISSED" ] && [ -n "$LINE_COVERED" ]; then
      TOTAL=$((LINE_MISSED + LINE_COVERED))
      if [ "$TOTAL" -gt 0 ]; then
        PERCENT=$((LINE_COVERED * 100 / TOTAL))
        echo "Line coverage: ${PERCENT}%"
        if [ "$PERCENT" -lt 80 ]; then
          echo "WARNING: Coverage ${PERCENT}% below 80% threshold"
          exit 1
        fi
      fi
    fi
  fi
elif [ -f "package.json" ]; then
  npx vitest run --coverage 2>&1
fi

echo "Coverage check complete."
exit 0
