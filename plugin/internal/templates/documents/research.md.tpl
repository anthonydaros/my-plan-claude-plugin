---
runId: {{runId}}
phase: research
date: {{date}}
trigger: {{researchTrigger}}
---

# Research

Created only when a research trigger fired. The trigger is named in the
frontmatter.

## Claims

| Claim | Source | URL | Accessed | Type | Confidence | Effect on the task |
|-------|--------|-----|----------|------|------------|--------------------|

One row per material claim. `Type` is primary, official, secondary, or community.
Regulated and high-stakes claims require a primary or official source when one
exists.

`Confidence` is derived, not felt:

| Level | When |
|-------|------|
| high | Official source, and the version matches what the lockfile actually installs |
| medium | Official source, compatible major version |
| low | Secondary source, or a version that diverges from what is installed |
| none | Could not establish. Flag it and ask rather than carrying it forward |

An official document for the wrong version reads exactly like an official document
for the right one. Without this column the specification inherits the claim
unqualified, and the implementation breaks against the real API.

## What this changed

How the evidence changed the questions, the options offered, or the
recommendation. Research informs the decision; it never silently decides the
user's product policy.

## What stayed open

Claims the available sources could not settle, and how the specification handles
that uncertainty.

## Query hygiene

Confirm that no repository code, secret, personal data, customer identifier, or
confidential business detail was sent to a search provider.
