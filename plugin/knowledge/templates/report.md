# Report: {{scope}}

Evidence record for a `review`, `review-plan`, or `validate` run. Markdown
evidence only — never product code, configuration, or executable content —
and conclusions, not model conversation.

## Scope

What was reviewed: a diff, a branch, a path, a plan and its task files, or
the whole repository (`--repo`), and against what, if anything — a brief,
a plan, or nothing named (see "Declared blindness" in the skill that
produced this report).

## Repository understanding

Only for a `--repo` scope with no diff to follow: what this pass established
about the current architecture before judging it, grounded in paths. A
report that judges before it understands produces noise.

## Findings

```
<path>:<line>  <severity>  <lens>  <what is wrong>. <the minimal correction>.
```

One line per finding, evidence first. If you cannot name what replaces the
thing, the finding isn't ready yet.

| Severity | Means | Example |
|----------|-------|---------|
| `blocker` | Wrong, unsafe, loses data, or breaks a contract. Fix before anything else | Auth bypass, silent data loss, an unhandled path that corrupts state |
| `major` | Real defect or real risk, but the system works today | Missing validation on an internal path, N+1 on a hot query, untested payment branch |
| `minor` | Worth fixing when nearby | Dead code, an unused export, an inconsistent name |
| `note` | Worth knowing, not worth doing now | A pattern that won't scale past a size the product is nowhere near |

Inflating severity to force attention is a failed report, the same as
missing a real one.

## Lens coverage

| Lens | Outcome | Reason if not applicable |
|------|---------|---------------------------|

Every lens from `checklists/review.md`, even the ones that don't apply.
`passed` means "I looked" — an absent row is not the same as a clean one.

## Not worth doing

Findings that are real but not worth the change, each with the reason. This
is the deliberate-deferral record the next reader won't otherwise have.

## Verdict

For a diff/branch/path scope: whether it's ready, and what blocks it if not.
For a `--repo` scope: a recommended subset worth doing now, ordered, with
what's deliberately left out.

End with the count, because a wall of findings with no shape is unusable:

```
17 findings: 2 blocker, 5 major, 8 minor, 2 note.
```

If the subject is in good shape, say so and stop. "No blockers. 3 minor
findings, none worth a change today." is a complete and useful report.
Manufacturing findings to look thorough costs the next report its trust.
