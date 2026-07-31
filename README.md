# My Plan

A Claude Code plugin. You describe a goal, approve a spec once, and it ships the
code.

Discovery, planning, implementation, validation, independent review, commit,
push. Three commands. Nothing installed into your project.

---

## Install

```bash
/plugin marketplace add anthonydaros/my-plan-claude-plugin
/plugin install my-plan@my-plan
```

Then run setup:

```
/my-plan-install
```

Setup checks what you have, tells you exactly how to fix what is missing, and
picks up where it left off.

**Required:** Claude Code 2.1.216+, Git, Context7.
**Optional:** Codex CLI, GitHub CLI, Playwright.

Missing Codex is not a problem. My Plan runs the whole flow on Claude alone.

---

## Use

```
/my-plan-start add rate limiting to the public API
```

Here is what happens:

**1. It reads your repository.** Code, docs, tests, history. Anything the code
can answer, it does not ask you.

**2. It asks what is left.** One question at a time, each with a recommendation
you can accept or override. Ten at most.

**3. You approve a spec.** One paragraph, plus a link to the full version. Say
yes in ordinary words. No token, no ID.

**4. It builds.** Worktree, plan, plan review, implementation in batches,
validation, independent code review, fixes, commit, push. No further questions.

**5. You get a short report.** What was done, what was validated, the commit, the
verified remote SHA.

### The three commands

| Command | What it does |
|---------|--------------|
| `/my-plan-start <goal>` | One goal, from question to pushed code |
| `/my-plan-start` | Resumes. Asks which run only if several match |
| `/my-plan-audit` | Read-only findings. Accept a scope and it delivers them |
| `/my-plan-install` | Setup, repair, reconfigure |

If another command already owns one of these names, use the full form:
`/my-plan:my-plan-start`. Setup tells you if that happens.

---

## What it will never do

- Touch your working checkout. All work happens in an isolated worktree.
- Change anything before you approve.
- Modify a file outside the approved write set.
- Run `git add -A`.
- Push the temporary branch, open a PR, force push, or rewrite history.
- Write a secret into a tracked file.
- Deploy. Delivery is not deployment; that needs its own approval.
- Let the model that wrote the code decide whether the code is good.

Change the scope and it needs a new approval. Change the code after review and
validation and review run again.

---

## How the work is split

Nobody reviews their own work. That is the whole design.

| Job | Claude only | With Codex |
|-----|-------------|------------|
| Discovery | Fable | Fable |
| Write the plan | Opus | Opus |
| Review the plan | Fable | Sol, xhigh |
| Write the code | Sonnet | Luna |
| Review the code | Fable | Sol xhigh + Fable |

If Codex runs out of quota or credits mid-run, My Plan switches to Claude and
keeps going. Your spec, plan, worktree, diff, findings, and validation survive
the switch. You are not asked to approve anything again.

One honest difference: Codex reviewers run in a process-enforced read-only
sandbox. Claude reviewers have no write tools and explicit instructions, but keep
shell access, because reviewing without `git diff` is not reviewing. In both
cases the backstop is the same: every changed path is checked against Git and the
approved write set before it is trusted.

---

## Running several at once

Open two terminals and start two runs in the same repository. Each gets its own
run ID, branch, worktree, state, and review hashes.

Overlapping files are reported as integration risk, not blocked. Integration
itself uses short optimistic locks, and no lock is ever held while a model is
thinking.

---

## Where things go

**In your repository**

```
docs/my-plan/SEAM.md                    current architecture, one file
docs/my-plan/runs/<run-id>-<slug>/      one doc per phase that ran
.claude/skills/my-plan-project/         this repo's verified facts
```

**Outside your repository**, in an app data directory: run state, handoffs,
results, locks, and worktrees. They survive terminal closure, session rotation,
restarts, and plugin updates. `/my-plan-install` prints the exact path.

No database. No daemon. No transcripts in your repo.

---

## Troubleshooting

**Commands do not appear.** Check `claude --version` for 2.1.216+, then
`/reload-plugins`. The reload summary counts only `commands/`, so it can say
`0 skills` while your skills did reload.

**`/my-plan-start` not found, but `/my-plan:my-plan-start` works.** Another
command owns the short name. Expected; the plugin does not fight it.

**An agent does not run.** A project or user agent with the same name wins over a
plugin agent. Check `.claude/agents/` and `~/.claude/agents/`.

**It asked something obvious.** Worth reporting. Repository facts should come
from the scan, not from you.

**A run is `BLOCKED`.** Three review rounds passed without closing a finding, or
the base branch kept moving. Nothing was committed; the report says what is open.

**You want a dry run.** Use `/my-plan-audit`. It is read-only by construction.

---

## Uninstall

```bash
/plugin uninstall my-plan@my-plan
```

Run state lives outside your repository; `/my-plan-install` prints the path so
you can delete it. Committed files stay, as with any commit.

---

## Developing

```bash
git clone https://github.com/anthonydaros/my-plan-claude-plugin
cd my-plan-claude-plugin

claude plugin validate ./plugin     # manifest and frontmatter
sh tests/smoke-posix.sh             # static checks
claude --plugin-dir ./plugin        # load without installing
```

`/reload-plugins` picks up edits without restarting.

The smoke tests check what actually breaks a static plugin: manifests parse,
skills are manual-only and take `$ARGUMENTS`, agent filenames match their
frontmatter names, reviewers never gain a write tool, plan author and reviewer
are different models, contracts satisfy strict structured output, every
`${CLAUDE_PLUGIN_ROOT}` reference resolves, and no runtime artifact reaches the
installed tree. CI runs them on Linux, macOS, and Windows.

**Two things not to "fix":**

*No `version` field.* Deliberate. The commit SHA versions the plugin, so every
push reaches installed users. `claude plugin validate` warns about it; leave the
warning. Pinning a version means nobody gets updates until someone remembers to
bump it. And never set it in both manifests: Claude Code uses the `plugin.json`
value and ignores the marketplace entry without saying so.

*Fully-populated `required` in the contracts.* Provider-enforced structured
output rejects a schema where any property is missing from `required`, or lacks
an explicit `type`, with HTTP 400 before the model runs. Optional fields are
nullable and still required. The smoke test enforces both.

---

## License

MIT
