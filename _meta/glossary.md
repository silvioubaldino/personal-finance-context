---
id: GLO
type: glossary
title: Linguagem ubíqua do domínio
status: approved
updated: 2026-06-25
owner: <nome>
related: []
---

# Glossário (Linguagem Ubíqua)

Definições canônicas dos termos do domínio. Toda a documentação e o código — em
**todos os repos** — usam estes termos com este significado. É isto que faz api, web e
mobile "falarem a mesma língua": um termo, uma definição.

> Regra: adicione o termo aqui **antes** de usá-lo em outros docs ou no código.
> **Termo canônico em inglês** (vira código); definição em português. Inclua sinônimos a
> evitar — é onde a ambiguidade costuma virar bug ou contrato confuso.
> (ver `conventions.md` §8 — idioma: docs em PT, código/entidades em EN)

| Termo | Definição | Sinônimos a evitar |
|-------|-----------|--------------------|
| **Movement** _(Movimentação)_ | Registro de uma entrada ou saída de dinheiro: valor, data, `Wallet`, `Category`/`Subcategory` e status `is_paid` (pago/pendente). É a unidade fundamental de dado financeiro do sistema. Pode ser avulsa ou gerada por uma `RecurrentMovement`. | "transação" (reservar para o contexto de `Statement`/pagamento externo), "lançamento contábil", "operação", "registro" |
| **RecurrentMovement** _(Movimentação Recorrente)_ | Regra de periodicidade (ex.: mensal) que gera `Movement`s futuros automaticamente a partir de um template (ex.: salário, assinatura de streaming). | "recorrência" isolada — sempre qualificar como "Movement recorrente" |
| **InternalTransfer** _(Transferência Interna)_ | Movimentação de valor entre duas `Wallet`s do mesmo usuário (`TypePayment: internal_transfer`). Não é uma entidade própria: é modelada como duas `Movement`s ligadas por `pair_id` (uma saída, uma entrada) e não entra no resultado de entradas/saídas do período. | "Transfer" isolado (no código o usecase/rota chama-se `Transfer`, mas o conceito de domínio é interno — reservar "Transfer" para uma eventual transferência externa, ex. Pix/TED), "Movement entre carteiras" |
| **Wallet** _(Carteira)_ | Conta de saldo do usuário (carteira física, conta corrente, poupança) que acumula o `Balance` resultante dos `Movement`s pagos. | "conta" (ambíguo com a conta/login do `User`), "banco" |
| **Balance** _(Saldo)_ | Valor acumulado de uma `Wallet` (ou total) num instante/período, calculado a partir dos `Movement`s pagos. Não é o saldo real do banco — é o saldo controlado dentro do app. | "saldo bancário" |
| **Category** / **Subcategory** _(Categoria / Subcategoria)_ | Classificação hierárquica obrigatória de todo `Movement`, usada em relatórios analíticos e em `Estimate`. | "tag", "grupo", "rótulo" |
| **Estimate** _(Planejamento)_ | Meta de valor planejada para uma `Category` ou `Subcategory` num mês, comparada ao valor realizado dos `Movement`s daquele período. | "orçamento" isolado (o termo de domínio/código é Estimate; "Planejamento" é só o rótulo de UI), "budget" |
| **CreditCard** _(Cartão de Crédito)_ | Meio de pagamento com limite, dia de fechamento e dia de vencimento. `Movement`s feitos no cartão não afetam o `Balance` da `Wallet` imediatamente — só impactam quando a `Invoice` é paga. | "cartão" isolado, sem o contexto de fatura |
| **Invoice** _(Fatura)_ | Agrupamento mensal dos `Movement`s de um `CreditCard`, com período (`period_start`/`period_end`), vencimento (`due_date`) e estado derivado de `is_paid` + datas (não é um enum gravado). Suporta parcelamento — uma compra distribuída em N faturas via `installment_group_id`. | "boleto", "conta a pagar" genérica |
| **Statement** _(Extrato Importado)_ | Arquivo (PDF ou imagem) de extrato bancário enviado pelo usuário; o sistema usa IA/visão computacional para extrair `Movement`s candidatos, com deduplicação por hash de idempotência (valor + data + descrição) antes da importação em lote. | "import" isolado, "upload" isolado |
| **Plan** _(Plano)_ | Nível de acesso do usuário: `free` ou `plus`. `free` tem `Limits` aplicados; `plus` (via `Subscription` ativa) não tem. | "premium" no lugar de "Plus" — o nome canônico do plano pago é **Plus** |
| **Subscription** _(Assinatura)_ | Vínculo do usuário a uma `SubscriptionPlan` paga, com origem (`stripe`, `iap` via RevenueCat/Apple/Google, ou `mp`/Mercado Pago legado), status (`pending`/`active`/`cancelled`/`expired`/`paused`/`past_due`) e período corrente. | — |
| **SubscriptionPlan** _(Plano de Assinatura)_ | Definição comercial de um plano pago: nome, preço, moeda e frequência de cobrança. | "tier" isolado |
| **Limits** _(Limites de Plano)_ | Tetos de uso aplicados a usuários `free`: número de `Wallet`s, `CreditCard`s, `Movement`s/mês e recorrências/mês. | "quota" isolado |
| **Coupon** _(Cupom)_ | Código promocional aplicável no checkout de uma `Subscription` para desconto. | — |
| **Agent** _(Agente IA)_ | Assistente financeiro conversacional baseado em IA generativa (Gemini), que responde perguntas e sugere economias com base no histórico real do usuário. | "chatbot" genérico, "assistente" isolado |
| **AgentMemory** _(Memória do Agente)_ | Fatos financeiros, metas de longo prazo e perfil de risco do usuário, persistidos para contextualizar o `Agent`. Nunca armazena PII (CPF, e-mail, IP). | — |
| **AgentConversation** / **AgentMessage** _(Conversa / Mensagem do Agente)_ | Sessão de chat entre usuário e `Agent`, e cada mensagem trocada dentro dela. | — |
| **User** _(Usuário)_ | Conta autenticada via Firebase Auth; titular dos dados financeiros (`Wallet`s, `Movement`s etc.), isolados por `user_id` em toda consulta. | "conta" (ver nota em `Wallet`) |
| **UserConsent** _(Consentimento do Usuário)_ | Registro do aceite de termos/política de privacidade (LGPD): versão do termo, IP e User-Agent. | — |
| **Device** _(Dispositivo)_ | Registro de um dispositivo móvel do usuário, usado para envio de push notifications. | — |
| **Export** _(Exportação)_ | Geração de um arquivo com os dados financeiros do usuário para download. | — |
