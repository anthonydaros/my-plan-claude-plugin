# My Plan

**Describe a goal. Approve a spec once. Get reviewed code.**

A Claude Code plugin that carries one approved specification through planning,
implementation, validation, independent review, and delivery. Three commands.
Nothing installed into your project.

---

## Why

Asking an agent to "build the feature" gives you a large diff, written in one long
session, reviewed by the same model that wrote it, if at all. It usually looks
right.

My Plan does the opposite of all three:

**Small tasks.** A goal becomes many precise tasks instead of one ambitious one.
Writers hold a limited working context and degrade over a long session, so each
task is a handful of files and one idea.

**Reviewed as it lands.** Every task is reviewed the moment it is delivered, not
at the end. A defect found now is one small correction; the same defect found ten
tasks later is a large diff against a session that has moved on.

**Never its own reviewer.** The model that wrote the code is never the model that
approves it. Not in any mode, not in any fallback.

You are asked once: do you approve this spec. Everything after that runs without
interrupting you.

---

## Install

```bash
/plugin marketplace add anthonydaros/my-plan-claude-plugin
/plugin install my-plan@my-plan
```

```
/my-plan-install
```

Setup checks what you have, tells you exactly how to fix what is missing, and
resumes where it stopped.

**Required:** Claude Code 2.1.216+, Git, Context7
**Optional:** Codex CLI, GitHub CLI, Playwright

Missing Codex is fine. The whole flow runs on Claude alone.

---

## Commands

| Command | What it does |
|---------|--------------|
| `/my-plan-start <goal>` | One goal, from question to pushed code |
| `/my-plan-start` | Resumes. Asks which run only if several match |
| `/my-plan-audit` | Read-only findings. Accept a scope and it delivers them |
| `/my-plan-install` | Setup, repair, reconfigure |

If another command already owns a name, the full form always works:
`/my-plan:my-plan-start`.

---

## The flow

```mermaid
flowchart TD
    A["Your goal"] --> B["Questions<br/><i>one at a time</i>"]
    B --> D["Discovery<br/><i>code, docs, the web</i>"]
    D -->|"new questions"| B
    D -->|"nothing left to ask"| C{"You approve<br/>the spec"}

    C ==> P["Plan<br/><i>many small tasks</i>"]
    P ==> T["Write one task"]
    T ==> R{"Review"}
    R -->|"not good enough"| T
    R ==>|"clean"| M{"Tasks left?"}
    M ==>|"yes"| T

    M ==>|"no"| F{"Full review"}
    F -->|"not good enough"| T
    F ==>|"clean"| S["Validate, changelog,<br/>commit locally"]
    S ==> PG{"You approve<br/>the push"}
    PG ==>|"yes"| PUSH["Push once"]
    PG -->|"not yet"| LOCAL["Done, kept local"]

    classDef gate fill:#1b5e3f,stroke:#2d8a5f,color:#fff,font-weight:bold
    class C,PG gate
```

**Before the green box: it asks until it stops having doubts.** You answer up to
ten questions. It takes your answers back to the code, and to the web when the
goal turns on business rules, a market, a regulation, or a standard the repository
never mentions. That usually raises questions it could not have asked before, so
it asks again. The loop repeats until a round produces nothing that would change
scope or behavior. Only then are you asked to approve.

**Between the green boxes: nothing ships until review is satisfied.** Every task
goes write, review, back to the writer, review again, until that task is clean.
Then the whole change is reviewed, and anything it finds goes back to the writer
too. The loop does not exit on a round count or a timer; it exits when there is
nothing left to fix.

**At the second green box: nothing leaves your machine without you.** It commits
as it goes, so you get real history to read, but it does not push. At the end it
shows you what was built, the commits, and what was validated, and asks. One push
for the whole run, after you say so.

Say no and the run is still complete: the work is committed and waiting on its
branch. That is a finished run, not a failed one.

You appear twice: to approve the spec, and to approve the push.

---

## What a run looks like

```
/my-plan-start add rate limiting to the public API
```

1. **It reads your repository first.** Anything the code can answer, it does not
   ask you.
2. **It asks what is genuinely open.** One question at a time, each with a
   recommendation you can accept or override. Ten at most in this round.
3. **It goes and finds out.** Your answers point at code it had not read and at a
   domain it had not researched. It reads both, and searches the web when the
   business, the market, or a regulation matters more than the code does.
4. **It asks again.** Whatever step 3 exposed, up to fifteen more. Then repeats
   steps 3 and 4 for as long as each round is still resolving something material.
   Ambiguity it cannot resolve is written into the spec as a flagged assumption,
   never guessed silently.
5. **You approve a spec.** One paragraph and a link. Say yes in ordinary words.
   This is the only approval, and it comes after the doubts are gone.
6. **It builds, in a loop.** One small task at a time: written, checked,
   reviewed. Findings go back to the writer one at a time and it reviews again.
   Nothing advances to the next task until this one is clean.
7. **It reviews the whole thing.** Per-task review misses what emerges between
   tasks. Anything the full review finds goes back to the writer, and it runs
   again. Repeat until clean.
8. **It commits.** Validation gate, changelog, and commits along the way. Before
   every commit it scans what is staged for credentials, keys, env files, and
   anything else that should not be published, including in its own notes.
9. **It asks before pushing.** What was built, the commits, what was validated,
   where it would go. Say `yes`, `sim`, or `push`. One push for the whole run.
10. **You get a short report.** What was done, what was validated, the commit, and
    the verified remote SHA if you pushed.

---

## What it will never do

- Touch your working checkout. Work happens in an isolated worktree.
- Change anything before you approve.
- Modify a file outside the approved scope.
- Run `git add -A`.
- **Push anything without asking you first.** Not a branch, not a tag, not "just
  the docs".
- Open a PR, force push, or rewrite history.
- Commit a credential. Every staged set is scanned before every commit, because a
  secret committed once stays in history even if the next commit removes it.
- Deploy. Delivery is not deployment; that needs its own approval.
- Let the model that wrote the code decide whether the code is good.

Change the scope and it asks again. Change the code after review and validation
and review run again.

---

## Who does what

Nobody reviews their own work.

| Job | Claude only | With Codex |
|-----|-------------|------------|
| Discovery | Fable | Fable |
| Write the plan | Opus | Opus |
| Review the plan | Fable | Sol, xhigh |
| Write the code | Sonnet | Luna |
| Review the code | Fable | Sol xhigh + Fable |

If Codex runs out of quota or credits mid-run, it switches to Claude and keeps
going. Your spec, plan, worktree, diff, findings, and validation survive the
switch, and you are not asked to approve anything again.

Codex reviewers run in a process-enforced read-only sandbox. Claude reviewers have
no write tools and keep shell access, because reviewing without `git diff` is not
reviewing. In both cases every changed path is checked against Git and the
approved scope before it is trusted.

---

## Several at once

Open two terminals, start two runs in the same repository. Each gets its own run
ID, branch, worktree, state, and review hashes.

Overlapping files are reported as integration risk, not blocked. Integration uses
short optimistic locks, and no lock is ever held while a model is thinking.

---

## What lands in your repository

```
docs/my-plan/SEAM.md                  current architecture, one file
docs/my-plan/runs/<run>/              one document per phase that ran
.claude/skills/my-plan-project/       this repo's verified facts
CHANGELOG.md                          or whatever your repo already uses
```

Run state, worktrees, and locks live outside your repository, in an app data
directory. They survive terminal closure, restarts, and plugin updates.
`/my-plan-install` prints the path.

No database. No daemon. No transcripts in your repo.

---

## Troubleshooting

**Commands do not appear.** Check `claude --version` for 2.1.216+, then
`/reload-plugins`. The reload summary can report `0 skills` while your skills did
reload.

**`/my-plan-start` not found, but `/my-plan:my-plan-start` works.** Another
command owns the short name. Expected.

**An agent does not run.** A project or user agent with the same name wins over a
plugin agent. Check `.claude/agents/` and `~/.claude/agents/`.

**It asked something obvious.** Worth reporting. Repository facts should come from
the scan, not from you.

**A run is `BLOCKED`.** Reviews stopped making progress, or the base branch kept
moving. Nothing was committed; the report says what is open.

**You want a dry run.** `/my-plan-audit` is read-only by construction.

---

## Uninstall

```bash
/plugin uninstall my-plan@my-plan
```

Run state lives outside your repository; `/my-plan-install` prints the path so you
can remove it.

---

MIT
