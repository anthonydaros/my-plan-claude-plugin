# Cleanup: Dead Code and Unused Dependencies

Applies to the `cleanup` skill's default sweep. Read `cleanup.md` first —
the confidence/severity split and the grep-verification step apply to
every candidate this file's tools produce.

## What counts as dead code

Unused imports and exports (search every import of an exported symbol;
zero references outside entry points and public API is a candidate).
Unreachable code: statements after an unconditional `return`/`throw`/
`break`/`continue`; branches impossible by type narrowing or a constant
condition; commented-out blocks (delete — git is the history, not the
comment). Dead feature flags: a flag or env check that's always true or
false in every environment — remove the dead branch *and* the flag check
together, not one and not the other. Old implementations kept "just in
case," unused DTOs/types, empty files, a duplicate function whose extra
copy has zero references (two copies both called is `--simplify`
duplication work, not dead code — see `cleanup-refactor.md`).

## Per-stack tooling

Detect the stack from what the repository actually declares
(`package.json`, `pyproject.toml`/`requirements.txt`, `go.mod`,
`Cargo.toml`, `pom.xml`/`build.gradle`, `*.csproj`, `composer.json`,
`Gemfile`) — never a guess from what a stack usually looks like. A
polyglot repository gets one pass per stack found.

| Stack | Dead code | Unused / missing dependencies |
|-------|-----------|--------------------------------|
| JS/TS | `npx knip` (`--production` for a stricter pass; covers files, exports, *and* deps in one run) — `tsc --noUnusedLocals --noUnusedParameters --noEmit`, ESLint `no-unused-vars` as lighter fallbacks | Knip covers this too; `npx depcheck` standalone |
| Python | `vulture <path> --min-confidence 60` (a 100 floor reports only unused arguments and unreachable code — unused functions and classes sit at 60%, imports at 90%, so a 100 floor blinds the tool to most dead code; the whole-repository grep, not this flag, is the false-positive filter); `ruff check --select F401,F841` or `pyflakes` for imports/locals | `deptry .` (DEP001–DEP005 violation codes, works with Poetry/pip/PDM/uv) |
| Go | compiler catches unused imports; `staticcheck` (`U1000`, broadest — funcs/vars/consts/types) or `deadcode ./...` (functions only, needs a `main`) | Find phase: `go mod tidy -diff` (Go 1.23+, prints the change without writing — the plain form rewrites `go.mod`/`go.sum` unconditionally and must never run in the find phase). Under `--fix`: plain `go mod tidy`, always followed by `go build ./... && go test ./...` — it can be too aggressive for a library re-exporting a dependency's types |
| Rust | `cargo clippy --all-targets --all-features` for `dead_code` (plain `cargo clippy` misses test/feature-gated code) | `cargo machete` (stable, fast, textual — default) or `cargo +nightly udeps` (slower, more accurate) |
| Java/Kotlin | No CLI-scriptable equivalent to Knip/Vulture exists here — IntelliJ's "unused declaration" inspection is real but IDE-driven; say so under confidence, don't invent tool authority | `mvn dependency:analyze` / Gradle `./gradlew buildHealth` (only with the Dependency Analysis plugin already applied — not a built-in Gradle task; absent the plugin, that's a tool-coverage gap to declare, not a plugin to add) |
| C# | Roslyn rules `IDE0051`/`IDE0052` via `dotnet format style --verify-no-changes --diagnostics IDE0051 IDE0052` (`--verify-no-changes` matters: `dotnet format` applies fixes by default, and the `analyzers` subcommand excludes code-style/IDE rules entirely) | — |
| PHP | `phpstan` dead-code rules, Rector's `dead-code` set | `composer unused` |
| Ruby | `debride <path>` or the newer `leftovers`; self-reported high false-positive rate under `send`/`method_missing` — lean on manual grep-verification more than the tool here | `degem`; same caveat — not `bundler-leak` (flags known memory-leak gem versions) or `bundle-audit` (vulnerabilities), neither of which finds dead dependencies |

A stack not in this table is not a gap to work around silently — say so
in the report and treat every finding there as manual-grep reasoning,
capped at medium confidence.

## False-positive traps, by shape (not by stack — the same shape recurs everywhere)

- **Framework entry points**: file-based routing (Next.js `pages/`/`app/`,
  Nuxt, SvelteKit), a Go `main` package, Django/Flask views only reached
  via `urls.py`/`@app.route` string dispatch.
- **Dynamic dispatch**: `@pytest.fixture`, Django `clean_*` validators and
  `Meta` classes, dependency-injection registries, `getattr`/`send`, a
  plugin loaded by string.
- **Gated code**: `#[cfg(test)]`, a Go build tag, a feature flag — a
  single default-config tool run won't see code compiled only under a
  different flag.
- **Public library surface**: an exported symbol with zero *internal*
  callers may be exactly the point of a package with no `main`; neither
  staticcheck nor `deadcode` nor clippy can see external callers.

## Also flag — report-only, even under `--fix`

Duplicated libraries doing the same job (two HTTP clients, two date
libraries), a dev-dependency living in production scope, a dependency
used only by code this same pass is about to remove. Each of these has
live callers, so resolving one is a migration, not a deletion —
`--simplify` or `plan` work, never a `--fix` removal.
