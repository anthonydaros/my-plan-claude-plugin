---
name: security
description: Audit the repository for leaked secrets (working tree and git history), dependency vulnerabilities, and OWASP-categorized code and configuration risk. Evidence-backed findings only, always report-only — this skill has no --fix. Manual only.
argument-hint: "[path]"
disable-model-invocation: true
---

# My Plan: Security

Audits the repository for security risk that no diff surfaces on its own:
secrets sitting in git history, dependencies with known vulnerabilities,
and configuration nobody wrote as part of a specific change — an absent
security header, a permissive CORS policy, a CI workflow that would run a
fork's code with this repository's secrets. Never fixes any of it. There
is no `--fix` for this skill, in any category — see
`../../knowledge/checklists/security.md` for why.

`review`'s `security` lens (`../../knowledge/checklists/review.md`)
already judges code against the same underlying checklist, including at
whole-repository scope with `review --repo` — but as a judgment call made
once, without a mandatory secrets-in-history scan, a real per-ecosystem
vulnerability-advisory tool, or a citation an audience outside this
repository can act on. `security` runs those three unconditionally, and
attaches an OWASP category and CWE number to every code finding, per
`security-code.md`, so the same underlying lens serves an audience
`review`'s own findings don't need to — a compliance reviewer, a pentest
handoff, an insurance questionnaire. It also owns a question no other
skill asks: is a
dependency the repository already has *vulnerable*, as opposed to
`cleanup`'s question of whether the repository still *uses* it — a
dependency that's both gets one answer, named explicitly wherever the two
overlap.

Arguments: $ARGUMENTS

Codex CLI does not substitute `$ARGUMENTS`. If you are running as a Codex
session, take the text after `$my-plan:security` in the user's message
instead.

Every `../../` path below resolves against the directory containing this
SKILL.md, not your working directory — Codex told you that file's
absolute path when it loaded this skill; use it.

No argument means the whole repository; a path narrows the sweep to that
subtree. Like `cleanup`, there is no diff-shaped default — secrets,
dependencies, and configuration aren't shaped by what's currently staged.

## Independence

**Claude Code.** Dispatch the find phase to the `my-plan-reviewer` agent
(`../../agents/my-plan-reviewer.md`) via the Task tool — read-only by its
own tool list, so a real secret it finds can't be tempted into a "fix" on
the way back. Give it: the scope, and which of
`../../knowledge/checklists/security-secrets.md`, `security-deps.md`,
`security-code.md`, or `security-config.md` apply to this invocation
(ordinarily all four). Some audit tools have a fix form of their own
(`npm audit fix`, `pnpm audit --fix`, `cargo audit fix`) — its existing
boundary already covers running the bare audit/check command, but tell it
explicitly, in the dispatch, never to pass one.

**Codex CLI.** No subagent primitive exists here. If your own context
shows you already touched the code you're about to audit, say that
plainly at the top of the report instead of presenting it as independent —
or hand the sweep to the other host, which restores real independence
instead of just declaring its absence.

## Declared blindness

If `gitleaks`/`trufflehog` aren't installed, or a stack's vulnerability
audit tool from `../../knowledge/checklists/security-deps.md` isn't
installed and can't be fetched, print one line per gap: `Tool coverage:
not evaluated for <what> — <tool> not available; findings in that
category are pattern/manual reasoning only, capped at medium confidence.`
A secret match in a provider's own token format (`sk-`, `ghp_`, `AKIA`,
and the rest of `secrets-patterns.md`'s prefix list) is exempt from that
cap — its own shape is what makes it high-confidence, not the presence of
a scanner, per `security.md`. Still run that category — say plainly what
backs each finding in it.

If the repository's history is deep enough that a full git-history scan
is impractical, say so and name the bounded window actually scanned, per
`../../knowledge/checklists/security-secrets.md`.

If `docs/map.md` doesn't exist, print: `Entry-point context: not
evaluated — docs/map.md not found; whether a flagged endpoint is
internal-only or public-facing (which changes several findings' severity)
is assumed from generic heuristics only.` Still run the sweep — the
absence of a map lowers the confidence ceiling, it doesn't cancel the
pass.

## What you do

1. **Read `../../knowledge/checklists/security.md` first** — the golden
   rules, the masking rule, confidence/severity, and the no-`--fix`
   boundary apply to everything below.
2. Read `security-secrets.md` and scan the working tree and git history
   for the patterns in `secrets-patterns.md`.
3. Read `security-deps.md`, detect the stack(s) present, run each one's
   vulnerability-audit tool, and check reachability before finalizing
   severity.
4. Read `security-code.md` and sweep the repository against `review.md`'s
   `security` lens plus the OWASP/CWE citation rules, using
   `../../knowledge/references/security-review-guide.md` for depth. Read
   `docs/map.md` first if it exists, so an endpoint's actual exposure is
   understood before its severity is judged.
5. Read `security-config.md` and check headers, CSP, CORS, cookies,
   CI/CD, Dockerfiles, and IaC for presence and strictness.
6. Report, in the shape below.

## Output

A report in the shape of `../../knowledge/templates/report.md`: Scope,
Repository understanding, Findings, Not worth doing, Verdict, carried over
unchanged. "Lens coverage" becomes **Category coverage** — one row per
category (`secrets`, `deps`, `code`, `config`), each `passed` / `found N`
/ `not-applicable` with a reason. Each finding row carries confidence,
severity, and — for a `code` finding — its OWASP category and CWE where
one cleanly applies:

```
<path>:<line>  <severity>  <confidence>  <category>  <what's wrong>. <the minimal correction>. [OWASP-A0x, CWE-xxx]
```

No secret's real value ever appears in a finding — masked per
`secrets-patterns.md`. Finding nothing is a valid result, and better than
manufacturing findings to look thorough.

## Closing note

```
Changed: none — read-only, always
Validated: not this skill's job
Open risks: <count of blocker findings, or "none">
Suggested next skill: plan, for a finding that needs a code or config
  change — or the package manager's own upgrade command, run yourself,
  for a dependency finding — then review and commit as usual.
  For a leaked credential: rotate it at the provider first, regardless of
  what else this suggests.
```
