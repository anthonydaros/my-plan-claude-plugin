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
    S["<b>/my-plan-start</b> your goal"] --> SCAN["Read the repository"]
    SCAN --> Q{"Can the code<br/>answer it?"}
    Q -->|"no, ask"| ASKQ["One question,<br/>with a recommendation"]
    ASKQ --> Q
    Q -->|"yes, all clear"| SPEC["Spec"]
    SPEC --> APPR{"You approve"}
    APPR -->|"change the scope"| SPEC

    APPR ==>|"yes"| PLAN["Plan: many small tasks"]
    PLAN --> PR{"Plan review"}
    PR -->|"findings"| PLAN

    PR ==>|"clean"| T["Next task"]
    T --> W["Write<br/><i>one task, alone or in parallel</i>"]
    W --> G["Checks"]
    G --> RV{"Review<br/>this delivery"}
    RV -->|"one finding at a time"| FIX["Fix"]
    FIX --> G
    RV -->|"clean, tasks left"| T

    RV ==>|"clean, none left"| FULL{"Full review<br/><i>the whole change</i>"}
    FULL -->|"findings"| REM["Fix"]
    REM --> FULL

    FULL ==>|"clean"| VAL["Validation gate"]
    VAL --> CL["Changelog"]
    CL --> CM["Commit"]
    CM --> PUSH["Push"]
    PUSH --> DONE(["Done"])
    PUSH -.->|"if a deploy target exists"| HOLD(["Held for<br/>your approval"])

    classDef gate fill:#1b5e3f,stroke:#2d8a5f,color:#ffffff,font-weight:bold
    classDef stop fill:#6b4423,stroke:#a06a35,color:#ffffff
    classDef done fill:#1b5e3f,stroke:#2d8a5f,color:#ffffff
    class APPR gate
    class DONE done
    class HOLD stop
```

Three loops carry the work: **questions** until nothing material is open,
**write, check, review, fix** for every single task, and **full review, fix**
over the whole change before anything ships.

The bold path is the happy one. You appear once, at the green box.

---

## What a run looks like

```
/my-plan-start add rate limiting to the public API
```

1. **It reads your repository first.** Anything the code can answer, it does not
   ask you.
2. **It asks what is genuinely open.** One question at a time, each with a
   recommendation you can accept or override. Ten at most.
3. **You approve a spec.** One paragraph and a link. Say yes in ordinary words.
4. **It builds.** Small tasks, each reviewed as it lands, each fixed before the
   next begins.
5. **It ships.** Full review, validation, changelog, commit, push.
6. **You get a short report.** What was done, what was validated, the commit, the
   verified remote SHA.

---

## What it will never do

- Touch your working checkout. Work happens in an isolated worktree.
- Change anything before you approve.
- Modify a file outside the approved scope.
- Run `git add -A`.
- Push the temporary branch, open a PR, force push, or rewrite history.
- Write a secret into a tracked file.
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
