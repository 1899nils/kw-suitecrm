# SuiteCRM auf Unraid installieren

## Voraussetzung – Image bauen (einmalig)

### 1. dev → main mergen
1. Gehe auf https://github.com/1899nils/kw-suitecrm
2. Klicke auf **"Compare & pull request"** für den `dev` Branch
3. **"Merge pull request"** → **"Confirm merge"**
4. Gehe auf **Actions** Tab → warte bis der Build grün ist (~5–10 Min)

### 2. Image öffentlich schalten (einmalig)
1. Gehe auf https://github.com/1899nils?tab=packages
2. Klicke auf **kw-suitecrm**
3. Rechts: **"Package settings"**
4. Ganz unten: **"Change visibility"** → **"Public"** → bestätigen

---

## Schritt 1 – MariaDB Container anlegen

Unraid → **Docker** → **"Container hinzufügen"**

| Feld | Wert |
|------|------|
| Name | `suitecrm-db` |
| Quelle | `mariadb:11` |
| Netzwerktyp | Bridge |

**Pfad hinzufügen:**

| Container Pfad | Host Pfad |
|----------------|-----------|
| `/var/lib/mysql` | `/mnt/user/appdata/suitecrm/db` |

**Variablen hinzufügen:**

| Schlüssel | Wert |
|-----------|------|
| `MARIADB_ROOT_PASSWORD` | `DeinRootPasswort123!` |
| `MARIADB_DATABASE` | `suitecrm` |
| `MARIADB_USER` | `suitecrm_user` |
| `MARIADB_PASSWORD` | `DeinDBPasswort456!` |
| `MARIADB_CHARACTER_SET` | `utf8mb4` |
| `MARIADB_COLLATE` | `utf8mb4_unicode_ci` |

→ **Anwenden**

---

## Schritt 2 – SuiteCRM Container anlegen

Unraid → **Docker** → **"Container hinzufügen"**

| Feld | Wert |
|------|------|
| Name | `suitecrm` |
| Quelle | `ghcr.io/1899nils/kw-suitecrm:latest` |
| Netzwerktyp | Bridge |

**Port hinzufügen:**

| Container Port | Host Port | Protokoll |
|----------------|-----------|-----------|
| `80` | `8080` | TCP |

**Pfad hinzufügen:**

| Container Pfad | Host Pfad |
|----------------|-----------|
| `/var/www/html` | `/mnt/user/appdata/suitecrm/app` |

**Variable hinzufügen:**

| Schlüssel | Wert |
|-----------|------|
| `TZ` | `Europe/Berlin` |

→ **Anwenden**

---

## Schritt 3 – SuiteCRM im Browser installieren

1. `http://<UNRAID-IP>:8080` öffnen
2. Installations-Assistent folgen
3. Datenbankverbindung:

| Feld | Wert |
|------|------|
| Host | `suitecrm-db` |
| Datenbank | `suitecrm` |
| Benutzer | `suitecrm_user` |
| Passwort | *(dein Passwort aus Schritt 1)* |

4. Admin-Konto anlegen → fertig!

---

## SuiteCRM updaten

Wenn eine neue Version erscheint (z.B. 8.8.0):

1. In `Dockerfile` die Zeile `ARG SUITECRM_VERSION=8.7.1` auf die neue Version ändern
2. Commit & Push auf `main` → GitHub Actions baut automatisch ein neues Image
3. Unraid → Docker → `suitecrm` → **"Update"** → Container neustarten
4. SuiteCRM Upgrade-Assistent im Browser durchlaufen:
   `http://<UNRAID-IP>:8080/index.php?module=Administration&action=UpgradeWizard`

> ⚠️ Vor jedem Update Datenbank-Backup erstellen (siehe unten)!

---

## Nützliche Befehle (SSH)

```bash
# Logs beobachten
docker logs -f suitecrm

# Container neustarten
docker restart suitecrm

# Datenbank-Backup erstellen
docker exec suitecrm-db sh -c \
  'mysqldump -u root -p"$MARIADB_ROOT_PASSWORD" suitecrm' \
  > /mnt/user/appdata/suitecrm/backup_$(date +%Y%m%d_%H%M).sql

# In Container einloggen
docker exec -it suitecrm bash
```
