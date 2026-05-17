#!/usr/bin/env bash
set -euo pipefail
# Hook: PII Detection Guard
# Trigger: Pre Tool Use (write)
# Purpose: Detect hardcoded PII in file writes - Singapore NRIC, credit cards,
#          email addresses, phone numbers, passport numbers.
# Exit code: 0 = PASS (no PII found), 1 = BLOCK (hardcoded PII detected)

TOOL_INPUT=$(cat)

# Extract the file content from tool input
FILE_CONTENT=$(echo "$TOOL_INPUT" | grep -oP '"(text|content)"\s*:\s*"\K[^"]*' | head -1 || true)

if [ -z "$FILE_CONTENT" ]; then
  # Try to use the full input as content
  FILE_CONTENT="$TOOL_INPUT"
fi

BLOCKED=0

# Singapore NRIC: S/T/F/G followed by 7 digits and a letter
# Only match when in string literals (quoted)
if echo "$FILE_CONTENT" | grep -qE "['\"][^'\"]*[STFG][0-9]{7}[A-Z][^'\"]*['\"]"; then
  echo "BLOCKED: Hardcoded Singapore NRIC detected."
  echo "Pattern: [STFG]XXXXXXX[A-Z] (e.g., S1234567A)"
  echo "Use tokenized references or secure vault storage instead."
  BLOCKED=1
fi

# Credit card numbers: 13-19 digit sequences (with optional spaces/dashes)
if echo "$FILE_CONTENT" | grep -qE "['\"][^'\"]*[0-9]{4}[-\s]?[0-9]{4}[-\s]?[0-9]{4}[-\s]?[0-9]{1,7}[^'\"]*['\"]"; then
  echo "BLOCKED: Hardcoded credit card number detected."
  echo "Pattern: 13-19 digit sequence with optional separators"
  echo "Never store card numbers in source code. Use tokenization."
  BLOCKED=1
fi

# Hardcoded email addresses in string literals
if echo "$FILE_CONTENT" | grep -qE "['\"][^'\"]*[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^'\"]*['\"]"; then
  # Exclude common non-PII patterns (example.com, test domains, annotations)
  if echo "$FILE_CONTENT" | grep -E "['\"][^'\"]*[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}[^'\"]*['\"]" | grep -qvE "(example\.com|test\.com|localhost|@param|@returns|@author|@Override|@Service|@Component|@Entity)"; then
    echo "BLOCKED: Hardcoded email address detected in string literal."
    echo "Use configuration or environment variables for email addresses."
    BLOCKED=1
  fi
fi

# Singapore phone numbers: +65 followed by 8 digits
if echo "$FILE_CONTENT" | grep -qE "['\"][^'\"]*\+65\s?[0-9]{4}\s?[0-9]{4}[^'\"]*['\"]"; then
  echo "BLOCKED: Hardcoded Singapore phone number detected."
  echo "Pattern: +65XXXXXXXX"
  echo "Use secure storage for personal phone numbers."
  BLOCKED=1
fi

# Passport numbers: letter followed by 7-8 digits in string literals
# Only flag when "passport" context is nearby (variable name, field name, or comment)
# to avoid false positives on version strings, constants, and reference codes.
if echo "$FILE_CONTENT" | grep -qiE "(passport|travel_doc|travel_document)" ; then
  if echo "$FILE_CONTENT" | grep -qE "['\"][^'\"]*[A-Z][0-9]{7,8}[^'\"]*['\"]"; then
    # Avoid false positives by requiring it not to look like NRIC (already caught above)
    if echo "$FILE_CONTENT" | grep -E "['\"][^'\"]*[A-Z][0-9]{7,8}[^'\"]*['\"]" | grep -qvE "[STFG][0-9]{7}[A-Z]"; then
      echo "BLOCKED: Possible hardcoded passport number detected."
      echo "Pattern: [A-Z][0-9]{7,8} in passport-related context"
      echo "Use secure vault storage for identity documents."
      BLOCKED=1
    fi
  fi
fi

if [ $BLOCKED -eq 1 ]; then
  echo ""
  echo "PDPA Compliance: Personal data must not be hardcoded in source code."
  exit 1
fi

exit 0
