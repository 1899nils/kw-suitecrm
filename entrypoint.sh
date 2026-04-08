#!/bin/bash

SUITECRM_DIR="/var/www/html"
SUITECRM_SOURCE="/opt/suitecrm-source"
INSTALL_FLAG="${SUITECRM_DIR}/.suitecrm_installed"

echo "============================================="
echo " SuiteCRM Docker – kw-suitecrm"
echo " Version: ${SUITECRM_VERSION}"
echo "============================================="

# ── Dateien ins Volume kopieren (nur beim ersten Start) ──────
if [ ! -f "${SUITECRM_DIR}/bin/console" ]; then
    echo "[INFO] Kopiere SuiteCRM Dateien ins Volume..."
    cp -r "${SUITECRM_SOURCE}/." "${SUITECRM_DIR}/"
    echo "[INFO] Kopieren abgeschlossen."
fi

# ── Temp-Dir (fuer sys_temp_dir in php.ini) ─────────────────
mkdir -p "${SUITECRM_DIR}/tmp"
chown www-data:www-data "${SUITECRM_DIR}/tmp"
chmod 775 "${SUITECRM_DIR}/tmp"

# ── Berechtigungen IMMER setzen (nicht nur beim ersten Start) ─
# Installer/Updates schreiben als root, Cache-/Vardef-Dateien
# muessen aber von www-data schreibbar sein. Daher bei jedem
# Start neu durchziehen.
echo "[INFO] Setze Berechtigungen..."
chown -R www-data:www-data "${SUITECRM_DIR}"
find "${SUITECRM_DIR}" -type d -exec chmod 775 {} \;
find "${SUITECRM_DIR}" -type f -exec chmod 664 {} \;
echo "[INFO] Berechtigungen gesetzt."

# ── Automatische Installation (wenn Env-Vars gesetzt) ────────
if [ ! -f "${INSTALL_FLAG}" ] && [ -n "${DB_USER}" ] && [ -n "${DB_PASSWORD}" ] && [ -n "${ADMIN_PASSWORD}" ]; then
    DB_HOST="${DB_HOST:-suitecrm-db}"
    DB_PORT="${DB_PORT:-3306}"
    DB_NAME="${DB_NAME:-suitecrm}"
    ADMIN_USER="${ADMIN_USER:-admin}"
    SITE_URL="${SITE_URL:-http://localhost}"

    echo "[INFO] Warte auf Datenbank (${DB_HOST}:${DB_PORT})..."
    until php -r "new PDO('mysql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_NAME}', '${DB_USER}', '${DB_PASSWORD}');" 2>/dev/null; do
        echo "[INFO] Datenbank noch nicht bereit – warte 5 Sekunden..."
        sleep 5
    done
    echo "[INFO] Datenbank bereit."

    echo "[INFO] Starte automatische SuiteCRM Installation..."
    if php "${SUITECRM_DIR}/bin/console" suitecrm:app:install \
        --db_host="${DB_HOST}" \
        --db_port="${DB_PORT}" \
        --db_username="${DB_USER}" \
        --db_password="${DB_PASSWORD}" \
        --db_name="${DB_NAME}" \
        --site_host="${SITE_URL}" \
        --site_username="${ADMIN_USER}" \
        --site_password="${ADMIN_PASSWORD}" \
        -n; then

        echo "[INFO] Installation abgeschlossen."

        # SuiteCRM-8-Installer legt bcrypt-Hash an, der Legacy-Login
        # erwartet aber plain MD5. Daher das Passwort nachtraeglich
        # direkt als MD5 in die DB schreiben.
        echo "[INFO] Setze Admin-Passwort als MD5 (Legacy-kompatibel)..."
        ADMIN_MD5=$(php -r "echo md5('${ADMIN_PASSWORD}');")
        php -r "
            \$pdo = new PDO('mysql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_NAME}', '${DB_USER}', '${DB_PASSWORD}');
            \$stmt = \$pdo->prepare('UPDATE users SET user_hash = ? WHERE user_name = ?');
            \$stmt->execute(['${ADMIN_MD5}', '${ADMIN_USER}']);
        " && echo "[INFO] Admin-Passwort gesetzt."

        # Permissions nach Install nochmal setzen (Installer schreibt als root)
        chown -R www-data:www-data "${SUITECRM_DIR}"
        find "${SUITECRM_DIR}" -type d -exec chmod 775 {} \;
        find "${SUITECRM_DIR}" -type f -exec chmod 664 {} \;

        echo "installed" > "${INSTALL_FLAG}"
    else
        echo "[WARN] Installation fehlgeschlagen – prüfe die Logs"
    fi

elif [ -f "${INSTALL_FLAG}" ]; then
    echo "[INFO] SuiteCRM bereits installiert, überspringe Installation."
else
    echo "[INFO] Keine DB/Admin Env-Vars gesetzt – bitte Web-Installer unter http://<IP>:8080 nutzen."
fi

# ── OAuth2 API-Keys generieren ──────────────────────────────
OAUTH_DIR="${SUITECRM_DIR}/public/legacy/Api/V8/OAuth2"
if [ -d "${OAUTH_DIR}" ] && [ ! -f "${OAUTH_DIR}/private.key" ]; then
    echo "[INFO] Generiere OAuth2 Keys für API v8..."
    openssl genrsa -out "${OAUTH_DIR}/private.key" 2048
    openssl rsa -in "${OAUTH_DIR}/private.key" -pubout -out "${OAUTH_DIR}/public.key"
    chmod 600 "${OAUTH_DIR}/private.key"
    chmod 644 "${OAUTH_DIR}/public.key"
    chown www-data:www-data "${OAUTH_DIR}/private.key" "${OAUTH_DIR}/public.key"
fi

# ── Cron für Scheduler ──────────────────────────────────────
echo "* * * * * www-data php -f ${SUITECRM_DIR}/public/legacy/cron.php > /dev/null 2>&1" \
    > /etc/cron.d/suitecrm
chmod 0644 /etc/cron.d/suitecrm
cron

echo "[INFO] ============================================="
echo "[INFO] Bereit! Öffne ${SITE_URL:-http://localhost}"
echo "[INFO] ============================================="

exec "$@"
