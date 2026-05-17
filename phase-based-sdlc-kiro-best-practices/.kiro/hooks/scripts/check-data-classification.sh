#!/usr/bin/env bash
set -euo pipefail
# Hook: Data Classification Guard
# Trigger: Pre Tool Use (write)
# Purpose: Ensure source files in sensitive directories have proper data
#          classification headers (@classification CONFIDENTIAL/RESTRICTED/INTERNAL/PUBLIC).
# Exit code: 0 = PASS (classification present or not required), 1 = BLOCK (missing classification)

TOOL_INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$TOOL_INPUT" | grep -oP '"path"\s*:\s*"\K[^"]*' | head -1 || true)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only check source files
if ! echo "$FILE_PATH" | grep -qE "\.(java|ts|tsx|js)$"; then
  exit 0
fi

# Only check files in sensitive directories
if ! echo "$FILE_PATH" | grep -qE "(transaction|auth|lending|payment|kyc|compliance)/"; then
  exit 0
fi

# Extract file content
FILE_CONTENT=$(echo "$TOOL_INPUT" | grep -oP '"(text|content)"\s*:\s*"\K[^"]*' | head -1 || true)

if [ -z "$FILE_CONTENT" ]; then
  FILE_CONTENT="$TOOL_INPUT"
fi

# Check for classification header
if echo "$FILE_CONTENT" | grep -qE "@classification\s+(CONFIDENTIAL|RESTRICTED|INTERNAL|PUBLIC)"; then
  exit 0
fi

echo "BLOCKED: Missing data classification header."
echo "File: $FILE_PATH"
echo "Files in sensitive directories (transaction/, auth/, lending/, payment/, kyc/, compliance/)"
echo "must include a classification header in a comment block."
echo ""
echo "Add one of the following to the top of the file:"
echo "  // @classification CONFIDENTIAL"
echo "  // @classification RESTRICTED"
echo "  // @classification INTERNAL"
echo "  // @classification PUBLIC"
echo ""
echo "MAS TRM requires proper data classification for all sensitive modules."
exit 1
