#!/bin/bash

SUITECRM_DIR="/var/www/html"
SUITECRM_SOURCE="/opt/suitecrm-source"

echo "============================================="
echo " SuiteCRM 7 Docker (Legacy) – kw-suitecrm"
echo " Version: ${SUITECRM_VERSION}"
echo "============================================="

# ── Dateien ins Volume kopieren (nur wenn leer) ──────────────
# Baseline-Installation; wird ueberschrieben sobald das echte
# Backup (tar.gz) in das Volume entpackt wird.
if [ ! -f "${SUITECRM_DIR}/include/entryPoint.php" ] && [ ! -f "${SUITECRM_DIR}/install.php" ]; then
    echo "[INFO] Kopiere SuiteCRM 7 Baseline ins Volume..."
    cp -r "${SUITECRM_SOURCE}/." "${SUITECRM_DIR}/"
    echo "[INFO] Kopieren abgeschlossen."
fi

# ── Temp-Dir (fuer sys_temp_dir in php.ini) ─────────────────
# Wichtig auf Unraid-Bindmounts: rename() scheitert sonst
# cross-device und legacy Cache-Dateien werden korrupt.
mkdir -p "${SUITECRM_DIR}/tmp"
chown www-data:www-data "${SUITECRM_DIR}/tmp"
chmod 775 "${SUITECRM_DIR}/tmp"

# ── Berechtigungen IMMER setzen (nicht nur beim ersten Start) ─
# Backups werden als root entpackt, Cache-/Upload-Ordner
# muessen aber von www-data beschreibbar sein.
echo "[INFO] Setze Berechtigungen..."
chown -R www-data:www-data "${SUITECRM_DIR}"
find "${SUITECRM_DIR}" -type d -exec chmod 775 {} \;
find "${SUITECRM_DIR}" -type f -exec chmod 664 {} \;
# config.php & .htaccess schreibbar halten (Suite 7 updated die)
[ -f "${SUITECRM_DIR}/config.php" ] && chmod 664 "${SUITECRM_DIR}/config.php"
[ -f "${SUITECRM_DIR}/config_override.php" ] && chmod 664 "${SUITECRM_DIR}/config_override.php"
[ -f "${SUITECRM_DIR}/.htaccess" ] && chmod 664 "${SUITECRM_DIR}/.htaccess"
echo "[INFO] Berechtigungen gesetzt."

# ── Cron für Scheduler ──────────────────────────────────────
echo "* * * * * www-data cd ${SUITECRM_DIR}; php -f ${SUITECRM_DIR}/cron.php > /dev/null 2>&1" \
    > /etc/cron.d/suitecrm
chmod 0644 /etc/cron.d/suitecrm
cron

echo "[INFO] ============================================="
echo "[INFO] Bereit! Oeffne ${SITE_URL:-http://localhost}"
echo "[INFO] Hinweis: Dieses Image ist nur fuer Migration"
echo "[INFO] von SuiteCRM 7. Siehe MIGRATION.md"
echo "[INFO] ============================================="

exec "$@"
