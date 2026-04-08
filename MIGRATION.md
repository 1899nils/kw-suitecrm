# SuiteCRM 7 Migration (Unraid)

Ziel: altes SuiteCRM-7-Backup (`suitecrm.sql.gz` + `suitecrmfilebackup.tar.gz`)
auf einem neuen Unraid-Server als Container wieder aufsetzen.

## 1. Unraid-Container anlegen

In der Unraid Docker-UI einen **neuen** Container anlegen (zusaetzlich
zum vorhandenen Suite-8-Container – NICHT den bestehenden aendern):

| Feld | Wert |
|---|---|
| Name | `suitecrm7` |
| Repository | `ghcr.io/1899nils/kw-suitecrm:7` |
| Network Type | `suitecrm-network` (gleiches wie MariaDB-Official) |
| Port | Host `8081` → Container `80` |
| Volume | `/mnt/user/appdata/suitecrm7/app` → `/var/www/html` |

**Env-Variablen:**
- `TZ = Europe/Berlin`
- `SITE_URL = http://SERVER-IP:8081`

Container starten. Beim ersten Start kopiert das Image eine leere Suite 7
Baseline ins Volume. Die wird gleich ueberschrieben.

## 2. Backup-Dateien nach Unraid kopieren

Beide Dateien liegen bereits in `/mnt/user/appdata/suitecrm/backup/`:
- `suitecrm.sql.gz`
- `suitecrmfilebackup.tar.gz`

## 3. Container stoppen (Dateien werden gleich ausgetauscht)

```bash
docker stop suitecrm7
```

## 4. Volume leeren und Backup entpacken

```bash
# Alte Baseline weg
rm -rf /mnt/user/appdata/suitecrm7/app/*
rm -rf /mnt/user/appdata/suitecrm7/app/.[!.]*

# Backup entpacken (vorher Struktur pruefen!)
tar -tzf /mnt/user/appdata/suitecrm/backup/suitecrmfilebackup.tar.gz | head -5
```

**Je nach Ausgabe des `head -5`:**

- Wenn die Pfade mit `./` oder `config.php` direkt anfangen:
  ```bash
  tar -xzf /mnt/user/appdata/suitecrm/backup/suitecrmfilebackup.tar.gz \
    -C /mnt/user/appdata/suitecrm7/app/
  ```
- Wenn sie mit einem Unterordner wie `public_html/` oder `suitecrm/` anfangen:
  ```bash
  tar -xzf /mnt/user/appdata/suitecrm/backup/suitecrmfilebackup.tar.gz \
    -C /mnt/user/appdata/suitecrm7/app/ --strip-components=1
  ```

## 5. Datenbank anlegen und importieren

```bash
# Neue DB fuer das alte System (separat von der Suite-8-DB!)
docker exec -i MariaDB-Official mysql -uroot -p'ROOTPW' -e \
  "CREATE DATABASE suitecrm7 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER IF NOT EXISTS 'suitecrm7_user'@'%' IDENTIFIED BY 'DBPW';
   GRANT ALL PRIVILEGES ON suitecrm7.* TO 'suitecrm7_user'@'%';
   FLUSH PRIVILEGES;"

# Dump einspielen
zcat /mnt/user/appdata/suitecrm/backup/suitecrm.sql.gz | \
  docker exec -i MariaDB-Official mysql -uroot -p'ROOTPW' suitecrm7
```

`ROOTPW` und `DBPW` durch eigene Werte ersetzen.

## 6. config.php anpassen

Die `config.php` aus dem Backup zeigt noch auf die alte Umgebung
(Webhoster DB, alte URL). Anpassen:

```bash
nano /mnt/user/appdata/suitecrm7/app/config.php
```

Folgende Werte setzen:
```php
'db_host_name' => 'MariaDB-Official',
'db_user_name' => 'suitecrm7_user',
'db_password'  => 'DBPW',
'db_name'      => 'suitecrm7',
'site_url'     => 'http://SERVER-IP:8081',
'cache_dir'    => 'cache/',
'tmp_dir'      => '/var/www/html/tmp/',
'upload_dir'   => 'upload/',
```

Falls vorhanden auch `config_override.php` pruefen (`$sugar_config['site_url']`).

## 7. Caches leeren

```bash
rm -rf /mnt/user/appdata/suitecrm7/app/cache/*
```

## 8. Container starten

```bash
docker start suitecrm7
```

Das Entrypoint-Script setzt automatisch die Berechtigungen neu.
Im Log pruefen:
```bash
docker logs -f suitecrm7
```

## 9. Im Browser oeffnen und einloggen

`http://SERVER-IP:8081`

Login mit den **alten** Admin-Credentials aus dem Webhoster-System.
Suite 7 nutzt MD5 – die Hashes aus dem Dump funktionieren direkt.

Falls das Admin-Passwort nicht mehr bekannt ist:
```bash
docker exec MariaDB-Official mysql -uroot -p'ROOTPW' suitecrm7 -e \
  "UPDATE users SET user_hash=MD5('NEUES_PW') WHERE user_name='admin';"
```

## 10. Reparatur & Rebuild im Admin-Menue

Nach dem ersten Login:
1. Admin → **Reparieren** → "Quick Repair and Rebuild" ausfuehren
2. Unten auf der Ergebnisseite ggf. **"Execute"** klicken (DB-Schema angleichen)

## 11. Sobald alles laeuft: Upgrade auf Suite 8

Das machen wir separat. Erstmal alten Stand sauber zum Laufen bringen,
testen dass alle Daten/Module da sind. Upgrade-Schritt kommt danach.
