#!/usr/bin/env bash
set -euo pipefail
# Hook: DLP Guard
# Trigger: Pre Tool Use (write)
# Purpose: Detect data loss prevention violations - logging PII fields,
#          returning unfiltered customer objects, sending sensitive data externally.
# Exit code: 0 = PASS (no DLP violation), 1 = BLOCK (DLP violation detected)

TOOL_INPUT=$(cat)

BLOCKED=0

# Check for logging of sensitive field names
SENSITIVE_FIELDS="nric|creditCard|cardNumber|ssn|passport|bankAccount|password|secret|token"

if echo "$TOOL_INPUT" | grep -qEi "(console\.(log|info|warn|error|debug)|logger\.(info|debug|warn|error|trace)|log\.(info|debug|warn|error|trace|fatal))\s*\(.*($SENSITIVE_FIELDS)"; then
  echo "BLOCKED: DLP violation - sensitive data being logged."
  echo "Detected logging statement containing sensitive field names."
  echo "Never log PII or sensitive fields. Use masked/redacted values instead."
  BLOCKED=1
fi

# Check for returning full customer/user objects without field filtering
if echo "$TOOL_INPUT" | grep -qEi "(return\s+(customer|user|account|client|member|applicant)\b|res\.(json|send)\s*\(\s*(customer|user|account|client|member|applicant)\s*\)|response\.(body|data)\s*=\s*(customer|user|account|client|member|applicant)\b)"; then
  echo "BLOCKED: DLP violation - returning full entity object without field filtering."
  echo "API responses must explicitly select safe fields (allowlist pattern)."
  echo "Use a DTO/view model to filter sensitive fields before returning."
  BLOCKED=1
fi

# Check for sending sensitive data to external endpoints
if echo "$TOOL_INPUT" | grep -qEi "(fetch|axios\.(post|put|patch)|http\.(post|put|patch)|request\.(post|put|patch))\s*\(" | head -1 > /dev/null 2>&1; then
  if echo "$TOOL_INPUT" | grep -qEi "(body|data|payload)\s*[:=].*($SENSITIVE_FIELDS)"; then
    echo "BLOCKED: DLP violation - sensitive data being sent to external endpoint."
    echo "Detected sensitive field names in HTTP request body."
    echo "Ensure data is masked/tokenized before external transmission."
    BLOCKED=1
  fi
fi

if [ $BLOCKED -eq 1 ]; then
  echo ""
  echo "Data Loss Prevention: Sensitive data must not leak through logs, APIs, or external calls."
  exit 1
fi

exit 0
