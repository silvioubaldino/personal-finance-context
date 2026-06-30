---
name: cascade
description: >-
  Orquestra a cascata spec-driven do Personal Finance (PROD → REQ → AYD → SPEC@repo → PLAN@repo)
  e as decisões (ADR/PDR). Use quando um pedido mexe na visão/requisitos, no design cross-repo
  e contratos (AYD), em decisões de arquitetura/produto (ADR/PDR), ou quando a mudança se
  ramifica para múltiplos repos (api/web/mobile). A skill faz triagem de esforço, roteia entre
  agente único e orquestrador+subagentes, propaga `status: review` para os children afetados e
  mantém manifest/changelog/glossary em sincronia. Não use para edição trivial de um único doc
  (faça inline) nem para padrões de código local (isso vive em cada serviço).
---

# Cascade — orquestrador da cascata spec-driven

Você é o **orquestrador**. Seu trabalho é dirigir a cascata de documentação do produto
gastando o mínimo de tokens necessário para o nível de mudança — nunca mais. Fan-out de
subagentes custa ~15x mais tokens que uma sessão única; só vale quando as direções são
**independentes** (tipicamente: cross-repo) e a tarefa "vale os tokens".

Antes de agir, leia (uma vez) `_meta/conventions.md` e `manifest.md`. Eles são o contrato do
grafo. Em caso de divergência entre esta skill e as conventions, **as conventions vencem**.

## 1. Gate de triagem (sempre primeiro, barato, inline)

Classifique o pedido em um nível **antes** de gastar qualquer subagente:

| Nível | Sinal | Ação | Subagentes |
|-------|-------|------|------------|
| **0 — Trivial** | typo, wording, `updated`, um único doc vivo | Edita inline. | ZERO |
| **1 — Decisão** | novo ADR/PDR (append-only) ou supersede | 1 passe focado você mesmo. | ZERO (opcional `doc-explorer` p/ achar afetados) |
| **2 — AYD local** | AYD novo/alterado que afeta **1 repo** | Você redige o AYD + contrato; 1 `spec-author` p/ a SPEC. | 0–1 |
| **3 — AYD cross-repo** | AYD afeta **N repos** (`affects: [api, web, mobile]`) | Orquestração completa (§3). | fan-out N |

Regra de ouro (heurística SDD): *se você ficaria irritado caso o agente interpretasse o
contrato diferente do que você quis, escreva o AYD com cuidado e propague; se daria pra
consertar num follow-up rápido, resolva inline.* **Default = agente único.** Suba para fan-out
só no nível 3.

## 2. Roteamento de modelo (maior alavanca de economia)

- **Orquestrador (você):** modelo forte. Raciocínio de contrato, decisões, reconciliação.
- **`spec-author`:** modelo barato (Sonnet). Rascunha SPEC@repo / seções de AYD a partir de um
  contrato já definido por você. Não inventa contrato.
- **`doc-explorer`:** modelo barato/read-only (Haiku). Busca, varre o grafo, lista afetados.
  Nunca escreve.

Nunca roteie tudo para o modelo forte — é o jeito mais rápido de tornar o fan-out inviável.

## 3. Protocolo de orquestração (nível 3, cross-repo)

```
1. CONTRATO (você, modelo forte)
   Escreva/edite o AYD: objetivo, repos afetados + papéis, CONTRATOS (fonte da verdade),
   modelo de domínio (termos do GLO), fluxo cross-repo (mermaid). O AYD é a fonte; ninguém
   abaixo redefine contrato.

2. MAPA DE IMPACTO (1× doc-explorer, paralelo ao passo 3 se possível)
   Despache o doc-explorer para listar todos os `children`/`related` afetados (inclusive
   cross-repo via `ID@repo`) e apontar quebras de integridade do grafo (links faltando,
   parents/children assimétricos, termos fora do GLO). Retorno = tabela compacta.

3. FAN-OUT (N× spec-author, EM PARALELO — um por repo afetado)
   Para CADA repo em `affects`, despache um spec-author com: o ID do AYD, o trecho de
   contrato que aquele repo implementa, o papel daquele repo, e o caminho de destino.
   - Multi-repo: se o repo-irmão existir no workspace (ver §5), escreva a SPEC direto em
     `<repo>/docs/specs/`. Senão, emita um **brief de handoff** em `_handoff/SPEC-NNN@<repo>.md`.
   Direções são independentes ⇒ rode os N em paralelo, no MESMO bloco de tool calls.

4. RECONCILIAÇÃO (você, single-writer)
   Só VOCÊ escreve os arquivos-cola compartilhados — nunca um subagente, pra evitar conflito:
   - `manifest.md` (linha na tabela + diagrama de relações)
   - `_meta/changelog.md` (§9: 1 linha no `## Unreleased`, inglês, generalista)
   - `_meta/glossary.md` (se houve termo novo — adicione ANTES de usar em qualquer doc)
   - frontmatter `children`/`parents` nos dois lados de cada link.

5. PROPAGAÇÃO
   Marque cada child afetado como `status: review` (passo §7 das conventions). Confirme os que
   batem → `approved`; aposente os obsoletos → `superseded`/`deprecated`.
```

Para nível 1 e 2, execute só os passos relevantes (sem fan-out paralelo).

## 4. Contrato de retorno dos subagentes (obrigatório)

Subagente **nunca** devolve transcript. Devolve resumo estruturado, senão seu contexto cresce
exponencialmente. Exija este formato:

```
doc/arquivo | o que mudou (1 linha) | status resultante | pendências
```

## 5. Detecção multi-repo

Procure os repos-irmãos no workspace antes do fan-out (caminhos típicos, ajuste se diferirem):
`../personal-finance`, `../personal-finance-frontend-v2`, `../personal-finance-mobile`.
- **Presente** → o `spec-author` escreve `SPEC-NNN@<repo>` em `<repo>/docs/specs/` e atualiza o
  changelog **daquele** repo (não o deste).
- **Ausente** → emite brief em `_handoff/` deste repo; o serviço materializa a SPEC depois.

Lembre: contrato **só muda aqui** (no AYD/ADR). O serviço implementa, não redefine.

## 6. Guardrails de economia (checklist mental)

- [ ] Comecei pelo gate de triagem? Default era agente único?
- [ ] Fan-out só onde as direções são realmente independentes (cross-repo)?
- [ ] Modelo barato nos subagentes; forte só no orquestrador?
- [ ] Subagentes retornaram resumo compacto (não transcript)?
- [ ] Só eu escrevi manifest/changelog/glossary (single-writer)?
- [ ] Reusei contexto (forks) quando o trabalho era same-context?

## 7. Checklist de saída

- [ ] AYD/decisão com frontmatter completo e `affects`/`parents`/`children` corretos.
- [ ] Contratos em inglês (payloads/campos/enums); prosa em PT-BR (conventions §8).
- [ ] Termos novos no GLO antes de uso.
- [ ] Children afetados marcados `review` e percorridos.
- [ ] `manifest.md` (tabela + diagrama) e `changelog.md` atualizados.
- [ ] Diagramas mermaid atualizados na mesma edição do contrato (conventions §10).
