---
id: META-conventions
type: meta
title: Convenções da documentação
status: approved
updated: 2026-06-25
---

# Convenções da documentação

O "contrato" que mantém os documentos conectados e legíveis por humanos e IAs,
de forma consistente entre o repo de contexto e os repos de serviço.
(Isto define como escrever DOCS. Padrões de CÓDIGO ficam em cada serviço, em `docs/conventions/`.)

## 1. Tipos de documento e IDs

ID = `PREFIXO-NNN`, estável (nunca muda, mesmo se o arquivo for renomeado/movido).

| Prefixo | Tipo | Onde | Escopo |
|---------|------|------|--------|
| PROD | Produto (visão + estratégia) | contexto: `product.md` | compartilhado |
| REQ  | Requisitos | contexto: `requirements.md` | compartilhado |
| AYD  | Análise & Design (por feature) | contexto: `design/` | compartilhado, cross-repo |
| ROAD | Roadmap / planejamento | contexto: `roadmap.md` | compartilhado |
| PDR  | Product Decision Record | contexto: `product_decisions/` | compartilhado |
| ADR  | Architecture Decision Record | contexto: `architecture_decisions/` | compartilhado, cross-repo |
| ARCH | Visão de arquitetura (C4 vivo: contexto + containers) | contexto: `architecture.md` | compartilhado, cross-repo |
| SPEC | Especificação (parte de um repo) | serviço: `docs/specs/` | local |
| PLAN | Plano de implementação | serviço: `docs/plans/` | local |
| TDR  | Technical Decision Record | serviço: `docs/technical_decisions/` | local |
| CONV | Convenção de engenharia (teste, estilo, git…) | serviço: `docs/conventions/` | local |
| GLO  | Glossário (linguagem ubíqua) | contexto: `_meta/glossary.md` | compartilhado |

## 2. Frontmatter padrão (obrigatório em todo doc)

```yaml
---
id: AYD-007
type: design             # product|requirements|design|roadmap|pdr|adr|spec|plan|tdr
title: Upload de mídia
status: draft            # draft | review | approved | superseded | deprecated
created: 2025-01-01
updated: 2025-01-01
owner: <nome>
affects: [api, web, mobile]        # só em AYD/ADR: repos impactados
parents: [REQ-003]                 # o que este doc refina (camada acima)
children: [SPEC-012@api, SPEC-013@web]   # o que refina este doc (pode ser cross-repo)
related: [ADR-002, GLO]            # contexto transversal
tags: [media]
superseded_by: null                # ID que substitui este doc, se houver
---
```

## 3. Referências entre repos

IDs são **globais no produto**. Para apontar um doc de outro repo, use `ID@repo`:
`AYD-007@context`, `SPEC-012@api`, `SPEC-013@web`. (`@context` é o repo de contexto.)

## 4. Ciclo de status

`draft → review → approved → (superseded | deprecated)`
- **approved** = fonte da verdade vigente. **superseded/deprecated** = não usar para decisões.

## 5. Regras de linkagem (a "cola" do grafo)

- Refinamento declarado nos dois lados: `children` no pai, `parents` no filho.
- Toda `SPEC` tem ao menos um `AYD` em `parents` (ex.: `[AYD-007@context]`).
- **1 AYD → N SPECs**, uma por repo afetado. O AYD é a fonte dos contratos.
- **Contrato só muda no AYD/ADR (no repo de contexto).** Serviços implementam, não redefinem.
- Termos de domínio vivem só no `GLO`; os outros docs apenas referenciam.

## 6. Ciclo de vida: vivo vs imutável

| Tipo | Comportamento | Como mudar |
|------|---------------|-----------|
| PROD / REQ / AYD / ROAD / ARCH | **Vivo** | Edita in-place, atualiza `updated`. |
| PDR / ADR / TDR | **Append-only** | Nunca reescreve. Decisão nova substitui a antiga via `superseded_by`. |
| SPEC | **Congela ao aprovar** | Mutável em draft/review; vira contrato quando `approved`. |
| PLAN | **Efêmero** | Documento de trabalho; após executado, é histórico. |
| GLO | Vivo | Edita in-place. |

Auditoria dos docs vivos mora no **git + changelog**.

## 7. Propagação de mudanças

Ao alterar um doc:
1. Edita (ou cria uma decisão PDR/ADR/TDR, se for o caso) e atualiza `updated`.
2. Registra no `changelog.md` do repo.
3. Percorre os `children` (inclusive em outros repos) e marca os afetados como `status: review`.
4. Revisa cada filho; confirma → `approved`, ou aposenta → `superseded`/`deprecated`.
5. **Topologia:** se a mudança adiciona/remove/move um serviço ou integração externa,
   atualiza `architecture.md` (vivo) **na mesma edição**.

## 8. Idioma (documentação vs. código)

- **Prosa dos docs → português.** Entidades, campos, enums, endpoints e eventos → **inglês**
  (atravessam para o código). Em contratos (AYD/ADR), payloads/enums em inglês
  (ex.: `SubscriptionStatus: active | past_due | canceled`).
- O **GLO define o termo canônico em inglês**; os demais docs **referenciam** esse termo.
- **Exceção:** o `changelog.md` é em **inglês** (padrão Keep a Changelog). Ver §9.

## 9. Changelog

Inglês, [Keep a Changelog](https://keepachangelog.com) + [SemVer](https://semver.org),
ordem invertida (recente no topo), **uma linha por PR**. A política completa (formato do
bloco `Unreleased`, recorte por versão, o que a linha descreve) mora no **header do próprio
`changelog.md`** de cada repo — é lá que se consulta ao escrever uma entrada.

## 10. Convenções de diagramas

- **Mermaid embutido no `.md`** (versionável, renderiza no GitHub) — nunca imagem/PNG como canônico.
- Cada diagrama mora no doc da camada que descreve:
  - **Topologia vigente (C4 nível 1–2: contexto + containers) → `architecture.md` (vivo).**
    Visão única e canônica de serviços, integrações externas e provedores. Atualizada sempre
    que entra/sai um serviço ou integração (§7.5).
  - **Sequência cross-repo → AYD** (fluxo ponta a ponta de uma feature).
  - O **ADR** registra a *decisão* de topologia (o porquê) e pode embutir um **snapshot
    congelado** para ilustrar a mudança; o estado vigente vive em `architecture.md`.
- O diagrama **ilustra**; se divergir do texto/tabela, **o texto vence**. Herda o ciclo de
  vida do doc-pai e é atualizado **na mesma edição** que muda o contrato/fluxo/topologia.
