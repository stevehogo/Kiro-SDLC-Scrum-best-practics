# Security Hook Tests

Automated tests for the enterprise security hook scripts.

## Running Tests

```bash
bash tests/test-security-hooks.sh
```

## What's Tested

| Script | Tests | Description |
|--------|-------|-------------|
| detect-pii.sh | 5 | PII detection: NRIC, credit card, phone, email, clean code |
| check-dlp.sh | 3 | DLP: logging sensitive fields, returning unfiltered objects, clean code |
| check-data-classification.sh | 3 | Classification headers in sensitive directories |
| check-cross-border.sh | 3 | AWS region checks for data residency |
| check-prompt-security.sh | 3 | Prompt injection/bypass attempts |

## Adding Tests

Follow the pattern in `test-security-hooks.sh`:
- `assert_blocks "test name" "script.sh" "input"` - expects the hook to BLOCK (exit 1)
- `assert_passes "test name" "script.sh" "input"` - expects the hook to PASS (exit 0)
