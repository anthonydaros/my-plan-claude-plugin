# Security Checklist

The master checklist for the `security` skill. Read this always; read the
category files under this one only for what's in scope for the current
invocation.

## Golden rules

Report, never remediate. This skill has no `--fix`, in any category, ever:
rotating a credential, upgrading a vulnerable dependency, and adding a
security header each carry a blast radius — a breaking API change, a
compatibility break, a locked-out legitimate request — that a repository
sweep has no way to verify safe. `review --fix`, `plan`, and `implement`
exist for exactly that judgment; `security` stops at the finding.

## Never print a secret's real value

Every finding that touches a credential — found in a tracked file, a log
line, an error message, git history, anywhere — reports its location, its
kind, and a masked form only, per `secrets-patterns.md`. The report
itself must never become a second leak of what it found.

## Confidence and severity are two different axes

Same split as `cleanup.md`, applied to a different domain. **Confidence**
says how sure a finding is a real risk, not a false positive: a secret
matching a provider's own token format (`sk-`, `ghp_`, `AKIA`) in a
tracked file is high; a generic `password = "..."` assignment needing
manual judgment about whether it's a real value or a placeholder is
medium; a heuristic pattern with no corroborating shape is low.
**Severity** says how bad it is if real: a live credential in a tracked
file, or a dependency vulnerability with a known public exploit reachable
from this repository's own code, is `blocker`; a vulnerability with a
patch available but no known exploit, or a secret found only in old git
history no longer reachable from a running deployment, is `major`; a
missing defense-in-depth control on an already-authenticated internal
surface is `minor`; a hardening suggestion with no concrete exploit path
in this repository is `note`.

Report both on every finding. A low-confidence blocker is still
low-confidence — reported plainly as one, never inflated by its own
severity and never suppressed for the same reason.

## What this skill never does

- Never remediates. No `--fix` exists here, in any category.
- Never touches git history — reading it is the whole point of the
  secrets category below; rewriting it is `commit`'s explicit never,
  inherited here without exception.
- Never generates a security header, CSP policy, or middleware from
  scratch. It reports whether one exists and whether what exists is
  permissive — writing new security-bearing code is `implement`'s job,
  from a `plan`, reviewed like any other change before it ships.
- Never fabricates a CVE ID, CWE number, or OWASP category it cannot cite
  from actual tool output or actual code. An uncited severity claim is not
  a finding.

## A leaked secret is not fixed by deleting it from the working tree

If a real secret turns up in git history and not only the working tree,
say so explicitly and separately: removing it from the latest commit does
not remove it from history, and the only real fix — rotating the
credential at its provider — is an action outside this repository that no
`--fix` here could ever perform safely. Report every commit it appears in
and recommend rotation first; a history rewrite (`git filter-repo` or the
BFG, run by the user, never by this skill) is optional and secondary to
rotation, not a substitute for it.

## A dependency finding belongs to exactly one skill — name which

A dependency that is both vulnerable and unused is a `cleanup` removal,
not a `security` upgrade: deleting dead surface is strictly better than
patching it. State which applies on every dependency finding instead of
leaving the reader to cross-reference two reports.

## Done gate

- [ ] Every finding cites what backs it: a tool's actual output, a
      matched pattern with the match shown masked, or a specific missing
      control named against a specific entry point.
- [ ] No secret's full value appears anywhere in the report.
- [ ] Every category in scope has a coverage row, even a clean one.

## Category files

Every invocation reads all five — there's no flag that narrows this
skill's scope the way `cleanup`'s refactor flags do. `security-deps.md`
is the one exception: skip it, with the reason stated in the report, when
no dependency manifest exists at all.

| File | When |
|------|------|
| `secrets-patterns.md` | Always — the pattern list itself, shared with `commit` |
| `security-secrets.md` | Always — working tree and git history |
| `security-deps.md` | Always, unless no dependency manifest exists |
| `security-code.md` | Always — OWASP-categorized code-level review |
| `security-config.md` | Always — headers, CSP, CORS, cookies, CI/CD, infra config |
