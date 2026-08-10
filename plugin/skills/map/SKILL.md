---
name: map
description: Write or refresh docs/map.md, a committed, user-editable repository navigator — stack, exact validation commands, module boundaries, non-obvious conventions, proven pitfalls. The planning, review, and validation skills read it first when it exists. Manual only.
argument-hint: "[focus area] | refresh"
disable-model-invocation: true
---

# My Plan: Map

Builds or updates `docs/map.md`: the one document every other My Plan skill
checks for first, so a bare `review` or `implement` invocation isn't starting
from nothing. It replaces two things from an earlier, more automated version
of this plugin — a per-run architecture memory that got rebuilt and thrown
away every time, and a generated project file only the plugin was allowed to
edit. Neither survives here. `docs/map.md` is an ordinary file: commit it,
edit it by hand, delete a section that's gone stale. This skill writes it
directly but never commits it — review the diff, amend it, or revert it;
you keep the last word.

Arguments: $ARGUMENTS

Codex CLI does not substitute `$ARGUMENTS`. If you are running as a Codex
session, treat the line above as literal and instead take the text typed
after `$my-plan:map` in the user's message as your argument string.

Empty arguments or `refresh` means re-verify the whole document against the
repository as it stands today. A focus area (a module name, a directory)
narrows what you re-verify but never shrinks the document's other sections —
you're updating one part of a whole map, not writing a partial one.

## What you do

1. **Read before you write anything.** Package manifests and lockfiles, CI
   configuration, existing canonical docs (`README`, `CONTRIBUTING`,
   architecture docs the repository already has), test configuration, and
   `git log` for changes that reveal a pattern (a file that keeps getting
   fixed for the same reason is a pitfall worth recording). Use whatever
   navigation tool is actually available — an LSP, an indexing tool, the
   host's own search — and fall back to plain reading when none is. Every
   fact in the output must be verified from this repository, not assumed
   from what its stack usually looks like.

2. **If `docs/map.md` already exists**, read it first and treat it as a
   claim to verify, not a draft to overwrite. Where it still holds, leave it
   alone — don't rewrite prose that didn't need rewriting just to have
   touched it. Where the repository has moved on, update the affected
   section and say what changed. Where a human clearly hand-edited a
   section (a note, a caveat, a correction that doesn't read like generated
   prose), preserve it; you're a contributor to this file, not its owner.

3. **Write `docs/map.md`** in this shape:

   ```markdown
   # <repository name>: Map

   Verified from the repository, not assumed from its stack. Written by
   `/my-plan:map`; edited by anyone. Refresh with `/my-plan:map refresh`
   when it drifts.

   ## Stack

   <languages, frameworks, package manager — use it, don't introduce another>

   ## Validation

   <the exact commands that prove a change works, each citing the source
   that defines it — a CI config path or a package script — and marked
   "observed passing" only when this run actually executed it. Never
   guessed>

   ## Module boundaries

   <where one module requires a matching change in another, and where
   changes are safely isolated>

   ## Conventions that aren't obvious from the code

   <only what a competent stranger would get wrong — not a style guide>

   ## Pitfalls

   <proven failures, each with the evidence that proved it — a past bug, a
   comment explaining a workaround, a test guarding a specific regression.
   Not hypothetical warnings>
   ```

   Omit a section with nothing real to say rather than filling it with
   generic advice — a padded section is worse than a missing one, because it
   reads like verified content when it isn't.

## Declared blindness, from the other side

The other skills check for `docs/map.md` before reasoning without it —
`validate` runs this document's Validation commands first, before it even
looks at CI config. That only works if this skill keeps the document
honest: don't record a validation command you can't cite to the CI config
or package script that defines it, a boundary you inferred rather than
confirmed, or a pitfall you can't point to real evidence for. A wrong map
is worse than no map, because the skills that lean on it won't know to
doubt it.

## Closing note

End with, printed to the conversation, never elaborated beyond this:

```
Changed: <sections of docs/map.md touched, or "none — already current">
Validated: not this skill's job
Open risks: <anything you couldn't verify and left out, or "none">
Suggested next skill: spec, if there's a change to plan next
```
