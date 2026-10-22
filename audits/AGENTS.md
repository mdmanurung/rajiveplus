# AGENTS

Canonical agent/session protocol for this repository. Root-level tracking files
should not carry live state; this directory owns active project tracking.

## Active Maintainer Docs

Read Markdown sources, not generated site output. Generated pkgdown/site files
under `docs/*.html`, `docs/reference/`, `docs/articles/`, and `docs/deps/` are
validation artifacts only.

| File | Owns |
|---|---|
| [../AGENTS.md](../AGENTS.md) | Compatibility pointer only |
| [PROGRESS.md](PROGRESS.md) | Current operational dashboard, next commands, validation snapshot |
| [PLANS.md](PLANS.md) | Current strategy, gates, durable blockers |
| [AGENTS.md](AGENTS.md) | Session protocol, issue tracker, triage labels, runtime environment |
| [../CONTEXT.md](../CONTEXT.md) | Domain glossary only |
| [../docs/architecture.md](../docs/architecture.md) | Architecture map and links to ADRs |
| [../docs/adr/](../docs/adr/) | Durable architectural decisions |
| [NEWS.md](NEWS.md) | Package-facing development changelog |
| [archive/README.md](archive/README.md) | Archive and evidence status index |

Never copy the same live fact into multiple active files. Cross-reference
instead.

## Session Start

1. Read [PROGRESS.md](PROGRESS.md) and execute the **Rapid Next Action** block first.
2. Read [PLANS.md](PLANS.md) to confirm gates, durable blockers, and constraints.
3. Read this file for repo protocol, runtime, issue tracking, and labels.
4. Read [../CONTEXT.md](../CONTEXT.md) when naming domain concepts.
5. Read [../docs/architecture.md](../docs/architecture.md) and relevant ADRs when changing result objects, decomposition vocabulary, or module boundaries.

If local assumptions conflict with these files, align to the active docs before
implementation.

## Session End

Update tracking docs before ending work that changes project state:

- [PROGRESS.md](PROGRESS.md): update status, rapid next action, open blockers,
  validation snapshot, and one concise session note.
- [PLANS.md](PLANS.md): update only when strategy, gates, durable blockers, or
  phase definitions changed.
- [../CONTEXT.md](../CONTEXT.md): update only when domain vocabulary is resolved.
- [../docs/architecture.md](../docs/architecture.md) or [../docs/adr/](../docs/adr/):
  update only when architecture decisions or maps changed.

## Issue Tracker

Issues are tracked in GitHub Issues for `mdmanurung/rajiveplus`. Use the `gh`
CLI from inside this clone so the repository is inferred from `git remote -v`.

Common operations:

```bash
gh issue create --title "..." --body "..."
gh issue view <number> --comments
gh issue list --state open --json number,title,body,labels,comments
gh issue comment <number> --body "..."
gh issue edit <number> --add-label "..."
gh issue edit <number> --remove-label "..."
gh issue close <number> --comment "..."
```

When a skill says "publish to the issue tracker", create a GitHub issue. When a
skill says "fetch the relevant ticket", run `gh issue view <number> --comments`.

## Triage Labels

| Skill label | Tracker label | Meaning |
|---|---|---|
| `needs-triage` | `needs-triage` | Maintainer needs to evaluate this issue |
| `needs-info` | `needs-info` | Waiting on reporter for more information |
| `ready-for-agent` | `ready-for-agent` | Fully specified, ready for an AFK agent |
| `ready-for-human` | `ready-for-human` | Requires human implementation |
| `wontfix` | `wontfix` | Will not be actioned |

## Domain Routing

This is a single-context R package repository for `rajiveplus`, an
implementation of RAJIVE+ for matched multi-view / multi-omics data
integration.

Use root [../CONTEXT.md](../CONTEXT.md) for canonical domain language. Use
[../docs/adr/](../docs/adr/) for architectural decisions that touch the area
being changed. If an output contradicts an existing ADR, surface the conflict
explicitly instead of silently overriding it.

## Runtime Environment

R runs in conda environment `R4_51`.

Invocation patterns:

```bash
conda run -n R4_51 R --no-save -q -e "<R code>"
conda run -n R4_51 Rscript <script.R>
```

## Development Loop

1. Read [PROGRESS.md](PROGRESS.md) Rapid Next Action.
2. Run the smallest validating command.
3. Apply focused edits.
4. Re-run targeted validation in order: `testthat::test_file()` ->
   `devtools::test()` -> `devtools::check()`.
5. Update [PROGRESS.md](PROGRESS.md), and update [PLANS.md](PLANS.md) only if
   strategy changed.

## Behavioral Coding Guidelines

These guidelines bias toward caution over speed. For trivial tasks, use
judgment.

### Think Before Coding

- State assumptions explicitly when they affect the implementation.
- If multiple interpretations exist, surface them before changing code.
- If a simpler approach exists, say so.
- If something is unclear and cannot be discovered from local context, ask.

### Simplicity First

- Implement only what was requested.
- Avoid abstractions for single-use code.
- Avoid speculative configurability.
- Keep the smallest clear change that solves the problem.

### Surgical Changes

- Touch only files required by the request.
- Match existing style.
- Do not refactor adjacent code unless required for the requested fix.
- Remove only imports, variables, or helpers made unused by your own changes.

### Goal-Driven Execution

Convert work into verifiable goals:

```text
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Loop until the requested behavior is implemented and verified, or until a
concrete blocker is recorded in [PROGRESS.md](PROGRESS.md).
