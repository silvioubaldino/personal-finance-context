---
id: ARCH
type: architecture
title: Visão de arquitetura (C4 vivo)
status: approved
created: 2025-01-01
updated: 2025-01-01
owner: <nome>
affects: [api, web, mobile]
parents: []
related: [ADR-001]
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
        web["Web app<br/>(Vercel)"]
    end

    api["API<br/>(Cloud Run)"]
    auth["Auth<br/>(Firebase Auth)"]
    db[("Database<br/>(Neon · Postgres)")]

    mobile -->|HTTPS · Bearer ID token| api
    web -->|HTTPS · Bearer ID token| api
    mobile -.->|signup / login| auth
    web -.->|signup / login| auth
    api -->|verifica ID token| auth
    api -->|SQL| db
```

## Containers (legenda)

| Container | Papel | Provedor |
|-----------|-------|----------|
| **Mobile app** | Cliente do `Subscriber`/`PartnerOperator` | React Native / Expo (EAS) |
| **Web app** | Superfície web (ex.: assinatura/landing) | Vercel |
| **API** | Núcleo de domínio; fonte da verdade | Cloud Run |
| **Auth** | Identidade (ID token) | Firebase Auth |
| **Database** | Persistência do domínio | Neon (Postgres) |

> Substitua os containers/provedores acima pela topologia real do seu produto. Mantenha a
> tabela e o diagrama em sincronia — se divergirem, **a tabela vence** (texto sobre desenho,
> `conventions.md` §10).
