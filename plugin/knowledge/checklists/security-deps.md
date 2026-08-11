# Security: Dependency Vulnerabilities

Applies to the `security` skill's dependency category. Read `security.md`
first. This asks a different question than `cleanup`'s dependency check:
`cleanup` asks whether a dependency is still *used*; this asks whether one
the repository *keeps* is *vulnerable*. A dependency that is both is a
`cleanup` removal, not a finding here — say so explicitly when it comes up
instead of reporting the same package twice under two different verdicts.

## Per-ecosystem tooling

Detect the stack from what the repository actually declares, the same way
`cleanup-code.md` does. A polyglot repository gets one pass per stack
found.

| Stack | Command | Notes |
|-------|---------|-------|
| JS/TS (npm) | `npm audit --json` | Severity: critical/high/moderate/low |
| JS/TS (pnpm) | `pnpm audit` | |
| JS/TS (yarn) | Yarn 1: `yarn audit --json`; Yarn 2+ (Berry): `yarn npm audit --json` | Yarn Berry removed the bare `audit` subcommand entirely; check the installed major version first |
| Python | `pip-audit` | Queries PyPI's advisory feed by default, `--service osv` opts into the OSV database, no API key needed either way; prefer over `safety check`, deprecated in favor of `safety scan` and whose full database is commercial |
| Go | `govulncheck ./...` | Call-graph aware — it only flags a vulnerability if this repository's code actually reaches the vulnerable function, so a clean result is a stronger claim than a manifest-only scan, not a blind spot |
| Rust | `cargo audit` | Needs `cargo install cargo-audit` if absent — a tool-coverage gap to declare, not a blocker |
| Java/Kotlin (Maven) | `mvn dependency-check:check`, or the standalone `dependency-check.sh`/`osv-scanner`/`trivy fs`/`grype` against the manifest if the Maven plugin isn't applied | OWASP Dependency-Check (any form) needs an NVD API key since the 2023 NVD API change — without one, database updates throttle to near-unusable; declare that gap explicitly rather than reporting a stale "clean" |
| Java/Kotlin (Gradle) | `./gradlew dependencyCheckAnalyze`, same fallbacks as Maven | Same NVD API key caveat |
| PHP | `composer audit` | Built into modern Composer, no separate tool install needed |
| Ruby | `bundle audit check --update` | Needs `gem install bundler-audit` if absent; `--update` refreshes the local advisory database first — a stale DB under-reports silently |
| C#/.NET | `dotnet list package --vulnerable --include-transitive` | |
| Docker (if a Dockerfile exists) | `docker scout cves <image>` or `trivy image <image>`, whichever is installed | An application-level audit never sees the base image's own CVEs — flag the gap if neither tool is available rather than skipping the question |

A stack not in this table is not a gap to work around silently — say so
in the report and treat every finding there as manual-reasoning only,
capped at medium confidence.

## Never resolve dependencies inside the repository being audited

Some of these tools need a resolved lockfile to run at all and error
without one — `npm audit` fails with `ENOLOCK` against a manifest that has
no `package-lock.json`. That error is never license to run the installer
in place: doing so writes a lockfile into a repository this skill must
leave untouched, the same violation a fix-mode audit command would cause.
Copy the manifest (and lockfile, if one exists) to a scratch directory
outside the repository, resolve and audit there, and discard the copy
afterward — never resolve, install, or lock anything inside the
repository itself.

## Direct vs. transitive

Report which a vulnerable package is. A direct dependency's fix is
usually a version bump in the manifest; a transitive one usually needs an
override/resolution field (`overrides` in npm, `resolutions` in Yarn,
`[patch]` in Cargo) pointing at a fixed version, since the manifest never
names it directly. Say which fix shape applies — "bump the version" is
the wrong instruction for a transitive finding.

## Exploitability in this repository, not just in the advisory

A CVE's own severity score describes the vulnerable function in the
abstract; whether it's a `blocker` here depends on whether this
repository's code actually reaches that function. Before finalizing
severity: does the code call the vulnerable function/module/codepath, or
only an unrelated part of the same package? `govulncheck` answers this
for Go directly; for every other stack, a targeted grep for the vulnerable
API name (the advisory usually names it) is the same "grep before trusting
the tool" discipline `cleanup` applies to a dead-code candidate, aimed at
the opposite question — not "is this unused" but "is this reachable."

Reachability is a fact about the code, confirmed or not — never let
whether it was *confirmed* leak into the severity tier itself. When no
tool and no grep settles it either way, assume reachable (the safer
assumption when direction is unknown) for severity purposes, and cap
confidence at medium per `security.md` to say plainly that the tier rests
on an assumption, not a check.

## Severity mapping

- **`blocker`** — critical/high CVSS, a known public exploit, and the
  vulnerable path is reached (or reachability is unconfirmed).
- **`major`** — critical/high CVSS with a patch available but no known
  public exploit, and the path is reached (or unconfirmed); or the
  finding is in a dev-only dependency that still touches CI/build supply
  chain.
- **`minor`** — low/moderate CVSS with a low-friction patch available; or
  any CVSS level where the vulnerable path is confirmed *not* reached
  from this repository's own code.
- **`note`** — a package past its own end-of-life (no future security
  patch will ever come, whether or not a CVE exists today) is worth
  flagging even with nothing currently exploitable — the finding is "plan
  the upgrade," not "patch a vulnerability."

## Out of scope here

A merely outdated-but-not-vulnerable package is staleness, not a security
finding — leave it alone unless it's also past end-of-life (see `note`
above). Applying the fix (`npm audit fix`, a manual version bump, an
override entry) is never this skill's job — report the package, the
version that resolves it, and whether that's a direct or transitive fix;
running it is the user's call, or `implement`'s from a `plan` when the
upgrade needs compatibility testing first.
