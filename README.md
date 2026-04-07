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

## SuiteCRM updaten

1. In `Dockerfile` die Zeile `ARG SUITECRM_VERSION=8.7.1` auf die neue Version ändern
2. Commit & Push auf `main`
3. GitHub Actions baut automatisch ein neues Image
4. Auf Unraid: `docker compose pull && docker compose up -d`

## Unraid Setup

### 1. Repo klonen (einmalig)
```bash
cd /mnt/user/appdata
git clone https://github.com/1899nils/kw-suitecrm.git
cd kw-suitecrm
```

### 2. `.env` anlegen
```bash
cp .env.example .env
nano .env   # Passwörter anpassen!
```

### 3. Starten
```bash
docker compose pull
docker compose up -d
```

### 4. Installation abschließen
Browser öffnen: `http://<UNRAID-IP>:8080`

> **DB-Host beim Installer:** `mariadb`

## Nützliche Befehle

```bash
# Logs anzeigen
docker logs -f suitecrm

# Update auf neue Image-Version
docker compose pull && docker compose up -d

# Backup der Datenbank
docker exec suitecrm-db sh -c \
  'mysqldump -u root -p"$MARIADB_ROOT_PASSWORD" suitecrm' \
  > backup_$(date +%Y%m%d).sql

# Neu einloggen in Container
docker exec -it suitecrm bash
```

## Daten auf Unraid

```
/mnt/user/appdata/suitecrm/
├── app/   → SuiteCRM Dateien & Uploads
└── db/    → MariaDB Datenbank
```
