# STRIDE Threat Model: Inter-Bank Fund Transfer API

## Feature Description

The inter-bank fund transfer feature allows authenticated customers to initiate real-time transfers from their accounts to external bank accounts via FAST (Fast And Secure Transfers) network in Singapore.

## Data Flow Diagram

```
User (Browser/Mobile) 
    → Frontend (React SPA)
        → API Gateway (Kong + WAF)
            → Transfer Service (Spring Boot)
                → Core Banking System (Mainframe via MQ)
                    → Database (Aurora PostgreSQL)
                → FAST Network Gateway (External)
```

### Trust Boundaries
1. Internet → DMZ (WAF/API Gateway)
2. DMZ → Internal Network (Transfer Service)
3. Internal → Core Banking (Mainframe)
4. Internal → External (FAST Network)

## STRIDE Analysis

| Category | Threat | Description | Likelihood | Impact | Risk Level | Mitigation |
|----------|--------|-------------|-----------|--------|------------|------------|
| **Spoofing** | Stolen JWT token reuse | Attacker intercepts and replays a valid JWT to initiate unauthorized transfers | Medium | Critical | High | Short-lived tokens (15 min), refresh token rotation, device fingerprinting, transaction signing with OTP |
| **Spoofing** | Man-in-the-middle on FAST gateway | Attacker impersonates the FAST network endpoint to redirect funds | Low | Critical | High | Mutual TLS (mTLS) with pinned certificates, dedicated private network link to FAST |
| **Tampering** | Amount modification in transit | Attacker modifies transfer amount between API Gateway and Transfer Service | Low | Critical | High | Request signing with HMAC-SHA256, end-to-end payload integrity verification |
| **Tampering** | Database record manipulation | Insider modifies transaction records directly in the database | Low | Critical | High | Database audit logging, row-level checksums, separation of duties (no direct DB access in production) |
| **Repudiation** | Customer denies initiating transfer | Customer claims they did not authorize the transfer | Medium | High | High | Multi-factor transaction signing (OTP + biometric), comprehensive audit trail with device info and IP |
| **Repudiation** | Missing audit trail for internal operations | System admin actions not logged, preventing forensic investigation | Low | High | Medium | Immutable audit logs in separate account, CloudTrail for all API calls, log integrity verification |
| **Information Disclosure** | Account balance exposure via error messages | Verbose error messages reveal account balance or status of other customers | Medium | Medium | Medium | Generic error responses, detailed errors only in secure internal logs, never expose internal state |
| **Information Disclosure** | PII leakage in application logs | Customer NRIC, full account numbers, or transaction details written to logs | Medium | High | High | Log masking middleware, only log last 4 digits of account numbers, no PII in request/response logs |
| **Denial of Service** | Transfer API rate flooding | Attacker floods the transfer endpoint to exhaust processing capacity | High | High | High | Per-user rate limiting (10 transfers/hour), CAPTCHA after threshold, circuit breaker on downstream services |
| **Denial of Service** | FAST gateway timeout cascade | Slow FAST network responses cause thread pool exhaustion in Transfer Service | Medium | High | High | Circuit breaker pattern, async processing with timeout (30s), bulkhead isolation for FAST calls |
| **Elevation of Privilege** | IDOR on transfer approval | Attacker modifies transfer ID in approval request to approve their own high-value transfer | Medium | Critical | Critical | Authorization check: approver cannot be initiator, server-side ownership validation, dual-control for amounts > SGD 10,000 |
| **Elevation of Privilege** | Service account compromise | Compromised service account used to bypass transfer limits | Low | Critical | High | Least-privilege service accounts, no shared credentials, secrets rotation every 24 hours, anomaly detection on service-to-service calls |

## Security Stories Generated

Based on the STRIDE analysis above, the following security stories should be added to the sprint backlog:

1. **As a security engineer**, I want all transfer requests to be signed with HMAC-SHA256 so that tampering is detected before processing.
2. **As a security engineer**, I want per-user rate limiting on the transfer API (10/hour) so that DoS attacks are mitigated.
3. **As a customer**, I want transaction signing with OTP so that unauthorized transfers cannot be initiated with a stolen session.
4. **As an auditor**, I want immutable audit logs for all transfer operations so that repudiation claims can be investigated.
5. **As a security engineer**, I want PII masking in all application logs so that data exposure from log access is prevented.
6. **As a security engineer**, I want circuit breaker patterns on FAST gateway calls so that downstream failures do not cascade.
7. **As a security engineer**, I want server-side ownership validation on transfer approvals so that IDOR attacks are blocked.
8. **As a security engineer**, I want mutual TLS on the FAST network connection so that man-in-the-middle attacks are prevented.

## Residual Risks

Even after implementing all mitigations, the following residual risks remain:

| Risk | Residual Likelihood | Residual Impact | Acceptance Rationale |
|------|--------------------|-----------------|-----------------------|
| Sophisticated insider with DB access and log deletion capability | Very Low | Critical | Mitigated by separation of duties, but zero-day exploits on DB engine could bypass controls. Accepted with annual penetration testing. |
| Zero-day in FAST network protocol | Very Low | High | Dependency on external network operator. Mitigated by monitoring and alerting on anomalous FAST responses. |
| Coordinated social engineering for OTP bypass | Low | High | Multi-factor reduces risk but sophisticated social engineering (SIM swap + phishing) remains possible. Mitigated by device binding and behavioral analytics. |
| State-sponsored attack on infrastructure | Very Low | Critical | Beyond organization's threat model scope. Escalated to national CERT and MAS for coordinated response. |
