---
id: MANIFEST
type: meta
title: Manifesto / Índice do produto
status: approved
updated: 2026-06-25
owner: Silvio Ubaldino
---

# Manifesto — Mapa da Documentação

> Ponto de entrada para humanos e IAs. Mantenha sincronizado com os arquivos.

## Estado do produto
- **Produto:** Personal Finance
- **Repos:** context (este) · api (`personal-finance`) · web (`personal-finance-frontend-v2`) · mobile (`personal-finance-mobile`)
- **Fase atual:** Execução — produto em produção (com cobrança via Stripe/RevenueCat); documentação compartilhada em backfill (PROD/REQ/GLO preenchidos; primeiro AYD real — AYD-002, monitoramento — registrado; ROAD e ADRs ainda pendentes)

## Grafo de documentos
| Camada | ID | Documento | Status | Refina | Detalhado por |
|--------|----|-----------|--------|--------|----------------|
| Produto      | PROD-001 | Visão & estratégia | draft    | —        | REQ-001 |
| Requisitos   | REQ-001  | Requisitos         | draft    | PROD-001 | AYD-002 |
| Design       | AYD-001  | (exemplo) Feature  | draft    | REQ-001  | SPEC-001@api, SPEC-001@web |
| Design       | AYD-002  | Monitoramento e observabilidade | draft | REQ-001 | — (nenhuma SPEC formal ainda) |
| Roadmap      | ROAD-001 | Roadmap            | draft    | PROD-001 | — |
| Decisão prod | PDR-001  | (exemplo)          | accepted | —        | — |
| Decisão arq  | ADR-001  | (exemplo)          | accepted | —        | — |
| Arquitetura  | ARCH     | Visão de arquitetura (C4 vivo) | approved | — | — |
| Glossário    | GLO      | Linguagem ubíqua   | approved | —        | — |

## Ordem de leitura para a IA
1. `_meta/conventions.md` (regras, ciclo de vida, propagação) →
2. esta tabela →
3. a camada relevante para a tarefa (ver `CLAUDE.md`).

## Diagrama de relações
```
PROD-001
   ├─ REQ-001 ─ AYD-001 (exemplo) ─┬─ SPEC-001@api ─ PLAN-001@api
   │                               ├─ SPEC-001@web ─ PLAN-001@web
   │                               └─ SPEC-001@mobile ─ PLAN-001@mobile
   │          └ AYD-002 (monitoramento, real) ─ (sem SPEC ainda)
   └─ ROAD-001
(PDR / ADR / ARCH / GLO referenciados transversalmente por todos)
 ARCH = topologia vigente (C4 vivo); atualizado quando entra/sai serviço ou integração.
```
