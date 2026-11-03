#!/bin/bash
# Applies the latest settings from this repo and restarts the server.
# Enshrouded itself updates on every container start.
set -euo pipefail

export HOME="${HOME:-/root}"

base=/opt/enshrouded
repo="$base/repo"
config="$base/enshrouded_server.json"
compose=(docker compose --project-name enshrouded --file "$repo/azure/compose.yaml")

# Pull first, then rerun, so the new version of this script applies the changes.
if [ -z "${ENSHROUDED_UPDATE_PULLED:-}" ]; then
  git -C "$repo" pull --ff-only
  ENSHROUDED_UPDATE_PULLED=1 exec "$repo/azure/update.sh"
fi

set -a
# shellcheck source=/dev/null
. "$base/secrets.env"
set +a

if [ -z "${SERVER_PASSWORD:-}" ]; then
  echo "SERVER_PASSWORD is not set in $base/secrets.env, refusing to start a public server" >&2
  exit 1
fi

# The repo is public, so the passwords are only added here, on the VM.
# The Admin group gets its own password, and every other group gets the player password.
if [ -z "${ADMIN_PASSWORD:-}" ]; then
  # An Admin group without its own password would give admin powers to every player.
  echo "ADMIN_PASSWORD is not set in $base/secrets.env, so the Admin group is left out" >&2
  filter='del(.userGroups[] | select(.name == "Admin")) | .userGroups[].password = env.SERVER_PASSWORD'
elif [ "$ADMIN_PASSWORD" = "$SERVER_PASSWORD" ]; then
  echo "ADMIN_PASSWORD must be different from SERVER_PASSWORD" >&2
  exit 1
else
  filter='.userGroups[] |= (.password = if .name == "Admin" then env.ADMIN_PASSWORD else env.SERVER_PASSWORD end)'
fi

tmp=$(mktemp "$base/config.XXXXXX")
trap 'rm -f "$tmp"' EXIT
jq "$filter" "$repo/azure/enshrouded_server.json" > "$tmp"
chown 10000:10000 "$tmp"
chmod 640 "$tmp"
mv -f "$tmp" "$config"

"${compose[@]}" pull
"${compose[@]}" up --detach --force-recreate

cp "$repo/azure/enshrouded-backup.service" "$repo/azure/enshrouded-backup.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable enshrouded-backup.timer
# Restart rather than start, so a changed schedule applies straight away
systemctl restart enshrouded-backup.timer

echo "Update complete"
