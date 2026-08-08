# Review Checklist

Applies to audit, plan review, and code review. Every item produces a finding only
when it can be tied to a path and a line range. An item with nothing behind it is
not reportable.

Skip any lens the changed surface does not touch. A backend-only diff has no
accessibility findings.

## conformance

- Every requirement and acceptance criterion in the approved specification has
  corresponding behavior in the diff.
- No behavior exists that the specification does not authorize. Scope added
  quietly is a finding, however small.
- The diff stays inside the approved write set.
- The plan's completed tasks match what the diff actually contains.

## correctness

- The change does what it claims for the ordinary case.
- Edge cases: empty, zero, one, missing, malformed, duplicate, concurrent, and
  maximum input.
- Error paths are reachable and correct, not just present.
- No off-by-one, inverted condition, wrong operator precedence, or swapped
  argument.
- Async work is awaited, ordered, and cancelable where ordering matters.
- Existing callers of every modified function still hold. A signature or behavior
  change that fixes one caller and breaks its siblings is a blocker.
- Every API, method, and library the diff calls exists in the version the
  lockfile installs. A confident call to a function that was never in that
  release is the defect a writing model produces most often, and it reads as
  correct code.
- Read-check-write on shared state uses an atomic update, a constraint, a lock,
  or a version, rather than hoping the window is small.
- Anything that charges, sends, or provisions is idempotent under retry. Retries
  are bounded and are not applied to validation, authorization, or permanent
  conflicts.
- Outbound calls carry a timeout, and cancellation propagates.
- A migration is separable from the deploy: the previous version of the code
  still runs against the new schema, or the diff shows why it never has to.

## security

- Input from a trust boundary is validated before use, not after.
- No secret in a tracked file, log line, error message, or fixture.
- Authorization is checked at the boundary that enforces it, not only in the UI,
  and per resource rather than per session: ownership, tenant, role, or scope.
  Authentication without that is the shape an IDOR takes.
- The authorization filter is inside the query, not applied to what it returned.
- Writable fields are an explicit allowlist. A raw payload persisted as-is is how
  `role`, `isAdmin`, `ownerId`, and `tenantId` arrive from the client.
- Injection surfaces are parameterized: SQL, shell, path, template, deserializer.
- User-controlled data does not reach a sink that executes or renders it raw.
- User input that reaches an LLM prompt is treated as an injection surface, with
  the same suspicion as input reaching a SQL query.
- LLM output is untrusted input. It is schema-validated or sanitized before it
  reaches anything that executes, queries, renders, or calls a tool.
- New dependencies and external calls are justified and pinned.

## maintainability

- Naming says what the thing is, in the language the repository already uses.
- No copy-paste of logic that already exists elsewhere in the repository.
- Comments explain why, not what. A comment restating the code is noise.
- Dead code, unused exports, unreachable branches, and leftover debugging are
  removed.
- The change is consistent with the module boundaries in the Architecture Memory.
- A failure in the new code would be diagnosable from what it logs or reports.
  Code on a critical path that fails silently is a finding here, at the severity
  its path deserves — not an observability wishlist.

## tests

- New non-trivial behavior has an observable-behavior check.
- Auth, deletion, persistence, payment, cost, and external contract paths have a
  behavioral or integration check. This is not negotiable by convenience.
- Tests assert real outcomes, not that a mock was called.
- A failing test would actually fail if the logic broke. A test that passes
  against a broken implementation is worse than no test.
- A regression check has been observed failing against the unfixed code. A check
  written after the fix, that never failed, proves only that the code does what
  the code does.
- A refactor over previously uncovered code pinned the old behavior first.
- Mock-pain tripwire: when the setup is larger than the assertions, the seam is
  wrong. That is a design finding, not a test finding.
- The seam reached for is the cheapest one that works, in this order: an exported
  pure helper, an injectable client, a module mock, then integration. Reaching
  past a cheaper seam needs a reason.
- Coverage debt, if any, is explicit with its reason and escape plan.
- One small behavioral check is the floor. Never ask for it to be deleted, and
  never ask for it to be grown into a suite nobody requested.

## performance

- No N+1 query, unbounded fetch, or loop over a network call.
- Data structure and algorithm fit the real input size, not the toy case.
- No blocking work on a latency-sensitive path.
- Caching, when added, has a correct invalidation story.

## behavior

- The end-to-end flow works from the user's entry point, not only at the unit
  level.
- State transitions are complete: loading, empty, error, partial, and success.
- Failure is recoverable and does not lose user work.
- The change matches what the specification promised the user, not merely what it
  said technically.

## design

- Visual hierarchy matches the importance of the actions on the screen.
- Spacing, alignment, and type scale follow the repository's existing system
  rather than introducing new values.
- New components reuse existing primitives.

## accessibility

- Interactive elements are reachable and operable by keyboard, in a sensible
  order.
- Every control has an accessible name.
- Color is not the only signal for state, and contrast meets the repository's
  stated standard.
- Focus is visible and moves correctly when content changes.
- Motion respects a reduced-motion preference.

## ux

- Copy is specific and actionable. An error tells the user what to do next.
- The number of decisions and steps is the minimum the task requires.
- Destructive actions are confirmable or reversible.
- Nothing surprising happens without feedback.

## complexity

Stop at the first answer:

1. Does this code need to exist at all, given the approved specification?
2. Does the repository already have a helper, type, or pattern for it?
3. Does the standard library or platform do it?
4. Does an already-installed dependency do it?

Additional signals:

- An interface, factory, or generic with exactly one use.
- Configuration for a value that never varies.
- Indirection that exists only to be flexible later.
- A new dependency for what a few lines already in the repository can do.
- A wrapper that only delegates.
- A dead flag, or a branch nothing reaches.

Name the kind of cut so the correction is unambiguous:

| Kind | What it means | The replacement |
|------|---------------|-----------------|
| delete | Dead code, unused flexibility, speculative feature | Nothing |
| reuse | The repository already has this | Name the existing helper |
| stdlib | Hand-rolled thing the standard library ships | Name the function |
| native | Code doing what the platform already does | Name the feature |
| yagni | One implementation, one caller, one setting | The direct call |
| shrink | Same logic, fewer lines | Show the shorter form |

Every complexity finding names the concrete smaller replacement. This lens never
removes required validation, error handling, security, accessibility, or explicit
product behavior. Deleting a guard is not a simplification.

## Depth, when a lens needs it

`internal/references/` holds one guide per stack and one per cross-cutting
concern, next to this checklist; `references/README.md` maps them. Load at most
two: the repository's stack, and the concern actually in front of you.

They are depth, not authority. A guide says what a defect looks like in Go or in
React; this checklist still decides whether it is reportable, and the rules that
outrank every guide are the ones above — a finding names a path and a line range,
style and taste are not findings, and severity is not inflated to force
attention. Several of those guides were written to hand a human a list of
suggestions. This product hands a contract to another Worker.

A stack with no guide is not a gap. The lenses stand without one.
