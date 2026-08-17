---
id: AYD-005
type: design
title: Planejamentos — orçado × realizado (agregação no servidor)
status: draft
created: 2026-08-17
updated: 2026-08-17
owner: Silvio Ubaldino
affects: [api, web, mobile]
parents: [REQ-001]
children: []
related: [AYD-003, GLO]
tags: [estimate, planning, balance, consistency]
superseded_by: null
---

# AYD-005: Planejamentos — orçado × realizado (agregação no servidor)

> **Nota de origem:** este AYD nasce de uma análise cross-repo da página de Planejamentos
> (17/ago/2026), motivada por um sintoma de produção: **os mesmos dados exibem valores
> diferentes no web e no mobile**. A análise leu o código das três branches de trabalho e
> confirmou a causa — a regra de cálculo está reimplementada em quatro lugares
> independentes, que discordam em cinco pontos. Este documento fixa o recorte canônico e o
> contrato; não descreve implementação (isso é SPEC/PLAN por repo).

> **Nota de status:** `draft`. Três decisões de produto estão marcadas como
> **pendentes de review** na seção homônima — a recomendação de cada uma já está escrita e é
> o que o contrato abaixo assume. Confirmadas ou corrigidas, o doc vai a `review` e as SPECs
> podem começar.

## Objetivo

Atender REQ-001 na parte de `Estimate`: garantir que a página de Planejamentos mostre
**o mesmo número em qualquer cliente**, movendo o cálculo de "realizado", dos agregados e
dos totais para a api, e deixando web e mobile apenas exibindo.

O problema não é ausência de backend. A regra de teto/piso do `Balance` **já existe em Go**,
implementada duas vezes (legacy e clean-arch) e documentada no `swagger.yaml`. O problema é
que **nenhum front a consome**: os dois hooks que apontam para ela existem e estão órfãos
(`hooks/use-estimates.ts:157`@web, `src/hooks/use-estimates.ts:29`@mobile — nenhum
componente os chama). Cada front reimplementou a agregação com um recorte próprio de
`Movement`s.

## Repos afetados e papéis

| Repo | Papel nesta feature | Status do desenho | SPEC gerada |
|------|---------------------|--------------------|-------------|
| api | Passa a ser o dono do cálculo: novo `GET /v2/estimate/summary` que devolve linhas por `Category`/`Subcategory` e totais já agregados; corrige os bugs de soma listados em "Débito técnico bloqueante" | Detalhado — contrato fechado abaixo | nenhuma ainda |
| web | Consome o contrato e **remove** a agregação local (`use-estimate-with-movements.ts`, `estimate-calculations.ts`, `sum-movements-by-category.ts`); migra também a leitura de `/estimate` legacy para v2 | Detalhado o suficiente para SPEC | nenhuma ainda |
| mobile | Consome o **mesmo contrato** e remove os três `useMemo` de agregação do `PlanningScreen.tsx` | Detalhado o suficiente para SPEC | nenhuma ainda |

> `children` fica vazio: nenhuma `SPEC` foi escrita ainda. Este AYD fixa o contrato e o
> recorte canônico; SPEC@api é o próximo passo, e SPEC@web / SPEC@mobile saem em paralelo
> depois que o endpoint existir.

## Sumário executivo (decisões-chave)

| Tema | Decisão |
|---|---|
| **Onde a regra mora** | Na **api**, num único usecase. Web e mobile não recalculam nada — recebem números prontos. |
| **Forma da entrega** | Endpoint **aditivo** `GET /v2/estimate/summary`; os endpoints atuais continuam de pé até os dois fronts migrarem. Nada quebra no dia do deploy. |
| **O que a api devolve** | **Números**, nunca string formatada, cor, label traduzido ou valor absoluto. Formatação, i18n e cor continuam sendo responsabilidade de cada front. |
| **Recorte de "realizado"** | Fora: `internal_transfer` (o `GLO` já diz que não entra no resultado do período) e `invoice_payment` (as compras já vêm itemizadas — contá-lo duplica o cartão). Dentro: compras no cartão, via itens da `Invoice`. |
| **Pendente conta?** | O payload devolve **`realized`** (todos) e **`realized_paid`** (só `is_paid`). Planejamentos usa `realized`; AYD-003 usa `realized_paid`. Ver "Decisões pendentes de review". |
| **Sinal do `result`** | Uma convenção só, para os dois fronts: **positivo = sobrou**. Elimina a inversão de sinal entre web e mobile. |
| **Receita × despesa** | Classificado pela flag `is_income` da `Category`, **nunca pelo sinal do valor** — um estorno em categoria de despesa reduz a despesa, não vira receita. |
| **Período** | `month`/`year` inteiros; o servidor resolve as datas. Nenhum front monta janela de data. |

## Diagnóstico — as regras hoje

Quatro implementações da mesma regra:

| Implementação | Arquivo | Consumida? |
|---|---|---|
| api · legacy | `internal/domain/balance/service/balance.go:29`@api | não |
| api · v2 | `internal/usecase/balance_usecase.go:36`@api | não |
| web | `hooks/use-estimate-with-movements.ts:34`@web | **sim** |
| mobile | `src/screens/PlanningScreen.tsx:125–331`@mobile (inline na tela) | **sim** |

Além disso, os fronts leem os planejamentos de **endpoints diferentes**: web usa
`GET /estimate` (legacy, `internal/domain/estimate/api/handler.go:25`@api) e mobile usa
`GET /v2/estimate/` (`internal/infrastructure/api/estimate_api.go:33`@api).

### Divergências confirmadas

| # | Regra | api (balance) | web | mobile |
|---|---|---|---|---|
| 1 | Recorte de `type_payment` | Exclui `credit_card` e `invoice_remainder`; **inclui** `internal_transfer` e `invoice_payment` (`movement_repository.go:107`) | Exclui `invoice_payment`; **inclui** `internal_transfer` (`use-estimate-with-movements.ts:55`) | Exclui `internal_transfer`; **inclui** `invoice_payment` (`PlanningScreen.tsx:137`) |
| 2 | `is_paid` | Só pagas (`GetPaidMovements`) | Todas | Todas |
| 3 | Receita × despesa | Pelo **sinal** (`Amount < 0`) | Pela flag `is_category_income` | Pela flag `category.is_income` |
| 4 | Sinal do `result` | — | `budgeted − realized`, e a cor vem do tipo da categoria — despesa fica vermelha mesmo quando economizou (`estimate-calculations.ts:1` + `estimate-display.ts:6`) | `abs(realized) − abs(budgeted)` para receita, invertido para despesa; cor pelo sinal (`PlanningCategoryRow.tsx:66`) |
| 5 | Janela do período | — | `toISOString()` sobre data local — desloca um dia em fusos a **leste** de Greenwich, ou seja usuários `pt-PT` (`movement-context.tsx:30`) | `startOfMonth`/`endOfMonth` em hora local (`PlanningScreen.tsx:106`) |

Já **coincidem** nos três lugares (portanto são as fáceis de mover): teto/piso nos cards de
resumo, linhas virtuais para categoria com gasto e sem planejamento, e normalização do sinal
na escrita (despesa negativa) — esta última feita nos dois fronts, **sem validação na api**.

### Impacto medido

Mesmo mês, mesmos dados. Planejado: Alimentação `−1.000`, Salário `+5.000`. Movimentações:
salário pago `+5.000`; mercado pago `−600`; mercado **pendente** `−300`; restaurante no
cartão `−400`; pagamento da fatura `−400`; transferência interna de `1.000` entre `Wallet`s.

| | web | mobile | api (`/v2/balance`) |
|---|---:|---:|---:|
| Receitas | 6.000 | 5.000 | 6.000 |
| Despesas | −2.300 | −1.700 | −2.400 |
| **Saldo do período** | **3.700** | **3.300** | **3.600** |
| Linhas fantasma na lista | 2 × transferência interna | 1 × "Cartão de Crédito" | — |

Nenhum dos três está correto. O realizado de Alimentação — a linha que o usuário olha — dá
`−1.300` nos fronts e `−600` na api.

Duas causas específicas merecem nome:

- **Web** deixa passar as duas pernas de cada `InternalTransfer`, que têm categorias
  dedicadas (`transfer_usecase.go:68`@api) e por isso viram duas linhas fantasma na lista e
  inflam os dois cards.
- **Mobile** deixa passar o `Movement` de `invoice_payment`, que carrega uma `Category` de
  cartão fixa (`invoice_usecase.go:405`@api) — então **conta as compras do cartão duas
  vezes**: item por item via `invoices[].movements` e outra vez no valor cheio da fatura.

### Débito técnico bloqueante

`internal/domain/movement.go:83`@api — `GetSumByCategory` lê o mapa com `movement.CategoryID`
e escreve com `movement.Category.ID`, e **a chave do mapa é um ponteiro** (`map[*uuid.UUID]`).
Cada `Movement` carrega o seu próprio ponteiro, então duas movimentações da mesma `Category`
caem em chaves distintas e a soma **nunca acumula**; depois, em `getBalanceSum`, os ponteiros
são desreferenciados e colapsam, ficando com o valor de *uma* movimentação em vez da soma.
Mesmo padrão em `GetEstimateByCategory` (`internal/domain/estimatecategory.go:23`@api).

Consequência para esta feature: **o cálculo do servidor não pode ser reusado como está**. A
correção entra na SPEC@api, antes de qualquer front passar a confiar no endpoint.

## Contrato (fonte da verdade)

```
GET /v2/estimate/summary?month=8&year=2026
Auth: Firebase (header user_token)
```

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `month` | int (1–12) | Mês do planejamento |
| `year` | int | Ano do planejamento |

Response (`200`):

```json
{
  "month": 8,
  "year": 2026,
  "totals": {
    "income":  { "budgeted": 5000,  "realized": 5000,  "realized_paid": 5000,  "consolidated": 5000 },
    "expense": { "budgeted": -1000, "realized": -1300, "realized_paid": -1000, "consolidated": -1300 },
    "period_balance": 3700
  },
  "categories": [
    {
      "estimate_id": "0f7d…",
      "category_id": "3a91…",
      "category_name": "Alimentação",
      "is_income": false,
      "is_planned": true,
      "budgeted": -1000,
      "realized": -1300,
      "realized_paid": -1000,
      "result": -300,
      "progress": 1.3,
      "subcategories": [
        {
          "sub_estimate_id": "b21c…",
          "sub_category_id": "7fe0…",
          "sub_category_name": "Mercado",
          "is_planned": true,
          "budgeted": -600,
          "realized": -900,
          "realized_paid": -600,
          "result": -300,
          "progress": 1.5
        }
      ]
    }
  ]
}
```

Semântica:

| Campo | Regra |
|---|---|
| `realized` | Soma dos `Movement`s do período que passam pelo **recorte canônico** (abaixo). Despesa negativa. |
| `realized_paid` | O mesmo recorte, restrito a `is_paid = true`. Mesma semântica de "realizado" que AYD-003 usa. |
| `budgeted` | Valor do `Estimate` do mês. `0` quando a linha não é planejada. |
| `result` | **Positivo sempre significa "sobrou".** Despesa: `budgeted − realized`. Receita: `realized − budgeted`. O front colore pelo sinal, sem conhecer o tipo da linha. |
| `progress` | `abs(realized) / abs(budgeted)`; **`null`** quando `budgeted = 0` (evita divisão por zero e o "100%" arbitrário que os fronts inventam hoje). |
| `consolidated` | Teto/piso — `min` para despesa, `max` para receita, por categoria. É o número dos cards de resumo, e é a regra que o `swagger.yaml` já documenta em `/v2/balance/estimate/period`. |
| `is_income` | Vem da flag da `Category`, **nunca do sinal do valor**. |
| `is_planned` | `false` para linha virtual (tem `Movement`, não tem `Estimate`); nesse caso `estimate_id` / `sub_estimate_id` vêm `null`. |
| `period_balance` | `totals.income.consolidated + totals.expense.consolidated`. |
| sinais | Despesa **sempre negativa** em todo o payload, igual ao que AYD-003 já fixou. Valor absoluto é escolha de exibição de cada front. |
| ordenação | Receita antes de despesa; planejado antes de não planejado; alfabética por nome dentro de cada bloco. Os fronts **não** reordenam. |
| aninhamento | Duas camadas apenas (`categories[].subcategories[]`); subcategoria não aninha mais. |

**Recorte canônico de `realized`** — esta é a definição que os três repos passam a
compartilhar:

| Situação | Entra? | Por quê |
|---|---|---|
| `Movement` normal do período | sim | — |
| Compra no `CreditCard` | sim, via itens da `Invoice` | É despesa da categoria da compra, no mês da compra |
| `internal_transfer` (as duas pernas) | **não** | `GLO`: `InternalTransfer` não entra no resultado de entradas/saídas do período |
| `invoice_payment` | **não** | As compras já entram itemizadas; contar a fatura duplica o valor |
| `invoice_remainder` | **não** (ver pendência 2) | Hoje já fica fora; conta no mês da fatura que o recebe |
| `Movement` recorrente projetado | sim | Já vem de `GET /v2/movements/`; é compromisso do mês |

Erros: `month` fora de 1–12 ou `year` não inteiro → `400` (`WrapInvalidInput`); falha de
repositório → `500`. Isolamento por `user_id` como em todo endpoint autenticado.

Este mesmo contrato serve **api → web** e **api → mobile**; nenhum repo redefine campo ou
semântica localmente (`conventions.md` §5).

## Modelo de domínio afetado

Nenhuma entidade nova e **nenhuma migração**. A feature agrega `Estimate`, `Movement`,
`Category`/`Subcategory` e `Invoice` — todos já canônicos no `GLO`.

Dois termos abaixo são vocabulário **do contrato**, não conceitos de domínio ubíquos, por
isso ficam só aqui e não entram no `GLO`:

| Termo | Significado |
|---|---|
| `realized` | Soma dos `Movement`s de uma `Category`/`Subcategory` no mês, sob o recorte canônico. É o "realizado" que o `Estimate` compara. |
| `consolidated` | Resultado do teto/piso entre `budgeted` e `realized` — o `Estimate` funciona como teto para despesa e piso para receita. |

Uma regra passa a ser responsabilidade da api e deixa de ser de cada front: a
**normalização do sinal na escrita** (`POST`/`PUT` de `Estimate`) — despesa gravada
negativa, receita positiva, derivado da flag da `Category`. Hoje isso é feito em duplicata
(`normalizeEstimateAmount`@web e um ternário inline no `EstimateModal`@mobile) e a api aceita
qualquer sinal que chegue.

## Fluxo cross-repo

```mermaid
sequenceDiagram
  participant W as Web (EstimateContent)
  participant M as Mobile (PlanningScreen)
  participant A as API

  W->>A: GET /v2/estimate/summary?month&year (user_token)
  A-->>W: { totals, categories[] }
  M->>A: GET /v2/estimate/summary?month&year (user_token)
  A-->>M: { totals, categories[] }
  Note over W,M: Mesmo payload; cada repo só formata e desenha.

  Note over W,A: Modal de detalhes (lista de Movements) continua<br/>em GET /v2/movements/ — o summary não devolve lista.
```

## Consumidores

### O que cada front mantém

Layout, formatação de moeda e locale (`pt-BR` / `pt-PT` / `en-US`), escolha entre valor
absoluto e sinal, cores, barra de progresso, expandir/colapsar, badge de "não planejado",
modais de criar/editar, invalidação de cache. Os fronts continuam donos da UX — deixam de
ser donos da aritmética.

### Web

```
EstimateContent
   └─ useEstimateSummary(month, year)        (hooks/use-estimates.ts, SWR)
        └─ GET /v2/estimate/summary
   ├─ EstimateBalance          ← totals
   └─ EstimateCategoriesClient ← categories[]
```

Remove: `use-estimate-with-movements.ts`, `lib/utils/estimate-calculations.ts`,
`lib/utils/sum-movements-by-category.ts` e `lib/utils/group-movements-by-category.ts` (este
último já é código morto — nenhum import). Mantém a query de `Movement`s (já global via
`MovementProvider`) apenas para o modal de detalhes. Migra também o CRUD de `/estimate`
legacy para `/v2/estimate/*` — em PR separado (ver pendência 3).

### Mobile

```
PlanningScreen
   └─ useEstimateSummary(month, year)        (src/hooks/use-estimates.ts, React Query)
        └─ GET /v2/estimate/summary
   ├─ PlanningSummary      ← totals
   └─ PlanningCategoryRow  ← categories[]
```

Remove os três `useMemo` do topo da tela (`cleanedTransactions`, `spendingByCategory`,
`planningItems/summary`). A tela passa a distribuir props. Mantém `useMovementsByPeriod`
apenas para o `CategoryDetailsModal`, que precisa da lista e não do agregado.

## Fases

| Fase | Repo | Entrega |
|---|---|---|
| 1 | context | Este AYD em `review` → `approved`, com as três pendências resolvidas |
| 2 | api | SPEC + PLAN; usecase de summary; **correção de `GetSumByCategory` / `GetEstimateByCategory`**; normalização de sinal na escrita; swagger; endpoints antigos intactos |
| 3 | web · mobile (paralelo) | Uma SPEC por repo; consumir o summary; apagar a agregação local |
| 4 | api | Aposentar `/estimate`, `/sub-estimate`, `/balance/estimate/period`, `internal/domain/estimate/*`, `internal/domain/balance/*` e `/v2/balance/estimate/period` + os dois `useEstimateBalance` órfãos |

A Fase 3 só começa depois da 2; a Fase 4 só depois de web e mobile em produção.

**Cobertura obrigatória (Fase 2):** um caso table-driven **por regra** da tabela de
semântica, mais um *golden file* com o cenário de "Impacto medido" acima. O que permitiu esta
divergência não foi descuido — foi não existir um lugar onde as implementações se
comparassem. As SPECs de web e mobile batem nos mesmos números desse golden file.

## Decisões pendentes de review

As três não são inferíveis do código, porque o código discorda de si mesmo. A recomendação
de cada uma é o que o contrato acima já assume.

### 1. `Movement` pendente conta no realizado?

**Tensão:** AYD-003 escreveu que "realizado = `Movement`s **pagos**, mesma semântica do
`Balance`". Os dois fronts hoje contam tudo. Seguir AYD-003 ao pé da letra em Planejamentos
**muda o número de todo usuário** no dia do release.

**Recomendação:** devolver os dois campos e distinguir por tela — Planejamentos usa
`realized` (compromissos do mês, mantém o comportamento atual), Análises usa
`realized_paid` (o que de fato aconteceu). São perguntas diferentes: planejar é sobre o mês
inteiro, analisar é sobre o passado. Registrada aqui para não parecer contradição com
AYD-003.

### 2. `invoice_remainder` entra no realizado?

**Tensão:** hoje está fora do `FindByPeriod` da api e invisível para os fronts. Mas
conceitualmente é despesa real, empurrada para a fatura seguinte.

**Recomendação:** manter fora do mês em que foi gerado e contar no mês da `Invoice` que o
recebe — que é o comportamento atual de fato. Confirmar explicitamente para virar regra e
não permanecer acidente de implementação.

### 3. O web migra o CRUD junto com a leitura?

**Tensão:** o web ainda usa `/estimate` legacy para ler **e** escrever. O legacy tem contrato
levemente diferente (`estimates_sub_categories` sempre presente vs. `omitempty` no v2; não
devolve `user_id`) e desreferencia ponteiro sem checar nil
(`internal/domain/estimate/service/estimate_category.go:50`@api, corrigido no v2).

**Recomendação:** não. Leitura primeiro (só o summary), CRUD num PR seguinte. Dois PRs
pequenos em vez de um grande; o legacy só sai quando os dois terminarem.

## Riscos

- **Os números vão mudar para todos os usuários.** Não existe versão correta hoje, então
  corrigir é necessariamente mexer no que o usuário vê. Vale nota de release e publicar em
  virada de mês.
- **No mobile, corrigir o double-count do cartão vai parecer "sumiu dinheiro".** As despesas
  caem visivelmente para quem usa cartão. É a correção certa, mas merece aviso.
- **Formatação não pode migrar junto.** Se a api começar a devolver string formatada, cor ou
  label, o i18n dos três locales volta a divergir — pelo caminho inverso. Números no payload,
  sempre.

## Decisões relacionadas

- **AYD-003** compartilha a definição de "realizado" e a regra de sinais (despesa negativa).
  O campo `realized_paid` deste contrato é exatamente o que `current_month.budget.realized`
  de AYD-003 precisa — as duas features devem ler a mesma implementação no servidor, não
  duas parecidas.
- **Nenhum `ADR` aplicável:** não entra nem sai serviço ou integração externa; é mudança de
  contrato e de responsabilidade entre camadas, não de topologia. `architecture.md` não muda
  (`conventions.md` §7.5).

## Fora de escopo / questões em aberto

- [ ] **Decisões 1, 2 e 3** acima — bloqueiam a SPEC@api.
- [ ] **SPEC@api** — escrever a partir deste AYD antes de implementar a Fase 2.
- [ ] **SPEC@web / SPEC@mobile** — Fase 3, em paralelo, depois do endpoint no ar.
- [ ] **Movimentações por categoria** — o modal de detalhes continua filtrando a lista no
      cliente. Se o payload de `GET /v2/movements/` incomodar, avaliar depois um
      `GET /v2/estimate/summary/{category_id}/movements`. Não bloqueia nada.
- [ ] **Tipos gerados do contrato** — hoje web e mobile escrevem os tipos de `Estimate` à mão,
      em duplicata. Gerar do `swagger.yaml` fecharia a última porta de divergência; fica como
      questão aberta, fora do escopo desta feature.
- [ ] **Enum `TypePayment` divergente entre os fronts** — web tem `DEBIT`/`CASH`, mobile tem
      `MONEY`, e ambos convivem com `debit_card`. Não afeta este contrato (o recorte passa a
      ser feito no servidor), mas é dívida a limpar em algum momento.
