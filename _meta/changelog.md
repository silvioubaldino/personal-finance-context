---
id: META-changelog
type: meta
title: Changelog do repo de contexto
status: approved
updated: 2026-06-29
owner: Silvio Ubaldino
---

# Changelog — Context

All notable changes to the shared docs (PROD, REQ, AYD, ROAD, decisions) are documented
here. This is where the audit trail of the "why" behind the **living** documents lives.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this
repo adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Policy**:
- **Order:** most recent on top; new entries go **above** the previous ones.
- **Unreleased:** unreleased work accrues under `## Unreleased` (always the top block), with
  no date/version. On the PRs, `## Unreleased` becomes `## [dd-MM-yyyy - vX.Y.Z]`
  (SemVer) and a new empty `## Unreleased` is opened above it.
- **One line per PR:** each PR adds a **single line** describing summarized what it delivers — general,
  no implementation or docs-framework detail; reference the PR (e.g. `[PR#02](url)`). The
  line **may omit SPEC/PLAN additions** (tracked by their own files/git): if a PR only adds a
  SPEC/PLAN, summarize the feature they open.

## Unreleased

- Updated AYD-003 (financial analytics): added a yearly expense-by-category breakdown,
  sorted largest to smallest.
- Updated AYD-003 (financial analytics): dropped the four period KPIs, added credit card
  invoice totals stacked by card (carrying each card's own colour) and an expense-count
  distribution by weekday, and required a labelled currency axis on the money bar charts;
  linked SPEC-002@api and SPEC-002@mobile.
- Updated AYD-002 + ARCH (observability): unified web and mobile telemetry onto a single
  ingestion contract (`POST /v1/telemetry` → sidecar), dropping the web's direct
  `@vercel/otel`→Grafana path and the mobile Crashlytics/GA4/BigQuery client-side plan
  from the design and diagram; web now emits perceived request latency
  (`app_http_client_request_duration_seconds`). ARCH now draws the client telemetry
  ingestion path and records Vercel RUM as a separate native pane (kept configured, not
  bridged into Grafana). Trace preparation (Tempo, Fase 6) kept for the future.
- Added AYD-004 (credit card invoice import design: layered statement/invoice
  differentiation, `confirm-invoice` contract reusing the existing `InvoiceUseCase`,
  phased rollout), covering api, web and mobile; sourced from `personal-finance`'s
  `AyDimportfatura.md` design notes; linked as a child of REQ-001.
- Added AYD-003 (financial analytics design: trends over time, budget vs. actual,
  savings-rate KPIs), covering api, web and mobile; linked as a child of REQ-001.
- Added AYD-002 (monitoring/observability design: OTel Collector sidecar routing,
  `biz_*` business KPI catalog, SLO targets and rollout phases), the first real AYD,
  sourced from `personal-finance`'s informal design notes (`AyDmonitoramento.md` /
  `diagramainframonitoramento.md`); linked as a child of REQ-001.
- Filled in GLO, PROD-001, REQ-001 and ARCH from product/code analysis (vision, personas,
  functional and non-functional requirements, business rules and the C4 container view for the
  features already in production); renamed `Transfer` to `InternalTransfer` in GLO per review.
- Documentation initialized from the scaffold.
