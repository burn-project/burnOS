#!/system/bin/sh
# burnOS — register extra F-Droid repos on first boot (Guardian Project, etc.).
set -eu

MARKER=/data/system/burn_fdroid_repos_done
CONF=/product/etc/burn/fdroid-extra-repos.conf
LOG_TAG=burn-fdroid

if [ -f "$MARKER" ]; then
  exit 0
fi

if ! pm path org.fdroid.fdroid >/dev/null 2>&1; then
  log -t "$LOG_TAG" "F-Droid not installed yet"
  exit 0
fi

if [ ! -f "$CONF" ]; then
  log -t "$LOG_TAG" "missing $CONF"
  exit 0
fi

log -t "$LOG_TAG" "adding extra F-Droid repositories"

while IFS= read -r repo || [ -n "$repo" ]; do
  case "$repo" in
    ''|'#'*) continue ;;
  esac
  log -t "$LOG_TAG" "repo: $repo"
  am start -a android.intent.action.VIEW \
    -c android.intent.category.BROWSABLE \
    -d "$repo" \
    -n org.fdroid.fdroid/org.fdroid.fdroid.views.repos.AddRepoActivity \
    >/dev/null 2>&1 || true
  sleep 2
done < "$CONF"

am broadcast -a org.fdroid.action.UPDATE_REPOS org.fdroid.fdroid >/dev/null 2>&1 || true
touch "$MARKER"
log -t "$LOG_TAG" "done"
