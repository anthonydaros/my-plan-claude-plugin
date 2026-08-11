# Security: Secrets

Applies to the `security` skill's secrets category. Read `security.md`
first — the confidence/severity split and the masking rule apply to
every candidate this file's scan produces.

## Working tree

Every tracked file, plus untracked files that aren't gitignored (an
untracked `.env` is exactly the shape a leak takes before its first
commit). Read `secrets-patterns.md` for the exact filenames to flag
outright and the exact content patterns to grep for.

Also check `.gitignore` coverage: does it exclude `.env`, `*.pem`,
`*.key`, and the other refuse-outright patterns from `secrets-patterns.md`?
A repository with no such entries isn't automatically a finding — it may
simply never have needed one — but a repository that *has* a matching
tracked file and *lacks* the `.gitignore` entry that would have stopped it
is a `major` on its own, independent of whatever the file itself contains.

## Git history

A secret removed from the working tree is not removed from history — this
is the check `commit`'s pre-stage scan structurally cannot do, since it
only ever sees what's about to be staged. For each pattern in
`secrets-patterns.md`, run:

```
git log --all -p -G'<pattern>' -- .
```

`-G` (not `-S`), because the patterns in `secrets-patterns.md` are
regexes (`api[_-]?key`, `xox[baprs]-`) — plain `-S` treats its argument as
a literal string unless `--pickaxe-regex` is added, so it silently misses
most of this list. `-G` also catches a secret that's later moved or
edited, which a pure count-based pickaxe can miss. `--all` covers every
branch and tag, not only the current `HEAD`, since a secret can survive
on an abandoned branch nobody deleted.

A repository with a very large history (as a rough line: history deep
enough that a full `-G` pass across every pattern would run for minutes,
not seconds) is a real cost-benefit call, not a silent shortcut — say so
under Declared blindness, scan a bounded window instead (the most recent
N commits, or the last two years, whichever the repository's own age
makes more sensible), and name the exact bound used in the report.

For every match found in history, record which commit(s), whether that
content is still present in the current `HEAD` (a working-tree finding
too, if so) or only in history, and treat it per the "leaked secret" rule
in `security.md` — rotation first, regardless of whether it's still
live in the working tree.

## Masking, always

Every finding — working tree or history — is masked per
`secrets-patterns.md`. No exception for a history-only match just because
it's "already old."

## False-positive shape

A matched pattern in a test fixture using an obviously fake value (a
provider's own documented example key, a value like `sk-test-000...0`),
in a comment describing the pattern rather than containing an instance of
it, or in this plugin's own `secrets-patterns.md`, `security.md`, or this
file (which must legitimately contain these strings to check for them) is
not a finding — read the surrounding context before reporting, the same
grep-then-verify discipline `cleanup` applies to a tool's raw output. Mask
it in the report the same way a real finding would be, even while
explaining why it's excluded — the exclusion changes whether it's a
finding, not whether its value gets printed.
