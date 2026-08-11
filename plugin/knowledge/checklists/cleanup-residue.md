# Cleanup: Build Residue and Orphan Files

Applies to the `cleanup` skill's default sweep. Read `cleanup.md` first —
the same confidence/severity split and never-without-approval list apply
here.

## Build residue and artifacts

Untracked generated output (`dist/`, `build/`, `coverage/`,
`__pycache__/`, `target/`), logs, dumps, `.DS_Store`, editor swap files,
and a lockfile left behind by a package manager the repository no longer
uses.

```sh
git clean -ndX                         # preview ignored files, dry-run — never -f here
git clean -nd                          # preview untracked-and-not-ignored files — .DS_Store, logs, and swap files live here when no ignore rule covers them
git ls-files -i --exclude-standard -c  # tracked files that should be ignored instead
```

The first two commands preview what `git clean` *would* remove without
touching anything — this skill runs the preview forms only, never the
destructive `-f`. `-ndX` covers only files a `.gitignore` rule already
matches; `-nd` is what catches the common case — a stray `.DS_Store` or
log file the repository never bothered to ignore. The third command finds
the opposite problem: something tracked in Git that a `.gitignore` rule
already covers, meaning it was added before the rule existed, or the rule
was added after.

## Orphan and stale files

Unreferenced assets (images, fonts, fixtures, seed data) — test
snapshots of code that's already gone — files named `*.old`, `*.bak`,
`*-copy`, `*-v2`, `temp*` — documentation for a feature that's been
removed entirely (a broken link *inside* a doc that should stay is
`doc-drift`, not this category — see `cleanup-docs.md`).

`.env.example` (or the repository's equivalent template) out of sync with
the variables the code actually reads — a variable in the template
nothing reads anymore, or a variable the code reads that the template
never mentions, either direction is a finding.

## What makes these different from dead code

No stack-specific tool exists for most of this category — it's grep and
`git log`/`git blame` reasoning, not a static analyzer's output. Treat
"untouched for 6+ months, zero references, no test/fixture use" as a
useful heuristic for staleness, never as confidence on its own — it still
needs the same whole-repository grep `cleanup.md` requires before
anything here becomes a finding rather than a candidate.
