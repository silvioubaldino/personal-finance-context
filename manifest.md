---
id: MANIFEST
type: meta
title: Manifesto / Índice do produto
status: approved
updated: 2026-08-14
owner: Silvio Ubaldino
---

# Manifesto — Mapa da Documentação

> Ponto de entrada para humanos e IAs. Mantenha sincronizado com os arquivos.

## Estado do produto
- **Produto:** Personal Finance
- **Repos:** context (este) · api (`personal-finance`) · web (`personal-finance-frontend-v2`) · mobile (`personal-finance-mobile`)
- **Fase atual:** Execução — produto em produção (com cobrança via Stripe/RevenueCat); documentação compartilhada em backfill (PROD/REQ/GLO preenchidos; AYDs reais registrados — AYD-002 monitoramento, AYD-003 análises financeiras (api/mobile em implementação, com SPEC), AYD-004 import de fatura de cartão e AYD-005 transferência interna (parcialmente implementada, com SPEC no mobile); ROAD e ADRs ainda pendentes)
- **Fase atual:** Execução — produto em produção (com cobrança via Stripe/RevenueCat); documentação compartilhada em backfill (PROD/REQ/GLO preenchidos; AYDs reais registrados — AYD-002 monitoramento, AYD-003 análises financeiras, AYD-004 import de fatura de cartão e AYD-005 planejamentos orçado×realizado (todos em design, ainda sem SPEC); ROAD e ADRs ainda pendentes)

## Grafo de documentos
| Camada | ID | Documento | Status | Refina | Detalhado por |
|--------|----|-----------|--------|--------|----------------|
| Produto      | PROD-001 | Visão & estratégia | draft    | —        | REQ-001 |
| Requisitos   | REQ-001  | Requisitos         | draft    | PROD-001 | AYD-002, AYD-003, AYD-004, AYD-005 |
| Design       | AYD-001  | (exemplo) Feature  | draft    | REQ-001  | SPEC-001@api, SPEC-001@web |
| Design       | AYD-002  | Monitoramento e observabilidade | draft | REQ-001 | — (nenhuma SPEC formal ainda) |
| Design       | AYD-003  | Análises financeiras (visão ao longo do tempo) | draft | REQ-001 | SPEC-002@api, SPEC-002@mobile, SPEC-002@web |
| Design       | AYD-004  | Import de fatura de cartão de crédito | draft | REQ-001 | — (nenhuma SPEC ainda) |
| Design       | AYD-005  | Transferência interna entre carteiras | draft | REQ-001 | SPEC-003@mobile |
| Design       | AYD-005  | Planejamentos — orçado × realizado (agregação no servidor) | draft | REQ-001 | — (nenhuma SPEC ainda) |
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
   ├─ REQ-001 ─ AYD-001 (exemplo) ─┬─ SPEC-001@api
   │                               ├─ SPEC-001@web
   │                               └─ SPEC-001@mobile
   │                                 (1 SPEC por repo = spec + plano no mesmo doc)
   │          ├ AYD-002 (monitoramento, real) ─ (sem SPEC ainda)
   │          ├ AYD-003 (análises financeiras, real) ─┬─ SPEC-002@api
   │          │                                       ├─ SPEC-002@mobile
   │          │                                       └─ SPEC-002@web
   │          ├ AYD-004 (import de fatura de cartão, real, em design) ─ (sem SPEC ainda)
   │          └ AYD-005 (transferência interna, real, parcialmente implementada) ─ SPEC-003@mobile
   │          ├ AYD-003 (análises financeiras, real, em design) ─ (sem SPEC ainda)
   │          ├ AYD-004 (import de fatura de cartão, real, em design) ─ (sem SPEC ainda)
   │          └ AYD-005 (planejamentos orçado×realizado, real, approved) ─┬─ SPEC-002@api    (fase 2)
   │             │                                                        ├─ SPEC-003@web    (fase 3)
   │             │                                                        ├─ SPEC-004@mobile (fase 3)
   │             │                                                        ├─ SPEC-005@web    (fase 3.5)
   │             │                                                        └─ SPEC-006@api    (fase 4)
   │             └ compartilha a definição de "realizado" com AYD-003
   └─ ROAD-001
(PDR / ADR / ARCH / GLO referenciados transversalmente por todos)
 ARCH = topologia vigente (C4 vivo); atualizado quando entra/sai serviço ou integração.
```
