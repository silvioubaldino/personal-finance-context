---
id: META-changelog
type: meta
title: Changelog do repo de contexto
status: approved
updated: 2026-08-21
owner: Silvio Ubaldino
---

# Changelog — Context

All notable changes to the shared docs (PROD, REQ, AYD, ROAD, decisions) are documented
here — **what** changed in each of them, so the living docs have a trail of edits. The
**why** is not repeated here: it lives inside the doc that changed (an AYD states its own
rationale, a PDR/ADR *is* the rationale).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this
repo adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Policy**:
- **Order:** most recent on top; new entries go **above** the previous ones.
- **Unreleased:** unreleased work accrues under `## Unreleased` (always the top block), with
  no date/version. On the PRs, `## Unreleased` becomes `## [dd-MM-yyyy - vX.Y.Z]`
  (SemVer) and a new empty `## Unreleased` is opened above it.
- **One line per PR, ≤350 characters:** each PR adds a **single line**, at most 350
  characters, stating **what** changed — never the how or the why (implementation details,
  rationale, and docs-framework mechanics stay out); reference the PR (e.g. `[PR#02](url)`).
  The line **may omit SPEC/PLAN additions** (tracked by their own files/git): if a PR only
  adds a SPEC/PLAN, summarize the feature they open.

## Unreleased

- Updated AYD-003 (financial analytics): the money aggregates now use AYD-005's canonical
  realized cut — the credit card is counted once, itemized by its real categories, and
  "Realizado" is the plain paid sum. User-facing numbers change.
- Updated AYD-003 (financial analytics): recorded the web as implemented and restated the
  screen as five visualizations plus KPIs in the shipped order.
- Updated AYD-005 (planning): fixed two claims that did not match the server — a card item
  counts in its Invoice's due-date month and is born unpaid.
- Added AYD-005: internal transfer between wallets design, covering api, web and mobile.
- Updated AYD-003 (financial analytics): added a Month option to the period scope toggle.
- Updated AYD-003 (financial analytics): documented the Year/Quarter scope toggle.
- Updated AYD-003 (financial analytics): added a yearly expense-by-category breakdown.
- Updated AYD-003 (financial analytics): replaced the period KPIs with total income/expense,
  added credit card invoice totals by card and an expense distribution by weekday, and
  added currency axes to the money charts.
- Updated AYD-002 and ARCH (observability): unified web and mobile telemetry onto a single
  ingestion contract and updated the architecture diagram.
- Added AYD-004: credit card invoice import design, covering api, web and mobile.
- Added AYD-003: financial analytics design, covering api, web and mobile.
- Added AYD-002: monitoring and observability design, covering api, web and mobile.
- Filled in GLO, PROD-001, REQ-001 and ARCH from product and code analysis.
- Documentation initialized from the scaffold.
