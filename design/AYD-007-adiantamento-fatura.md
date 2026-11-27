---
id: AYD-007
type: design
title: Adiantamento de fatura de cartão de crédito (Invoice Advance Payment)
status: draft
created: 2026-11-26
updated: 2026-11-26
owner: Silvio Ubaldino
affects: [api, web, mobile]
parents: [REQ-001]
children: []
related: [AYD-004, AYD-003, AYD-005, GLO]
tags: [invoice, credit-card, payment, import, statement]
superseded_by: null
---

# AYD-007: Adiantamento de fatura de cartão de crédito

> Análise & Design cross-repo. Define o mecanismo de **`InvoiceAdvancePayment`** (pagar
> parte de uma `Invoice` antes de quitá-la), **de onde nasce todo pagamento de fatura** (botão
> manual ou import do **extrato bancário**, nunca o import da fatura do cartão) e o ajuste no
> import de fatura (AYD-004), que passa a filtrar todas as linhas de pagamento e a conferir o
> total considerando os adiantamentos.
>
> `AYD-005` neste doc é sempre o de **planejamentos (orçado × realizado)**, onde vive o recorte
> canônico de "realizado"; o ID está duplicado com o de transferência interna no `manifest`.

## Objetivo

Atende **RF-06** (controlar `CreditCard` e `Invoice`) e **RF-07** (importar
extrato/fatura). Hoje a `Invoice` aceita **um único pagamento**, que a quita:
`POST /v2/invoices/:id/pay` marca `is_paid`, debita a `Wallet` e, se o valor for menor que o
total, joga o restante para a fatura seguinte (`invoice_remainder`). Não há como registrar que
o usuário **já pagou parte da fatura** durante o ciclo, coisa que todo banco permite e que o
Mercado Pago, por exemplo, lista na própria fatura.

Resultado esperado:
1. O usuário registra um ou mais adiantamentos numa `Invoice` aberta. Cada um debita a
   `Wallet` na data e libera limite do cartão, e a fatura continua aberta pelo **restante**.
2. Na quitação, o valor sugerido é o restante, e o cálculo da sobra que vai para a fatura
   seguinte considera o que já foi adiantado.
3. **Pagamentos de fatura (quitação ou adiantamento) nascem de dois lugares só:** o botão no
   app ou o import do **extrato bancário**, onde a linha "pagamento do cartão" vira o pagamento
   da `Invoice` em vez de uma despesa da `Wallet`. É no extrato que o dinheiro sai de fato.
4. O **import da fatura do cartão não registra pagamento nenhum**: filtra todas as linhas de
   pagamento e as usa só para conferir o total do documento, que passa a bater com o do app.

## Evidência — fatura Mercado Pago, jan/2026

Teste funcional do import (AYD-004) na `develop`, nov/2026. Resumo impresso na fatura:

| Linha do resumo | Valor |
|---|---|
| Total da fatura de dezembro | R$ 178,44 |
| Consumos de 30/12 a 29/01 | R$ 1.503,90 |
| Pagamentos e créditos devolvidos | − R$ 377,44 |
| **Total a pagar** (vence 04/02/2026) | **R$ 1.304,90** |

Os R$ 377,44 são três linhas em "Movimentações na fatura":

| Data | Descrição | Valor | O que é |
|---|---|---|---|
| 30/12 | Pagamento da fatura de dezembro/2025 | 178,44 | pagamento da fatura **anterior** (vencida em 04/01). Anula a linha "Total da fatura de dezembro" |
| 11/01 | Pagamento da fatura de janeiro/2026 | 150,00 | **adiantamento desta fatura** |
| 16/01 | Pagamento da fatura de janeiro/2026 | 49,00 | **adiantamento desta fatura** |

A guarda do AYD-004 (§"Itens que não pertencem à fatura") filtra as três como
`invoice_payment`. As compras somam corretamente − R$ 1.503,90, mas o `total_amount_mismatch`
dispara (esperado −1.304,90, detectado −1.503,90), porque o total do documento já desconta os
adiantamentos. E, como o app não sabe que R$ 199,00 já foram pagos, quitar os R$ 1.304,90 pelo
`pay` vira pagamento parcial e **joga R$ 199,00 para fevereiro**, uma dívida que não existe.

Não foi erro do modelo: a extração estava certa. Falta ao domínio o conceito de adiantamento.

## Estado atual (api) — o que o mecanismo precisa contornar

| Ponto | Comportamento hoje | Impacto |
|---|---|---|
| `Invoice.Pay` (`invoice_usecase.go`) | Um pagamento por fatura; `amount` entre `invoice.Amount` e 0; sobra `invoice.Amount − paid` vai para a fatura seguinte | Precisa operar sobre o **restante** |
| `buildMovementWithAmount` | O `Movement` de pagamento usa **`ID = invoice.ID`** | Hoje só cabe um pagamento por fatura. Este é o pagamento de **quitação** |
| `FindInvoicePaymentByInvoiceID` / `DeleteByInvoiceID` (`movement_repository.go`) | Filtram por `invoice_id` + `type_payment = invoice_payment` e supõem um único registro | Com tipo próprio para o adiantamento, continuam achando só a quitação: o `revert-pay` não toca nos adiantamentos |
| `FindByInvoiceID` / `RecalculateInvoice` | Já excluem `invoice_payment` da soma da fatura | Sem impacto: adiantamento não altera `invoice.amount` |
| Recorte de "realizado" (AYD-003/AYD-005), agente, planejamentos, dashboard; filtros dos clientes | Excluem `type_payment = invoice_payment` em pontos espalhados (~16 referências na api, ~11 arquivos no web, 4 no mobile, levantados na `develop` em nov/2026) | Cada um precisa excluir também o tipo novo — por isso a Decisão 2 centraliza a lista |
| web/mobile — lista de fluxo de caixa | Escondem o `Movement` real de `invoice_payment` da fatura e desenham uma linha **virtual** com `invoice.amount` | Esconderiam os adiantamentos e mostrariam o total bruto como "a pagar" |
| Import de **extrato** (`/confirm`) | A linha "pagamento do cartão" do extrato entra como **despesa comum** da `Wallet` | Se o usuário também paga a fatura no app, o débito conta duas vezes |

## Repos afetados e papéis

| Repo | Papel nesta feature | SPEC gerada |
|------|---------------------|-------------|
| api | Dono do mecanismo: endpoints de adiantamento, campos derivados na `Invoice`, `pay`/`revert-pay` sobre o restante; no import de **extrato**, sugere e executa o vínculo da linha com a fatura; no import de **fatura**, classifica as linhas de pagamento para conferir o total | a criar (SPEC@api) |
| web | Detalhe da fatura (adiantado/restante, lista, adiantar, desfazer), modal de pagamento sugerindo o restante, fluxo de caixa sem esconder adiantamentos; revisão do extrato com o vínculo "pagamento de fatura"; revisão da fatura com o aviso dos pagamentos filtrados | a criar (SPEC@web) |
| mobile | O mesmo do web: detalhe da fatura, pagamento, `movements-view`, revisão de extrato e de fatura | a criar (SPEC@mobile) |

## Decisões-chave

| # | Decisão | Por quê |
|---|---|---|
| 1 | **Adiantamento é um `Movement` com `type_payment` próprio: `invoice_advance_payment`**, `is_paid: true`, ligado à fatura por `invoice_id`. A quitação continua `invoice_payment`, única por fatura. Nenhum campo novo no `Movement`. | Não incha a entidade (revisão de nov/2026, que trocou a flag `is_advance_payment` pelo tipo): a distinção fica no tipo, como já acontece com `invoice_remainder`. De quebra, as consultas da quitação (`FindInvoicePaymentByInvoiceID`, `DeleteByInvoiceID`) seguem certas sem mudança. |
| 2 | **"Pagamento de fatura" passa a ser um conjunto de tipos, definido num lugar só por repo:** `invoice_payment` + `invoice_advance_payment`. Todo filtro que hoje exclui `invoice_payment` do realizado/despesa passa a usar esse conjunto (api: helper de domínio, ex. `TypePayment.IsInvoicePayment()`, usado também nos SQLs; web e mobile: uma constante, ex. `INVOICE_PAYMENT_TYPES`). | É o custo do tipo novo: um filtro esquecido conta o adiantamento como despesa sem erro visível. Centralizar transforma ~30 pontos soltos em um, e a invariante de aceite (adiantamento nunca é despesa) pega o que escapar. |
| 3 | **`invoice.amount` continua bruto** (soma das compras da competência). Entram dois campos derivados: `advance_paid_amount` e `remaining_amount`. | "Faturas por cartão" (AYD-003) e o limite consumido seguem a competência; o adiantamento muda **quanto falta pagar**, não **quanto se gastou**. |
| 4 | **Só em fatura não paga, e sempre menor que o restante** (em módulo). Adiantar o restante inteiro é quitar: usa-se `pay`, que já aceita `payment_date` anterior ao vencimento. **Pagar mais que o restante (saldo credor) é proibido** (confirmado em nov/2026). | Mantém uma única forma de quitar e evita fatura "paga por adiantamentos" sem quitação. O app não modela crédito a favor do usuário na fatura seguinte. |
| 5 | **Efeitos imediatos na data do adiantamento:** debita a `Wallet` e **libera limite** do cartão no valor adiantado. A fatura continua aberta. | É o que o banco faz: o limite volta na hora do pagamento. RN-02 passa a ler "a `Invoice` afeta o `Balance` quando paga, **no todo ou em adiantamentos**". |
| 6 | **`pay` opera sobre o restante:** `amount` padrão = `remaining_amount`; válido entre `remaining_amount` e 0; a sobra para a fatura seguinte é `remaining_amount − pago`. | Sem isso, o caso do Mercado Pago vira a dívida fantasma de R$ 199,00 descrita na evidência. |
| 7 | **`revert-pay` desfaz só a quitação.** Adiantamentos se desfazem um a um pelo `DELETE` próprio, e só com a fatura não paga (desfaz-se primeiro a quitação). | Desfazer a quitação não deve apagar pagamentos que de fato aconteceram, e a ordem fixa evita recalcular a sobra da fatura seguinte com uma base que mudou. |
| 8 | **Pagamento de fatura nasce só do botão manual ou do import do extrato bancário — nunca do import da fatura do cartão** (confirmado em nov/2026). No extrato, a linha de pagamento do cartão, vinculada a uma `Invoice`, vira quitação ou adiantamento dela, e não despesa da `Wallet`. | O extrato é onde o dinheiro sai, com a `Wallet` certa. A fatura do cartão só *ecoa* o pagamento; registrá-lo a partir dela duplicaria o que o extrato ou o botão já registram e chutaria a `Wallet` de origem. |
| 9 | **No import da fatura do cartão, toda linha de pagamento é filtrada**: o pagamento da fatura anterior e os adiantamentos desta fatura. A classificação entre os dois (por data, com desempate pelo total) serve **só** para a conferência do total e para avisar o usuário. | O total impresso pelo banco desconta os adiantamentos desta fatura, mas não o pagamento da anterior. Sem separar os dois, o checksum acusa divergência em toda fatura com adiantamento. |

## Contratos (fonte da verdade)

### `POST /v2/invoices/{id}/advance-payments` *(novo)*

```jsonc
// req
{
  "amount": 150.00,               // obrigatório; aceita positivo ou negativo, normalizado para negativo (como o /pay)
  "wallet_id": "uuid",            // opcional; padrão = invoice.wallet_id (carteira default do cartão)
  "payment_date": "2026-01-11"    // opcional; padrão = hoje (fuso do usuário). Não pode ser posterior a due_date
}
// res 201 — a Invoice atualizada (shape abaixo), incluindo advance_payments[]
```

**Erros** (contrato de erro global, `error.type` quando houver):

| Situação | HTTP | `error.type` |
|---|---|---|
| Fatura não encontrada / de outro usuário | 404 | — |
| Fatura já paga | 409 | `invoice_already_paid` |
| `amount` = 0 ou ausente | 422 | `invalid_payment_amount` |
| \|`amount`\| ≥ \|`remaining_amount`\| (quitaria a fatura ou geraria saldo credor) | 422 | `advance_payment_settles_invoice` |
| `payment_date` posterior a `due_date` | 422 | `advance_payment_after_due_date` |
| `Wallet` não encontrada | 404 | — |

### `DELETE /v2/invoices/{id}/advance-payments/{movement_id}` *(novo)*

Desfaz um adiantamento: devolve o valor à `Wallet`, volta a consumir o limite e apaga o
`Movement`. `res 200` traz a `Invoice` atualizada.

| Situação | HTTP | `error.type` |
|---|---|---|
| Fatura paga (desfazer a quitação primeiro) | 409 | `invoice_already_paid` |
| `movement_id` não é adiantamento desta fatura | 404 | `advance_payment_not_found` |

### `Invoice` — campos novos (aditivos)

Em **todas** as respostas que devolvem `Invoice` (`GET /v2/invoices/{id}`, `/date`, `/detailed`,
`pay`, `revert-pay`, `recalculate` e os dois endpoints acima):

```jsonc
{
  "amount": -1503.90,                // inalterado: bruto, soma das compras da competência
  "advance_paid_amount": -199.00,    // (novo) soma dos adiantamentos; 0 quando não há; mesmo sinal de amount
  "remaining_amount": -1304.90,      // (novo) amount − advance_paid_amount; o que falta pagar
  // só em GET /v2/invoices/{id}, /detailed e nas respostas dos endpoints de adiantamento:
  "advance_payments": [              // (novo) ordem por payment_date
    { "id": "uuid",                  // id do Movement
      "payment_date": "2026-01-11",
      "amount": -150.00,
      "wallet_id": "uuid",
      "description": "Adiantamento da fatura - Mercado Pago" }
  ]
}
```

Depois de quitada, `remaining_amount` continua sendo o valor que a quitação cobriu (não vai a
zero): é a base do cálculo da sobra e o valor que os clientes exibem na linha da fatura.

### `POST /v2/invoices/{id}/pay` — semântica alterada, payload inalterado

`req { wallet_id, payment_date?, amount? }`, como hoje. Mudam três coisas:
- `amount` ausente ⇒ paga `remaining_amount` (hoje: `amount`).
- Validação: `remaining_amount ≤ amount < 0` (hoje: contra `amount`). Fora disso, 422
  `invalid_payment_amount`, como hoje.
- Sobra levada à fatura seguinte = `remaining_amount − amount pago`.

### `POST /v2/invoices/{id}/revert-pay` — semântica alterada

Desfaz **só a quitação**: estorna o valor dela na `Wallet` e no limite e remove a sobra lançada
na fatura seguinte, calculada sobre `remaining_amount`. Os adiantamentos permanecem.

### `Movement` — campo novo (aditivo)

```jsonc
{ "type_payment": "invoice_advance_payment", "invoice_id": "uuid", "is_paid": true }
```

Nenhum campo novo: o adiantamento é identificado pelo `type_payment`. `invoice_payment`
continua sendo só a quitação. Os clientes usam o tipo para decidir o que esconder no fluxo de
caixa (ver "Clientes") e incluem `invoice_advance_payment` em todo filtro que hoje exclui
`invoice_payment` (Decisão 2).

### Import de extrato bancário — linha de pagamento do cartão vira pagamento da fatura *(novo)*

Mesmo padrão do vínculo com recorrência (`recurrence_id`) no caminho statement: **o servidor
sugere, o cliente decide, o servidor revalida e executa.**

**`POST /v2/statements/extract`** (statement): cada linha de **saída** que pareça pagamento de
cartão recebe uma sugestão `invoice_payment_match`. A detecção combina três sinais:
- o prompt de extrato marca a linha com `"is_card_payment": true` (campo interno do modelo,
  não exposto);
- a descrição traz termos de fatura/cartão ("PAGAMENTO FATURA", "PAG FAT", "PGTO CARTAO",
  "BOLETO CARTAO"...) ou o nome de um `CreditCard` do usuário;
- o valor coincide com o `remaining_amount` de uma `Invoice` aberta.

```jsonc
{
  "date": "2026-01-11",
  "description": "PIX MERCADO PAGO FATURA",
  "amount": -150.00,
  "type_payment": "pix",
  "invoice_payment_match": {            // (novo) sugestão do servidor
    "invoice_id": "uuid",
    "credit_card_id": "uuid",
    "credit_card_name": "Mercado Pago",
    "due_date": "2026-02-04",
    "remaining_amount": -1503.90,       // antes desta linha
    "kind": "advance",                  // "settlement" | "advance"
    "confidence": 0.7
  },
  "invoice_payment": {                  // (novo) decisão; preenchido pelo servidor só com confiança alta
    "invoice_id": "uuid",
    "kind": "settlement"
  }
}
```

**Regras da sugestão** (só faturas **não pagas** do usuário são candidatas):

| Situação | `kind` | Confiança | Pré-decidido? |
|---|---|---|---|
| \|valor\| = \|`remaining_amount`\| (tolerância de R$ 0,01) e data até o vencimento + 5 dias | `settlement` | alta (0.95) | sim |
| Linha marcada como pagamento de cartão, \|valor\| < \|`remaining_amount`\| e data até o vencimento | `advance` | média (0.7) | não: o usuário aceita num toque |
| Mais de uma fatura candidata | a de vencimento mais próximo da data da linha; o nome do cartão na descrição desempata | — | não |
| Nenhuma candidata | sem sugestão; a linha segue como hoje | — | — |

**Warning novo:** `{ "type": "invoice_payment_match_found" }` quando ≥ 1 linha tiver sugestão.

**`POST /v2/statements/confirm`** (statement): item com `invoice_payment` **não cria despesa**.
Com a `Wallet` do import (`wallet_id`), a data e o valor da linha, ele executa:
- `kind: "settlement"` ⇒ a mesma regra do `pay`. Valor menor que o restante quita
  parcialmente, e a sobra vai para a fatura seguinte;
- `kind: "advance"` ⇒ a mesma regra do `POST .../advance-payments`.

Comportamento:
- Viola a regra (fatura já paga, valor ≥ restante num `advance`...)? O item vai para `errors`
  e `skipped` e **não vira despesa**: o usuário resolve pelo botão. Cair no caminho de despesa
  reabriria a contagem dupla.
- **Dedup:**
  - o hash de idempotência da linha é gravado no `Movement` de pagamento, então reimportar o
    mesmo extrato pula a linha;
  - adiantamento já existente na fatura com o mesmo valor e data a até 3 dias, ou fatura já
    quitada pelo botão, também pulam.
- Item sem `invoice_payment` segue o caminho atual: despesa comum. O servidor **não decide
  sozinho** sem confiança alta.
- A response ganha `invoice_payments_created` (quitações + adiantamentos criados).

### Import da fatura do cartão — linhas de pagamento filtradas (delta sobre AYD-004)

O import da fatura **não registra pagamento**. O delta serve para o total bater e para o
usuário entender o que foi filtrado.

**`POST /v2/statements/extract`** (invoice):

- **Camada 1 (prompt), revisada:** o modelo passa a **extrair todas as linhas de pagamento**
  ("Pagamento da fatura…", "PAGAMENTO ON LINE", "PAGTO FATURA"…), sempre com **valor
  positivo**, em vez de omiti-las. Também não extrai linhas do bloco de resumo ("Total da
  fatura anterior", "Saldo anterior", "Pagamentos e créditos"). Elas saem marcadas na camada 2,
  e omiti-las tiraria da conferência do total os adiantamentos que o banco já descontou.
- **Camada 2 (guarda), estendida:** toda linha reconhecida por `IsInvoicePaymentDescription`
  tem o sinal normalizado para positivo, sai como `excluded: true` e recebe um motivo:

  | Motivo | `exclusion_reason` | Regra de data |
  |---|---|---|
  | Pagamento da fatura anterior | `invoice_payment` (inalterado) | data ≤ vencimento da fatura **anterior** |
  | Adiantamento desta fatura | `advance_payment` *(novo)* | vencimento da anterior < data ≤ `period_end` da fatura alvo |

  - **Por que a data separa:** a fatura anterior só se paga até o vencimento dela. O que vem
    depois só pode estar abatendo a fatura atual. No caso do Mercado Pago, dezembro venceu em
    04/01: a linha de 30/12 é da anterior; as de 11/01 e 16/01 são adiantamentos.
  - **Datas de referência:** a fatura alvo é a mesma da regra de competência futura
    (`ResolveTargetInvoicePeriodEnd`, pelo cartão). O vencimento da anterior é o `due_date`
    da fatura que fecha no dia anterior ao `period_start` da alvo.
  - **Sem `credit_card_id`:** usa `invoice_meta.closing_date` como `period_end` e
    `invoice_meta.due_date − 1 mês` como vencimento da anterior.
  - **Sem nenhum dos dois:** tudo vira `invoice_payment`, o comportamento atual.
  - **Desempate pelo total:** a regra de data erra quando a fatura anterior foi paga **com
    atraso** (ex.: dezembro pago em 10/01 seria lido como adiantamento). Se existe
    `invoice_meta.total_amount`, a classificação por data **não** reconcilia com ele (camada 3)
    e "todas as linhas como `invoice_payment`" reconcilia, vale a segunda.
  - Os dois motivos têm o mesmo efeito no import: **o item não entra**. A diferença é só de
    conferência e de mensagem ao usuário.
- **Camada 3 (checksum), reformulada:** `Σ itens não marcados + Σ linhas advance_payment ≈
  invoice_meta.total_amount` (tolerância atual). No Mercado Pago: −1.503,90 + 199,00 =
  −1.304,90. Em faturas sem adiantamento a fórmula se reduz à atual.
- **Warning novo:** `{ "type": "advance_payment_detected", "detected": "199.00" }` quando ≥ 1
  item vier com `exclusion_reason: "advance_payment"`; `detected` é a soma das linhas. Os
  clientes avisam que esses valores não foram registrados e apontam os caminhos: o import do
  extrato bancário ou o botão "Adiantar pagamento".

```jsonc
{
  "date": "2026-01-11",
  "description": "Pagamento da fatura de janeiro/2026",
  "amount": 150.00,
  "type_payment": "credit_card",
  "excluded": true,
  "exclusion_reason": "advance_payment"   // (novo) filtrado como o invoice_payment
}
```

**`POST /v2/statements/confirm-invoice`:** **sem mudança de contrato.** `advance_payment`
entra na guarda que já pula os itens marcados, e o `confirm-invoice` passa a reaplicá-la também
para esse motivo. Reincluir uma linha de pagamento como item da fatura **não** é oferecido
para `advance_payment` (nem para `invoice_payment`): pagamento nunca é despesa.

## Modelo de domínio afetado

- **`InvoiceAdvancePayment`** — termo novo no GLO. Não é entidade nem tabela própria: é um
  `Movement` com `type_payment = invoice_advance_payment`, `is_paid = true`, `invoice_id` e
  `credit_card_id` da fatura, `wallet_id` de quem pagou e categoria padrão de cartão.
- **`Invoice`** ganha os derivados `advance_paid_amount` e `remaining_amount`. Nada novo é
  gravado em `invoices`: `amount`, `is_paid`, `payment_date` e `wallet_id` mantêm o sentido de
  hoje, e `payment_date`/`wallet_id` continuam sendo os da **quitação**.
- **Invariantes** (entram nas invariantes de aceite da api, SPEC-008@api):
  - `advance_paid_amount = Σ amount` dos adiantamentos da fatura;
  - `remaining_amount = amount − advance_paid_amount`, com `remaining_amount < 0` enquanto a
    fatura não for quitada e tiver adiantamento;
  - limite usado do cartão = Σ `remaining_amount` das faturas não pagas (+ sobras lançadas);
  - `Balance` da `Wallet` reflete cada adiantamento na data dele;
  - `invoice_advance_payment` nunca entra em despesa nem em realizado;
  - uma linha de extrato vinculada a fatura gera **exatamente um** `Movement` (o pagamento) e
    nenhuma despesa.

## Clientes (web e mobile)

1. **Detalhe da fatura:** mostra Total (`amount`), Adiantado (`advance_paid_amount`) e
   Restante (`remaining_amount`), mais a lista de `advance_payments` com ação de desfazer
   (desabilitada se a fatura estiver paga). A ação **"Adiantar pagamento"** abre um modal com
   valor (< restante), carteira (padrão do cartão) e data.
2. **Modal de pagamento:** valor sugerido = `remaining_amount`. O texto de "pagamento parcial"
   passa a falar do restante.
3. **Fluxo de caixa** (`movements-view.ts`@mobile, lista de transações@web): **não esconder**
   `invoice_advance_payment`, que são débitos reais da `Wallet`. A linha virtual da fatura passa
   a mostrar `remaining_amount`. Gráficos por categoria, planejamento e export passam a
   descartar o conjunto de tipos de pagamento de fatura (Decisão 2), não só `invoice_payment`.
4. **Revisão do extrato bancário:**
   - a linha com `invoice_payment_match` mostra o vínculo "Pagamento da fatura <cartão>
     (vence dd/mm)" e o tipo (quitar / adiantar);
   - aceitar, trocar de fatura ou recusar; recusar a mantém como despesa comum;
   - linhas vinculadas não somam como despesa no resumo da revisão.
5. **Revisão da fatura do cartão:**
   - as linhas `invoice_payment` e `advance_payment` aparecem esmaecidas, sem opção de
     reincluir, como "pagamento — não entra na fatura";
   - com `advance_payment_detected`, um aviso: "R$ 199,00 já foram adiantados nesta fatura.
     Registre pelo import do extrato do banco ou pelo botão Adiantar pagamento";
   - o resumo mostra Compras e, quando houver adiantamentos, **A pagar** (compras −
     adiantamentos), que bate com `invoice_meta.total_amount`.

## Fluxo cross-repo

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuário
    participant C as web / mobile
    participant A as api
    participant G as Gemini

    rect rgb(240,240,240)
    note over U,A: Adiantamento manual (botão)
    U->>C: Adiantar R$150 na fatura de janeiro
    C->>A: POST /v2/invoices/{id}/advance-payments {amount, wallet_id, payment_date}
    A->>A: valida (não paga, |150| < |restante|, data ≤ vencimento)
    A->>A: Movement invoice_advance_payment + debita Wallet + libera limite
    A-->>C: 201 Invoice {amount, advance_paid_amount, remaining_amount, advance_payments}
    end

    rect rgb(240,240,240)
    note over U,G: Import do extrato bancário — pagamento nasce aqui
    U->>C: envia extrato da conta
    C->>A: POST /v2/statements/extract (source_type=statement)
    A->>G: prompt de extrato (marca linhas de pagamento de cartão)
    G-->>A: linhas
    A->>A: casa linha × faturas abertas → invoice_payment_match (settlement | advance)
    A-->>C: movements[] com sugestão (pré-decidida se confiança alta)
    U->>C: aceita / troca fatura / recusa
    C->>A: POST /v2/statements/confirm {wallet_id, movements[ invoice_payment ]}
    A->>A: settlement → regra do pay · advance → regra do adiantamento (sem despesa)
    A-->>C: {created, skipped, invoice_payments_created, errors}
    end

    rect rgb(240,240,240)
    note over U,G: Import da fatura do cartão — pagamentos filtrados
    U->>C: envia PDF da fatura
    C->>A: POST /v2/statements/extract (source_type=invoice, credit_card_id)
    A->>G: prompt de fatura (extrai também as linhas de pagamento, positivas)
    G-->>A: itens + invoice_meta
    A->>A: pagamentos → excluded (invoice_payment | advance_payment, por data + desempate pelo total)
    A->>A: checksum Σ itens + Σ adiantamentos ≈ total_amount
    A-->>C: movements[] + warning advance_payment_detected
    C->>A: POST /v2/statements/confirm-invoice (só compras; pagamentos pulados)
    end
```

## Implementação por repo (pontos de entrada)

- **api:**
  - `internal/usecase/invoice_usecase.go`: novo `AdvancePayment`/`RevertAdvancePayment`;
    `Pay`, `handleRemainder` e `RevertPayment` sobre o restante.
  - `internal/domain/typepayment.go`: `TypePaymentInvoiceAdvancePayment` e o helper do conjunto
    de tipos de pagamento de fatura; trocar os filtros soltos (`agent_financial_repository.go`,
    `movement_repository.go`, `estimate_usecase.go`, `dashboard_usecase.go`) por ele.
  - `internal/infrastructure/repository/movement_repository.go`: soma dos adiantamentos;
    `FindInvoicePaymentByInvoiceID`/`DeleteByInvoiceID` ficam como estão (só a quitação).
  - `internal/infrastructure/api/invoice_api.go` (rotas novas); `internal/domain/invoice.go`
    (derivados).
  - `internal/domain/statement.go` e `internal/usecase/statement_usecase.go`: classificação e
    checksum no caminho invoice; sugestão e execução do vínculo no caminho statement
    (`Extract`/`Confirm`).
  - `internal/infrastructure/gateway/gemini_vision_gateway.go`: prompts de fatura, de extrato
    e auto.
- **web:** detalhe/pagamento de fatura (`lib/api/invoices.ts`, modais de fatura), lista de
  transações do dashboard, `components/statement-import/*` e `hooks/use-statement-import.ts`.
- **mobile:** `src/lib/api/invoices.ts`, tela de detalhe do cartão/fatura,
  `src/lib/dashboard/movements-view.ts`, `src/screens/StatementReviewScreen.tsx`.

## Plano faseado

| Fase | Repo | Entrega | Depende de |
|---|---|---|---|
| 1 | api | Mecanismo: endpoints de adiantamento, derivados na `Invoice`, `pay`/`revert-pay` sobre o restante, `invoice_advance_payment` + filtros centralizados | — |
| 2 | api | Import da fatura: prompt extrai pagamentos, `advance_payment`, desempate, checksum, warning | — |
| 3 | web, mobile | Exibição correta (restante, fluxo de caixa) + adiantar/desfazer manual | 1 |
| 4 | web, mobile | Revisão da fatura: pagamentos esmaecidos sem reinclusão, aviso de adiantamentos, "A pagar" | 2 |
| 5 | api | Import do extrato: `invoice_payment_match` e execução no `/confirm` | 1 |
| 6 | web, mobile | Revisão do extrato com o vínculo de pagamento de fatura | 5 |

A fase 2 não depende do mecanismo, porque só filtra e confere. Pode sair primeiro e já tira o
falso `total_amount_mismatch` do caso Mercado Pago.

## Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Pagamento **atrasado** da fatura anterior classificado como adiantamento no import da fatura | Desempate pelo total. Mesmo errando, o efeito é só na mensagem e no checksum: as duas classes são filtradas |
| Linha de extrato vinculada à fatura errada (dois cartões, valores parecidos) | Só pré-decide com valor exato igual ao restante; o resto é sugestão que o usuário aceita; recusar mantém como despesa |
| Usuário que não importa extrato nem usa o botão | A fatura fica com o restante cheio. O aviso `advance_payment_detected` na revisão da fatura aponta o caminho |
| Filtro esquecido conta o adiantamento como despesa | Conjunto de tipos centralizado (Decisão 2) + invariante de aceite |
| Versão antiga do app mobile não conhece o tipo e o soma como despesa no gráfico | Adiantamento só nasce de telas novas (botão, vínculo no extrato); só aparece numa versão antiga se o usuário adiantou por outro cliente já atualizado. O `Balance` vem da api e não é afetado |
| Cliente antigo no import de extrato ignora `invoice_payment` e envia a linha sem decisão | O item segue como despesa, igual a hoje. Nenhuma regressão |
| Agregados que usam `invoice.amount` como "a pagar" | `amount` mantém o sentido bruto; o que for "a pagar" migra para `remaining_amount`, e cada SPEC lista seus pontos de uso |

## Decisões relacionadas

- **AYD-004** — o import de fatura. Este AYD revisa a camada 1 (prompt) e estende as camadas 2
  e 3 de §"Itens que não pertencem à fatura"; o AYD-004 aponta para cá.
- **AYD-003 / AYD-005 (planejamentos)** — o recorte de "realizado" exclui pagamento de fatura;
  passa a excluir o conjunto `invoice_payment` + `invoice_advance_payment` (Decisão 2).
- **Nenhum ADR aplicável:** não há serviço nem integração nova.

## Fora de escopo / questões em aberto

- [x] **Saldo credor — decidido (nov/2026): proibido.** Adiantar o valor que falta ou mais é
      rejeitado (`advance_payment_settles_invoice`), mesmo que o banco aceite e gere crédito.
      Quitar é pelo `pay`; crédito na fatura seguinte não existe no app.
- [x] **Origem do pagamento — decidido (nov/2026):** botão manual ou import do extrato
      bancário. O import da fatura do cartão só filtra as linhas de pagamento (Decisões 8 e 9).
- [x] **Desempate pelo total no import da fatura — aprovado (nov/2026).**
- [ ] **Fatura anterior parcialmente paga** (sobra rolada pelo banco): a linha de resumo
      "Total da fatura anterior" diferente do pagamento dela não é tratada. O app modela isso
      via `invoice_remainder`, mas o import não reconcilia.
- [ ] **Extrato com pagamento de fatura já quitada no app pelo botão:** hoje vai para
      `skipped`. Avaliar se a revisão deve avisar antes do confirm.
- **Não confundir com "antecipação de parcelas"** (quitar parcelas futuras de uma compra com
  desconto): conceito bancário distinto, fora deste AYD.
