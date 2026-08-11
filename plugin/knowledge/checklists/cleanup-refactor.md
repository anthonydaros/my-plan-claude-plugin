# Cleanup: Simplify, Extract, Rename

Only relevant when `--simplify`, `--extract`, or `--rename` was given
explicitly — never part of a default sweep. This is active code
transformation, not removal of no-longer-needed things; it earns a higher
bar of care than the rest of `cleanup`, not a lower one. Read `cleanup.md`
first — the "behavior-preserving, tests before and after" golden rule
applies to every operation below without exception.

## Simplify

Applies where complexity isn't justified by the domain — never where it
is; a function that's complex because the domain is complex gets a
comment, not a rewrite.

- **Nesting**: convert nested `if`/`else` to early returns (guard
  clauses); target a maximum of three indent levels; extract a deeply
  nested callback into a named function.
- **Naming**: no abbreviations (`usr` → `user`, `cfg` → `config`);
  booleans read as questions (`isValid`, `hasPermission`); a
  boolean-returning function starts with `is`/`has`/`can`/`should`.
- **Duplication**: parameterize instead of copy-paste; tolerate
  duplication across a module boundary when the coupling a shared
  function would add is worse than the repetition.
- **Conditionals**: a descriptive variable for a complex boolean, a
  lookup table instead of a long `if`/`else` chain, no ternary nested
  inside another ternary.

Simpler means easier to read on first pass, not fewer lines. Run the real
test suite after each simplification, one kind of change per commit.
Simplify never chooses its own scope: it runs only on the path the user
named. No path, no simplify.

## Extract (function, component, module, hook)

1. Determine parameters (variables used inside the block but defined
   outside it) and returns (variables the block modifies that are used
   after it); identify side effects.
2. Name by purpose, not implementation. A typed interface. Five
   parameters or fewer — an options object past that.
3. Replace the original block with a call to the extracted unit; update
   every import and call site; keep the exact same error-handling
   behavior, not an improved one — this is extraction, not a rewrite.
4. Tests pass before and after.

## Rename (symbol or file)

1. Find every reference — source, tests, mocks, configuration, env vars,
   CI, documentation — **including string literals** (API routes, error
   messages) and related names (`User` → also `UserProps`, `UserSchema`).
2. Handle casing variants (`myFunc`/`MyFunc`/`MY_FUNC`) and preserve each
   convention rather than normalizing them. Never touch
   `node_modules`/`vendor`/a dependency directory.
3. A file rename updates every import path referencing the old name,
   including dynamic imports and bundler/tsconfig path aliases. Use
   `git mv` so history follows the file.
4. **Preview every change and get explicit confirmation before applying**
   — this step is not optional the way it might be for a single-file
   simplify. Then apply atomically and run the type checker and test
   suite.

## What stops any of these three

The same revert discipline as everywhere else in `cleanup`: if the
build/test run after applying fails, revert the whole operation as one
unit rather than leaving a half-applied transformation in the tree —
`git checkout HEAD -- <path>` for every file the operation *modified*,
`git mv <new> <old>` to reverse a rename, and plain `rm` for a file the
operation *created*, since `git checkout HEAD --` errors with "pathspec
did not match" on a path `HEAD` has never seen.
