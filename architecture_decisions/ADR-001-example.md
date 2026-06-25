---
id: ADR-001
type: adr
title: Upload via URL assinada (EXEMPLO)
status: accepted
created: 2025-01-01
updated: 2025-01-01
owner: <nome>
affects: [api, web, mobile]
parents: []
related: [AYD-001]
tags: [storage]
superseded_by: null
---

# ADR-001: Upload via URL assinada (EXEMPLO)

## Contexto
Upload de arquivos grandes; passar tudo pela API onera o backend e a latência.

## Decisão
Clientes (web/mobile) sobem direto para o storage usando URL assinada emitida pela API.

## Alternativas consideradas
| Opção | Prós | Contras | Por que (não) escolhida |
|-------|------|---------|-------------------------|
| URL assinada | escala, menos carga na API | fluxo em 2 passos | **Escolhida** |
| Proxy pela API | simples | gargalo/custo | descartada |

## Consequências / trade-offs
- **Positivas:** API leve, upload escalável.
- **Negativas:** clientes lidam com expiração da URL.
- **Impacto:** define o contrato em AYD-001; afeta SPEC-001 dos três repos.
