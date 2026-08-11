# Secret Patterns

Shared by `commit`'s pre-stage scan and the `security` skill's secrets
category — one list, so the two can never drift apart on what counts as a
leak.

## Refuse outright, whatever the content

`.env` and `.env.*` other than `.env.example`, `*.pem`, `*.key`, `*.p12`,
`*.pfx`, `id_rsa` and other private keys, `*.keystore`, `.npmrc` and
`.pypirc` with credentials, `credentials.json`, `service-account*.json`,
`*.tfstate`, `.aws/`, `.ssh/`, `.kube/config`, any local database dump.

## Grep the content for assigned secrets

`password`, `passwd`, `secret`, `token`, `api[_-]?key`, `private[_-]?key`,
`authorization`, `bearer `, `BEGIN .* PRIVATE KEY`, plus provider prefixes
`sk-`, `sk_live_`, `sk_test_` (the `-` in `sk-` never matches the Stripe
underscore form), `ghp_`, `gho_`, `github_pat_`, `ghs_`, `ghu_`, `glpat-`,
`npm_`, `AKIA`, `AIza`, `xox[baprs]-`, and `eyJ` opening a long dotted
token (a JWT). A hit that's a real value, not a variable name or
placeholder, is the one that counts.

If `gitleaks` or `trufflehog` is installed, run it over the paths in
scope for the pass using this list — the candidate paths only for
`commit`, the working tree and git history for `security` — and treat its
findings as findings — a maintained scanner outranks this list; the list
is the floor, not the ceiling.

## Masking

A finding never carries a secret's real value — first 4 characters, then
`...`. The record of a leak must never become a second copy of it.
