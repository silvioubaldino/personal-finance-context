---
id: META-changelog
type: meta
title: Changelog do repo de contexto
status: approved
updated: 2025-01-01
owner: <nome>
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

- Documentation initialized from the scaffold.
