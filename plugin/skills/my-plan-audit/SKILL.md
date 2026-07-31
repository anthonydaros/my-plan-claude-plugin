---
name: my-plan-audit
description: Read-only repository-wide discovery and audit covering architecture, complexity, correctness risk, maintainability, product behavior, and relevant design and accessibility. Accepted findings become a spec and enter delivery without another command. Manual only.
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
   read-only reviewer Workers in `audit` mode.

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

## Rules

- Read-only until findings are accepted. No worktree, no branch, no edits.
- Confront the code against the Architecture Memory and prior audit records. When
  they disagree, say which one is wrong.
- Do not repeat a finding an earlier audit already recorded as not worth doing.
  State that it was checked.
- Every finding needs a real path with a line range, a concrete impact, and the
  minimal correction. A finding without evidence is not reportable.
- Finding IDs are stable semantic keys, so a later audit merges instead of
  duplicating.
- Severity is honest. A blocker is wrong, unsafe, loses data, breaks a contract,
  or violates a stated requirement. Everything else is major or minor.
- Report what is deliberately left out of the recommended scope, and why.
- After rendering `audit.md`, grep it for `{{`. A surviving placeholder is a
  failed render, not a document.

## Reporting

A short recommended scope, ordered, with the reason each item earns its place. The
full evidence stays in `audit.md`. Do not paste the whole report into the
response.
