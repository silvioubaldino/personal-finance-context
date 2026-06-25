---
id: REQ-001
type: requirements
title: Requisitos do produto
status: draft
created: 2025-01-01
updated: 2026-06-25
owner: Silvio Ubaldino
parents: [PROD-001]
children: []
related: [GLO]
tags: []
superseded_by: null
---

# Requisitos

> Produto já em produção. Esta versão documenta os requisitos **já construídos e em uso**
> (extraídos da análise do código), não um MVP por lançar. `children` fica vazio até existirem
> `AYD`s reais por feature — hoje só existe o `AYD-001` de exemplo no scaffold.

## Funcionais (RF)
| ID | Requisito | Prioridade (MoSCoW) | Critério de aceite |
|----|-----------|---------------------|--------------------|
| RF-01 | Registrar `Movement` (entrada/saída) com valor, data, `Wallet` e `Category`/`Subcategory` | Must | Usuário cria um `Movement` em poucos cliques; categoria e subcategoria são obrigatórias; pode marcar como pago ou pendente |
| RF-02 | Controlar `Wallet`s e visualizar `Balance` | Must | Usuário cria/edita/exclui `Wallet`s; `Balance` reflete a soma dos `Movement`s pagos |
| RF-03 | Transferir valores entre `Wallet`s (`Transfer`) | Must | A transferência gera duas `Movement`s ligadas por `pair_id`, sem afetar entradas/saídas do período |
| RF-04 | Criar `Movement`s recorrentes | Must | `RecurrentMovement` gera `Movement`s futuros automaticamente conforme periodicidade configurada |
| RF-05 | Planejar (`Estimate`) por `Category`/`Subcategory` e comparar com o realizado | Must | Usuário define meta de valor por categoria/mês; app mostra realizado vs. planejado |
| RF-06 | Controlar `CreditCard`, parcelamento e `Invoice` | Must | Compra parcelada distribui valores nas faturas seguintes; a fatura só afeta o `Balance` da `Wallet` quando paga |
| RF-07 | Importar extrato/fatura (`Statement`) via IA, com deduplicação | Must | Usuário envia PDF/foto; o sistema extrai `Movement`s candidatos e evita duplicidade por hash valor+data+descrição |
| RF-08 | Conversar com o `Agent` de IA sobre os próprios gastos | Must | Usuário faz perguntas em chat; o `Agent` responde com base no histórico real e em `AgentMemory` (sem PII) |
| RF-09 | Assinar o plano `plus` e remover `Limits` de uso | Must | Usuário `free` tem `Limits` (`Wallet`s, `CreditCard`s, `Movement`s/mês, recorrências/mês); ao assinar via Stripe (web) ou RevenueCat (mobile), os limites somem |
| RF-10 | Autenticar via Firebase (e-mail/senha ou Google) | Must | Usuário só acessa o app após login via Firebase Auth; dados isolados por `user_id` |
| RF-11 | Registrar consentimento de termos/privacidade (`UserConsent`, LGPD) | Must | Toda conta nova registra versão do termo aceito, IP e User-Agent |
| RF-12 | Excluir conta e dados (direito ao esquecimento) | Must | Fluxo apaga `Movement`s, `Wallet`s, `AgentMemory` e faturas do usuário |
| RF-13 | Receber push notifications | Should | Usuário recebe notificações nos `Device`s registrados |
| RF-14 | Exportar dados financeiros | Could | Usuário gera um arquivo para download com seus dados |

## Não-funcionais (RNF)
| ID | Categoria | Requisito | Alvo |
|----|-----------|-----------|------|
| RNF-01 | UX / Performance | Ações principais (lançar, transferir, planejar) levam poucos cliques | Sem meta numérica definida ainda |
| RNF-02 | Segurança | Dados financeiros isolados por usuário; comunicação via TLS; tokens via Firebase Auth | 100% das queries multi-tenant escopadas por `user_id` |
| RNF-03 | Privacidade (LGPD) | `Agent` nunca armazena PII (CPF, e-mail, IP) em memória de longo prazo | 0 ocorrências de PII em `AgentMemory` |
| RNF-04 | Disponibilidade | API disponível para uso diário do app | Meta formal pendente (depende de uma decisão de observabilidade ainda não formalizada como ADR) |

## Regras de negócio
- RN-01: Toda `Movement` deve ter `Category` e `Subcategory` (obrigatório para relatórios e `Estimate`).
- RN-02: `Movement` em `CreditCard` não afeta o `Balance` da `Wallet` — só impacta quando a `Invoice` correspondente é paga.
- RN-03: Usuários do plano `free` têm `Limits` (padrão: 2 `Wallet`s, 1 `CreditCard`, 50 `Movement`s/mês, 3 recorrências/mês — configuráveis); usuários `plus` não têm limite.
- RN-04: `Transfer` é sempre duas `Movement`s ligadas por `pair_id` (uma saída, uma entrada) e nunca conta como entrada/saída isolada no resultado do período.
- RN-05: Cancelamento de `Subscription` mantém acesso `plus` até o fim do ciclo de cobrança vigente (downgrade gracioso).

## Restrições
- Dados isolados por usuário (multi-tenant) em todas as consultas.
- Conformidade com a LGPD (consentimento, direito ao esquecimento, auditoria de decisões automatizadas de IA).
- Gateways de pagamento: Stripe (web), RevenueCat/IAP (mobile); Mercado Pago mantido só para assinantes legados.

## Escopo do MVP
> Não é um MVP por lançar — é o recorte do que já está em produção. Revisar quando `ROAD-001`
> for estruturado.
- **Dentro:** RF-01 a RF-12.
- **Fora (por enquanto):** a definir junto ao roadmap — ainda não estruturado.
