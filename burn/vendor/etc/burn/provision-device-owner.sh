#!/system/bin/sh
# burnOS — one-shot device owner + secure-settings grant on first boot (fresh device, no accounts).
set -eu

MARKER=/data/system/burn_device_owner_done
PKG=com.burner.tel
ADMIN=com.burner.tel/com.burn.app.service.BurnDeviceAdminReceiver
LOG_TAG=burn-provision

if [ -f "$MARKER" ]; then
  exit 0
fi

log -t "$LOG_TAG" "starting burn device owner provisioning"

pm grant "$PKG" android.permission.WRITE_SECURE_SETTINGS 2>/dev/null || true

if cmd device_policy set-device-owner "$ADMIN" 2>/dev/null; then
  log -t "$LOG_TAG" "device owner set: $ADMIN"
  touch "$MARKER"
  exit 0
fi

# Retry once after a short delay (package manager may still be settling).
sleep 5
if cmd device_policy set-device-owner "$ADMIN" 2>/dev/null; then
  log -t "$LOG_TAG" "device owner set on retry: $ADMIN"
  touch "$MARKER"
  exit 0
fi

log -t "$LOG_TAG" "device owner not set — device may have accounts or another owner"
exit 0
