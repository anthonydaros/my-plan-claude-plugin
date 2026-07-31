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
flowchart LR
    subgraph ASK[" 1 · Ask "]
        direction TB
        S["/my-plan-start<br/><i>your goal</i>"] --> SCAN["Read the repo<br/><i>code, tests, history</i>"]
        SCAN --> Q{"Anything the<br/>code can't answer?"}
        Q -->|yes| ASKQ["One question,<br/>with a recommendation"]
        ASKQ --> Q
        Q -->|no| SPEC["Spec"]
        SPEC --> APPR{"You approve"}
    end

    APPR -->|"yes"| PLAN
    APPR -->|"change scope"| SPEC

    subgraph BUILD[" 2 · Build · no further questions "]
        direction TB
        PLAN["Plan<br/><i>many small tasks</i>"] --> PR{"Plan review"}
        PR -->|"findings"| PLAN
        PR -->|"clean"| T

        T["Next task<br/><i>alone or in parallel</i>"] --> W["Write"]
        W --> GATE["Checks"]
        GATE --> RV{"Review<br/>this delivery"}
        RV -->|"one finding<br/>at a time"| FIX["Fix"]
        FIX --> GATE
        RV -->|"clean"| MORE{"Tasks left?"}
        MORE -->|"yes"| T
    end

    MORE -->|"no"| FULL

    subgraph SHIP[" 3 · Ship "]
        direction TB
        FULL{"Full review<br/><i>the whole change</i>"} -->|"findings"| REM["Fix"]
        REM --> FULL
        FULL -->|"clean"| VAL["Validation gate"]
        VAL --> CL["Changelog"]
        CL --> C["Commit"]
        C --> P["Push"]
    end

    P --> DONE(["Done"])
    P -.->|"deploy target"| HOLD(["Waiting for<br/>your approval"])

    style APPR fill:#2d6a4f,stroke:#40916c,color:#fff
    style DONE fill:#1b4332,stroke:#40916c,color:#fff
    style HOLD fill:#7f4f24,stroke:#bc6c25,color:#fff
    style ASK fill:#f8f9fa,stroke:#adb5bd
    style BUILD fill:#f8f9fa,stroke:#adb5bd
    style SHIP fill:#f8f9fa,stroke:#adb5bd
```

Three loops do the work: **questions** until nothing material is unresolved,
**task → review → fix** until each delivery is clean, and **full review → fix**
until the whole change is.

You appear once, at the green box.

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
