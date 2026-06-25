---
id: ARCH
type: architecture
title: Visão de arquitetura (C4 vivo)
status: approved
created: 2025-01-01
updated: 2026-06-25
owner: Silvio Ubaldino
affects: [api, web, mobile]
parents: []
related: [GLO]
tags: [architecture, c4]
superseded_by: null
---

# Visão de arquitetura (C4 — contexto + containers)

> **Documento vivo.** Retrata a topologia **vigente** do produto: quais serviços existem,
> como se conectam e em que provedores rodam. É a foto do "como está hoje", não o histórico
> de decisões — o **porquê** de cada escolha mora nos `ADR`.
>
> **Atualize na mesma edição** que adiciona/remove um serviço ou integração externa
> (ver `_meta/conventions.md` §7 e §10). Ao criar um `ADR` que mude a topologia, atualize o
> diagrama abaixo no mesmo PR.
>
> Nomes de serviços/sistemas em **inglês** (atravessam para o código); provedores entre
> parênteses. Diagrama em **Mermaid `flowchart`** (renderiza no GitHub de forma confiável)
> expressando um C4 nível 1–2.

## Diagrama (container view)

```mermaid
flowchart TB
    subgraph clients[Clients]
        mobile["Mobile app<br/>(React Native / Expo · EAS)"]
        web["Web app<br/>(Next.js · Vercel)"]
    end

    subgraph run[Cloud Run]
        api["API<br/>(Go)"]
        otel["OTel Collector<br/>(sidecar)"]
    end

    auth["Auth<br/>(Firebase Auth)"]
    db[("Database<br/>(Neon · Postgres)")]
    ai["Generative AI<br/>(Google Gemini / ADK)"]

    subgraph pay[Gateways de pagamento]
        stripe["Stripe<br/>(assinatura web)"]
        revenuecat["RevenueCat<br/>(IAP mobile · Apple/Google)"]
        mp["Mercado Pago<br/>(legado)"]
    end

    subgraph obs[Observabilidade]
        grafana["Grafana Cloud<br/>(saúde técnica · RED, 14d)"]
        cloudmon["Cloud Monitoring<br/>(KPIs de negócio, 24m)"]
        cloudlog["Cloud Logging<br/>(logs)"]
    end

    mobile -->|"HTTPS · Bearer ID token"| api
    web -->|"HTTPS · Bearer ID token"| api
    mobile -.->|"signup / login"| auth
    web -.->|"signup / login"| auth
    api -->|"verifica ID token"| auth
    api -->|SQL| db
    api -->|"checkout / webhook"| stripe
    mobile -.->|"compra IAP"| revenuecat
    api -->|webhook| revenuecat
    api -->|"webhook"| mp
    api -->|"prompt / vision"| ai

    api -->|OTLP| otel
    otel -->|"histogramas RED"| grafana
    otel -->|"métricas biz_*"| cloudmon
    api -->|stdout| cloudlog
    grafana -.->|datasource| cloudmon
    grafana -.->|datasource| cloudlog
```

> A pilha de observabilidade (OTel Collector + Grafana Cloud + Cloud Monitoring + Cloud
> Logging) já está em produção (ver `CHANGELOG@api` v1.18.0–v1.20.0); a decisão/justificativa
> ainda não foi formalizada como `ADR` — pendente (ver `RNF-04@context`).

## Containers e integrações (legenda)

| Container / Integração | Papel | Provedor |
|-------------------------|-------|----------|
| **Mobile app** | Cliente do `User` no celular | React Native / Expo (EAS) |
| **Web app** | Cliente do `User` no navegador | Next.js (Vercel) |
| **API** | Núcleo de domínio; fonte da verdade | Go (Cloud Run) |
| **OTel Collector** | Sidecar de telemetria; roteia métricas/traces por destino | Cloud Run |
| **Auth** | Identidade (ID token) | Firebase Auth |
| **Database** | Persistência do domínio | Neon (Postgres) |
| **Generative AI** | `Agent` (chat) e extração de `Statement` (visão computacional) | Google Gemini / ADK |
| **Stripe** | Cobrança de `Subscription` no web | Stripe |
| **RevenueCat** | Cobrança de `Subscription` via IAP no mobile (Apple App Store / Google Play) | RevenueCat |
| **Mercado Pago** | Gateway legado; mantido só para assinantes com `Subscription` anterior à migração | Mercado Pago |
| **Grafana Cloud** | Dashboards de saúde técnica (RED/USE); retenção de 14 dias | Grafana Cloud (free tier) |
| **Cloud Monitoring** | KPIs de negócio (`biz_*`); retenção de 24 meses | Google Cloud Monitoring |
| **Cloud Logging** | Logs estruturados da API | Google Cloud Logging |

> Mantenha a tabela e o diagrama em sincronia — se divergirem, **a tabela vence** (texto sobre
> desenho, `conventions.md` §10).
