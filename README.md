# Karaoké 🎤

Sistema de karaokê self-hosted com scoring em tempo real.

## Estrutura

```
karaoke/
├── backend/          # Servidor Python (FastAPI) — roda no Pi 5
└── flutter_app/      # App Android (Flutter) — instala no FireTV
```

## Como funciona

- O **backend** roda no Pi 5 como container Docker
- O **app** é instalado no FireTV via sideload (APK gerado automaticamente pelo GitHub Actions)
- Os microfones bluetooth conectam direto no FireTV
- O pitch detection roda localmente no FireTV e envia o score para o servidor via WebSocket
- Acesso pelo app de qualquer lugar com internet

## Acesso

- **Admin**: login com usuário e senha (gerencia biblioteca, salas, usuários)
- **Convidados**: entram na sala pelo código, sem login

## Setup rápido

### 1. Backend no Pi (Docker)

```bash
docker compose up -d
```

### 2. APK no FireTV

Baixe o APK mais recente em **Releases** e instale via sideload:

```bash
adb connect <ip-do-firetv>
adb install karaoke.apk
```

## Desenvolvimento

Veja `backend/README.md` e `flutter_app/README.md` para instruções detalhadas.
