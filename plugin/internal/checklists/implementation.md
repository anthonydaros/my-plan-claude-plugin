# Implementation Checklist

The defects that survive a plausible-looking implementation: the code compiles,
the happy path works, the test passes, and the failure arrives in production
under load, under concurrency, or under an attacker. Reading the code does not
reveal them, which is why they are listed rather than left to judgement.

Two readers. **The Worker writing code** works the parts its task's surface
actually touches, and nothing wider — a task that adds a string constant has no
transaction story. **An audit** works the same list across the repository, where
it is a catalogue of what to go looking for rather than a standard to meet.

The audit reading changes the burden of proof, not the list. A missing
transaction is a finding when you can name the two writes that must land
together and the path where they do not; "this could theoretically race" is not
a finding, in an audit or anywhere else in this product.

## Database access

- **No N+1.** A query inside a loop over rows is the default failure. Use a join,
  controlled eager loading, batch loading, or an aggregate query.
  `references/cross-cutting/n-plus-one-queries.md`
- Select the fields needed. Not `SELECT *`, not whole relations in a listing, not
  a serialized entity where an id would do.
- Filter, sort, aggregate, and paginate in the database, not in memory after
  fetching everything.
- Pagination on anything that grows: a maximum limit and a stable ordering with a
  tiebreaker. Prefer a cursor to a large offset.
- Index what you filter, join, and sort on, including the idempotency key.
- **A transaction around writes that must land together.** Order plus balance
  plus stock is one write or none.
- No open transaction across an HTTP call.

## Concurrency and reliability

- Read, check, then write is a race. Use an atomic update, a constraint, a lock,
  or optimistic versioning — and say in the result which one.
  `references/cross-cutting/async-concurrency-patterns.md`
- **Idempotency on anything that costs money or sends a message.** A key, a
  constraint, or a deduplication window that actually holds under retry.
- Retry only what is safe to retry. Never a validation error, an authorization
  failure, a permanent conflict, or a non-idempotent request. With a limit,
  backoff, and jitter.
- A timeout on every outbound operation, with cancellation propagated.
- No blocking call in an async context, no fire-and-forget without failure
  tracking, no unbounded concurrency.
- No mutable global holding per-request or per-user state.

## Migrations

Expand, migrate, contract — in separate steps, so the old and new code can run at
once. Never in one step: dropping or renaming a column, adding `NOT NULL` to a
large table without a backfill, a type change that takes a long lock, or an index
build that blocks writes.

The code, the database, the queues, and the API contract stay compatible between
adjacent versions. A deploy that requires exact simultaneity is a deploy that
will fail once.

## Security, per endpoint the task touches

- Authorization per resource — ownership, tenant, role, scope — not merely
  authentication. This is what prevents IDOR, and it is the most common missing
  piece.
- The authorization filter belongs inside the query, not applied to its results.
- Mass assignment: an explicit allowlist of writable fields. Never persist a raw
  payload, or `role`, `isAdmin`, `ownerId`, and `tenantId` arrive from the client.
- Re-validate on the server everything the client sent: price, status, quantity,
  permission. The frontend is a convenience, never a control.
- Parameterized queries only.
  `references/cross-cutting/sql-injection-prevention.md`
- Encode on output, per sink. `references/cross-cutting/xss-prevention.md`
- No secret in code, logs, error messages, fixtures, or a container image. No
  password, token, cookie, card number, or full payload in a log line.
- Explicit limits on every public operation: payload size, page size, filter
  count, export size.
- `references/security-review-guide.md` for CORS, uploads, rate limiting, webhook
  replay, and the fail-open versus fail-closed decision.

## Errors

Never `catch` everything into a 500, and never into `null`, an empty list, or a
false success. Distinguish validation, authorization, conflict, and
unavailability, and keep the error contract consistent with what the repository
already returns. `references/cross-cutting/error-handling-principles.md`

An error swallowed here is a bug reported six months later with no stack trace.

## Before reporting the task complete

Your validation commands are in the handoff and they are the gate. These are the
things the commands do not catch:

- The changed flow was actually exercised, not merely compiled.
- No mock, hardcoded value, `TODO`, or silent fallback left as the answer.
- No dead code, no duplicated function, no second implementation of a flow kept
  alongside the first.
- No `any`, cast, ignore comment, or disabled rule added to quiet the compiler.
- **Every API, method, and library used exists in the version the lockfile
  installs.** A plausible call to a function that does not exist is the defect a
  writing model produces most often and the one a reading reviewer catches least.
- No new dependency the repository could not already do without.
- Documentation the task's write set covers is updated: README, OpenAPI,
  examples, environment variables.
- Tests cover the rule, the contract, and the failure — not the happy path alone
  and not a mock asserting it was called.

A risk you could not validate goes in the result as a blocker or a note. It never
goes unreported because the commands passed.
