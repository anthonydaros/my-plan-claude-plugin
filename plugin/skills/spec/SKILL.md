---
name: spec
description: Turn a rough goal into a decision-complete brief with testable acceptance criteria, through a bounded round of one-at-a-time questions. Writes docs/brief.md and touches nothing else in the repository. Manual only.
argument-hint: "<goal>"
disable-model-invocation: true
---

# My Plan: Spec

Turns a goal into `docs/brief.md`: requirements, non-goals, acceptance
criteria, risks, and an expected write set — decided, not vague, and
checkable by someone who didn't write it. Nothing changes while this runs
except `docs/brief.md` itself. Invoking `plan` on the result afterward is
what treats it as approved; this skill itself asks for nothing beyond the
questions it raises along the way.

Arguments: $ARGUMENTS

Codex CLI does not substitute `$ARGUMENTS`. If you are running as a Codex
session, take the text after `$my-plan:spec` in the user's message as the
goal instead.

## Before asking anything

Read `docs/map.md` if it exists — stack, boundaries, conventions, pitfalls,
already verified. If it doesn't exist, say so plainly and do a lighter
version yourself: read the code the goal touches, canonical docs, tests, and
relevant history. Every question you ask that the repository could have
answered spends the user's attention on work you should have done first.
Suggest `/my-plan:map` in the closing note when its absence cost you real
digging.

**Research, when the repository can't settle it.** Specialized business
terminology, market behavior, regulation, standards, current facts, an
external integration, or a greenfield idea with nothing local to check
against — any of these means the web is the evidence and the code isn't.
Search generically and never send repository code, secrets, personal data,
customer identifiers, or confidential business details to a search
provider. Regulated or high-stakes claims need a primary or official
source where one exists; note where you couldn't find one.

## Asking questions

Ask only what actually changes something: product behavior, user
experience, business policy, scope, acceptance criteria, consequential
risk, credentials, an external side effect, or a real preference between
similarly valid options. A reversible technical detail with one clearly
safer, simpler answer — pick it yourself, note it in the brief's Decisions
table, and don't spend a question on it.

One question at a time; wait for the answer before the next. Arrive with a
recommendation, not an open request to think for the user — "it depends"
is not an answer to hand back. Each question: a precise prompt, two to
four concrete options with honest tradeoffs, and one clearly marked
recommendation.

Round shape: ask what's material now, take the answers back to the
evidence (they usually reveal something you couldn't have known to check
before), ask what that exposes, repeat. Stop when a round produces nothing
that would change scope, behavior, acceptance criteria, or risk — or
earlier, if you notice you're asking things the repository could answer or
re-asking something already settled. If genuine ambiguity survives anyway,
don't guess silently: write it into the brief as an explicit, flagged
assumption instead.

Across all rounds, stay under roughly ten questions total. Past that
you're interrogating, not specifying — write what's left as flagged
assumptions, each with your recommended answer, and let the user reopen
the ones that matter.

**Sharpen the language as you go.** When the user's term conflicts with
what the repository already calls it, say so and ask which governs. When a
word is vague or overloaded, propose a precise term and confirm it. When
the user describes behavior the code contradicts, surface the
contradiction directly — don't quietly pick a side. Record each resolved
term in the brief with the synonyms it displaces, so the same collision
doesn't reopen the debate later.

## Write `docs/brief.md`

Render it from `../../knowledge/templates/brief.md`. Every requirement
testable, every acceptance criterion checkable by someone who wasn't in the
room. The expected write set is the product paths the goal actually
touches — name a directory or glob where the exact files aren't knowable
yet; `plan` narrows it, never widens it — plus the repository's changelog
when it keeps one and the change will be visible to a user of the
software.

If `docs/brief.md` already exists and this is a new goal, ask before
overwriting it — a stale brief nobody reads is better than a real one
silently lost. If it's the same goal revised, say what changed and why.

Before closing, print the decisions you made without asking (the
Decisions table rows that never became questions) and every flagged
assumption. Invoking `plan` is what approves this brief, so what the user
would be approving must be visible in the conversation, not only in the
file.

## Closing note

```
Changed: docs/brief.md written/updated
Validated: not this skill's job
Open risks: <flagged assumptions the brief carries, or "none">
Suggested next skill: plan — or map first, if its absence cost real
  digging here
```
