# kw-suitecrm

SuiteCRM 8 – selbst gehostet auf Unraid via Docker.
Image wird automatisch per GitHub Actions gebaut und auf `ghcr.io` veröffentlicht.

## Stack

| Komponente | Version |
|------------|---------|
| SuiteCRM   | 8.7.1   |
| PHP        | 8.2     |
| Apache     | 2.4     |
| MariaDB    | 11      |

## Installation

Vollständige Anleitung: [SETUP-ANLEITUNG.md](SETUP-ANLEITUNG.md)

**Kurzfassung:**
1. GitHub Actions baut das Image automatisch nach einem Push auf `main`
2. In Unraid zwei Container anlegen: `mariadb:11` + `ghcr.io/1899nils/kw-suitecrm:latest`
3. Browser öffnen → Installations-Assistent folgen

## Container Konfiguration

### SuiteCRM
| Einstellung | Wert |
|-------------|------|
| Image | `ghcr.io/1899nils/kw-suitecrm:latest` |
| Port | `8080 → 80` |
| Volume | `/mnt/user/appdata/suitecrm/app → /var/www/html` |
| Variable | `TZ=Europe/Berlin` |

### MariaDB
| Einstellung | Wert |
|-------------|------|
| Image | `mariadb:11` |
| Volume | `/mnt/user/appdata/suitecrm/db → /var/lib/mysql` |

## Daten auf Unraid

```
/mnt/user/appdata/suitecrm/
├── app/   → SuiteCRM Dateien & Uploads
└── db/    → MariaDB Datenbank
```

## SuiteCRM updaten

1. In `Dockerfile` die Version ändern: `ARG SUITECRM_VERSION=8.x.x`
2. Commit & Push auf `main` → GitHub Actions baut neues Image
3. Unraid → Docker → Container updaten
