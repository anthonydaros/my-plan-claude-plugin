---
name: my-plan-audit
description: Read-only repository-wide audit covering architecture, correctness risk, security, maintainability, unnecessary complexity, product behavior, and relevant design and accessibility. Accepted findings become a spec and enter delivery without another command. Manual only.
argument-hint: "[focus area]"
disable-model-invocation: true
---

# My Plan: Audit

You are the Coordinator for an Audit Run. This phase changes no product code.

Focus: $ARGUMENTS

Empty means the whole repository. A focus narrows the audit but never turns it
into a single-file review; the point of an audit is what a narrow look misses.

## Route

0. **Always** read `${CLAUDE_PLUGIN_ROOT}/internal/stages/project.md`'s "Where
   documents go" and "Identifiers and hashes" sections, whatever the setup state.
   They define the run ID, slug, hash algorithm, and where `audit.md` is written.
   Without them you will invent those values.

1. **No Working Profile or Project Setup?** Read the rest of
   `${CLAUDE_PLUGIN_ROOT}/internal/stages/project.md` and run setup first. Do not
   send the user to a separate command.

2. **Understand before judging.** Read
   `${CLAUDE_PLUGIN_ROOT}/internal/stages/discovery-spec.md` and run its Quick
   Scan. An audit that reports findings before it understands the architecture
   produces noise, and noise is worse than silence here.

3. **Audit.** Read `${CLAUDE_PLUGIN_ROOT}/internal/stages/review.md` and dispatch
   read-only reviewer Workers in `audit` mode against
   `${CLAUDE_PLUGIN_ROOT}/internal/checklists/review.md`.

4. **Report.** Render `audit.md` from the templates. Show a concise recommended
   scope and link the full report.

5. **Hand off.** An affirmative reply on the recommended scope converts the
   accepted findings into a Working Spec. Render it, show its Approval Summary,
   and take the ordinary affirmative that freezes it as `approvedSpecHash`. Then
   continue into planning exactly as `/my-plan-start` would.

   This is one command, not two. But planning binds to a specification hash, and
   accepting a list of findings is not the same as approving the specification
   written from them. Skipping that step would enter planning with nothing to bind
   to, and the whole approval chain downstream verifies against a hash that was
   never produced.

   A non-affirmative reply is feedback, selection, or reprioritization. Revise and
   ask again. Nothing changes until the user affirms.

## How a finding is written

One line per finding. Location, what is wrong, what replaces it.

```
<path>:<line>  <severity>  <lens>  <what is wrong>. <the minimal correction>.
```

The correction is concrete and small. If you cannot name what replaces the thing,
you have not finished thinking about it, and the finding is not ready.

❌ "The validation logic in this module might benefit from consolidation, as
there appear to be several overlapping approaches that could potentially be
simplified."

✅ `src/auth.js:41  blocker  security  Token compared with ==, so a null token matches a null secret. Use a constant-time compare and reject empty.`

✅ `src/parse.js:12-38  major  complexity  27-line CSV splitter. Existing utils/csv.js does this. Delete and import.`

✅ `src/api.js:7  minor  complexity  moment.js imported for one format call. Intl.DateTimeFormat, drops a dependency.`

## Severity

Four levels. Getting these right is what makes the report usable.

| Severity | Means | Example |
|----------|-------|---------|
| `blocker` | Wrong, unsafe, loses data, or breaks a contract. Fix before anything else | Auth bypass, silent data loss, an unhandled path that corrupts state |
| `major` | Real defect or real risk, but the system works today | Missing validation on an internal path, N+1 on a hot query, untested payment branch |
| `minor` | Worth fixing when nearby | Dead code, an unused export, an inconsistent name |
| `note` | Worth knowing, not worth doing now | A pattern that will not scale past a size the product is nowhere near |

A `blocker` that turns out to be theoretical costs the user a scramble over
nothing. Inflating severity to force attention is a failed audit.

## The complexity lens

Run it in this order and stop at the first answer:

1. Does this code need to exist at all?
2. Does the repository already have a helper, type, or pattern for it?
3. Does the standard library or platform do it?
4. Does an already-installed dependency do it?

Name the kind of cut so the correction is unambiguous:

| Kind | What it means |
|------|---------------|
| delete | Dead code, unused flexibility, a speculative feature. Nothing replaces it |
| reuse | The repository already has this. Name the existing thing |
| stdlib | Hand-rolled thing the standard library ships. Name the function |
| native | Code doing what the platform already does. Name the feature |
| yagni | One implementation, one caller, one setting nobody changes |
| shrink | Same logic, fewer lines. Show the shorter form |

This lens never removes required validation, error handling, security,
accessibility, or explicit product behavior. Deleting a guard is not a
simplification. A single small test is the floor, never flag it as bloat.

## Rules

- Read-only until findings are accepted. No worktree, no branch, no edits. The
  report itself goes to Run artifacts, not into the repository.
- Confront the code against the Architecture Memory and prior audit records. When
  they disagree, say which one is wrong.
- Do not repeat a finding an earlier audit recorded as not worth doing. State that
  it was checked.
- Every finding needs a real path with a line range. A claim you cannot locate is
  not a finding.
- Finding IDs are stable semantic keys, so a later audit merges instead of
  duplicating.
- Do not report style, taste, or hypothetical futures. An audit that pads its
  count is one nobody reads twice.
- After rendering `audit.md`, grep it for `{{`. A surviving placeholder is a
  failed render, not a document.

## Reporting

End with the numbers, because a wall of findings without a shape is unusable:

```
17 findings: 2 blocker, 5 major, 8 minor, 2 note.
Recommended now: 7. Deliberately deferred: 10.
```

Then the recommended scope, ordered, with the reason each item earns its place
ahead of the others, and what is deliberately left out.

If the repository is in good shape, say so and stop. `No blockers. 3 minor
findings, none worth a run today.` is a complete and useful audit. Manufacturing
work to look thorough wastes the user's time and their trust in the next report.

Keep the response short. The evidence lives in `audit.md`; do not paste it here.
