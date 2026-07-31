# Stage: Review

Independent review of the Review Subject, remediation of what it finds, and the
approval that authorizes delivery. Also runs the read-only audit for
`/my-plan-audit`.

The Worker that wrote the code never reviews it. This holds in every backend and
every fallback. If the only remaining option would merge those identities, block
the Run instead.

## The Review Subject

The exact Run-owned Git diff proposed for delivery: code, tests, configuration,
memory, specification, plan, implementation record, and validation evidence.

Excluded: `review.md` and `delivery.md`. They record this subject's outcome, so
they cannot be inside it. Those two files are limited to fixed-template Markdown
at their exact Run Dossier paths and may never contain product code,
configuration, or executable content.

Hash the subject before dispatching review. Verify it again before approving. If
it changed under the reviewer, the review is void: rerun affected validation and
review the new subject.

## Reviewers

Every review handoff carries `reviewerRole` and `ownedLenses`. A reviewer cannot
otherwise tell whether a lens it did not examine belonged to someone else or was
its own omission, and the coverage record becomes meaningless.

Every lens has exactly one owner. Together the roles cover all eleven.

**Claude-only.** One independent read-only Fable Worker, the `my-plan-reviewer`
agent, `reviewerRole: "sole"`, owning all eleven lenses. The Coordinator handles
the ledger and remediation. Sonnet wrote the code, so the reviewer is a different
model as well as a different session.

**Hybrid.** Two independent read-only Workers review the same subject:

| `reviewerRole` | Model | `ownedLenses` |
|----------------|-------|---------------|
| `product` | An independent Fable Worker | conformance, behavior, design, accessibility, ux |
| `technical` | Sol at `xhigh` effort via Codex, read-only sandbox | correctness, security, maintainability, tests, performance, complexity |

Repository conventions are part of the maintainability lens, not a lens of their
own. Complexity belongs to the technical reviewer: judging whether code needs to
exist is a technical call, and leaving it unassigned means nobody makes it.

Dispatch Codex Workers per `${CLAUDE_PLUGIN_ROOT}/internal/codex.md`.

Approval requires zero unresolved blockers from every active role.

## Dispatch

Build a handoff matching `${CLAUDE_PLUGIN_ROOT}/internal/contracts/handoff.schema.json`
with `role: "reviewer"` and the right `mode`:

| Mode | Scope |
|------|-------|
| `plan-check` | A plan, before any code exists |
| `audit` | No Run diff. The repository as it stands |
| `incremental` | One task's delivery, or the delta since the last subject hash plus any pending findings |
| `initial` | The complete Review Subject, first pass over the whole change |
| `final` | The complete Review Subject, once more, before delivery |

Most review in a Run is `incremental`, one task at a time as each is delivered.
That is deliberate: a small diff reviewed while the writer still holds its context
costs one cheap correction, and the same defect found ten tasks later costs a
large diff against a session that has moved on.

`initial` and `final` still see everything. Per-task review catches local defects;
only a full pass catches what emerges between tasks.

Artifacts depend on the mode. Send what exists, never a path to a file that does
not:

| Mode | Artifacts |
|------|-----------|
| `audit` | Architecture Memory, project skill, checklist, and prior audit records (`kind: "audit"`). There is no specification, plan, or validation evidence in an Audit Run |
| `initial`, `incremental`, `final` | Specification, plan, validation evidence, Architecture Memory, project skill, checklist |

Pass the handoff path. Never concatenate documents into the prompt; reviewers read
the current files themselves.

Reviewers receive only the active subject, pending Finding Ledger entries, and new
evidence. Closed findings and prior review history are not resent.

## Verify the result

Validate against `${CLAUDE_PLUGIN_ROOT}/internal/contracts/review-result.schema.json`
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
5. Run one `final` complete review from every active role.
6. Bind `REVIEW_APPROVED` to the final subject hash.

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
resolved or dispositioned, the Validation Gate green, and the final complete
review clean.

It binds to the specification hash, plan hash, base SHA, Review Subject hash,
backend, Worker identity, and model.

Any later change to a Review Subject path invalidates it. Rerun affected
validation and a renewed final review. Rendering `review.md` and `delivery.md`
does not invalidate it; that is why they are excluded.

Render `review.md` from
`${CLAUDE_PLUGIN_ROOT}/internal/templates/documents/review.md.tpl`, from the
structured ledger. No extra synthesis model call. It records conclusions and
stable finding IDs, not model conversation.

## Audit mode

For `/my-plan-audit`. Read-only: no worktree, no branch, no edits.

Understand the architecture before judging it. An audit that reports findings
before it understands produces noise, and noise is worse than silence.

Confront the code against the Architecture Memory and prior audit records. When
they disagree, say which one is wrong. Do not resurface a finding an earlier audit
recorded as not worth doing; state that it was checked.

Render `audit.md` from
`${CLAUDE_PLUGIN_ROOT}/internal/templates/documents/audit.md.tpl`. Show a concise
recommended scope, ordered, and say what is deliberately left out.

An affirmative reply converts accepted findings into a Working Spec and enters
planning. No second command. A non-affirmative reply is feedback: revise and ask
again. Nothing changes until the user affirms.
