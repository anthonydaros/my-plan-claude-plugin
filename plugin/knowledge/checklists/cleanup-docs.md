# Cleanup: Meta-Doc and Config Drift

Applies to the `cleanup` skill's default sweep. Read `cleanup.md` first.
Unlike dead code, most of this category is text-only under `--fix` — see
`cleanup.md`'s "what `--fix` may ever touch" rule.

## What rots fastest

Guidance files describe the repository as it was when last edited, and
nobody re-reads them on every change — verify every path, command, and
count they mention still matches the repository as it stands, never trust
the prose that's already there.

- **`CLAUDE.md` / `AGENTS.md`** (or their equivalents): a skill, command,
  or module count that no longer matches `ls`; an instruction referencing
  a deleted path, script, or command; a stale convention contradicted by
  the code itself. Long files burn tokens every session they're
  loaded — drop what's no longer true rather than appending a correction
  next to the outdated line.
- **`.claude/`**: `commands/` or `skills/` entries for something that no
  longer exists; `settings.json` permissions or hooks pointing at a
  script that's gone.
- **`.cursor/`, `.cursorrules`, `.github/copilot-instructions.md`,
  `.windsurfrules`**: same treatment as CLAUDE.md/AGENTS.md — and if the
  team has visibly stopped using one of these tools (no other trace of it
  in the repository), the config is itself a candidate for removal, not
  just a correction.
- **`.github/workflows/`, `.vscode/`**: a workflow step, task, or launch
  entry referencing a deleted app, script, or path.
- **README and other prose docs**: a relative link that no longer
  resolves; a documented command that no longer runs; an example
  referencing a removed feature.

## `.gitignore` coverage, both directions

Something tracked that a `.gitignore` rule already covers (see
`cleanup-residue.md`'s `git ls-files -i` command) — and the reverse:
something excluded only by a *global* or user-level ignore file, not this
repository's own `.gitignore`. The second case is invisible on the
machine that has the global rule and shows up as untracked-and-committable
on any other — a real, previously-observed instance of this: a
`.claude/settings.local.json` ignored only by the user's global gitignore,
not the project's own.

## How to verify, not just grep

A count or enumeration in prose ("eight skills," "three checklists") is
checked against the actual directory listing, not against what the
sentence already claims. A link is checked by resolving the relative path
from the file that contains it, not by pattern-matching the string. A
"this command still works" claim needs the command to actually be
runnable from what the repository declares (`package.json` scripts,
`Makefile` targets) — not assumed from the sentence being grammatically
fine.
