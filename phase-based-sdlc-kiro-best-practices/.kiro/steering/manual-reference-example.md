---
inclusion: manual
---
## Regulatory Quick Reference (On-Demand)

This steering file is included manually when agents need regulatory context for specific compliance tasks. Use `#[[file:.kiro/steering/manual-reference-example.md]]` to include it.

### MAS TRM Key Controls (Quick Reference)
| Control | Requirement | Verification |
|---------|-------------|--------------|
| TRM 4.1.1 | IT security policies approved by Board | Annual review documented |
| TRM 4.5.1 | Penetration testing annually | Test report + remediation plan |
| TRM 5.1.3 | Patch management within 30 days (Critical) | Automated scanning evidence |
| TRM 6.1.1 | Access control based on least privilege | IAM audit trail |
| TRM 7.2.1 | Encryption of data at rest and in transit | KMS + TLS configuration |
| TRM 8.1.1 | Audit trail for all privileged operations | CloudWatch/SIEM logs |

### PDPA Key Obligations
- Consent: Obtain consent before collecting personal data
- Purpose limitation: Use data only for stated purposes
- Retention: Delete data when no longer needed
- Transfer: No cross-border transfer without adequate protection
- Breach notification: Notify PDPC within 3 days of significant breach

### PCI-DSS Quick Checks
- Never store CVV/CVC after authorization
- Encrypt cardholder data at rest (AES-256)
- Restrict access on need-to-know basis
- Quarterly vulnerability scans (ASV)
- Annual penetration testing
