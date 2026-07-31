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

## 2. Domain Research

Trigger-based, not mandatory. A local change with sufficient current repository
evidence does not search the web.

Triggers: specialized business terminology, market behavior, regulation,
standards, current facts, an external integration, greenfield work, insufficient
local evidence, or an explicit user request.

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

### Budget

At most ten answered questions in the first round. If material ambiguity remains,
one more round of one to fifteen questions, still one at a time.

Running out of budget with ambiguity left means the specification states the
assumption explicitly and flags it. It does not mean guessing silently.

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

## 4. Deeper discovery

After the first answers, go deeper into the repository and the domain. Research
additional claims only when an answer exposed a material knowledge gap.

You now know what the change actually touches. Read that.

## 5. Consensus

Give the reviewers the same bounded evidence packet: local facts, user decisions,
and cited research.

**Hybrid.** Fable and Sol at `xhigh` effort receive the same packet independently.

**Claude-only.** Dispatch two independent read-only Fable discovery agents over
non-overlapping evidence partitions, then challenge and synthesize their results.

Partition the evidence. Making each agent reread the whole repository costs twice
as much and returns the same blind spots twice.

Dispatch with a handoff matching
`${CLAUDE_PLUGIN_ROOT}/internal/contracts/handoff.schema.json`, `role:
"discovery"`, `mode: "challenge"`. Validate results against
`${CLAUDE_PLUGIN_ROOT}/internal/contracts/challenge-result.schema.json`.

The synthesis separates verified facts from inferences, records what the reviewers
disagreed on and how it resolved, and turns anything still unsettled into either a
question or an explicit risk.

## 6. Working Spec

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

## 7. Approval

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

One affirmative reply authorizes everything downstream: worktree, project files,
implementation, validation, review, remediation, commit, integration, and push. Do
not ask again at each phase.

It never authorizes deployment or publishing. Those need separate explicit
approval naming the target.
