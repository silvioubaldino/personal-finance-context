---
id: AYD-003
type: design
title: Análises financeiras (visão ao longo do tempo)
status: draft
created: 2026-06-25
updated: 2026-06-26
owner: Silvio Ubaldino
affects: [api, web, mobile]
parents: [REQ-001]
children: []
related: [GLO]
tags: [analytics, dashboard]
superseded_by: null
---

# AYD-003: Análises financeiras (visão ao longo do tempo)

> **Nota de status:** esta feature está em design — nenhuma `SPEC` foi escrita ainda em
> nenhum repo, e nenhum dos três repos tem código desta feature na branch de trabalho
> atual. O desenho de **api** e **mobile** veio de uma sessão de design já detalhada
> (incluindo um mapa de arquivos planejado); o papel do **web** foi adicionado nesta
> revisão e é só um esqueleto — sem rota, nome de menu ou componentes definidos. Ao
> implementar, abra a SPEC/PLAN no repo correspondente; este AYD fixa o contrato e os
> papéis, não a lista de arquivos.

## Objetivo

Hoje a Dashboard mostra só o mês corrente. Esta feature adiciona uma tela de
**Análises** que dá ao usuário uma visão financeira **ao longo do tempo**, com três
visualizações a partir de um único endpoint agregador no backend:

1. **Renda vs Despesa** — série mensal (barras pareadas) ao longo do período.
2. **Orçado vs Realizado** — comparativo do mês selecionado (reusa `Estimate`).
3. **KPIs** — taxa de poupança, saldo do período e médias mensais de renda/despesa.

"Realizado" = `Movement`s **pagos** (mesma semântica do `Balance`). Despesas mantêm
sinal **negativo** em todo o fluxo, nos três repos.

## Repos afetados e papéis

| Repo | Papel nesta feature | Status do desenho | SPEC gerada |
|------|---------------------|--------------------|-------------|
| api | Agrega `Movement`s e `Estimate`s existentes (sem nova tabela/migração) num único endpoint por período; aplica isolamento por `user_id` | Detalhado (feature clean-arch `dashboard`: domain → usecase → infra/api → bootstrap) | nenhuma ainda |
| mobile | Consome o contrato; tela "Análises" acessada pelo menu **Mais**; só formata/desenha o que a api devolve, sem agregação no cliente | Detalhado | nenhuma ainda |
| web | Consome o **mesmo contrato**; tela equivalente como item de primeiro nível na sidebar (sem a restrição de espaço do mobile) | Esqueleto — proposto nesta revisão, sem desenho fino | nenhuma ainda |

> `children` fica vazio: nenhuma SPEC formal foi escrita ainda em nenhum repo.

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
  "kpis": {
    "total_income": 30000, "total_expense": -19200,
    "avg_monthly_income": 5000, "avg_monthly_expense": -3200,
    "period_net": 10800, "savings_rate": 0.36
  }
}
```

Semântica:

| Campo | Regra |
|---|---|
| `monthly_series[]` | 1 entrada por mês do span (meses sem `Movement` vêm zerados → eixo contínuo). `income`/`expense` = soma de pagos; `net = income + expense` |
| `current_month.budget` | mês de `to`. `budgeted` vem do `Estimate`; `realized` = pagos do mês (reusa lógica teto/piso do `Balance`) |
| `kpis.avg_*` | total ÷ nº de meses do período |
| `kpis.savings_rate` | `period_net / total_income` (**0** quando `total_income ≤ 0`) |
| sinais | despesas sempre **negativas** |

Erros: `from`/`to` em formato inválido ou período inválido (`period.Validate()`) →
`400` (`WrapInvalidInput`); falha de repositório → `500`.

Este mesmo contrato serve **api → mobile** e **api → web**; nenhum repo redefine campo
ou semântica localmente (regra de linkagem, `conventions.md` §5).

## Fluxo cross-repo

```mermaid
sequenceDiagram
  participant M as Mobile (AnalyticsScreen)
  participant W as Web (página Análises)
  participant A as API

  M->>A: GET /v2/dashboard/summary?from&to (user_token)
  A-->>M: { monthly_series, current_month, kpis }
  W->>A: GET /v2/dashboard/summary?from&to (user_token)
  A-->>W: { monthly_series, current_month, kpis }
  Note over M,W: Mesmo payload; cada repo só formata/desenha — nenhuma agregação no cliente.
```

## Consumidores

### Mobile (detalhado)

```
AnalyticsScreen
   └─ useDashboardSummary(from, to)          (src/hooks/use-dashboard.ts)
        └─ fetchDashboardSummary             (src/lib/api/dashboard.ts → fetcher)
             └─ GET /v2/dashboard/summary
   ├─ FinancialKpiCards        ← kpis
   ├─ IncomeExpenseBarChart    ← monthly_series
   └─ BudgetVsActualChart      ← current_month.budget
```

- Acesso: menu **Mais** (não vira nova aba — a tab bar já tem 5 itens + FAB).
- Período: 1º de janeiro → fim do mês selecionado (via `MonthSelector` + contexto `useMonth`).
- Cache: React Query (`staleTime` 5 min, `gc` 10 min); chave inclui `from`/`to`.
- Estados: skeletons no loading; empty-state por componente; despesa usa valor absoluto
  para altura da barra.
- Gráficos: svg + d3-scale (já no projeto, sem nova dependência).

### Web (esqueleto — a detalhar na SPEC@web)

```
Página Análises (rota a definir)
   └─ useDashboardSummary(from, to)          (hooks/use-dashboard.ts, SWR)
        └─ fetchDashboardSummary             (lib/api/dashboard.ts → fetcher)
             └─ GET /v2/dashboard/summary
   ├─ FinancialKpiCards
   ├─ IncomeExpenseBarChart
   └─ BudgetVsActualChart
```

- Acesso: item de primeiro nível na sidebar (`components/dashboard/dashboard-sidebar.tsx`)
  — web não tem a restrição de espaço do mobile (tab bar + FAB), então não precisa ficar
  atrás de um menu "Mais" equivalente.
- Cache: SWR (padrão do repo, `lib/api/cache-keys.ts`), seguindo o mesmo padrão dos
  outros domínios (`movements.ts`, `wallets.ts`...).
- Gráficos: `recharts` (já é dependência do projeto); sem nova lib.
- Esta seção é um esqueleto de design, não um contrato fechado: nome de rota, label do
  item de menu e componentes finais ficam para a SPEC@web.

## Decisões de design

| # | Decisão | Por quê |
|---|---|---|
| 1 | Endpoint agregador no backend | Menos payload e zero lógica de agregação duplicada nos clientes (mobile e web) |
| 2 | Realizado = `Movement`s pagos | Consistência com a semântica de "realizado" do `Balance` |
| 3 | Mobile acessa via menu **Mais** | Tab bar já tem 5 itens + FAB |
| 4 | Web ganha item de sidebar de primeiro nível | Sem a restrição de espaço do mobile |
| 5 | Realizado do orçamento filtrado ao mês de `to` | Período é multi-mês (≠ `Balance`); evita somar o período inteiro |
| 6 | Cada cliente usa sua própria lib de gráfico já existente (mobile: svg+d3-scale; web: recharts) | Reaproveita o que já está instalado em cada repo; o contrato é o mesmo, a renderização não precisa ser |

## Decisões relacionadas

Nenhum `ADR`/`PDR` aplicável ainda — não há mudança de topologia (nenhum
serviço/integração novo) nem decisão de produto formal envolvida.

## Fora de escopo / questões em aberto

- [ ] **SPEC@api** — escrever a partir deste AYD antes de implementar (`domain → usecase
      → infra/api → bootstrap` da feature `dashboard`).
- [ ] **SPEC@mobile** — formalizar o desenho já detalhado aqui (telas, hooks, componentes).
- [ ] **SPEC@web** — o esqueleto acima ainda não tem rota, label de menu nem componentes
      detalhados; é o próximo passo antes de implementar no web.
- [ ] **Top categorias no tempo, fixo×variável, projeção de fluxo de caixa** — extensões
      futuras do mesmo endpoint/contrato, fora do MVP.
