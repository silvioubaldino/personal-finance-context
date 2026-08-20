---
id: AYD-005
type: design
title: Transferência interna entre carteiras
status: draft
created: 2026-08-20
updated: 2026-08-20
owner: Silvio Ubaldino
affects: [api, web, mobile]
parents: [REQ-001]
children: [SPEC-003@mobile]
related: [AYD-003, GLO]
tags: [wallet, movement, internal-transfer]
superseded_by: null
---

# AYD-005: Transferência interna entre carteiras

> **Nota de status:** feature **parcialmente implementada e não concluída**. A api já tem os
> cinco endpoints do par (`POST`/`PUT`/`DELETE`/`pay`/`revert-pay`), a migração e o
> `TypePayment`, com o par sempre operado como unidade (decisão #12); o web tem cliente
> HTTP, hook e o formulário inteiro — mas **nenhum botão liga o modo transferência**, então a
> feature é inalcançável pelo usuário. O mobile tem só o hook. Além disso, várias métricas de
> despesa ainda **contam** a transferência, que é justamente o que a feature existe para
> evitar. Este AYD formaliza o contrato já existente e fecha as lacunas que faltam para
> concluir.

## Objetivo

Permitir que o usuário registre a movimentação de dinheiro **entre duas `Wallet`s suas** sem
que isso apareça como receita ou despesa. O dinheiro não saiu do patrimônio do usuário —
mudou de lugar.

Regras de produto:

1. Em **uma única request**, o usuário informa origem, destino, valor e data; o sistema cria
   **duas `Movement`s** — uma de saída (valor negativo) na origem e uma de entrada (valor
   positivo) no destino — ligadas por um `pair_id`.
2. As duas movimentações carregam o `TypePayment` **`internal_transfer`**.
3. Elas **aparecem na lista de transações** (o usuário precisa ver que o dinheiro se moveu).
4. Elas **não aparecem** em nenhum gráfico, KPI, total ou comparativo de **receita/despesa**.
5. Quando `is_paid: true`, o `Balance` das duas `Wallet`s é ajustado na mesma transação de
   banco.

Ver `GLO` → **InternalTransfer**: não é entidade própria, é um par de `Movement`s.

## Repos afetados e papéis

| Repo | Papel nesta feature | Estado |
|------|---------------------|--------|
| api | Dona do contrato. Cria/atualiza/apaga/liquida o par transacionalmente (sempre como unidade), ajusta `Balance`, e **exclui** `internal_transfer` de toda agregação de receita/despesa | **Parcial** — os cinco endpoints do par estão prontos e mapeados para os HTTP corretos; exclusão das métricas ainda incompleta |
| web | Formulário de transferência (origem/destino/valor/data/pago) + exibição na lista | **Parcial** — todo o código existe, mas o modo transferência é inalcançável na UI |
| mobile | Mesmo formulário e mesma exclusão de métricas | **Parcial** — só `useCreateTransfer`; sem UI de criação |

## Contrato (fonte da verdade)

O par (`pair_id`) é sempre operado como unidade — nunca existe operação por
`movement_id` isolado numa perna de `internal_transfer` (decisão #12). As cinco rotas
abaixo cobrem o ciclo de vida completo do par: criar, atualizar, apagar, liquidar e
reverter liquidação.

### Criar

```
POST /v2/transfers/
Auth: Firebase (header user_token)
```

Request:
```json
{
  "origin_wallet_id": "0f1c…",
  "destination_wallet_id": "7ab2…",
  "amount": 250.00,
  "date": "2026-08-20",
  "description": "reserva de emergência",
  "is_paid": true
}
```

| Campo | Tipo | Obrigatório | Regra |
|---|---|---|---|
| `origin_wallet_id` | uuid | sim | `Wallet` do usuário; **diferente** de `destination_wallet_id` |
| `destination_wallet_id` | uuid | sim | `Wallet` do usuário |
| `amount` | number | sim | Sempre **positivo**. O sinal é derivado pela api (saída negativa, entrada positiva) |
| `date` | date (`2006-01-02`) | sim | Mesma data para as duas pernas |
| `description` | string | não | Complemento; a api sempre prefixa `"Transferência de {origem} para {destino}"` |
| `is_paid` | bool | não (default `false`) | `true` ⇒ ajusta o `Balance` das duas `Wallet`s |

Response (`201`):
```json
{
  "pair_id": "9c3a…",
  "origin_movement":      { "id": "…", "amount": -250.00, "pair_id": "9c3a…", "type_payment": "internal_transfer", "wallet_id": "0f1c…", "category_id": "c1a2b3c4-…" },
  "destination_movement": { "id": "…", "amount":  250.00, "pair_id": "9c3a…", "type_payment": "internal_transfer", "wallet_id": "7ab2…", "category_id": "c2b3c4d5-…" }
}
```

`origin_movement` e `destination_movement` são `MovementOutput` completos (mesmo shape do
`GET /v2/movements/`), aqui abreviados nos campos que a transferência define.

Categorias fixas (seed, `user_id = default_category_id`, migração `010`):

| Papel | ID | Descrição | `is_income` |
|---|---|---|---|
| Saída | `c1a2b3c4-d5e6-f7a8-b9c0-d1e2f3a4b5c6` | Transferência interna - saída | `false` |
| Entrada | `c2b3c4d5-e6f7-a8b9-c0d1-e2f3a4b5c6d7` | Transferência interna - entrada | `true` |

### Atualizar

```
PUT /v2/transfers/{pair_id}
Auth: Firebase (header user_token)
```

Substitui as duas pernas do par por um novo `origin_wallet_id`/`destination_wallet_id`/
`amount`/`date`/`description` — mesmo shape de campos do `POST`, sem `is_paid` (o estado de
pagamento não muda por aqui; ver `pay`/`revert-pay`). Se o par já estava pago
(`is_paid: true`), os dois `Balance`s são recalculados atomicamente na mesma transação:
reverte o efeito das pernas antigas e aplica o das novas, com um único write líquido por
carteira mesmo quando a mesma carteira aparece nos dois lados (ex.: só o valor mudou) — ver
`walletBalanceChanges` na seção "Consumidores" abaixo. Se o par estava agendado
(`is_paid: false`), só as pernas são atualizadas; nenhum saldo se move.

Response (`200`): mesmo shape do `POST`.

### Apagar

```
DELETE /v2/transfers/{pair_id}
Auth: Firebase (header user_token)
```

Remove as duas pernas do par. Se estava pago, reverte o efeito nas duas carteiras
atomicamente antes de apagar. Response (`204`, sem corpo).

### Liquidar (`pay`)

```
POST /v2/transfers/{pair_id}/pay
Auth: Firebase (header user_token)
```

Marca as duas pernas como `is_paid: true` e move o `Balance` das duas carteiras
atomicamente (débito na origem, crédito no destino). Sem corpo de request. Response
(`200`): mesmo shape do `POST`, com `is_paid: true` nas duas pernas.

### Reverter liquidação (`revert-pay`)

```
POST /v2/transfers/{pair_id}/revert-pay
Auth: Firebase (header user_token)
```

Marca as duas pernas como `is_paid: false` e desfaz o movimento de saldo nas duas
carteiras atomicamente (estorna o crédito no destino e o débito na origem). Sem corpo de
request. Response (`200`): mesmo shape do `POST`, com `is_paid: false` nas duas pernas.

### Erros

| Situação | Endpoints | Sentinel (api) | HTTP |
|---|---|---|---|
| JSON/data inválidos | criar, atualizar | `domain.ErrInvalidInput` | `400` |
| `pair_id` não é UUID válido | atualizar, apagar, pay, revert-pay | `domain.ErrInvalidInput` | `400` |
| Origem == destino | criar, atualizar | `ErrSameWalletTransfer` | `400` |
| `amount <= 0` | criar, atualizar | `ErrInvalidTransferAmount` | `400` |
| Data ausente | criar, atualizar | `ErrDateRequired` | `400` |
| Tentativa de operar uma perna isolada via `/v2/movements/{id}/...` | pay, revert-pay (e update/delete legado) | `ErrTransferMustUsePairEndpoint` | `400` |
| `Wallet` inexistente | criar, atualizar | `ErrWalletNotFound` | `404` |
| `pair_id` não encontrado (ou pertence a outro usuário) | atualizar, apagar, pay, revert-pay | `ErrTransferPairNotFound` | `404` |
| Par incompleto (≠ 2 pernas) ou pernas não são `internal_transfer` | atualizar, apagar, pay, revert-pay | `ErrTransferPairMismatch` | `400` |
| `pay` chamado com o par já `is_paid: true` | pay | `ErrMovementAlreadyPaid` | `409` |
| `revert-pay` chamado com o par `is_paid: false` | revert-pay | `ErrMovementNotPaid` | `409` |
| Pernas do par com `is_paid` divergente (corrupção de dados) | pay, revert-pay | `ErrTransferPairInconsistentPayment` | `409` |
| Saldo insuficiente na origem (criar/atualizar com `is_paid`, ou `pay`) | criar, atualizar, pay | `ErrInsufficientBalance` | `422` |
| Saldo insuficiente no destino (o que foi transferido já foi gasto) | revert-pay | `ErrInsufficientBalance` | `422` |
| Falha de repositório | todos | — | `500` |

Este contrato serve **api → web** e **api → mobile**; nenhum cliente redefine campo ou
semântica (`conventions.md` §5).

## Semântica nas métricas (o coração da feature)

Regra geral: **todo agregado de receita/despesa exclui `type_payment = internal_transfer`**;
**toda listagem de transações inclui**.

| Superfície | Regra | Estado |
|---|---|---|
| `GET /v2/movements/` (lista) | **Inclui** as duas pernas, com `pair_id` | ✔ |
| `expense_weekday_distribution` (AYD-003) | Exclui | ✔ |
| `expense_by_category` (AYD-003) | Exclui (por `type_payment` **e** pelos dois `category_id` fixos) | ✔ |
| `monthly_series` (AYD-003) | Exclui | **✘ inclui** |
| `kpis.total_income` / `total_expense` (AYD-003) | Exclui | **✘ inclui** |
| `current_month.budget.realized` (AYD-003) | Exclui | **✘ inclui** |
| `GET /balances/period` (legado) | Exclui | **✘ inclui** |
| `GET /balance/estimate/period` (Planejamento) | Exclui | **✘ inclui** |
| Agente IA (`agent_financial_repository`) | Exclui | ✔ |
| Web — gráfico de despesas por categoria | Exclui | ✔ |
| Web — Planejamento (`use-estimate-with-movements`) | Exclui | **✘ inclui** |
| Web/mobile — lista de transações | Inclui, rotulada "Transferência Interna" | ✔ |
| Mobile — `movements-view` e `PlanningScreen` | Exclui | ✔ |

A causa raiz dos itens ✘ na api é `MovementList.GetExpenseMovements()` /
`GetIncomeMovements()`, que filtram **só por sinal do `amount`** — já registrado como questão
em aberto no `AYD-003`. Este AYD assume essa correção.

## Fluxo cross-repo

```mermaid
sequenceDiagram
  participant U as Usuário
  participant C as Cliente (web/mobile)
  participant A as API
  participant D as Postgres

  U->>C: escolhe "Transferência", origem, destino, valor, data
  C->>A: POST /v2/transfers/ (user_token)
  A->>A: valida (origem≠destino, amount>0, data, saldo se is_paid)
  A->>D: BEGIN
  A->>D: INSERT movement saída  (-amount, wallet origem,  pair_id, internal_transfer)
  A->>D: INSERT movement entrada (+amount, wallet destino, pair_id, internal_transfer)
  alt is_paid
    A->>D: UPDATE balance origem / destino
  end
  A->>D: COMMIT
  A-->>C: 201 { pair_id, origin_movement, destination_movement }
  C->>C: invalida cache de movimentações do período + carteiras
  Note over C: as duas pernas entram na LISTA; ficam fora de gráficos e KPIs de despesa
```

## Consumidores

### API (parcial)

```
POST /v2/transfers/
  └─ api.TransferHandler.Add          (internal/infrastructure/api/transfer_api.go)
       └─ usecase.Transfer.Execute    (internal/usecase/transfer_usecase.go)
            ├─ WalletRepository.FindByID  (origem, destino)
            ├─ txManager.WithTransaction
            │    ├─ MovementRepository.Add ×2  (pair_id, internal_transfer)
            │    └─ WalletRepository.UpdateAmount ×2  (só se is_paid)
            └─ domain.TypePaymentInternalTransfer + categorias fixas
                                        (internal/domain/typepayment.go)

PUT /v2/transfers/{pair_id}
  └─ api.TransferHandler.Update       (internal/infrastructure/api/transfer_api.go)
       └─ usecase.UpdateTransfer.Execute  (internal/usecase/update_transfer_usecase.go)
            ├─ MovementRepository.FindByPairID → identifyTransferPair (internal/usecase/transfer_pair.go)
            ├─ txManager.WithTransaction
            │    ├─ walletBalanceChanges  (acumula deltas em memória; 1 read + 1 write por
            │    │    carteira mesmo quando a mesma carteira aparece nos dois lados — evita
            │    │    o bug de write duplicado corrigido nesta rodada)
            │    └─ MovementRepository.Update ×2
            └─ só recalcula saldo se o par já estava `is_paid`

DELETE /v2/transfers/{pair_id}
  └─ api.TransferHandler.Delete       (internal/infrastructure/api/transfer_api.go)
       └─ usecase.DeleteTransfer.Execute  (internal/usecase/delete_transfer_usecase.go)
            ├─ MovementRepository.FindByPairID → identifyTransferPair
            └─ txManager.WithTransaction
                 ├─ WalletRepository.UpdateAmount ×2  (só se estava is_paid; reverte)
                 └─ MovementRepository.Delete ×2

POST /v2/transfers/{pair_id}/pay
POST /v2/transfers/{pair_id}/revert-pay
  └─ api.TransferHandler.Pay / RevertPay  (internal/infrastructure/api/transfer_api.go)
       └─ usecase.PayTransfer.Execute / Revert  (internal/usecase/pay_transfer_usecase.go)
            ├─ MovementRepository.FindByPairID → identifyTransferPair
            ├─ valida is_paid consistente nas duas pernas (senão ErrTransferPairInconsistentPayment)
            ├─ valida saldo na carteira certa por direção
            │    (pay → origem; revert-pay → destino, decisão #13)
            └─ txManager.WithTransaction
                 ├─ walletBalanceChanges  (1 write líquido por carteira)
                 └─ MovementRepository.UpdateIsPaid ×2
```

Wiring: `internal/bootstrap/transfer/setup.go`, chamado por `SetupCleanArchComponents`.
Persistência: migração `010_add_internal_transfer` (coluna `movements.pair_id` + índice +
seed das duas categorias). Sem tabela nova.

`internal/usecase/movement_usecase.go` (`payMovement`/`RevertPay`) e o serviço legado
(`internal/domain/movement/service/movement.go`) rejeitam com `ErrTransferMustUsePairEndpoint`
qualquer tentativa de pagar/reverter uma perna de `internal_transfer` via
`/v2/movements/{id}/pay` — só os endpoints acima operam o par.

### Web (formulário pronto, porta fechada)

```
AddMovementButton
  └─ MovementFormModal            (isTransferMode, origem/destino/valor/data/pago)
       └─ onSaveTransfer → useCreateTransfer → createTransfer → POST /v2/transfers/
```

`isTransferMode` existe, o formulário inteiro (§ `MovementFormModal`, seleção de origem e
destino, validação própria) está escrito, o handler e o toast de sucesso/erro estão no
`AddMovementButton` — mas o seletor de modo do topo do modal só tem **Despesa / Receita /
Cartão / Importar**. Nada nunca chama `setIsTransferMode(true)`: **código morto**.

### Mobile (só o cliente HTTP)

`src/hooks/use-transfers.ts` e `src/lib/api/transfers.ts` existem e ninguém os chama.
`MovementModal` conhece o rótulo `internal_transfer` mas não oferece o modo. As exclusões de
métrica (`movements-view`, `PlanningScreen`) já estão corretas.

## Decisões de design

| # | Decisão | Por quê |
|---|---|---|
| 1 | Transferência **não é entidade própria** — é um par de `Movement`s ligadas por `pair_id` | O `Balance` da `Wallet`, a lista de transações e os filtros já operam sobre `Movement`; uma tabela nova duplicaria tudo isso |
| 2 | Endpoint dedicado `POST /v2/transfers/`, não dois `POST /movements` | Atomicidade: as duas pernas e os dois saldos vivem numa transação só. Dois requests deixariam meia transferência gravada em caso de falha |
| 3 | `TypePayment` próprio (`internal_transfer`) é o **discriminador canônico** das exclusões | Um único predicado, legível em SQL e nos clientes. Filtrar por `category_id` é o backup (dado antigo/importado), não a regra |
| 4 | Categorias fixas de saída/entrada, seedadas como `default_category_id` | Todo `Movement` exige `Category` (GLO); sem categorias fixas cada usuário criaria a sua e as exclusões por categoria quebrariam |
| 5 | `amount` sempre positivo no request; a api deriva os sinais | O cliente não deve poder gravar um par com sinais incoerentes |
| 6 | Descrição gerada pela api (`"Transferência de X para Y"`), com o texto do usuário como sufixo | As duas pernas ficam auto-explicativas na lista sem o usuário digitar nada |
| 7 | `is_paid: false` é permitido (transferência agendada) e **não** mexe em `Balance` | Mesma semântica de "pago" do resto do produto (`Balance` = pagos) |
| 8 | Saldo insuficiente **bloqueia** a transferência, mas só quando `is_paid` | Uma transferência futura ainda não tirou dinheiro de lugar nenhum |
| 9 | As duas pernas **aparecem** na lista de transações | O usuário precisa enxergar o movimento do dinheiro; escondê-las faria o saldo da carteira "andar sozinho" |
| 10 | Exclusão feita em **cada agregado**, não filtrando na origem do `GET /v2/movements/` | A lista precisa das transferências; só os agregados não. Filtrar na fonte quebraria a decisão #9 |
| 11 | Contagem de plano (`movements_per_month`) deve valer para a transferência, contando **1** | É uma ação do usuário, não duas. Contar 2 puniria quem transfere; contar 0 (comportamento atual) abre um bypass do limite do plano `free` |
| 12 | Editar/apagar uma perna opera sobre **o par inteiro** | Meia transferência é um estado inválido: um saldo se mexe e o outro não |
| 13 | `pay`/`revert-pay` são endpoints dedicados por `pair_id` (`POST /v2/transfers/{pair_id}/pay`), não `POST /v2/movements/{id}/pay` reaproveitado | Mesma razão da #12: liquidar/reverter uma perna isolada deixaria uma carteira com o saldo movido e a outra não. O endpoint de `movement` bloqueia pernas de `internal_transfer` (`ErrTransferMustUsePairEndpoint`) e devolve a operação para cá |
| 14 | Saldo suficiente é validado na carteira **de origem** ao liquidar (`pay`) e na carteira **de destino** ao reverter (`revert-pay`) | `pay` debita a origem — ela precisa ter saldo para sair. `revert-pay` estorna o crédito do destino — ele precisa ainda ter o dinheiro que recebeu (se já foi gasto, reverter deixaria o saldo negativo) |

## Decisões relacionadas

Nenhum `ADR`/`PDR` aplicável — sem mudança de topologia e sem decisão de produto formal
registrada. Depende de `AYD-003` no ponto do `GetExpenseMovements` (questão em aberto de lá).

## O que falta para concluir

### api

- [x] **Mapear os erros de transferência no `HandleErr`** — `ErrSameWalletTransfer`,
      `ErrInvalidTransferAmount`, `ErrDateRequired` → `400`; `ErrInsufficientBalance` →
      `422`; `ErrTransferPairNotFound` → `404`; `ErrMovementAlreadyPaid`,
      `ErrMovementNotPaid`, `ErrTransferPairInconsistentPayment` → `409`. Todos mapeados em
      `errors_handler.go::toAPIError`, batendo com o `swagger.yaml`.
- [ ] **Excluir `internal_transfer` dos agregados restantes** — `monthly_series`, `kpis` e
      `current_month.budget.realized` no `dashboard_usecase`; `balance` legado
      (`/balances/period`); `estimate` por categoria. Correção na raiz:
      `MovementList.GetExpenseMovements()`/`GetIncomeMovements()` (ou um
      `GetOperationalMovements()` que filtra `internal_transfer` e `invoice_payment` antes).
- [x] **Pareamento em update, delete, pay e revert-pay** — `PUT`/`DELETE
      /v2/transfers/{pair_id}` e os novos `POST .../pay` e `.../revert-pay` operam sempre as
      duas pernas juntas; `/v2/movements/{id}/pay` e `.../revert-pay` (clean-arch e serviço
      legado) rejeitam pernas de `internal_transfer` com `ErrTransferMustUsePairEndpoint`.
      Ver decisões #12–#14 e a seção "Consumidores" acima.
- [x] **Limite de plano** — `bootstrap/transfer/setup.go` injeta o `PlanLimitsValidator` em
      `usecase.NewTransfer`, contando 1 por transferência (decisão #11).
- [ ] **Esconder as duas categorias fixas do seletor de categorias** —
      `CategoryRepository.FindAll` devolve tudo que é `default_category_id`, então
      "Transferência interna - saída/entrada" aparecem no picker de movimentação, nos
      filtros e no Planejamento. (Mesma lacuna já existente na categoria de pagamento de
      fatura — decidir se corrige junto.)
- [ ] **`GET` de transferência por `pair_id`** — não existe rota para ler o par como
      unidade (só listar as duas pernas via `GET /v2/movements/` e filtrar por `pair_id` no
      cliente). `DELETE`, `pay` e `revert-pay` já cobrem as operações de escrita; avaliar se
      o `GET` dedicado é necessário para o MVP ou se o filtro client-side é suficiente.
- [x] **Testes** — `transfer_usecase_test.go`, `update_transfer_usecase_test.go`,
      `delete_transfer_usecase_test.go` e `pay_transfer_usecase_test.go` cobrem criação,
      atualização, remoção, liquidação e reversão, incluindo os cenários de erro (par
      inconsistente, saldo insuficiente em cada direção, par incompleto). Falta cobertura
      para as exclusões de agregado (item acima).

### web

- [ ] **Abrir a porta** — adicionar o botão "Transferência" no seletor de modo do
      `MovementFormModal` (o grid vira 4/5 colunas) chamando `setIsTransferMode(true)`. É a
      única coisa que falta para a feature existir para o usuário: hook, formulário,
      validação, invalidação de cache e toasts já estão prontos.
- [ ] **Excluir do Planejamento** — `use-estimate-with-movements` filtra
      `invoice_payment` mas não `internal_transfer`.
- [ ] **Corrigir o tipo de resposta** — `TransferResponse` em `lib/api/transfers.ts` não
      bate com o payload real da api (declara `id`/`origin_wallet_id`/…; a api devolve
      `pair_id` + as duas `MovementOutput`).
- [ ] **Editar/apagar transferência na lista** — quando a api expuser a operação pareada,
      a lista precisa avisar que a ação afeta as duas pernas.
- [ ] **SPEC@web** — não necessária para ativar a feature (é o botão que falta); vale
      escrever se as pendências acima virarem um trabalho maior.

### mobile

- [ ] **UI de criação** — modo transferência no `MovementModal`, ligado ao
      `useCreateTransfer` já existente.
- [x] **`SPEC-003@mobile`** — escrita; falta implementar.

## Fora de escopo / questões em aberto

- [ ] **Transferência externa (Pix/TED para terceiros)** — fora deste AYD. O `GLO` já reserva
      o termo "Transfer" para esse caso futuro; aqui é sempre **InternalTransfer**.
- [ ] **Transferência recorrente** — não suportada (`is_recurrent` não existe no contrato).
- [ ] **Transferência envolvendo `CreditCard`/`Invoice`** — fora de escopo; pagamento de
      fatura já tem `invoice_payment`.
- [ ] **Exibição pareada na lista** — hoje o usuário vê duas linhas independentes. Agrupar
      visualmente por `pair_id` (uma linha "R$ 250 · Carteira A → Carteira B") é decisão de
      UI ainda em aberto nos dois clientes.
- [ ] **Dados legados** — transferências criadas antes da correção das métricas continuam
      contaminando os agregados até que os filtros por `type_payment` entrem; não há
      backfill previsto (o `type_payment` já está gravado, então a correção é retroativa por
      construção).
