#!/system/bin/sh
# burnOS — apply dark mode, USB charging-only, and related defaults on first boot.
set -eu

MARKER=/data/system/burn_system_defaults_done
LOG_TAG=burn-defaults

if [ -f "$MARKER" ]; then
  exit 0
fi

log -t "$LOG_TAG" "applying burnOS system defaults"

# Dark mode (backup if framework overlay is not enough on first boot).
settings put secure ui_night_mode 2 2>/dev/null || true

# USB: charging only — no data transfer when cable connected / screen unlocked.
svc usb setScreenUnlockedFunctions "" 2>/dev/null || true
svc usb setFunctions "" 2>/dev/null || true

# Keep ADB off until user enables Developer options.
settings put global adb_enabled 0 2>/dev/null || true
settings put secure adb_enabled 0 2>/dev/null || true

touch "$MARKER"
log -t "$LOG_TAG" "done"
