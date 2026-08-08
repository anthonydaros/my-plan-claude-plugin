# Stage: Review

Independent review of the Review Subject, remediation of what it finds, and the
approval that authorizes delivery. Also runs the read-only audit for
`$my-plan:audit`.

The Worker and model that wrote the code never review it. If the only available
option would merge those identities, block the Run instead.

## The Review Subject

The exact Run-owned Git diff proposed for delivery: code, tests, configuration,
memory, specification, plan, implementation record, and validation evidence.

Excluded: `review.md` and `delivery.md`. They record this subject's outcome, so
they cannot be inside it. Those two files are limited to fixed-template Markdown
at their exact Run Dossier paths and may never contain product code,
configuration, or executable content.

Hash the subject before dispatching review. Run `git add -N` over the Run-owned
paths first: untracked files are invisible to `git diff`, and a subject hashed
with part of itself invisible verifies cleanly while covering less than the
approval thinks it does. Verify the hash again before approving. If it changed
under the reviewer, the review is void: rerun affected validation and review the
new subject.

## Reviewers

Every review handoff carries `reviewerRole` and `ownedLenses`. A reviewer cannot
otherwise tell whether a lens it did not examine belonged to someone else or was
its own omission, and the coverage record becomes meaningless.

Every lens has exactly one owner. Together the roles cover all eleven.

For `plan-check` the subject is a plan, not code, so most lenses have nothing to
look at. That review owns exactly four: `conformance` (does it deliver the
approved specification), `correctness` (is it executable as written, with real
paths and honest dependencies), `tests` (does non-trivial behavior get a check),
and `complexity` (does the work need to exist, and does it reuse what is there).
Everything else is `not-applicable`, because there is no code yet to secure,
maintain, or make accessible.

Two independent read-only Workers review the same subject:

| `reviewerRole` | Worker | `ownedLenses` |
|----------------|--------|---------------|
| `product` | Codex on Sol at `high` | conformance, behavior, design, accessibility, ux |
| `technical` | Codex on Sol at `high` | correctness, security, maintainability, tests, performance, complexity |

Both are Sol because Terra wrote the code and Sol did not, and both run in
separate threads that have seen none of the implementation. A reviewer that
watched the code being written reviews its own reasoning.

Sharing a tier means sharing its blind spots, which is the cost of this order and
worth naming. A product judgement the user marks as critical rotates to a fresh
Sol session at `xhigh`; a diff too wide for one thread splits by lens or area.

Escalate the technical role to Sol at `xhigh` when the subject is one deeply
interlocking thing — a race, a transaction that can half-commit, a permission
model. A wide subject splits instead; see below.

Repository conventions are part of the maintainability lens, not a lens of their
own. Complexity belongs to the technical reviewer: judging whether code needs to
exist is a technical call, and leaving it unassigned means nobody makes it.

**An audit has no writer.** Nothing was produced by this Run, so the independence
rule that picks a reviewer does not apply and only width decides. Use Terra at
`high`, `reviewerRole: "sole"`.

A whole repository is the widest subject this product reviews, and it is the one
most likely to exceed what a Codex thread can hold. When it does, split the audit
into `product` and `technical` roles, then split the technical side by lens if it
is still too wide. A subject nobody could read whole is a different result from
one a Worker chose not to, so every partition must be named in the coverage
record.

Dispatch Codex Workers per `<pluginRoot>/internal/codex.md`.

Approval requires zero unresolved blockers from every active role.

### The QA gate

Reading the diff and running it are different acts, and until here only one of
them has been done by someone independent. The Validation Gate in
`implementation.md` is real, but the Worker that wrote the code is the Worker that
ran it and the Worker that reported the exit codes. Every check between there and
here trusts that report.

So once no blockers remain and before the final complete review, one read-only
Worker executes the Validation Gate itself and reports what it observed.

It runs on the tier that did not write the code, which here is always Sol at
`high`: implementation is Terra and never Sol, for the same reason. Sol carries
technical review, product review, and QA, and that is acceptable because none of
them wrote the subject — but it is why QA is a separate session rather than
another pass in the technical reviewer's thread. A Worker that already argued the
code was correct is not the Worker to discover its tests do not run.

`mode: "qa"`, `reviewerRole: "qa"`, `ownedLenses` of `tests`, `correctness`, and
`conformance`, and the required commands in `validationCommands`. Empty
`writeSet`: it executes commands, it does not edit. Its instructions are
`<pluginRoot>/internal/prompts/qa.tpl`. Validate the result against
`review-result.schema.json` like any other review.

What it owns:

- Run every required Project Profile command and every affected test, from the
  handoff, not from memory of what the record says was run.
- Compare its observed exit codes against `validation.md`. A command recorded
  green that is not green now is a `blocker` on the `tests` lens, and the
  discrepancy itself is the finding — whichever way it points.
- Check that the acceptance criteria in the specification are actually exercised
  by something that ran. A criterion no command touches is a `conformance`
  finding, not a passing lens.

A QA Worker runs commands, so it is dispatched with `--sandbox workspace-write`
rather than the read-only sandbox every other reviewer gets. That is the one
review role where the sandbox cannot carry the read-only boundary, and the
Coordinator's path check against the write set is what covers it: build output,
caches, and coverage files are byproducts, never staged, and the commit stages
exactly the set named under Commit in `implementation.md`.

A `blocked` verdict returns to remediation like any other. It does not re-run the
whole review: the correction goes back to the implementation Worker, the affected
commands run again, and QA re-runs. Approval waits for it to come back clean.

### Splitting a review instead of escalating

A subject too large or too varied for one technical reviewer splits by specialty:
several read-only Workers on Sol at `high`, each carrying
`reviewerRole: "technical"` and a disjoint slice of the technical lenses —
correctness, security, performance, tests, and maintainability with complexity.
Every lens keeps exactly one owner, every Worker returns the same contract, and
their findings merge into the Finding Ledger by key like any other round. There is
no synthesis Worker: merging structured findings is the Coordinator's job.

Split when the lenses need different kinds of attention. Escalate when one lens
needs the same attention applied harder. Doing both at once returns the same
finding several times and costs a round to deduplicate.

## Dispatch

Build a handoff matching `<pluginRoot>/internal/contracts/handoff.schema.json`
with `role: "reviewer"` and the right `mode`:

| Mode | Scope |
|------|-------|
| `plan-check` | A plan, before any code exists |
| `audit` | No Run diff. The repository as it stands |
| `incremental` | One task's delivery, or the delta since the last subject hash plus any pending findings |
| `initial` | The complete Review Subject, first pass over the whole change |
| `qa` | The Validation Gate, executed independently once no blockers remain |
| `final` | The complete Review Subject, once more, before delivery: what the approved plan said would be delivered, against what actually was |

Most review in a Run is `incremental`, one task at a time as each is delivered.
That is deliberate: a small diff reviewed while the writer still holds its context
costs one cheap correction, and the same defect found ten tasks later costs a
large diff against a session that has moved on.

`initial` and `final` still see everything. Per-task review catches local defects;
only a full pass catches what emerges between tasks.

`initial` is for a change that arrives whole, without per-task review: an audit
handed to delivery, or a Run resumed with work already committed. When every task
was reviewed as it landed, skip straight to `final`; there is no first pass left
to make.

Artifacts depend on the mode. Send what exists, never a path to a file that does
not:

| Mode | Artifacts |
|------|-----------|
| `audit` | Architecture Memory, project skill, checklist, and prior audit records (`kind: "audit"`). There is no specification, plan, or validation evidence in an Audit Run, and `ownedLenses` therefore omits `conformance`: there is nothing approved to conform to |
| `initial`, `incremental`, `final`, `qa` | Specification, plan, validation evidence, Architecture Memory, project skill, checklist |

Pass the handoff path. Never concatenate documents into the prompt; reviewers read
the current files themselves.

Reviewers receive only the active subject, pending Finding Ledger entries, and new
evidence. Closed findings and prior review history are not resent.

## Verify the result

Validate against `<pluginRoot>/internal/contracts/review-result.schema.json`
before trusting it. Check that `subjectHash` matches what you dispatched. Check
that every finding cites a real path.

Invalid, unparseable, or unsupported output is a failed attempt, never an implicit
approval. A text sentinel alone approves nothing.

## Finding Ledger

Findings are keyed by `taskId` plus finding ID, not by finding ID alone. Two
parallel tasks can independently produce the same semantic key for genuinely
different defects in different files; merging them on the ID would silently close
one when the other was fixed.

Within one task, the same defect keeps the same ID across every round and every
reviewer. A reworded finding with a new ID is a duplicate, not a discovery.

Only the final complete review may consolidate IDs across tasks, and only with
explicit evidence that two findings are the same defect.

Every finding ends in one of four states, with evidence:

- **Resolved.** The correction landed and the reviewer confirmed it.
- **Not reproducible.** The reviewer could not reproduce it against the current
  subject.
- **Blocked by an owner decision.** Recorded with the decision and its reason.
- **Accepted, not blocking.** A `major` or `minor` finding the Run deliberately
  ships without fixing, with the reason. Only non-blockers are eligible.

That fourth state exists because only blockers go back for remediation. Without
it, a `major` finding can never reach a terminal state, and the ledger carries an
open item into approval that nothing will ever close.

Approval requires zero open blockers. It does not require zero findings.

## Remediation loop

1. Valid blockers go back to the implementation Worker, never to the reviewer that
   found them. Reviewers do not repair their own findings.

   Send them **one at a time**, or one tightly related group at a time. Never hand
   a writer the whole list. A writer given twelve findings fixes the first few
   properly and pattern-matches the rest, and the next review round has to work
   out which is which. Confirm one closed, then send the next.

2. Rerun the affected part of the Validation Gate.
3. Delta review: `incremental` mode, pending findings and the changed paths only.
4. Repeat until no blockers remain.
5. Run the QA gate. A blocker here re-enters this loop at step 1.
6. Run one `final` complete review from every active role.
7. Bind `REVIEW_APPROVED` to the final subject hash.

QA precedes the final review rather than following it, because the final review
judges delivery against the approved plan and a subject whose tests do not
actually pass is not ready to be judged on anything else. It also comes last among
the checks that can still send work back: putting it after approval would mean
either approving on an unverified run or invalidating a fresh approval.

The first review is complete. Remediation reviews are not; re-reviewing unchanged
code wastes a round and produces noise. Approval always requires one final
complete pass.

Reuse the same session per role across rounds so the repository is not resent.

### Budget

Budgets, like stagnation, are scoped to one remediation episode, not to the Run.
A twenty-task Run legitimately runs far more than four review rounds in total.

After four rounds or sixty minutes **within one episode**, rotate to a fresh role
session with the current subject, only pending findings, changed paths, and new
evidence. Rotation is not failure and never triggers plan rewriting or another
approval.

Rotate the Coordinator's own context the same way. The Finding Ledger is on disk;
closed findings, resolved rounds, and the diffs you already read do not need to
stay in your head. Carry the open findings and the current subject hash forward
and let the rest go. A Coordinator that runs out of context mid-loop strands a
Run that was otherwise finishing normally.

A Worker timeout preserves the diff, logs, and finding state, then resumes in the
same worktree.

### Stagnation

Stagnation is scoped to one remediation episode: a single subject with open
findings that successive rounds are trying to close. It is not a Run-wide counter.

Within an episode, progress means a pending finding closed, or new evidence
materially changed one. Rewording, prose edits, and re-reading an unchanged subject
are not progress.

Three consecutive rounds without progress **inside one episode** end the Run as
`BLOCKED`. Report what remains open. Do not approve incomplete work to escape the
loop, and do not keep spending on a loop that is not converging.

A clean review ends its episode and resets the counter. This matters now that
every task delivery is reviewed: a healthy twenty-task Run produces twenty reviews
that find nothing, and a Run-wide counter would read those as three rounds without
progress and block a Run whose only fault was being correct.

There is no fixed round limit while findings are actually being resolved.

## Approval

`REVIEW_APPROVED` is created only after: every contract validated, every finding
resolved or dispositioned, the Validation Gate green under the QA gate that
executed it independently, and the final complete review clean.

It binds to the specification hash, plan hash, base SHA, Review Subject hash,
runtime, Worker identity, and model.

Any later change to a Review Subject path invalidates it. Rerun affected
validation and a renewed final review. Rendering `review.md` and `delivery.md`
does not invalidate it; that is why they are excluded.

Render `review.md` from
`<pluginRoot>/internal/templates/documents/review.md.tpl`, from the
structured ledger. No extra synthesis model call. It records conclusions and
stable finding IDs, not model conversation.

## Audit mode

For `$my-plan:audit`. Read-only: no worktree, no branch, no edits.

Understand the architecture before judging it. An audit that reports findings
before it understands produces noise, and noise is worse than silence.

Confront the code against the Architecture Memory and prior audit records. When
they disagree, say which one is wrong. Do not resurface a finding an earlier audit
recorded as not worth doing; state that it was checked.

Render `audit.md` from
`<pluginRoot>/internal/templates/documents/audit.md.tpl`. Show a concise
recommended scope, ordered, and say what is deliberately left out.

An affirmative reply on the recommended scope converts the accepted findings into
a Working Spec. Render it, show its Approval Summary, and take the ordinary
affirmative that freezes it as `approvedSpecHash`. Only then enter planning.

One command, two confirmations. Accepting a list of findings is not the same as
approving the specification written from them, and planning binds to a
specification hash. Entering planning straight from the findings leaves
`approvedSpecHash` unset, and every downstream check verifies against a hash that
was never produced.

A non-affirmative reply is feedback: revise and ask again. Nothing changes until
the user affirms.
