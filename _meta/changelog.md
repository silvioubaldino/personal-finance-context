---
id: META-changelog
type: meta
title: Changelog do repo de contexto
status: approved
updated: 2026-08-28
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

- Added SPEC-001 in api, web and mobile for AYD-004 (invoice import), now covering the whole design: the api extracts and persists a credit card invoice reusing the existing invoice rules, the previous invoice's payment and installments belonging to later invoices are flagged instead of silently dropped, and installments already registered in the app are linked and repriced instead of duplicated; web and mobile review the extracted items, show the invoice metadata and every non-fatal warning, and let the user reinclude a flagged item or accept, undo and set an installment link by hand. AYD-004 also gained the optional `credit_card_id` on `/extract` (without it the server cannot derive the invoice period or search existing series, so the enrichment degrades and `confirm-invoice` reapplies the rules defensively), restricted the future-competence rule to installments so an ordinary purchase dated after the closing day still reaches the next invoice, and corrected the credit-limit error name. Open items found while reading the code — a positive refund classified as income, plan limits not applied to invoice import, `invoice_id` overriding date-based invoice resolution, a paid invoice aborting the import midway, correction reimports and the interaction with invoice payment in AYD-003 — are recorded as questions, not implemented.
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
