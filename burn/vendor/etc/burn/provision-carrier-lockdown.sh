#!/system/bin/sh
# burnOS — deny contacts, phone, media, storage, and backup access for carrier apps.
# Re-runs every boot (and after SIM events) because telephony may re-grant defaults.
set -eu

LOG_TAG=burn-carrier-lock
ADMIN=com.burner.tel/com.burn.app.service.BurnDeviceAdminReceiver

# Core telephony stack — never touch.
EXCLUDE_PKGS="
com.android.phone
com.android.providers.telephony
com.android.providers.contacts
com.android.providers.media
com.android.providers.downloads
com.android.shell
com.android.systemui
com.burner.tel
"

DENY_RUNTIME_PERMS="
android.permission.READ_CONTACTS
android.permission.WRITE_CONTACTS
android.permission.GET_ACCOUNTS
android.permission.READ_CALL_LOG
android.permission.WRITE_CALL_LOG
android.permission.CALL_PHONE
android.permission.READ_PHONE_STATE
android.permission.READ_PHONE_NUMBERS
android.permission.READ_SMS
android.permission.RECEIVE_SMS
android.permission.SEND_SMS
android.permission.RECEIVE_MMS
android.permission.READ_EXTERNAL_STORAGE
android.permission.WRITE_EXTERNAL_STORAGE
android.permission.READ_MEDIA_IMAGES
android.permission.READ_MEDIA_VIDEO
android.permission.READ_MEDIA_AUDIO
android.permission.READ_MEDIA_VISUAL_USER_SELECTED
android.permission.ACCESS_MEDIA_LOCATION
android.permission.MANAGE_EXTERNAL_STORAGE
"

DENY_APPOPS="
READ_CONTACTS
WRITE_CONTACTS
READ_CALL_LOG
WRITE_CALL_LOG
CALL_PHONE
READ_PHONE_STATE
READ_SMS
RECEIVE_SMS
SEND_SMS
READ_EXTERNAL_STORAGE
WRITE_EXTERNAL_STORAGE
READ_MEDIA_IMAGES
READ_MEDIA_VIDEO
READ_MEDIA_AUDIO
"

is_excluded() {
  case " $EXCLUDE_PKGS " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

collect_carrier_pkgs() {
  # Sysconfig entries for carrier apps (product / system / vendor).
  for dir in /product/etc/sysconfig /system/etc/sysconfig /vendor/etc/sysconfig; do
    [ -d "$dir" ] || continue
    for xml in "$dir"/*.xml; do
      [ -f "$xml" ] || continue
      grep -E 'disabled-until-used-carrier-app' "$xml" 2>/dev/null \
        | sed -n 's/.*package="\([^"]*\)".*/\1/p' || true
    done
  done

  # Common OEM / Google carrier packages on Pixel-class devices.
  printf '%s\n' \
    com.android.carrierdefaultapp \
    com.google.android.apps.carrier.carrierwifi \
    com.google.android.carrier \
    com.google.android.carriersetup \
    com.verizon.mips.services \
    com.att.myWireless \
    com.tmobile.pr.adapt \
    com.sprint.ce.updater \
    com.android.omadm.service \
    com.android.sdm.plugins.diagmon \
    com.android.sdm.plugins.dcmo
}

has_device_owner() {
  dpm list-owners 2>/dev/null | grep -q "com.burner.tel" || return 1
}

deny_pkg() {
  pkg="$1"
  if is_excluded "$pkg"; then
    return 0
  fi

  for perm in $DENY_RUNTIME_PERMS; do
    pm revoke --user 0 "$pkg" "$perm" 2>/dev/null || true
    if has_device_owner; then
      cmd device_policy set-permission-grant-state "$ADMIN" "$pkg" "$perm" denied 2>/dev/null || true
    fi
  done

  for op in $DENY_APPOPS; do
    cmd appops set "$pkg" "$op" deny 2>/dev/null || true
  done

  # Block background backup / exfil paths carrier apps sometimes use.
  cmd appops set "$pkg" RUN_IN_BACKGROUND deny 2>/dev/null || true
  cmd appops set "$pkg" RUN_ANY_IN_BACKGROUND deny 2>/dev/null || true
}

log -t "$LOG_TAG" "applying carrier privacy lockdown"

# Legacy Android backup transport (not Seedvault). Carriers must not use cloud backup hooks.
settings put secure backup_enabled 0 2>/dev/null || true
settings put secure backup_auto_restore 0 2>/dev/null || true
bmgr enable false 2>/dev/null || true

# De-dupe package list.
CARRIER_PKGS=""
for pkg in $(collect_carrier_pkgs); do
  case " $CARRIER_PKGS " in
    *" $pkg "*) ;;
    *) CARRIER_PKGS="$CARRIER_PKGS $pkg" ;;
  esac
done

for pkg in $CARRIER_PKGS; do
  if pm path "$pkg" >/dev/null 2>&1; then
    deny_pkg "$pkg"
    log -t "$LOG_TAG" "denied sensitive access: $pkg"
  fi
done

log -t "$LOG_TAG" "done"
