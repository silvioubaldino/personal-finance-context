---
id: MANIFEST
type: meta
title: Manifesto / Índice do produto
status: approved
updated: 2025-01-01
owner: <nome>
---

# Manifesto — Mapa da Documentação

> Ponto de entrada para humanos e IAs. Mantenha sincronizado com os arquivos.

## Estado do produto
- **Produto:** _<nome>_
- **Repos:** context (este) · api · web · mobile
- **Fase atual:** _Produto / Requisitos / Design / Execução_

## Grafo de documentos
| Camada | ID | Documento | Status | Refina | Detalhado por |
|--------|----|-----------|--------|--------|----------------|
| Produto      | PROD-001 | Visão & estratégia | draft    | —        | REQ-001 |
| Requisitos   | REQ-001  | Requisitos         | draft    | PROD-001 | AYD-001 |
| Design       | AYD-001  | (exemplo) Feature  | draft    | REQ-001  | SPEC-001@api, SPEC-001@web |
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
   ├─ REQ-001 ─ AYD-001 ─┬─ SPEC-001@api ─ PLAN-001@api
   │                     ├─ SPEC-001@web ─ PLAN-001@web
   │                     └─ SPEC-001@mobile ─ PLAN-001@mobile
   └─ ROAD-001
(PDR / ADR / ARCH / GLO referenciados transversalmente por todos)
 ARCH = topologia vigente (C4 vivo); atualizado quando entra/sai serviço ou integração.
```
