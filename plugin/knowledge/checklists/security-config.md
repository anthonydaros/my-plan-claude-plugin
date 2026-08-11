# Security: Configuration and Infrastructure

Applies to the `security` skill's config category. Read `security.md`
first. Every item below is a presence-and-strictness check: does a
control exist, and if it does, is it actually strict. Recommending the
fix is this file's job; writing the header, middleware, or policy from
scratch is `implement`'s, from a `plan` — the same boundary `cleanup`
draws around structural reorganization.

## HTTP security headers

Check for `Content-Security-Policy`, `Strict-Transport-Security`,
`X-Content-Type-Options: nosniff`, `X-Frame-Options` or a `frame-ancestors`
CSP directive, `Referrer-Policy`, and `Permissions-Policy`. Look in the
framework's own security middleware (Express `helmet`, Django's
`SecurityMiddleware` settings, Rails `secure_headers`/`config.force_ssl`)
and in reverse-proxy/CDN config (nginx, Caddy, a CDN's edge config) before
concluding a header is absent — a modern framework may already set safe
defaults, and the absence of explicit application code is not itself a
finding if the framework's default covers it. Confirm the actual default,
don't assume it.

## Content-Security-Policy, specifically

If one exists: is it a real allowlist, or does it rely on `unsafe-inline`,
`unsafe-eval`, or a bare `*` source — each defeats most of what a CSP is
for. If none exists: severity depends on whether the application renders
any content that includes user-influenced data (a server-rendered page,
user-generated HTML) — an API-only backend that returns JSON to a
separate frontend has a different, usually lower, severity for this gap
than an application rendering markup directly.

## Rate limiting

Check specifically the endpoints where its absence has a concrete abuse
path: login, password reset, account creation, any endpoint that sends an
email/SMS or costs money per call. This is not "every endpoint needs rate
limiting" — that's a blanket hardening prescription, not an audit
finding. Report it where a concrete abuse path exists, skip it where it
doesn't.

## CORS

`Access-Control-Allow-Origin: *` combined with
`Access-Control-Allow-Credentials: true` is a real, common
misconfiguration — browsers reject the combination for most credentialed
requests, but a permissive reflected-origin implementation (echoing
whatever `Origin` header the request sent, without checking it against an
allowlist) achieves the same effect and passes the browser's check.

## Database-level authorization (Supabase, Firebase, and similar)

When the frontend talks to the database directly — no backend API in
between — the database's own row-level policy is the authorization
boundary, not a defense-in-depth extra. Check for Row Level Security on
every Supabase/Postgres table (`select relrowsecurity from pg_class`, or
the project's own migration files for `enable row level security`) and
for Firestore/Realtime Database security rules that default-deny rather
than default-allow. A table or collection with no policy at all is not
neutral: depending on the platform, it can mean every authenticated, or
even anonymous, client can read and write every row directly from the
browser. Treat this as `blocker` whenever real user data sits behind it —
the platform's own out-of-the-box default is frequently permissive, and
"the framework probably handles this" is exactly the assumption that
doesn't hold here.

## Cookies

Session cookies specifically: `Secure`, `HttpOnly`, and `SameSite` (`Lax`
or `Strict` for most applications; `None` only when cross-site use is an
actual requirement, and only paired with `Secure`).

## CI/CD

Workflow files (`.github/workflows/`, `.gitlab-ci.yml`, and equivalents):
a secret printed to a log (`echo $SECRET`, a debug step that dumps the
environment), `pull_request_target` combined with checking out and
running the PR's own untrusted code (lets a fork-submitted PR run with
the base repository's secrets — a well-known supply-chain vector), and a
third-party action pinned to a mutable tag (`@v1`) rather than a commit
SHA (a tag can be moved to point at different code after the fact; a SHA
cannot).

## Dockerfiles

No `USER` directive before the final stage (the container runs as root by
default), and a secret passed via `ARG`/`ENV` — even one not present in
the final running layer is still recoverable from the image's build
history unless a multi-stage build discards that layer entirely.

## Infrastructure as code

Terraform, CloudFormation, Pulumi, or equivalent, if present: a security
group or ingress rule open to `0.0.0.0/0` on a port that isn't meant to be
public, a storage bucket or resource with public-read (or public-write)
access by default.

## Coverage when nothing of a kind exists

A repository with no Dockerfile, no CI workflows, or no IaC isn't a gap —
mark that row `not-applicable` with the reason ("no Dockerfile in this
repository") rather than omitting it.
