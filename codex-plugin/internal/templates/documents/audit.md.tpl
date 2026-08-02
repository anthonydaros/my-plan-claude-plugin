---
runId: {{runId}}
phase: audit
date: {{date}}
scope: {{auditScope}}
status: read-only
---

# Audit

Read-only. No product code changes because of this document. Findings become work
only after the user accepts a scope.

## Repository understanding

What the audit established about the current architecture before judging it,
grounded in paths. An audit that judges before it understands produces noise.

## Findings

| ID | Severity | Lens | Evidence | Impact | Minimal correction |
|----|----------|------|----------|--------|--------------------|

Finding IDs are stable semantic keys so a later audit merges with this one instead
of reporting the same thing twice.

Every finding names a real path with a line range. A finding without evidence is
not reportable.

## Confronted with project memory

Where current code disagrees with the Architecture Memory, and which one is
wrong. Stale findings from earlier audit records are not repeated; state that they
were checked.

## Recommended scope

The subset worth doing now, ordered, with the reason each one earns its place
ahead of the others. Say what is deliberately left out.

## Not worth doing

Findings that are real but not worth the change. Recording these stops a later
audit from resurfacing them as new.
