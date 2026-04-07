# Schritt-für-Schritt: GitHub Repo einrichten & Unraid verbinden

## Teil 1 – GitHub Repository befüllen

### Option A: Per Git auf eurem PC (empfohlen)

```bash
# 1. ZIP entpacken und in den Ordner wechseln
cd kw-suitecrm

# 2. Git initialisieren
git init
git branch -M main

# 3. Remote setzen (euer Repo)
git remote add origin https://github.com/1899nils/kw-suitecrm.git

# 4. Alle Dateien hinzufügen
git add .
git commit -m "Initial: SuiteCRM 8.7.1 Docker Setup"

# 5. Pushen
git push -u origin main
```

Nach dem Push startet GitHub Actions automatisch und baut das Image.
Das dauert ~5-10 Minuten. Ihr seht den Fortschritt unter:
https://github.com/1899nils/kw-suitecrm/actions

---

## Teil 2 – Image öffentlich zugänglich machen (einmalig)

Nach dem ersten Build müsst ihr das Package auf ghcr.io einmal öffentlich schalten:

1. Geht auf https://github.com/1899nils?tab=packages
2. Klickt auf "kw-suitecrm"
3. Rechts: "Package settings"
4. Ganz unten: "Change visibility" → "Public"

---

## Teil 3 – Unraid einrichten

### Per SSH auf Unraid verbinden
```bash
ssh root@<EURE-UNRAID-IP>
```

### Repo direkt auf Unraid klonen
```bash
cd /mnt/user/appdata
git clone https://github.com/1899nils/kw-suitecrm.git
cd kw-suitecrm

# .env aus dem Beispiel erstellen
cp .env.example .env
```

### .env Passwörter setzen
```bash
nano .env
```
Alle Werte mit `Aendern_` durch echte, sichere Passwörter ersetzen!

### Starten
```bash
# Image von ghcr.io holen
docker compose pull

# Container starten
docker compose up -d

# Logs beobachten
docker logs -f suitecrm
```

---

## Teil 4 – SuiteCRM Installation im Browser

1. `http://<UNRAID-IP>:8080` öffnen
2. Installations-Assistent folgen
3. Datenbankverbindung:
   - **Host:** `mariadb`  ← wichtig, nicht die IP!
   - **Datenbank:** `suitecrm`
   - **Benutzer:** `suitecrm_user`
   - **Passwort:** (euer Passwort aus .env)
4. Admin-Konto anlegen
5. Fertig!

---

## Teil 5 – Spätere Updates (so einfach wird's)

Wenn SuiteCRM eine neue Version released (z.B. 8.8.0):

**Auf eurem PC:**
```bash
# Repo holen
git clone https://github.com/1899nils/kw-suitecrm.git
cd kw-suitecrm

# Dockerfile öffnen und Version ändern:
# ARG SUITECRM_VERSION=8.7.1
#                      ↓ ändern auf:
# ARG SUITECRM_VERSION=8.8.0

nano Dockerfile

# Committen und pushen
git add Dockerfile
git commit -m "Update SuiteCRM 8.7.1 → 8.8.0"
git push
```

GitHub Actions baut jetzt automatisch ein neues Image.

**Auf Unraid:**
```bash
cd /mnt/user/appdata/kw-suitecrm

# Neues Image holen und Container neustarten
docker compose pull
docker compose up -d

# SuiteCRM Upgrade-Assistent im Browser durchlaufen
# http://<UNRAID-IP>:8080/index.php?module=Administration&action=UpgradeWizard
```

> ⚠️ Vor jedem Update: Datenbank-Backup erstellen!
> ```bash
> docker exec suitecrm-db sh -c \
>   'mysqldump -u root -p"$MARIADB_ROOT_PASSWORD" suitecrm' \
>   > /mnt/user/appdata/suitecrm/backup_$(date +%Y%m%d_%H%M).sql
> ```
