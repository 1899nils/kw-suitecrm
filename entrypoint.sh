#!/bin/bash
set -e

SUITECRM_DIR="/var/www/html"
VERSION_FILE="${SUITECRM_DIR}/.suitecrm_version"
DOWNLOAD_URL="https://github.com/salesagility/SuiteCRM-Core/releases/download/v${SUITECRM_VERSION}/SuiteCRM-${SUITECRM_VERSION}.zip"

echo "============================================="
echo " SuiteCRM Docker – kw-suitecrm"
echo " Version: ${SUITECRM_VERSION}"
echo "============================================="

# ── SuiteCRM herunterladen (nur beim ersten Start) ──────────
if [ ! -f "${VERSION_FILE}" ]; then
    echo "[INFO] Erster Start – lade SuiteCRM ${SUITECRM_VERSION} herunter..."
    echo "[INFO] ${DOWNLOAD_URL}"

    curl -L --progress-bar "${DOWNLOAD_URL}" -o /tmp/suitecrm.zip

    echo "[INFO] Entpacke Archiv..."
    unzip -q /tmp/suitecrm.zip -d /tmp/suitecrm_extract

    # GitHub packt manchmal in Unterordner
    EXTRACTED=$(find /tmp/suitecrm_extract -maxdepth 1 -mindepth 1 -type d | head -1)
    if [ -n "$EXTRACTED" ]; then
        cp -r "${EXTRACTED}/." "${SUITECRM_DIR}/"
    else
        cp -r /tmp/suitecrm_extract/. "${SUITECRM_DIR}/"
    fi

    rm -rf /tmp/suitecrm.zip /tmp/suitecrm_extract
    echo "${SUITECRM_VERSION}" > "${VERSION_FILE}"
    echo "[INFO] Download abgeschlossen."
else
    INSTALLED=$(cat "${VERSION_FILE}")
    echo "[INFO] SuiteCRM ${INSTALLED} ist bereits installiert."
fi

# ── Berechtigungen (nur beim ersten Start) ──────────────────
PERMISSIONS_FLAG="${SUITECRM_DIR}/.permissions_set"
if [ ! -f "${PERMISSIONS_FLAG}" ]; then
    echo "[INFO] Setze Berechtigungen..."
    chown -R www-data:www-data "${SUITECRM_DIR}"
    find "${SUITECRM_DIR}" -type d -exec chmod 755 {} \;
    find "${SUITECRM_DIR}" -type f -exec chmod 644 {} \;

    # Schreibrechte für SuiteCRM-Verzeichnisse
    for DIR in \
        "cache" "custom" "modules" "themes" "data" "upload" "logs" \
        "public/legacy/cache" "public/legacy/custom" "public/legacy/modules" \
        "public/legacy/themes" "public/legacy/data" "public/legacy/upload" \
        "public/legacy/logs"; do
        [ -d "${SUITECRM_DIR}/${DIR}" ] && chmod -R 775 "${SUITECRM_DIR}/${DIR}"
    done

    echo "1" > "${PERMISSIONS_FLAG}"
    echo "[INFO] Berechtigungen gesetzt."
else
    echo "[INFO] Berechtigungen bereits gesetzt, überspringe..."
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
echo "[INFO] Bereit! Öffne http://<UNRAID-IP>:8080"
echo "[INFO] DB-Host beim Installer: mariadb"
echo "[INFO] ============================================="

exec "$@"
