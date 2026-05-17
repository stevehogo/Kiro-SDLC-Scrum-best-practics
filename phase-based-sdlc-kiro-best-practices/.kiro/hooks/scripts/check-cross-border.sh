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

# Non-Singapore regions to flag
NON_SG_REGIONS="us-east-1|us-west-1|us-west-2|eu-west-1|eu-central-1|ap-northeast-1|ap-south-1"

# Extract file content
FILE_CONTENT=$(echo "$TOOL_INPUT" | grep -oP '"(text|content)"\s*:\s*"\K[^"]*' | head -1 || true)

if [ -z "$FILE_CONTENT" ]; then
  FILE_CONTENT="$TOOL_INPUT"
fi

BLOCKED=0

# Check for non-SG regions in SDK client configuration context
# Patterns: region: 'us-east-1', region='us-east-1', {region: "eu-west-1"}, Region("us-west-2")
if echo "$FILE_CONTENT" | grep -qE "region['\"]?\s*[:=]\s*['\"]($NON_SG_REGIONS)['\"]"; then
  # Verify it's in an SDK configuration context (not a comment or doc string)
  if echo "$FILE_CONTENT" | grep -E "region['\"]?\s*[:=]\s*['\"]($NON_SG_REGIONS)['\"]" | grep -qvE "^\s*(//|#|\*|/\*|\"\"\"| \* )"; then
    echo "BLOCKED: Cross-border data transfer risk detected."
    echo "File: $FILE_PATH"
    DETECTED_REGION=$(echo "$FILE_CONTENT" | grep -oE "($NON_SG_REGIONS)" | head -1)
    echo "Non-Singapore region detected: $DETECTED_REGION"
    echo ""
    echo "PDPA requires personal data to remain in Singapore (ap-southeast-1)."
    echo "Cross-border transfers need explicit compliance approval and DPA."
    echo "Use ap-southeast-1 for all AWS SDK clients handling personal data."
    BLOCKED=1
  fi
fi

# Check for Region enum usage (Java SDK v2)
if echo "$FILE_CONTENT" | grep -qE "Region\.(US_EAST_1|US_WEST_1|US_WEST_2|EU_WEST_1|EU_CENTRAL_1|AP_NORTHEAST_1|AP_SOUTH_1)"; then
  echo "BLOCKED: Cross-border data transfer risk detected (AWS SDK Region enum)."
  echo "File: $FILE_PATH"
  echo "Use Region.AP_SOUTHEAST_1 for Singapore data residency compliance."
  BLOCKED=1
fi

if [ $BLOCKED -eq 1 ]; then
  echo ""
  echo "PDPA Compliance: Personal data must not be processed outside Singapore without approval."
  exit 1
fi

exit 0
