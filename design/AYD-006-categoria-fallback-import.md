---
id: AYD-006
type: design
title: Categoria de fallback do import (entrada não categorizada)
status: draft
created: 2026-08-24
updated: 2026-08-24
owner: Silvio Ubaldino
affects: [api, web, mobile]
parents: [REQ-001]
children: []
related: [AYD-003, AYD-004, AYD-005, GLO]
tags: [import, category, analytics]
superseded_by: null
---

# AYD-006: Categoria de fallback do import (entrada não categorizada)

## Objetivo

Atender RF-07 (`requirements.md`) sem corromper os agregados de dinheiro. Hoje o import de
`Statement` joga **todo** `Movement` que o usuário não categorizou numa única `Category` de
fallback — "Sem categoria" —, e essa categoria tem `is_income = false` fixo. Como toda a
classificação receita × despesa do produto sai da flag `is_income` da `Category` (regra do
recorte canônico, `AYD-005`), **toda entrada não categorizada vinda de extrato nasce como
despesa**, com valor positivo.

O resultado é uma `Category` de despesa que fecha o período **positiva**. Isso não é uma
anomalia teórica: foi a causa raiz da divergência de Análises investigada em 24/ago/2026
(ver `AYD-003` § Divergência de 24/ago/2026), e contamina qualquer tela que agregue por
`is_income` — Análises, Planejamentos e Dashboard.

## Onde o problema nasce

```
POST /v2/statements/confirm
   └─ StatementUseCase.Confirm            (statement_usecase.go@api)
        └─ resolveCategoryID(m.CategoryID, uncategorizedID)
             └─ domain.UncategorizedCategoryID = "c1a2b3c4-d5e6-4f7a-8b9c-0d1e2f3a4b5c"
                  └─ categories.is_income = false          ← o sinal do Movement é ignorado
```

O fallback é aplicado **sem olhar o sinal do `amount`**. Uma linha de crédito no extrato que
o usuário não categorizou na revisão vira `Movement` com `amount > 0` apontando para uma
`Category` de despesa.

### Evidência (banco local, usuário `ipKj9…SOt2`, ano de 2026)

| | |
|---|---|
| 14 `Movement`s "Dinheiro retirado Emergência" | **+5.530,00** em "Sem categoria" (`is_income = false`) |
| todos com `idempotency_hash` preenchido | vieram de import de extrato (criados em 19 e 25/04/2026) |
| 4 `Movement`s irmãos, mesma descrição | +8.500,00 em "Retorno de investimentos" (`is_income = true`) — categorizados à mão pelo usuário |

As irmãs categorizadas manualmente mostram a intenção: são **entradas**. Não existe `Wallet`
"Emergência" no cadastro, então é dinheiro que entra de fora, não `InternalTransfer`.

**Alcance:** varredura do banco inteiro encontrou **um único** caso — um usuário, uma
categoria. É falha estrutural latente, não incidente em curso. O que a torna relevante é que
qualquer usuário que importe extrato e deixe uma entrada sem categoria reproduz o defeito.

## Decisão de contrato

O fallback passa a existir em **duas flavors**, e o import escolhe **pelo sinal, no momento
da escrita**:

| `amount` | `Category` de fallback | `is_income` |
|---|---|---|
| `< 0` | `Sem categoria` (a atual, id inalterado) | `false` |
| `> 0` | `Sem categoria (receita)` (**nova**, `user_id = default_category_id`) | `true` |

Três consequências deliberadas:

- **A regra "classifica pelo `is_income`, nunca pelo sinal" continua intacta nos agregados.**
  O sinal decide apenas *qual categoria* é gravada, na escrita. Nenhum consumidor de
  `is_income` muda de comportamento — é justamente o que impede que um estorno legítimo em
  categoria de despesa vire receita (`AYD-005` § Recorte canônico).
- **É correção na escrita, não na leitura.** Tratar o caso dentro do dashboard exigiria que
  cada agregado conhecesse a categoria de fallback como exceção — três telas replicando a
  mesma regra, contra a `SPEC` de cada uma.
- **"Sem categoria" não é uma categoria de verdade**, é a ausência de uma. Por isso ela pode
  ter duas flavors sem virar precedente para categorias reais: o usuário nunca escolhe entre
  as duas, o import escolhe por ele.

### Repos afetados e papéis

| Repo | Papel nesta feature | SPEC gerada |
|------|---------------------|-------------|
| api | Cria a `Category` default `Sem categoria (receita)` (migração de seed) e roteia por sinal no confirm do `Statement`. Backfill das linhas já gravadas | ainda sem SPEC |
| web | Só exibe. Nenhuma mudança de contrato consumida — a categoria nova chega pelo `GET /v2/categories` como qualquer outra default | ainda sem SPEC |
| mobile | Idem web | ainda sem SPEC |

O seletor de categoria da tela de revisão do import **não** deve oferecer as duas flavors ao
usuário: elas são destino de fallback, não escolha.

### Backfill

As linhas já gravadas não se corrigem sozinhas. O backfill move para
`Sem categoria (receita)` todo `Movement` com `amount > 0` apontando hoje para
`UncategorizedCategoryID`. É idempotente e reversível pelo par (categoria, sinal).

Ele **muda números que o usuário já vê**: no caso medido, a despesa do ano vai de
−79.947,06 para −85.477,06 — os +5.530,00 de entradas paravam de abater despesa. O número
novo é o correto; o antigo subestimava a despesa. Vale nota de release, pela mesma razão que
a unificação do recorte em `AYD-003` valeu.

## Modelo de domínio afetado

Nenhuma entidade nova. Uma linha nova em `categories` (`user_id = default_category_id`),
seguindo o mesmo padrão das categorias fixas de `InternalTransfer`.

> **Atenção ao copiar ids.** `UncategorizedCategoryID`
> (`c1a2b3c4-d5e6-4f7a-8b9c-0d1e2f3a4b5c`) e `InternalTransferOutCategoryID`
> (`c1a2b3c4-d5e6-f7a8-b9c0-d1e2f3a4b5c6`) são a **mesma string hex deslocada de um nibble**.
> São ids distintos e o código está correto, mas a semelhança é um convite a erro em query
> manual e em migração escrita à mão. O id da flavor nova não deve seguir esse padrão.

## Decisões relacionadas

Nenhum `ADR`/`PDR` aplicável — não há mudança de topologia nem decisão de produto formal.
A decisão de contrato está registrada aqui (§ Decisão de contrato).

## Fora de escopo / questões em aberto

- [ ] **Sugerir categoria por histórico na revisão do import** — reduziria a incidência do
      fallback na origem, mas é feature de import (`AYD-004` já discute `source: "history"`),
      não desta correção.
- [ ] **`is_income` deveria ser derivável, e não flag por categoria?** Questão de fundo que
      esta decisão contorna sem resolver. Fora de escopo aqui.
