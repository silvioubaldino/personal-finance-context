---
id: AYD-003
type: design
title: Análises financeiras (visão ao longo do tempo)
status: draft
created: 2026-06-25
updated: 2026-08-24
owner: Silvio Ubaldino
affects: [api, web, mobile]
parents: [REQ-001]
children: [SPEC-002@api, SPEC-002@mobile, SPEC-002@web]
related: [AYD-005, AYD-006, GLO]
tags: [analytics, dashboard]
superseded_by: null
---

# AYD-003: Análises financeiras (visão ao longo do tempo)

> **Nota de status (22/ago/2026):** os **três** repos implementam a feature. api e mobile
> entregaram em `personal-finance#212` / `personal-finance-mobile#35`
> (`SPEC-002@api`, `SPEC-002@mobile`); o **web** ganhou `SPEC-002@web` e a página `/analises`
> na branch `claude/spec-ayd-analise-web-22qtwa`@web — implementada com paridade de
> visualizações e ordem com o mobile, **ainda não mergeada em `develop`**.
>
> **Recorte unificado (22/ago/2026):** os agregados de dinheiro passaram a ler o recorte
> canônico de `AYD-005` — uma implementação de servidor só, no lugar dos três recortes que
> conviviam na mesma resposta. Muda números que o usuário já via; ver
> [§ Recorte de "realizado"](#recorte-de-realizado).
>
> **Divergência de 24/ago/2026:** com o recorte já unificado, o web ainda mostrava
> `kpis.total_expense` e a soma de `expense_by_category` divergindo em R$ 5.300,90. São três
> defeitos empilhados — um de renderização no cliente, um de contrato (o invariante não é
> renderizável) e a causa raiz nos dados, que virou `AYD-006`. Ver
> [§ Divergência de 24/ago/2026](#divergência-de-24ago2026--categoria-positiva-na-tela).

## Objetivo

A Dashboard mostra só o mês corrente. Esta feature adiciona uma tela de **Análises** que dá
ao usuário uma visão financeira **ao longo do tempo**, a partir de um único endpoint
agregador no backend: **cinco visualizações + uma faixa de KPIs**, nesta ordem (a mesma nos
dois clientes, ver `SPEC-002@mobile` e `SPEC-002@web`):

| # | Visualização | Campo do payload |
|---|---|---|
| — | **KPIs** — receita e despesa totais do período (faixa no topo, não é gráfico) | `kpis` |
| 1 | **Receitas vs Despesas** — série mensal (barras pareadas) ao longo do período | `monthly_series` |
| 2 | **Despesas por categoria** — total pago no período por `Category`, da maior para a menor despesa | `expense_by_category` |
| 3 | **Orçado vs Realizado** — comparativo do mês selecionado (reusa `Estimate`) | `current_month.budget` |
| 4 | **Cartões de crédito** — total de `Invoice` por mês, empilhado por `CreditCard`, na cor de cada cartão | `credit_card_invoices` |
| 5 | **Despesas por dia da semana** — distribuição percentual da **quantidade** de `Movement`s de despesa por dia da semana (ex.: "46% das compras acontecem na sexta") | `expense_weekday_distribution` |

"Realizado" = `Movement`s **pagos** (mesma semântica do `Balance`), com uma exceção
deliberada na distribuição por dia da semana (§ Decisões, #7). Despesas mantêm sinal
**negativo** em todo o fluxo, nos três repos.

> **Ver AYD-005.** Ele detalha o *recorte* dessa mesma definição (quais `type_payment`
> entram e saem) e expõe o campo `realized_paid`, que é exatamente o que
> `current_month.budget.realized` precisa aqui. As duas features devem ler a mesma
> implementação no servidor, não duas parecidas — e desde 22/ago/2026 **leem**, ver
> [§ Recorte de "realizado"](#recorte-de-realizado).

## Repos afetados e papéis

| Repo | Papel nesta feature | Estado | SPEC |
|------|---------------------|--------|------|
| api | Agrega `Movement`s, `Estimate`s e `Invoice`s existentes (sem nova tabela/migração) num único endpoint por período; isolamento por `user_id` | Implementado | `SPEC-002@api` |
| mobile | Consome o contrato; tela "Análises" acessada pelo menu **Mais**; só formata/desenha o que a api devolve, sem agregação no cliente | Implementado | `SPEC-002@mobile` |
| web | Consome o **mesmo contrato**; página `/analises` como item de primeiro nível na sidebar; só formata/desenha, sem agregação no cliente | Implementado em branch (`claude/spec-ayd-analise-web-22qtwa`), fora de `develop` | `SPEC-002@web` |

## Contrato (fonte da verdade)

```
GET /v2/dashboard/summary?from=YYYY-MM-DD&to=YYYY-MM-DD
Auth: Firebase (header user_token)
```

| Parâmetro | Tipo | Descrição |
|---|---|---|
| `from` | date (`2006-01-02`) | Início do período (inclusivo) |
| `to` | date (`2006-01-02`) | Fim do período; o **mês de `to`** é o "mês selecionado" do orçado×realizado |

Response (`200`):
```json
{
  "monthly_series": [
    { "month": 1, "year": 2026, "income": 5000, "expense": -3200, "net": 1800 }
  ],
  "current_month": {
    "month": 6, "year": 2026,
    "budget": {
      "income":  { "budgeted": 5000, "realized": 4800 },
      "expense": { "budgeted": -3000, "realized": -3200 }
    }
  },
  "credit_card_invoices": {
    "cards": [
      { "credit_card_id": "0f1c…", "name": "Nubank", "color": "#820ad1" },
      { "credit_card_id": "7ab2…", "name": "Itaú",   "color": "" }
    ],
    "series": [
      {
        "month": 6, "year": 2026, "total": -2100,
        "by_card": [
          { "credit_card_id": "0f1c…", "amount": -1400 },
          { "credit_card_id": "7ab2…", "amount": -700 }
        ]
      }
    ]
  },
  "expense_weekday_distribution": [
    { "weekday": 0, "count": 3,  "percentage": 0.06 },
    { "weekday": 5, "count": 23, "percentage": 0.46 }
  ],
  "expense_by_category": [
    { "category_id": "9c3a…", "name": "Alimentação", "color": "#f97316", "total": -8400 },
    { "category_id": "1e7b…", "name": "Transporte",  "color": "",        "total": -4200 }
  ],
  "kpis": { "total_income": 30000, "total_expense": -19200 }
}
```

Semântica:

| Campo | Regra |
|---|---|
| `monthly_series[]` | 1 entrada por mês do span (meses sem `Movement` vêm zerados → eixo contínuo). `income`/`expense` = soma de pagos; `net = income + expense` |
| `current_month.budget` | mês de `to`. `budgeted` vem do `Estimate`; `realized` = pagos do mês (reusa lógica teto/piso do `Balance`) |
| `credit_card_invoices.cards[]` | Todo `CreditCard` com pelo menos uma `Invoice` no período. Ordenado por `name`; é a legenda/ordem de empilhamento canônica. `color` é a cor do próprio `CreditCard` (`#RRGGBB`) e vem **vazia** quando o usuário não escolheu nenhuma — o cliente aplica o fallback (§ Decisões, #11) |
| `credit_card_invoices.series[]` | 1 entrada por mês do span (mesmo eixo de `monthly_series`, meses sem fatura zerados). Uma `Invoice` cai no mês do seu **`due_date`** (§ Decisões, #8). `by_card[]` traz **todos** os cartões de `cards[]`, com `0` onde não houve fatura, para o empilhamento não “pular” cor. `total` = soma de `by_card[].amount` |
| `expense_weekday_distribution[]` | Sempre **7 entradas**, `weekday` 0=domingo … 6=sábado (mesma numeração de `time.Weekday`). `count` = quantidade de `Movement`s de despesa; `percentage` = `count / total de despesas do período` (fração 0–1, **0** quando não há despesa) |
| `expense_by_category[]` | Uma entrada por `Category` com despesa **paga** no período (soma de `Movement`s, exclui `internal_transfer`). Ordenado da maior despesa para a menor (em módulo). Categoria sem despesa paga no período **não aparece** — ao contrário de `by_card`, não há eixo de meses para manter estável, então não há zero-fill. `color` é a cor da própria `Category` e pode vir vazia (mesma regra do cartão, decisão #11) |
| `kpis` | Só `total_income` e `total_expense` do período |
| sinais | despesas e faturas sempre **negativas** |

Erros: `from`/`to` em formato inválido ou período inválido (`period.Validate()`) →
`400` (`WrapInvalidInput`); falha de repositório → `500`.

Este mesmo contrato serve **api → mobile** e **api → web**; nenhum repo redefine campo ou
semântica localmente (regra de linkagem, `conventions.md` §5).

### Recorte de "realizado"

A tabela acima diz *de onde* cada número vem; esta seção diz **quais `Movement`s** cada um
soma. Até 22/ago/2026 essa definição não existia no doc, e o resultado eram **três recortes
diferentes dentro da mesma resposta** — ver § Histórico, ao final da seção.

**Regra vigente (decidida pelo owner em 22/ago/2026):** todos os agregados de dinheiro desta
tela usam o **recorte canônico de `AYD-005`**, lendo a mesma implementação de servidor, não
uma parecida.

| Situação | Entra? | Onde conta |
|---|---|---|
| `Movement` avulso do período | sim | mês da própria data |
| Compra no `CreditCard` | sim, via itens da `Invoice` | mês do `due_date` da fatura |
| `invoice_remainder` | sim, via itens da `Invoice` | mês do `due_date` da fatura que o recebe |
| `invoice_payment` | **não** | — (as compras já entram itemizadas; contá-lo duplica o cartão) |
| `internal_transfer` | **não** | — (`GLO`: não entra no resultado do período) |
| `Movement` na `Category` fixa de transferência interna | **não** | — (pega as linhas antigas, gravadas antes do `type_payment` existir) |

Três regras derivam daí:

- **Mês de um item de fatura = mês do `due_date` da `Invoice`**, não o da compra. É a mesma
  convenção do gráfico de cartões (decisão #8) e a que `GET /v2/estimate/summary` já usa ao
  selecionar as faturas do mês. É o que garante `sum(monthly_series) == kpis` e
  `current_month.budget.realized == realized_paid` — atribuir pela data da compra jogaria
  itens para fora do span, que é selecionado por `due_date`. *(Nota: a linha "no mês da
  compra" em `AYD-005` § Recorte canônico descreve a intenção, não o que o servidor faz;
  registrado como pendência lá.)*
- **Receita × despesa sai da flag `is_income` da `Category`, nunca do sinal** — também parte
  do recorte canônico. Um estorno em categoria de despesa reduz a despesa em vez de virar
  receita. `Movement` sem `Category` fica **fora de todos os agregados de dinheiro**: não há
  como classificá-lo nem agrupá-lo, e é o mesmo corte de `aggregateRealized`, no summary de
  planejamentos. O `GLO` já diz que `Category` é obrigatória em todo `Movement`.
- **`current_month.budget.realized` é soma pura**, sem o teto/piso do `Balance` legacy
  (`getBalanceSum`). Orçado 5000 com 4800 realizado passa a mostrar **4800**, não 5000.

`expense_weekday_distribution` segue com pagas **e** pendentes (decisão #7), sobre esse mesmo
conjunto — é o que finalmente entrega as compras no cartão que a decisão prometia —, mas pelo
**dia da própria compra**, não pelo vencimento, e sem o `invoice_remainder`, que é saldo
empurrado para a fatura seguinte e não uma compra.

`credit_card_invoices` **não muda**: continua somando `Invoice.Amount` por `due_date`. É o
único bloco que fala de fatura.

#### Invariantes de conciliação

Os blocos não são listas independentes: **todos os agregados de dinheiro saem da mesma base**
(recorte canônico ∩ pagas ∩ com `Category`), sem nenhum filtro extra por bloco. O contrato
garante, e a api testa:

```
sum(expense_by_category[].total) == kpis.total_expense == sum(monthly_series[].expense)
sum(monthly_series[].income)     == kpis.total_income
monthly_series[mês de `to`]      == current_month.budget.{income,expense}.realized
monthly_series[].net             == income + expense
```

Dois blocos **não** entram nessas igualdades, de propósito:

- `expense_weekday_distribution` conta **quantidade**, não dinheiro, e é a única exceção que
  aceita pendente (decisão #7).
- `credit_card_invoices` é outra lente: soma `Invoice.Amount` por `due_date`, o que inclui
  compras ainda não pagas. Uma fatura em aberto aparece aqui e **não** nos agregados de
  dinheiro — só entra quando é paga.

**Consequência para o cliente:** uma `Category` de despesa pode vir com `total` **positivo**
(estorno maior que o gasto no período). Ela permanece no array porque é ela que faz a soma
fechar — omiti-la quebraria o primeiro invariante. Quem desenha barras deve filtrar por
`total < 0` **antes** de tirar o módulo; aplicar `Math.abs` primeiro transforma o estorno numa
barra de gasto e infla o total da tela.

**A não-duplicação é garantia do recorte, não da query.** Um `Movement` que pertence a uma
`Invoice` é recusado na lista avulsa porque entra pelos itens dela. Antes, o que segurava o
double-count era um `type_payment NOT IN (credit_card, invoice_remainder)` dentro de
`MovementRepository.FindByPeriod`@api — escrito para o `Agent` (`personal-finance#167`,
mar/2026), herdado sem intenção e sem registro em documento nenhum.

**Impacto para o usuário:** os números mudam. Quem usa cartão passa a ver a despesa
itemizada nas categorias reais em vez de um bloco "Cartão de crédito", e o "Realizado" do
orçamento deixa de ser inflado pelo piso do orçado. Vale nota de release.

<details>
<summary><strong>Histórico — os três recortes que conviviam até 22/ago/2026</strong></summary>

| Bloco do payload | `internal_transfer` | `invoice_payment` | compra no `credit_card` | `invoice_remainder` |
|---|---|---|---|---|
| `monthly_series` · `kpis` | fora | **dentro** | fora (SQL) | fora (SQL) |
| `current_month.budget.realized` | fora | **dentro** | fora (SQL) | fora (SQL) |
| `expense_by_category` | fora | fora | fora (SQL) | fora (SQL) |
| `expense_weekday_distribution` | fora | **dentro** | fora (SQL) | fora (SQL) |

O que isso causava:

1. `sum(expense_by_category) ≠ kpis.total_expense` — a diferença era o total das faturas
   pagas no período. Para quem usa cartão, **a despesa do cartão não aparecia no gráfico de
   categorias**.
2. `current_month.budget.realized ≠ realized_paid` — Análises somava o `invoice_payment` na
   `Category` genérica "Cartão de crédito" e ainda aplicava o teto/piso do `Balance`. A mesma
   linha "Orçado × Realizado" mostrava valores diferentes em Análises e em Planejamentos.
3. `expense_weekday_distribution` contradizia a decisão #7: contava uma linha de
   `invoice_payment` por fatura, no dia do vencimento, no lugar das compras. Media vencimento
   de fatura, não comportamento de compra.
4. Duplicação latente: `credit_card` e `invoice_payment` coexistem no banco, os dois
   `is_paid = true` depois que a fatura é paga. Só o filtro de SQL impedia o double-count — e
   `dashboard_usecase_test.go`@api chegava a fixá-lo como esperado (`kpis.total_expense =
   −700` para um gasto real de −350), com um mock que devolvia linhas que o repositório real
   nunca devolve.

</details>

### Divergência de 24/ago/2026 — categoria positiva na tela

Com o recorte já unificado, o web ainda mostrava dois totais diferentes para a mesma coisa,
no escopo "Ano":

| Onde | Valor |
|---|---|
| KPI "Despesa total (ano)" (`kpis.total_expense`) | **−79.947,06** |
| Card "Despesas por categoria (ano)" (soma das barras) | **85.247,96** |

A investigação reproduziu os dois números em SQL, a partir da base de dinheiro descrita
acima. Não é aproximação, é identidade — e são **três defeitos empilhados**, não um.

#### 1. O cliente aplica `Math.abs` antes de filtrar

`buildCategoryRanking` (`lib/charts/category-ranking.ts`@web) faz `Math.abs(point.total)` no
`.map` e só depois `.filter(total > 0)` — que, nessa ordem, descarta apenas zeros, que a api
nem manda. É exatamente o que § Invariantes de conciliação proíbe.

Uma `Category` fechou o ano em **+2.650,45**. Somada com o sinal trocado, ela responde por
`2 × 2.650,45 = 5.300,90` — a divergência inteira:

```
79.947,06 + 5.300,90 = 85.247,96
```

**O servidor está correto:** todos os invariantes do contrato fecham no payload. O defeito é
de renderização, e vale conferir o mobile, que declara paridade de visualizações.

#### 2. O invariante não é renderizável (defeito de contrato, não de código)

Corrigir a ordem no cliente **não fecha a conta**. Com o filtro certo, o card mostraria
82.597,51 contra um KPI de 79.947,06 — ainda 2.650,45 de diferença, porque a categoria
positiva simplesmente desaparece da tela: não há barra de despesa negativa a desenhar.

Ou seja: `sum(expense_by_category[].total) == kpis.total_expense` vale no **payload** e não
tem como valer na **tela** enquanto existir categoria positiva. O contrato pedia ao cliente
uma igualdade que ele não pode honrar.

**Decisão:** o total exibido no cabeçalho do card de categorias sai de `kpis.total_expense`,
**não** da soma das barras visíveis. As barras continuam sendo só as categorias negativas, em
módulo. Quando a soma das barras não fecha com o cabeçalho, o cliente sinaliza a diferença
(categorias omitidas por terem fechado positivas) em vez de escondê-la — é a única leitura
honesta, e evita que o cabeçalho minta em silêncio. O `hiddenCount` que o web já tem serve ao
agrupamento "outras" (limite de 6 linhas) e **não** cobre este caso.

#### 3. Causa raiz: a categoria positiva não deveria existir — ver `AYD-006`

A categoria de +2.650,45 é "Sem categoria", o fallback do import de `Statement`, que tem
`is_income = false` fixo. Ela acumulou 14 entradas não categorizadas vindas de extrato
(+5.530,00), que passaram a **abater despesa**. Não era estorno: era receita classificada
como despesa.

Isso é contrato de import, não de Análises, e está registrado em `AYD-006@context`
(categoria de fallback em duas flavors + backfill).

**Consequência incômoda: hoje nenhum dos dois números da tela está certo.** Com o backfill do
`AYD-006`, a despesa correta do ano medido é **−85.477,06**. O KPI (−79.947,06) subestimava
a despesa em exatamente os 5.530,00 de entradas; o card (85.247,96) errava por outro caminho
e caía a 229,10 do valor certo **por coincidência**. Corrigido o dado, nenhuma categoria fica
positiva e os dois números coincidem em 85.477,06 — sem depender da decisão do item 2, que
segue valendo para o caso legítimo (estorno real maior que o gasto).

#### Ações

| # | Repo | Ação | Depende de |
|---|---|---|---|
| 1 | web | Filtrar `total < 0` **antes** do `Math.abs` em `buildCategoryRanking` | — |
| 2 | web | Cabeçalho do card lê `kpis.total_expense`; sinalizar categorias omitidas | 1 |
| 3 | mobile | Auditar o mesmo ponto (paridade declarada) e aplicar 1 e 2 | — |
| 4 | api | Categoria de fallback em duas flavors + backfill | `AYD-006` |
| 5 | api | `buildExpenseWeekdayDistribution` classifica por **sinal**, não por `is_income` | — |

A ação 5 é achado lateral desta investigação: `dashboard_usecase.go`@api pula
`Amount >= 0` em vez de consultar `is_income`, contra a regra geral do recorte. Efeito real
medido: um `Movement` de −713,24 numa `Category` de receita conta como despesa na
distribuição por dia da semana. Não afeta nenhum agregado de dinheiro — a distribuição conta
quantidade e já está fora dos invariantes —, mas é inconsistência com a regra declarada.

### Removido nesta revisão

`kpis` deixou de expor `avg_monthly_income`, `avg_monthly_expense`, `period_net` e
`savings_rate` — os quatro cartões de KPI (receita média, despesa média, saldo do período,
taxa de poupança) saíram da tela por decisão de produto. São **breaking changes** no payload;
como a feature ainda não chegou a produção em nenhum cliente, não há versionamento a fazer.

## Fluxo cross-repo

```mermaid
sequenceDiagram
  participant M as Mobile (AnalyticsScreen)
  participant W as Web (/analises)
  participant A as API

  M->>A: GET /v2/dashboard/summary?from&to (user_token)
  A-->>M: { monthly_series, current_month, credit_card_invoices,<br/>expense_weekday_distribution, expense_by_category, kpis }
  W->>A: GET /v2/dashboard/summary?from&to (user_token)
  A-->>W: (mesmo payload)
  Note over M,W: Cada repo só formata/desenha — nenhuma agregação no cliente.
```

## Consumidores

### Mobile (implementado)

```
AnalyticsScreen
   └─ useDashboardSummary(from, to)          (src/hooks/use-dashboard.ts)
        └─ fetchDashboardSummary             (src/lib/api/dashboard.ts → fetcher)
             └─ GET /v2/dashboard/summary
   ├─ FinancialKpiCards         ← kpis (receita total, despesa total)
   ├─ IncomeExpenseBarChart     ← monthly_series
   ├─ BudgetVsActualChart       ← current_month.budget
   ├─ CreditCardInvoicesChart   ← credit_card_invoices  (empilhado, na cor de cada cartão)
   ├─ ExpenseWeekdayChart       ← expense_weekday_distribution  (barras, eixo em %)
   └─ ExpenseByCategoryChart    ← expense_by_category  (uma barra por categoria, na cor de cada uma)
```

- Acesso: menu **Mais** (não vira nova aba — a tab bar já tem 5 itens + FAB).
- Período: início do mês, do trimestre **ou** do ano do mês selecionado → fim do mês
  selecionado, conforme um seletor Mês/Trimestre/Ano na própria tela (`MonthSelector` +
  `useMonth` + `PeriodScopeToggle`). Trimestre segue o calendário civil do mês selecionado
  (ex.: março → 1º trimestre, início em 1º de janeiro). Mesmo endpoint, mesmo contrato — o
  escopo é só a escolha de `from` no cliente, sem campo novo na resposta.
- Cache: React Query (`staleTime` 5 min, `gc` 10 min); chave inclui `from`/`to`.
- Estados: skeletons no loading; empty-state por componente.
- Gráficos: svg + d3-scale (sem dependência nova).
- **Eixo Y:** todo gráfico de barras em dinheiro (`IncomeExpenseBarChart`,
  `BudgetVsActualChart`, `CreditCardInvoicesChart`, `ExpenseByCategoryChart`) desenha eixo
  vertical com ticks rotulados em **R$**, formatados pelo locale do usuário (§ Decisões, #9).
  `ExpenseWeekdayChart` é o único com eixo em **%**.

### Web (implementado em branch)

```
/analises  (app/analises/page.tsx)
   └─ AnalyticsContent (components/analytics/analytics-content.client.tsx)
        └─ useDashboardSummary(from, to)      (hooks/use-dashboard-summary.ts, SWR)
             └─ fetchDashboardSummary          (lib/api/dashboard.ts → fetcher)
                  └─ GET /v2/dashboard/summary
   ├─ FinancialKpiCards         ← kpis
   ├─ IncomeExpenseBarChart     ← monthly_series
   ├─ ExpenseByCategoryChart    ← expense_by_category
   ├─ BudgetVsActualChart       ← current_month.budget
   ├─ CreditCardInvoicesChart   ← credit_card_invoices
   └─ ExpenseWeekdayChart       ← expense_weekday_distribution
```

- Acesso: item de primeiro nível na sidebar (`components/dashboard/dashboard-sidebar.tsx`).
- Mesmo seletor Mês/Trimestre/Ano do mobile (`lib/utils/period-scope.ts`), mesma ordem de
  visualizações, mesmas regras de cor e de ranking (`lib/charts/`).
- Cache: SWR, chave em `lib/api/cache-keys.ts` incluindo `from`/`to`.
- Gráficos: `recharts` (já era dependência do repo), conforme decisão #6.

Detalhes em `SPEC-002@web`. Falta o merge em `develop`.

## Decisões de design

| # | Decisão | Por quê |
|---|---|---|
| 1 | Endpoint agregador no backend | Menos payload e zero lógica de agregação duplicada nos clientes |
| 2 | Realizado = `Movement`s pagos | Consistência com a semântica de "realizado" do `Balance`. Quais `Movement`s são esses vem do recorte canônico de `AYD-005` — ver § Recorte de "realizado" |
| 3 | Mobile acessa via menu **Mais** | Tab bar já tem 5 itens + FAB |
| 4 | Web ganharia item de sidebar de primeiro nível | Sem a restrição de espaço do mobile |
| 5 | Realizado do orçamento filtrado ao mês de `to` | Período é multi-mês (≠ `Balance`); evita somar o período inteiro |
| 6 | Cada cliente usa sua lib de gráfico já existente (mobile: svg+d3-scale; web: recharts) | O contrato é o mesmo; a renderização não precisa ser |
| 7 | Distribuição por dia da semana conta **todas** as despesas do período (pagas **e** pendentes), excluindo `internal_transfer` | Mede **comportamento de compra**, não caixa realizado. Compra no cartão fica `is_paid: false` até a `Invoice` ser paga — filtrar por pago apagaria justamente as compras de cartão e distorceria o gráfico. `InternalTransfer` é movimento entre `Wallet`s do próprio usuário, não compra (ver GLO). Desde 22/ago/2026 as compras no cartão de fato chegam ao gráfico, pelos itens da `Invoice`; o `invoice_remainder` fica fora, por não ser compra — ver § Recorte de "realizado" |
| 8 | `Invoice` entra no mês do seu `due_date` | É a convenção que a api já usa (`InvoiceRepository.FindByMonth` filtra por `due_date`); "fatura de agosto" = a que vence em agosto |
| 9 | Eixo Y rotulado em R$ nos gráficos de dinheiro | Sem escala, a barra só dá ordem relativa; o usuário pediu leitura de valor absoluto direto do gráfico |
| 10 | `by_card[]` sempre completo (com zeros) | Empilhamento estável: cor/ordem do cartão não muda de mês para mês |
| 11 | A cor do cartão viaja no contrato (`cards[].color`), e não é buscada à parte pelo cliente | O gráfico fica com a cor que o usuário já reconhece do cartão. Custa zero: o repositório de `Invoice` já faz `Preload("CreditCard")`. A alternativa — o cliente buscar os cartões num segundo request e cruzar por id — traria duas fontes para o mesmo dado, um round-trip extra e o risco de não achar cartão excluído no meio do período. **A api não inventa cor:** se não houver, manda vazio, e o fallback (paleta do app) é decisão de apresentação de cada cliente |
| 12 | `expense_by_category` soma o período inteiro (não é série mensal) e omite categoria sem despesa paga, ao invés de zero-preencher como `by_card` | Não há eixo de meses a manter estável aqui — é uma barra por categoria, não uma pilha que precisa de posição/cor consistente mês a mês. Zero-preencher só infiltraria categorias vazias sem ganho nenhum. Segue a regra geral de "realizado" (pagos, decisão #2) e exclui `internal_transfer`, mesma exclusão da decisão #7, para não herdar a lacuna aberta do `GetExpenseMovements` |
| 13 | Alternância Mês/Trimestre/Ano é um seletor de `from` no cliente, não um parâmetro novo no contrato | O endpoint já é genérico em período — qualquer `from`/`to` válido funciona. Adicionar um `scope=month\|quarter\|year` na api replicaria no backend uma regra (mapear mês → início do mês/trimestre/ano) que o cliente já precisa saber para desenhar o seletor, e criaria dois jeitos de pedir o mesmo dado. Trimestre é sempre calculado a partir do mês selecionado (não do mês corrente do relógio) — março pertence ao 1º trimestre mesmo se hoje for agosto. O escopo "Mês" foi adicionado depois de Ano/Trimestre pela mesma razão: é só mais um valor de `from`, não uma nova capacidade da api |

## Decisões relacionadas

Nenhum `ADR`/`PDR` aplicável — não há mudança de topologia (nenhum serviço/integração novo)
nem decisão de produto formal registrada.

## Fora de escopo / questões em aberto

- [x] **SPEC-002@web + implementação web** — escritos em 20/ago/2026; falta só o merge em
      `develop`.
- [x] **`GetExpenseMovements` inclui `internal_transfer`** — resolvido em
      `personal-finance#224` e `#226`: `monthly_series` e `current_month` passaram por
      `GetOperationalMovements` e `expense_by_category` ganhou também o filtro pelos
      `category_id` de transferência interna.
- [x] **Unificar o recorte de "realizado" com o canônico de `AYD-005`** — decidido pelo owner
      e implementado em 22/ago/2026 (`personal-finance#227`); ver
      [§ Recorte de "realizado"](#recorte-de-realizado).
- [ ] **`AYD-005` diz "no mês da compra" para o item de cartão** — o servidor conta no mês do
      `due_date` da `Invoice`, tanto no summary de planejamentos quanto aqui. A regra vigente
      é a do `due_date` (é o que fecha `sum(monthly_series) == kpis`); corrigir o texto de
      `AYD-005`, ou mudar a regra nos dois, é uma edição à parte naquele AYD.
- [ ] **Colisão de ID `SPEC-002@api`** — o repo api tem dois docs com `id: SPEC-002`
      (`docs/specs/SPEC-002-financial-analytics.md`, filho deste AYD, e
      `docs/specs/SPEC-002-estimate-summary.md`, filho de `AYD-005`). IDs são globais no
      produto (`conventions.md` §3), então a referência `SPEC-002@api` é ambígua nos
      `children` dos dois AYDs. Renumerar um dos dois é correção de doc, à parte.
- [ ] **Aplicar as ações da divergência de 24/ago/2026** — web (ordem do `Math.abs` e
      cabeçalho vindo do KPI), mobile (mesma auditoria) e api (classificação por sinal na
      distribuição por dia da semana). Ver
      [§ Divergência de 24/ago/2026](#divergência-de-24ago2026--categoria-positiva-na-tela).
      A causa raiz é tratada à parte, em `AYD-006`.
- [ ] **Top categorias no tempo, fixo×variável, projeção de fluxo de caixa** — extensões
      futuras do mesmo endpoint/contrato, fora do MVP.
- [ ] **Agrupar categorias pequenas em "Outros" em `expense_by_category`** — não implementado
      nesta versão; usuário com muitas categorias no período vê uma barra por categoria, sem
      limite.
