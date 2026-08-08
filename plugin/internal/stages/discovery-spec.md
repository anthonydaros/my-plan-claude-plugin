# Stage: Discovery and Specification

Read-only investigation that ends in a decision-complete Working Spec and one
ordinary approval.

Nothing in the user's repository changes during this stage. You write Run
artifacts and transient setup state, nothing else.

## 1. Quick Scan

Read before asking anything. Every question you ask that the repository could have
answered spends the user's attention on work you should have done.

Cover: code, canonical documentation, the project skill, the complete Architecture
Memory, tests, configuration, and relevant history. Scan the frontmatter of past
Run Dossiers and load only the ones relevant to this goal.

Then classify:

- Existing-product change, or greenfield idea.
- The business domain it belongs to.
- The repository's existing vocabulary for the concepts in the goal.

In Workspace Mode, read lightweight metadata for every repository in the snapshot,
then narrow deeper reading to the ones the goal actually touches.

In Greenfield Mode, record the empty state. The user's idea and constraints
replace repository evidence as the starting packet.

Greenfield discovery must also settle what an existing repository would have
answered: the Git identity to commit under, the initial branch name, and whether
the project has a remote at all. Record them in the decision register. The
identity in particular is checked again before `git init`, and there is nothing to
check it against unless discovery recorded it.

## 2. Domain Research

Trigger-based, not mandatory. A local change with sufficient current repository
evidence does not search the web.

Triggers: specialized business terminology, market behavior, regulation,
standards, current facts, an external integration, greenfield work, insufficient
local evidence, or an explicit user request.

Research is not only technical. The repository tells you how the software works;
it rarely tells you what the business needs it to do, what its market expects, or
which rules constrain it. When a goal turns on any of that, the web is the
evidence and the code is not.

Once a trigger fires, research runs automatically. Do not ask for a separate
command or permission.

- Context7 for version-specific technical documentation.
- Web search for current business, market, and regulatory evidence.
- Regulated or high-stakes claims need a primary or official source where one
  exists.

Queries are generic and sanitized. Never send repository code, secrets, personal
data, customer identifiers, or confidential business details to a search provider.

Record every material claim with its source title, URL, access date, type,
confidence, and relevance in `research.md`. Confidence comes from whether the
source is official and whether its version matches what the repository actually
installs, not from how convincing the page looked.

Research informs the questions and the recommendation. It never silently decides
the user's product policy.

In Greenfield Mode, research runs before the first question, so vague assumptions
become concrete options the user can choose between.

## 3. The Question Engine

### Resolve before you ask

For every uncertainty, try in this order: code, canonical documentation, history,
tests, the project skill, the Architecture Memory. Ask the user only what is left.

A question is allowed only when the answer materially changes product behavior,
user experience, business policy, scope, acceptance criteria, consequential risk,
credentials, remote creation, deployment, an irreversible external effect, or a
real preference between similarly valid alternatives.

A reversible technical mechanic with one clearly safer and simpler option follows
that option automatically under Recommendation Authority. Write it to the Decision
Checkpoint and the specification. It does not consume the question budget and it
does not interrupt the user.

### How to ask

One question at a time. Wait for the answer before the next one. A batch of
questions gets batch-quality answers.

Walk the design tree branch by branch, resolving dependencies between decisions in
order. A question whose answer depends on an unanswered question comes second.

Every question carries:

- A stable ID.
- A header of at most twelve characters.
- One precise prompt.
- Two to four concrete options, each with an honest tradeoff.
- One clearly marked recommendation. Always recommend. "It depends" is not an
  answer to hand back to the user.
- A free-form alternative.

Use native structured input when available; otherwise render the same contract as
Markdown.

Persist the evidence, the reason for asking, the options, the recommendation, the
answer, and the resulting decision before asking the next question.

### Rounds

Discovery is iterative. It is not one questionnaire.

1. **First round.** At most ten answered questions, one at a time.
2. **Go and find out.** Take the answers back to the evidence: read the code the
   answers pointed at, and research the domain the answers revealed. Answers
   routinely open questions that could not have been asked before, because you did
   not know enough to ask them.
3. **Ask again.** Up to fifteen more, one at a time, on what step 2 exposed.
4. **Repeat 2 and 3** while each round is still resolving material ambiguity.

Stop when a round produces no question that would change scope, behavior,
acceptance criteria, or risk. That is the real condition, not a counter.

Stop early, too, if rounds start returning questions you could answer yourself
from the repository, or restatements of settled decisions. That is the signal
that discovery is done and the engine is padding.

If genuine ambiguity survives, do not keep asking and do not guess silently: the
specification states the assumption explicitly, flags it as an assumption, and
records what would have to be true for it to hold.

The user is never asked to approve implementation until this loop closes. A
specification built on unresolved ambiguity buys an approval that means nothing.

### Sharpen the language

Precision about words is precision about the product.

- **Challenge against the existing glossary.** When the user's term conflicts with
  the repository's documented language, say so immediately: their glossary defines
  this term one way and they appear to mean another. Which one governs?
- **Sharpen fuzzy terms.** When a word is vague or overloaded, propose a precise
  canonical term and ask them to confirm. Two different things sharing one word is
  how a specification quietly becomes two specifications.
- **Cross-reference with the code.** When the user states how something works,
  check whether the code agrees. Surface the contradiction plainly: the code does
  one thing, they described another, which is right?
- **Stress-test with concrete scenarios.** Invent specific cases that probe the
  boundary between two concepts and force a precise answer. Abstract agreement
  hides disagreement; a scenario exposes it.

When a domain term resolves, capture it immediately: in the Decision Checkpoint
and the specification's decision register. Do not batch these; a term captured
three questions later is a term already half-forgotten.

Capture immediately, write to the repository later. Discovery is read-only, so
editing the repository's glossary now would touch the primary checkout before the
user has approved anything. Instead, add that glossary to the preliminary write
set. The update lands in the isolated worktree during implementation, with every
other approved change.

Record each resolved term with the synonyms it displaces. A canonical term that
carries its rejected aliases makes the next collision mechanical instead of
intuitive: any banned alias appearing in conversation triggers the challenge
above, in this session and in every later one.

Define what a term **is**, not what it does, in one sentence. Where two words
compete, pick one and list the other as an alias to avoid. Be opinionated; a
glossary that keeps both words has resolved nothing.

Record the ambiguity itself alongside its resolution, not just the winning term.
"This word was used for two distinct concepts, and here is the split" is what
stops the same argument from recurring in three months.

That glossary is a glossary. Never turn it into a specification, a scratch pad, or
a home for implementation decisions.

### Decision Checkpoints

Write one after every question round, and before any interruption or session
rotation. It carries the settled scope and decisions so a later session does not
re-ask.

Resume restores the single pending question by ID. Never ask an answered question
again.

## 4. Deeper discovery, between rounds

This runs after every question round, not once.

The answers just told you things the repository could not: which flow the user
actually meant, what the business rule is, which of two readings was right. Take
that back to the evidence.

- Read the code the answers pointed at. It is usually not the code you guessed.
- Research the domain the answers revealed. A term the user used casually may be
  regulated, standardised, or mean something specific in their market. Understand
  the business, not only the code: what the software is for, who it serves, and
  what the rules around it are. That is often where the real requirements live,
  and none of it is in the repository.
- Check whether the answers contradict something the code does today. If so, that
  contradiction is the next question.

Then ask the next round on what this exposed. Stop when it exposes nothing
material.

## 5. Consensus

Give the reviewers the same bounded evidence packet: local facts, user decisions,
and cited research.

**Hybrid.** Two independent read-only Codex Workers on Terra at `high`, over
non-overlapping evidence partitions. When opencode has passed its capability
probe, one of the two may run on opencode `Pro` instead — per
`${CLAUDE_PLUGIN_ROOT}/internal/opencode.md` and the Discovery row in
`project.md`'s Model mapping — widening vendor coverage on the same pass. This
is the only place in discovery opencode appears; escalation to Sol, below,
stays Codex-only.

**Claude-only.** The same shape with two `my-plan-discovery` Workers on Sonnet at
`high`.

Either way, challenge and synthesize the two results.

Partition the evidence. Making each agent reread the whole repository costs twice
as much and returns the same blind spots twice.

Two shapes of discovery need more than the default pair:

- **Hard.** Unfamiliar architecture, an intermittent fault, concurrency,
  security, a migration, several services at once, or evidence supporting
  contradictory hypotheses. Escalate the second opinion to Sol at `xhigh` in
  hybrid, or to an Opus model override in `claude-only`, so the two Workers do
  not share one model's blind spots.
- **Wide.** A monorepo or a change that crosses many areas. Split by area instead
  of escalating: one Worker per area, each with its own partition, on Terra at
  `high` in hybrid or on Sonnet in `claude-only`. Depth does not help a Worker
  that has not read the code; more eyes on disjoint evidence does. A partition
  still too large for a Codex thread goes to `my-plan-discovery` on Sonnet: the
  one case where width outranks the provider order.

Neither shape changes the contract or the synthesis. It is the same packet, the
same `challenge` mode, and the same result schema, from more Workers.

Dispatch with a handoff matching
`${CLAUDE_PLUGIN_ROOT}/internal/contracts/handoff.schema.json`, `role:
"discovery"`, `mode: "challenge"`. Validate results against
`${CLAUDE_PLUGIN_ROOT}/internal/contracts/challenge-result.schema.json`.

The synthesis separates verified facts from inferences, records what the reviewers
disagreed on and how it resolved, and turns anything still unsettled into either a
question or an explicit risk.

## 6. Findings review

The synthesis is the one artifact in discovery nothing has checked. Both partition
Workers returned contracts the Coordinator validated, and then the Coordinator
merged them itself — resolving disagreements, promoting inferences, and deciding
what was settled enough to leave out. That merge is unreviewed work by the one
participant who cannot be independent of it, and everything downstream binds to
it: the specification, the approval hash, the plan.

So one independent read-only Worker reads the synthesis against the evidence it
cites, before any of it becomes a specification.

**Hybrid.** `my-plan-reviewer-deep` on Opus at `high`. This is deliberately not a
Codex Worker and not opencode: the reviewer must share a model family with
neither partition, and in hybrid the partitions are Codex `Terra` and, when it is
available, opencode `Pro`. Crossing to Claude here buys the independence the pair
cannot supply from inside itself.

**Claude-only.** The same Worker, same model. The partitions ran on Sonnet, so
Opus is already a different model and nothing changes.

Dispatch with `role: "discovery"`, `mode: "challenge"`, an empty `writeSet`, and
the synthesized packet plus `discovery` and `research` artifacts. Validate against
`${CLAUDE_PLUGIN_ROOT}/internal/contracts/challenge-result.schema.json`.

It is answering three questions, and only these:

- Does every fact in the synthesis still hold against the source it cites? A fact
  whose evidence does not support it goes back to being an inference, or goes.
- What did the merge drop? A disagreement resolved in favor of one partition
  without stated grounds is the common case, and the grounds are what the reviewer
  is checking.
- What is being treated as settled that is not? Those become questions for the
  user or explicit risks in the specification. They do not become silent
  assumptions.

Fold its `facts`, `inferences`, and `disagreements` back into the synthesis.
Anything in its `questions` goes to the user through the Question Engine, in the
same round shape as any other question — a reviewer does not get a private channel
to the user, and its questions are not more urgent than the ones discovery already
raised.

Its `recommendation` is advisory. The Coordinator still owns the synthesis, and
disagreeing with the reviewer is allowed as long as the disagreement is recorded
with its reason. What is not allowed is dropping a contradiction because
addressing it would reopen a question that felt closed.

This gate runs before the specification exists, so it is cheap: one Worker, one
packet, no code. The same defect found after approval costs a revision and a
second approval.

## 7. Working Spec

Render `spec.md` from
`${CLAUDE_PLUGIN_ROOT}/internal/templates/documents/spec.md.tpl`, and
`discovery.md` from its own template.

The specification contains: requirements, non-goals, affected repositories and
modules, evidence, the decision register, acceptance criteria, expected tests,
risks, and the preliminary write set. It predeclares relative links to the later
phase records.

Every requirement is testable. An acceptance criterion someone else cannot check
is not a criterion.

The decision register records both user answers and automatic Recommendation
Authority decisions, marked by source.

The preliminary write set must include the Run's own paperwork as well as the
product paths: the Run Dossier directory, the Architecture Memory when this Run
updates it, the Project Skill when this Run materializes it, and the repository's
changelog whenever the change is visible to a user of the software — the path the
repository already uses, or `CHANGELOG.md` when none exists yet. Those files end
up in the reviewed diff and the commit, so approval has to cover them. Omitting
them does not make the Run safer; it makes the final review block on the Run's own
records. The changelog earns its place for a sharper reason: delivery may not
write outside the approved set, so a changelog missing here is a changelog the
Run is forbidden to write later — the omission silently decides no entry will
exist.

Durable current architecture belongs in the Architecture Memory, not here. Task
decisions belong here, not there.

This product never generates ADRs. Existing repository ADRs are read as evidence;
their active consequences go into the Architecture Memory, and the originals are
never modified or duplicated.

The three conditions that once justified an ADR still decide what earns a place in
the decision register: the decision is hard to reverse, it would surprise a future
reader without context, and it came from a real trade-off between genuine
alternatives. A decision missing any of the three is just a choice. Record it and
move on.

## 8. Approval

Store one `pendingApproval` record: Run ID, repository or workspace scope,
specification path, and the complete file hash.

Show a short Approval Summary, one paragraph, and a link to the full
specification. Do not paste the specification into the response.

Accept a simple, unambiguous affirmative reply. No magic token, no run ID, no
ceremony. Normalize ordinary language and record it as `approvedSpecHash`.

Approval freezes the complete file. A product scope change requires a new revision
and a new ordinary approval.

Approval survives resume and session rotation, is recovered from Run state rather
than from a transcript phrase, and can never cross Runs.

If the user changes scope before approving, revise the specification and the
summary. If they push back on something you recommended, that is their decision:
record it and proceed with their choice.

One affirmative reply authorizes everything downstream that stays local:
worktree, project files, implementation, validation, review, remediation, and
commits on the Run's branch. Do not ask again at each phase.

It never authorizes the push. Nothing leaves the machine until the push gate at
the end of the Run, where the user approves once more, having seen the work. And
it never authorizes deployment or publishing; those need separate explicit
approval naming the target.
