---
id: AYD-003
type: design
title: Análises financeiras (visão ao longo do tempo)
status: draft
created: 2026-06-25
updated: 2026-08-22
owner: Silvio Ubaldino
affects: [api, web, mobile]
parents: [REQ-001]
children: [SPEC-002@api, SPEC-002@mobile, SPEC-002@web]
related: [AYD-005, GLO]
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
> **Divergência aberta:** o recorte de `type_payment` que alimenta os agregados de dinheiro
> **não está fechado** e discorda do recorte canônico de `AYD-005` — ver
> [§ Recorte de "realizado"](#recorte-de-realizado-divergência-aberta). O contrato (campos,
> tipos, formato) está estável; o que está em aberto é *quais `Movement`s* cada campo soma.

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
> implementação no servidor, não duas parecidas — hoje **não leem**, ver
> [§ Recorte de "realizado"](#recorte-de-realizado-divergência-aberta).

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

### Recorte de "realizado" (divergência aberta)

A tabela acima diz *de onde* cada número vem, mas não dizia **quais `type_payment` entram**.
Essa omissão escondia três recortes diferentes dentro da **mesma resposta**. Levantamento de
22/ago/2026 sobre `internal/usecase/dashboard_usecase.go`@api e
`internal/infrastructure/repository/movement_repository.go:107`@api:

| Bloco do payload | `internal_transfer` | `invoice_payment` | compra no `credit_card` | `invoice_remainder` |
|---|---|---|---|---|
| `monthly_series` · `kpis` | fora (`GetOperationalMovements`) | **dentro** | fora (SQL) | fora (SQL) |
| `current_month.budget.realized` | fora | **dentro** | fora (SQL) | fora (SQL) |
| `expense_by_category` | fora (+ por `category_id`) | fora | fora (SQL) | fora (SQL) |
| `expense_weekday_distribution` | fora | **dentro** | fora (SQL) | fora (SQL) |
| **Recorte canônico (`AYD-005`)** | **fora** | **fora** | **dentro**, via itens da `Invoice` | **dentro**, via itens da `Invoice` |

O "fora (SQL)" não é escolha desta feature: `MovementRepository.FindByPeriod` já nasceu
com `type_payment NOT IN (credit_card, invoice_remainder)` para o `Agent`
(`personal-finance#167`, mar/2026) e o dashboard herdou o método. **Nenhum documento
registrava isso** — nem este AYD, nem `SPEC-002@api`.

Consequências hoje, em produção:

1. **`sum(expense_by_category) ≠ kpis.total_expense`.** A diferença é exatamente o total das
   faturas pagas no período: o KPI conta o `invoice_payment`, o gráfico de categorias não —
   e as compras no cartão, que seriam a contraparte itemizada, nunca chegam ao usecase.
   Para quem usa cartão, **a despesa do cartão simplesmente não aparece no gráfico de
   categorias**.
2. **`current_month.budget.realized` ≠ `realized_paid` de `GET /v2/estimate/summary`.**
   `AYD-005` fixa que os dois são o mesmo número; hoje o de Análises soma o `invoice_payment`
   (na `Category` genérica "Cartão de crédito") em vez das compras nas categorias reais, e
   ainda passa pelo teto/piso do `Balance` (`getBalanceSum`), que o recorte canônico não tem.
   A mesma linha "Orçado × Realizado" mostra valores diferentes em Análises e em
   Planejamentos.
3. **`expense_weekday_distribution` contradiz a decisão #7.** A decisão justifica contar
   pendentes *para não perder as compras no cartão* — mas elas são filtradas no SQL antes de
   chegar lá. O que o gráfico conta, no lugar delas, é **uma linha de `invoice_payment` por
   fatura**, no dia do pagamento/vencimento. O gráfico mede vencimento de fatura, não
   comportamento de compra.
4. **Risco latente de duplicação.** `credit_card` e `invoice_payment` coexistem no banco, os
   dois `is_paid = true` depois que a fatura é paga (`invoice_usecase.go`: `PayByInvoiceID`
   marca as compras **e** `buildMovementWithAmount` cria o pagamento). Só o filtro SQL impede
   o double-count. `internal/usecase/dashboard_usecase_test.go:479`@api chega a fixar esse
   double-count como esperado: com `credit_card −300`, `invoice_remainder −50` e
   `invoice_payment −350` na entrada, o teste espera `kpis.total_expense = −700` — o dobro
   dos −350 reais. O mock devolve linhas que o repositório real nunca devolve, então o teste
   documenta um comportamento que não existe e protege o errado.

**Direção proposta (pendente de decisão do owner):** os agregados de dinheiro desta tela
passam a ler o **recorte canônico de `AYD-005`** — fora `internal_transfer` e
`invoice_payment`, dentro as compras no `credit_card` e o `invoice_remainder` via itens da
`Invoice` — reusando a mesma implementação de servidor (`realized_paid`), não uma parecida.
`expense_weekday_distribution` segue com pagas **e** pendentes (decisão #7), mas sobre esse
mesmo conjunto, que é o que finalmente entrega as compras no cartão prometidas pela decisão.
`credit_card_invoices` **não muda**: continua somando `Invoice.Amount` por `due_date`, e é o
único bloco que deve falar de fatura.

Isso muda números que o usuário já vê — mesmo risco que `AYD-005` registra ("vai parecer que
sumiu dinheiro"). Vale nota de release e virada de mês, e vale fazer junto com a Fase 2 de
`AYD-005`, não antes: é a fase que cria o cálculo canônico único.

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
| 2 | Realizado = `Movement`s pagos | Consistência com a semântica de "realizado" do `Balance`. **O recorte de `type_payment` por trás disso está em aberto** — ver § Recorte de "realizado" |
| 3 | Mobile acessa via menu **Mais** | Tab bar já tem 5 itens + FAB |
| 4 | Web ganharia item de sidebar de primeiro nível | Sem a restrição de espaço do mobile |
| 5 | Realizado do orçamento filtrado ao mês de `to` | Período é multi-mês (≠ `Balance`); evita somar o período inteiro |
| 6 | Cada cliente usa sua lib de gráfico já existente (mobile: svg+d3-scale; web: recharts) | O contrato é o mesmo; a renderização não precisa ser |
| 7 | Distribuição por dia da semana conta **todas** as despesas do período (pagas **e** pendentes), excluindo `internal_transfer` | Mede **comportamento de compra**, não caixa realizado. Compra no cartão fica `is_paid: false` até a `Invoice` ser paga — filtrar por pago apagaria justamente as compras de cartão e distorceria o gráfico. `InternalTransfer` é movimento entre `Wallet`s do próprio usuário, não compra (ver GLO). **A implementação não cumpre a decisão:** as compras no cartão são filtradas antes, no repositório — ver § Recorte de "realizado", consequência 3 |
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
- [ ] **Unificar o recorte de "realizado" com o canônico de `AYD-005`** — decisão do owner
      pendente; ver [§ Recorte de "realizado"](#recorte-de-realizado-divergência-aberta).
      Enquanto não for tomada, `sum(expense_by_category) ≠ kpis.total_expense` para quem usa
      cartão, e `current_month.budget.realized` diverge de `realized_paid`.
- [ ] **Colisão de ID `SPEC-002@api`** — o repo api tem dois docs com `id: SPEC-002`
      (`docs/specs/SPEC-002-financial-analytics.md`, filho deste AYD, e
      `docs/specs/SPEC-002-estimate-summary.md`, filho de `AYD-005`). IDs são globais no
      produto (`conventions.md` §3), então a referência `SPEC-002@api` é ambígua nos
      `children` dos dois AYDs. Renumerar um dos dois é correção de doc, à parte.
- [ ] **Top categorias no tempo, fixo×variável, projeção de fluxo de caixa** — extensões
      futuras do mesmo endpoint/contrato, fora do MVP.
- [ ] **Agrupar categorias pequenas em "Outros" em `expense_by_category`** — não implementado
      nesta versão; usuário com muitas categorias no período vê uma barra por categoria, sem
      limite.
