# Product Context (SINGLE SOURCE)

Canonical repository for the product's **shared layer**.
Consumed **read-only** by the service repos (api, web, mobile),
which mirror it under `docs/shared/`.

## Start here
- @manifest.md — map of all documents
- @_meta/conventions.md — IDs, frontmatter, lifecycle, propagation, `ID@repo` refs
- @_meta/glossary.md — ubiquitous language (ALWAYS use these terms)

## What lives here (shared)
- **PROD** (`product.md`) — vision & strategy
- **REQ** (`requirements.md`) — product requirements
- **AYD** (`design/`) — Analysis & Design per feature (cross-repo: affected repos + contracts)
- **ROAD** (`roadmap.md`) — roadmap / planning
- **PDR** (`product_decisions/`) — product decisions
- **ADR** (`architecture_decisions/`) — cross-repo architecture decisions (contracts, protocols)
- **ARCH** (`architecture.md`) — living high-level architecture (C4 context + container) with provider names; updated whenever a service/integration is added or removed

## What does NOT live here
Each service's specs, plans, local technical decisions (TDR), code conventions, and changelog.

## Core rule (cross-repo)
**Contracts only change here** (in the AYD/ADR). Services implement; they do not redefine.
The details (1 AYD → N SPECs, global `ID@repo` IDs, linkage rules) are canonical in
`_meta/conventions.md` §1, §3 and §5.

## Lifecycle
- PROD / REQ / AYD / ROAD = living (edit in-place; log in `_meta/changelog.md`).
- PDR / ADR = append-only (a new decision supersedes the old one via `superseded_by`).
- When you change something, mark the affected `children` (including in other repos) as `status: review`.

## Other tools
- Claude Projects: connect this repo via the GitHub integration and use **Sync**.
- NotebookLM / Gemini Gems: run `scripts/bundle.sh` → `CONTEXT.md` for upload.
