#!/usr/bin/env bash
set -euo pipefail
# Hook: Prompt Security Guard
# Trigger: Prompt Submit
# Purpose: Block prompts that attempt to bypass security controls, disable hooks,
#          or skip compliance checks.
# Exit code: 0 = PASS (prompt is safe), 1 = BLOCK (security bypass attempt detected)

PROMPT_INPUT=$(cat)

# Convert to lowercase for case-insensitive matching
LOWER_INPUT=$(echo "$PROMPT_INPUT" | tr '[:upper:]' '[:lower:]')

# Blocked phrases that indicate attempts to bypass security
BLOCKED_PHRASES=(
  "skip security"
  "disable hook"
  "ignore compliance"
  "bypass guard"
  "turn off scan"
  "remove security"
  "disable validation"
  "skip validation"
  "ignore security"
  "bypass compliance"
  "disable guard"
  "skip audit"
  "ignore hook"
  "no security check"
  "without security"
)

for phrase in "${BLOCKED_PHRASES[@]}"; do
  if echo "$LOWER_INPUT" | grep -qF "$phrase"; then
    echo "BLOCKED: Security bypass attempt detected."
    echo "Phrase: '$phrase'"
    echo ""
    echo "Security controls cannot be bypassed via prompt."
    echo "These hooks enforce MAS TRM and PDPA compliance requirements."
    echo "If you believe a security check is incorrectly blocking your work,"
    echo "contact the security team for a proper exception process."
    exit 1
  fi
done

exit 0
