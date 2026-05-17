#!/usr/bin/env bash
set -euo pipefail
# Hook: Cross-Border Data Guard
# Trigger: Pre Tool Use (write)
# Purpose: PDPA compliance - detect non-Singapore AWS regions in application code
#          (SDK client configurations) and flag potential cross-border data transfers.
# Exit code: 0 = PASS (no cross-border violations), 1 = BLOCK (non-SG region in SDK config)

TOOL_INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$TOOL_INPUT" | grep -oP '"path"\s*:\s*"\K[^"]*' | head -1 || true)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only check application source files (not infra - that is handled by data-residency-guard)
if ! echo "$FILE_PATH" | grep -qE "\.(java|ts|tsx|js|py)$"; then
  exit 0
fi

# Skip infra/CDK files (already handled by data-residency-guard)
if echo "$FILE_PATH" | grep -qE "(infra/|cdk/|\.cdk\.|cloudformation|terraform)"; then
  exit 0
fi

# Allowed region (Singapore only for PDPA compliance)
ALLOWED_REGION="ap-southeast-1"

# Extract file content
FILE_CONTENT=$(echo "$TOOL_INPUT" | grep -oP '"(text|content)"\s*:\s*"\K[^"]*' | head -1 || true)

if [ -z "$FILE_CONTENT" ]; then
  FILE_CONTENT="$TOOL_INPUT"
fi

BLOCKED=0

# Allowlist approach: flag ANY AWS region pattern that is NOT ap-southeast-1.
# AWS region pattern: two lowercase letters, dash, word, dash, digit (e.g., us-east-1)
# Check for region assignment in SDK client configuration context
# Patterns: region: 'xx-yyyy-N', region='xx-yyyy-N', {region: "xx-yyyy-N"}, Region("xx-yyyy-N")
REGION_MATCHES=$(echo "$FILE_CONTENT" | grep -oE "region['\"]?\s*[:=]\s*['\"][a-z]{2}-[a-z]+-[0-9]+['\"]" || true)

if [ -n "$REGION_MATCHES" ]; then
  # Check if any matched region is NOT the allowed Singapore region
  NON_SG=$(echo "$REGION_MATCHES" | grep -oE "[a-z]{2}-[a-z]+-[0-9]+" | grep -v "^${ALLOWED_REGION}$" || true)
  if [ -n "$NON_SG" ]; then
    # Verify it's in an SDK configuration context (not a comment or doc string)
    DETECTED_REGION=$(echo "$NON_SG" | head -1)
    if echo "$FILE_CONTENT" | grep -E "region['\"]?\s*[:=]\s*['\"]${DETECTED_REGION}['\"]" | grep -qvE "^\s*(//|#|\*|/\*|\"\"\"| \* )"; then
      echo "BLOCKED: Cross-border data transfer risk detected."
      echo "File: $FILE_PATH"
      echo "Non-Singapore region detected: $DETECTED_REGION"
      echo ""
      echo "PDPA requires personal data to remain in Singapore (ap-southeast-1)."
      echo "Cross-border transfers need explicit compliance approval and DPA."
      echo "Use ap-southeast-1 for all AWS SDK clients handling personal data."
      BLOCKED=1
    fi
  fi
fi

# Check for Region enum usage (Java SDK v2) - allowlist approach
# Flag any Region.XX_YY_N that is NOT Region.AP_SOUTHEAST_1
ENUM_MATCHES=$(echo "$FILE_CONTENT" | grep -oE "Region\.[A-Z_]+[0-9]+" || true)

if [ -n "$ENUM_MATCHES" ]; then
  NON_SG_ENUM=$(echo "$ENUM_MATCHES" | grep -v "^Region\.AP_SOUTHEAST_1$" || true)
  if [ -n "$NON_SG_ENUM" ]; then
    echo "BLOCKED: Cross-border data transfer risk detected (AWS SDK Region enum)."
    echo "File: $FILE_PATH"
    echo "Non-Singapore region: $(echo "$NON_SG_ENUM" | head -1)"
    echo "Use Region.AP_SOUTHEAST_1 for Singapore data residency compliance."
    BLOCKED=1
  fi
fi

if [ $BLOCKED -eq 1 ]; then
  echo ""
  echo "PDPA Compliance: Personal data must not be processed outside Singapore without approval."
  exit 1
fi

exit 0
