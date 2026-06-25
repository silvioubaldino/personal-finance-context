---
id: PROD-001
type: product
title: Visão & Estratégia
status: draft
created: 2025-01-01
updated: 2026-06-25
owner: Silvio Ubaldino
parents: []
children: [REQ-001]
related: [GLO]
tags: []
superseded_by: null
---

# Produto — Visão & Estratégia

## Problema
Pessoas leigas em organização financeira não sabem para onde vai o seu dinheiro e não têm
clareza sobre sua vida financeira. Extratos bancários e faturas de cartão são trabalhosos de
interpretar, e alternativas manuais (planilhas, apps tradicionais) exigem esforço demais para
serem mantidas no dia a dia.

## Visão (North Star, uma frase)
Todo mundo tem clareza total sobre sua vida financeira, com o mínimo de esforço possível.

## Proposta de valor
O Personal Finance é o "personal trainer" das finanças: traduz extratos e faturas em clareza
automaticamente, com poucos cliques — sem a fricção de planilhas ou apps que exigem lançar e
categorizar tudo manualmente.

## Personas & Jobs To Be Done
| Persona | Contexto | Job (quando… quero… para…) |
|---------|----------|----------------------------|
| Leigo em organização financeira | Não sabe para onde vai o dinheiro; já tentou planilha ou outro app e desistiu pela fricção | Quando recebo um extrato ou fatura, quero entender meus gastos sem digitar nada, para finalmente ter clareza sobre minha vida financeira |

> Ainda não validamos uma persona distinta de "usuário avançado" (quem usa muito cartão/IA) —
> hipótese atual é que é a mesma persona leiga, só que mais madura no uso do app.

## Objetivos (OKRs / métrica North Star)
- Objetivo: Garantir que o app está realmente ajudando as pessoas a ter clareza sobre sua vida financeira.
  - KR1: Conversão de novos usuários (ativação).
  - KR2: Retenção dos usuários atuais.

> Metas numéricas ainda não definidas — ver `ROAD-001` quando o roadmap for estruturado.

## Posicionamento & diferencial
Para quem não tem clareza sobre sua vida financeira e acha outras ferramentas trabalhosas
demais, o Personal Finance é o app de finanças pessoais que transforma extratos e faturas em
clareza automaticamente, com o mínimo de esforço do usuário.

Diferenciais:
- Importação inteligente de extratos e faturas (IA/visão computacional) em vez de lançamento manual.
- Agente de IA que responde perguntas sobre os próprios gastos e sugere economias com base no histórico real.
- Poucos cliques para qualquer ação principal (lançar, transferir, planejar).

## Princípios de produto
- Simplicidade > completude: preferir a ação de menor fricção, mesmo cobrindo menos casos de borda.
- Automação tira trabalho do usuário: se um dado pode ser inferido por IA (extrato, fatura,
  categorização), o usuário não deveria precisar digitá-lo.

## O que NÃO é (anti-escopo)
- Não é um banco ou meio de pagamento: não movimenta dinheiro real do usuário, só controla.
- Não é uma ferramenta de contabilidade empresarial — foco é finanças pessoais/domésticas.
- Não é consultoria de investimentos: o Agente de IA dá clareza sobre gastos e sugestões de
  economia, não recomendação de investimento.
