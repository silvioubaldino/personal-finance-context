---
id: AYD-001
type: design
title: Upload de mídia (EXEMPLO)
status: draft
created: 2025-01-01
updated: 2025-01-01
owner: <nome>
affects: [api, web, mobile]
parents: [REQ-001]
children: [SPEC-001@api, SPEC-001@web, SPEC-001@mobile]
related: [ADR-001, GLO]
tags: [media]
superseded_by: null
---

# AYD-001: Upload de mídia (EXEMPLO)

> Exemplo preenchido para mostrar o formato cross-repo. Apague num projeto novo.

## Objetivo
Atender RF-01: usuário envia mídia e acompanha o progresso, em web e mobile.

## Repos afetados e papéis
| Repo | Papel nesta feature | SPEC gerada |
|------|---------------------|-------------|
| api    | Gera URL assinada, persiste metadados, valida tipo/tamanho | SPEC-001@api |
| web    | UI de upload com progresso; consome a API | SPEC-001@web |
| mobile | Upload com retomada; restrições de rede/offline | SPEC-001@mobile |

## Contratos (fonte da verdade)
```
POST /media/upload-url
req:  { filename, contentType, sizeBytes }
res:  { uploadUrl, mediaId, expiresAt }
erros: [ 413 too_large, 415 unsupported_type ]
```

## Modelo de domínio afetado
Entidade `Mídia` (ver GLO): id, owner, status(uploading|ready), metadados.

## Fluxo cross-repo
web/mobile pedem URL assinada → upload direto ao storage → api confirma e marca `ready`.

```mermaid
sequenceDiagram
  participant C as Cliente (web/mobile)
  participant A as API
  participant S as Storage
  C->>A: POST /media/upload-url {filename, contentType, sizeBytes}
  A-->>C: { uploadUrl, mediaId, expiresAt }
  C->>S: PUT arquivo (uploadUrl)
  S-->>C: 200 OK
  C->>A: POST /media/{mediaId}/complete
  A->>A: marca Mídia como "ready"
  A-->>C: { status: ready }
```

## Decisões relacionadas
ADR-001 (storage com URL assinada em vez de proxy pela API).

## Fora de escopo / questões em aberto
- [ ] Edição de mídia pós-upload (fora).
