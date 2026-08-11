# Security: Code-Level Review

Applies to the `security` skill's code category. Read `security.md` first.

This is the same underlying lens `review`'s `security` checklist already
applies — `review.md`'s `security` section is the floor of what to check
here, not a separate list to reconcile against. Depth per stack lives in
`../references/security-review-guide.md`, the same vendored guide
`review` loads for this lens. What differs is scope and audience:
`review` fires on a diff someone is already looking at; this runs the
whole repository unprompted by any change in flight, and every finding
carries an OWASP/CWE citation so the report is usable by an audience
`review`'s findings don't need to serve — a compliance reviewer, a pentest
handoff, an insurance questionnaire.

## OWASP Top 10 (2021) categories

Cite the category that fits, alongside the ordinary severity:

| Code | Category | Maps to (examples) |
|------|----------|---------------------|
| A01 | Broken Access Control | Missing per-resource authorization, IDOR, path traversal |
| A02 | Cryptographic Failures | Weak hashing, hardcoded keys, cleartext transmission of sensitive data |
| A03 | Injection | SQL/shell/path/template injection, XSS |
| A04 | Insecure Design | Missing rate limiting on an abuse-prone flow, trust boundary drawn in the wrong place |
| A05 | Security Misconfiguration | Debug mode in production, permissive CORS, default credentials, verbose error responses |
| A06 | Vulnerable and Outdated Components | Cross-reference `security-deps.md` — don't re-report the same finding under a different label |
| A07 | Identification and Authentication Failures | Weak session handling, missing MFA on sensitive operations, credential stuffing exposure |
| A08 | Software and Data Integrity Failures | Unsigned/unverified deserialization, CI/CD pipeline trusting unreviewed input (also see `security-config.md`) |
| A09 | Security Logging and Monitoring Failures | Auth failures, access-control failures, and high-value actions that leave no audit trail |
| A10 | Server-Side Request Forgery | Server-side fetch of a user-supplied URL with no allowlist |

## CWE citation

Cite a specific CWE number only when the pattern maps cleanly to one —
CWE-89 (SQL Injection), CWE-79 (XSS), CWE-798 (Use of Hard-coded
Credentials), CWE-306 (Missing Authentication for a Critical Function),
CWE-862 (Missing Authorization), CWE-918 (SSRF) are the common,
unambiguous ones. Never invent a CWE number to make a finding look more
authoritative — an OWASP category label alone is a complete finding when
no CWE maps cleanly.

## Boundary with security-config.md

A vulnerability in application code (an endpoint handler, a query, a
template) belongs here. A missing or permissive control that lives in
configuration rather than code — an HTTP header, a CORS policy, a
Dockerfile, a CI workflow, an IaC file — belongs in
`security-config.md`. When a finding straddles both (a hardcoded secret
used to construct a Dockerfile `ARG`), report it once, in whichever file's
category most directly names the fix.
