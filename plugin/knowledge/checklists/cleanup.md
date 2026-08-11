# Cleanup Checklist

The master checklist for the `cleanup` skill. Read this always; read the
category files under this one only for the tiers actually in scope for
the current invocation.

## Golden rules

Delete on evidence, never suspicion. Refactoring is behavior-preserving —
run the real build/test before and after, not just before. Every change
reversible: small, single-category commits, never one giant sweep landed
as one diff.

## Before anything: the safety net

`git status` clean, or the dirty paths are explicitly outside what this
pass will touch. The repository's real build/test command green *before*
touching anything — discovered the same way `validate` discovers it:
`docs/map.md`'s Validation section, then CI config, then package scripts.
No green baseline, no `--fix` — report-only until one exists. A
repository that declares no build/test command anywhere is not vacuously
green — code, dependency, and residue fixes are report-only there. Meta-doc
drift is the one exception: its re-verification is re-reading the edited
file, not a build, so text-only doc fixes may still proceed under
`--fix`.

This skill never creates a branch on its own. That's the user's call, the
same way `commit` never pushes on its own — if the stakes call for
isolation, the user makes that decision before running `--fix`, not this
skill on their behalf.

## Confidence and severity are two different axes

**Confidence** (high / medium / low) says how sure a finding is real:
high needs the stack's own tool flagging it (see `cleanup-code.md`) *and*
a whole-repository grep for the literal name finding no reference, with
no framework-entry-point or public-API shape. Medium is the grep clean
but no tool available for the stack — the ceiling for a tool-less
stack — or the entry-point/public-API shape ambiguous. Low is the grep
finding a real reference, whatever the tool said, or nothing but
reasoning behind the candidate.

One worked example to calibrate against: knip flags `formatShort` in
`src/utils/date.ts`; `git grep -n formatShort` returns only the
definition; the file is not under `pages/`/`app/` and the package is
private — high. The same export in a published library's `index.ts` —
never high, public-API shape. vulture flags a Django view, and the grep
finds `'app.views.export'` in `urls.py` — low, whatever vulture said.

**Severity** (blocker / major / minor / note) says how bad leaving it is.
A `blocker` is something actively misleading today — a doc instructing a
command that no longer exists, a dependency that only resolves by
transitive luck. `major` is a real risk that isn't broken yet. `minor` is
the ordinary case. `note` is worth knowing, not worth doing now.

Report both on every finding. Never let a high severity substitute for
confidence you don't actually have, or the reverse — a low-confidence
blocker is still low-confidence, and gets reported, not removed.

## A tool's "0 references" is never "0 references anywhere"

Before any candidate becomes a finding, grep the whole repository for its
literal name across what a static tool cannot see: string literals
(reflection, `send`/`getattr`, a plugin or dependency-injection registry
keyed by name), CI config, build/deploy scripts, configuration that loads
a module by string, and documentation. Framework entry points (file-based
routing, a `main` package), a library's public API surface, and
dynamic-dispatch-adjacent code are a structurally different risk class in
every stack — check for this shape explicitly before trusting any tool's
verdict. This single step is what separates a real finding from the most
common false positive.

## Never remove without explicit user approval, whatever the confidence

Public API surface (needs a deprecation period, not deletion) — migration
history — test utilities and fixtures, even ones that look unused — error
handling and fallback code never triggered yet, because not-yet-triggered
is its job — intentionally committed generated files (protobuf, GraphQL
types) — license and legal files — anything referenced only by an
external system (cron, infra, another repository) that this repository's
own grep can't see.

## Never auto-delete unattended

A real, documented case exists of an assistant treating roughly 30% of a
6,000-line codebase as dead code, in some cases hiding rather than
removing what it found. Low-confidence bulk removal is not a smaller
version of correct behavior — it is the failure mode this whole checklist
exists to prevent.

Under `--fix`: high-confidence findings only. A medium-confidence finding
is removed only when the user approves that exact finding in this
session; a low-confidence finding is never removed by this skill,
whatever its severity. Within what may be removed: one item at a time,
highest confidence first, never batched.

Remove it, re-run the real build/test command, and on failure revert just
that one item — `git checkout HEAD -- <path>` for every tracked path it
touched, but only when no earlier item in this run changed the same
file: `HEAD` holds pre-run content, so checking out a shared file also
undoes an earlier, already-verified fix. Before editing a file a previous
item touched, copy it aside and restore that copy on failure instead.

An **untracked** file deleted has no revert; delete it only after the
user approves that exact path in this session. Absent that approval,
report it and move on — `--fix` authorizes reversible removals, and this
one isn't. Never fold an untracked deletion into a batch.

Removing a dependency is not the same operation as editing the manifest:
use the package manager's own remove command (`npm uninstall` / `yarn
remove` / `pnpm remove`, `poetry remove` / `uv remove`, `cargo remove`,
`composer remove`, `bundle remove`; in Go, delete the import and run `go
mod tidy`) — never edit the manifest alone. An edited manifest leaves the
package installed, so the build/test re-run resolves it anyway and passes
whether the removal was safe or not. Reverting a dependency removal is
the same in reverse: restore the manifest and lockfile, then re-run the
installer before the next item's verification run, or that run inherits
a broken environment.

## What `--fix` may ever touch, by tier — not negotiable per invocation

- **Dead code, unused dependencies, build residue, orphan files: yes.**
  One item, re-verify, revert-on-failure, per the rule above.
- **Meta-doc and config drift: yes, but text-only, one file at a time.**
  Re-verify by re-reading the edited file, not a build/test run — there's
  nothing to build for a corrected link or count.
- **Simplify, extract, rename: not `--fix` work at all.** Each applies
  only under its own explicit flag, never as part of a default sweep, and
  `--fix` given alongside one adds nothing — the flag itself is the
  authorization. See `cleanup-refactor.md`.
- **Structural convention mismatches: never.** Report only, always. A
  reorganization is exactly what `plan` and `implement` exist to sequence
  safely — task-shaped, reviewed before it runs. Naming the mismatch and
  handing it off is this skill's job; applying it inline is not, no
  matter how obviously correct it looks.

## Done gate

- [ ] Build, typecheck, lint, full test suite pass against the same
      command discovered at the start — not a different, looser one.
- [ ] `git grep` for every removed/renamed name finds nothing left behind.
- [ ] Every removal or fix landed in its own small, single-category
      commit-ready diff — not one undifferentiated pile.
- [ ] The report accounts for every candidate: removed (with evidence),
      kept-uncertain (with the reason), or handed off (structural).

## Category files

Read only what's in scope for this invocation — not every file, every
time.

| File | When |
|------|------|
| `cleanup-code.md` | Always, for a default sweep — dead code and unused dependencies, per stack |
| `cleanup-residue.md` | Always, for a default sweep — build artifacts, orphan files |
| `cleanup-docs.md` | Always, for a default sweep — AI/tooling config and documentation drift |
| `architecture.md` | Whole-repository scope — the argument-less default — structural convention mismatches, report-only |
| `cleanup-refactor.md` | Only when `--simplify`, `--rename`, or `--extract` was given explicitly |
