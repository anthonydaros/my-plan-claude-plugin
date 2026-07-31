---
runId: {{runId}}
phase: validation
date: {{date}}
gate: {{gateStatus}}
---

# Validation

Exact commands and real results. A summarized claim without its command is not
evidence.

## Environment

Operating system, runtime versions, and package manager actually used.

## Commands

| Command | Exit | Result |
|---------|------|--------|

Every required command from the Project Profile plus every affected test suite. A
command that was not run does not appear here.

## Coverage of new behavior

What observable-behavior checks were added and what they assert.

Auth, deletion, persistence, payment, cost, and external contract paths require a
behavioral or integration check. If one of these paths has no check, the gate does
not pass.

## Coverage debt

Only for a hard-to-test non-critical path. State the path, why it resists testing,
and the escape plan. This section is omitted when there is no debt; it is never
used for the critical paths above.

## Failures and fixes

Failures encountered, their cause, and the change that resolved them. A failure
that was retried until it passed is a flaky test finding, not a fix.

## Gate status

`green` or `blocked`, with the deciding evidence. A failing required check
prevents delivery.
