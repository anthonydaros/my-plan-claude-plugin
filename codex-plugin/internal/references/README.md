# Reference guides

Depth behind the review lenses, the architecture checklist, and the
implementation checklist. Nothing here is a process: the lenses in
`checklists/review.md` decide what is a finding, the contracts decide the shape
of a result, and these files only say what the defect looks like in a given
stack.

**Load at most two: the one matching the repository's stack, and the one
matching the concern in front of you.** Loading the set defeats the point —
these files exist so a Worker can be specific without carrying twenty guides it
will not open. A stack the table does not list is not a gap to work around; the
lenses stand on their own.

Attribution and license: `NOTICE.md`.

## By stack

| Stack | File | Stack | File |
|-------|------|-------|------|
| React, Next.js | `react.md` | Java 17/21, Spring Boot 3 | `java.md` |
| Vue 3 | `vue.md` | Java 8, legacy | `java8.md` |
| Angular 17+ | `angular.md` | Kotlin, Android | `kotlin.md` |
| Svelte 5 | `svelte.md` | Swift, SwiftUI | `swift.md` |
| TypeScript | `typescript.md` | C# / .NET 8 | `csharp.md` |
| CSS, Less, Sass | `css-less-sass.md` | PHP 8.x | `php.md` |
| NestJS | `nestjs.md` | Ruby, Rails | `ruby.md` |
| Python | `python.md` | Go | `go.md` |
| Django, DRF | `django.md` | Rust | `rust.md` |
| FastAPI | `fastapi.md` | Zig | `zig.md` |
| C | `c.md` | C++ | `cpp.md` |
| Qt | `qt.md` | | |

A repository on several stacks takes the one the diff is actually in, not all of
them.

## By concern

| Concern | File | Reached from |
|---------|------|--------------|
| SOLID, coupling, dependency direction, anti-patterns | `architecture-review-guide.md` | `checklists/architecture.md`, the `complexity` lens |
| Web Vitals, memory, hot paths, caching | `performance-review-guide.md` | the `performance` lens |
| SQLi, XSS, CSRF, SSRF, IDOR, uploads, CORS, secrets | `security-review-guide.md` | the `security` lens |
| Reuse audit, parameter sprawl, leaky abstractions, redundant state | `code-quality-universal.md` | the `maintainability` and `complexity` lenses |
| Language-specific pitfalls | `common-bugs-checklist.md` | the `correctness` lens |
| Writing a finding someone can act on | `code-review-best-practices.md` | rarely: the contract and `change-check.tpl` already say this |
| N+1 and query shape | `cross-cutting/n-plus-one-queries.md` | `checklists/implementation.md`, the `performance` lens |
| Parameterization and raw SQL | `cross-cutting/sql-injection-prevention.md` | `checklists/implementation.md`, the `security` lens |
| Output encoding | `cross-cutting/xss-prevention.md` | `checklists/implementation.md`, the `security` lens |
| Error classification and contracts | `cross-cutting/error-handling-principles.md` | `checklists/implementation.md`, the `correctness` lens |
| Async, workers, races, cancellation | `cross-cutting/async-concurrency-patterns.md` | `checklists/implementation.md`, the `correctness` lens |

## Where these sit against the lenses

A reference never overrides a lens. Where a guide is stricter than
`checklists/review.md`, the lens still decides whether something is reportable
and at what severity — in particular the rule that a finding names a path and a
line range, and the rule that style and taste are not findings. Several of these
guides were written for a review that hands a human a list of suggestions; this
product hands a contract to another Worker, and the difference matters most
exactly where a guide is most enthusiastic.
