#!/bin/bash
# Runs the server on your own Linux machine, with the same settings as Azure.
# Run it again to apply new settings or restart the server.
#   sudo ./home/setup.sh
# Keeps everything in /srv/enshrouded. To use another folder:
#   sudo ENSHROUDED_DATA=/path/to/folder ./home/setup.sh
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
data="${ENSHROUDED_DATA:-/srv/enshrouded}"
export ENSHROUDED_DATA="$data"
secrets="$data/secrets.env"
config="$data/enshrouded_server.json"
compose=(docker compose --project-name enshrouded --file "$repo/home/compose.yaml")

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this with sudo" >&2
  exit 1
fi
for cmd in docker jq; do
  command -v "$cmd" > /dev/null || { echo "$cmd is not installed" >&2; exit 1; }
done

mkdir -p "$data/install" "$data/savegame"
chown 10000:10000 "$data/install"
# Recursive, so a world copied in by hand is writable by the server
chown -R 10000:10000 "$data/savegame"

if [ ! -f "$secrets" ]; then
  install -m 600 /dev/null "$secrets"
  printf "SERVER_PASSWORD=''\nADMIN_PASSWORD=''\n" > "$secrets"
  echo "Created $secrets. Add the passwords to it, then run this again." >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
. "$secrets"
set +a

if [ -z "${SERVER_PASSWORD:-}" ]; then
  echo "SERVER_PASSWORD is not set in $secrets, refusing to start a public server" >&2
  exit 1
fi

# The repo is public, so the passwords are only added here, on this machine.
# The Admin group gets its own password, and every other group gets the player password.
if [ -z "${ADMIN_PASSWORD:-}" ]; then
  # An Admin group without its own password would give admin powers to every player.
  echo "ADMIN_PASSWORD is not set in $secrets, so the Admin group is left out" >&2
  filter='del(.userGroups[] | select(.name == "Admin")) | .userGroups[].password = env.SERVER_PASSWORD'
elif [ "$ADMIN_PASSWORD" = "$SERVER_PASSWORD" ]; then
  echo "ADMIN_PASSWORD must be different from SERVER_PASSWORD" >&2
  exit 1
else
  filter='.userGroups[] |= (.password = if .name == "Admin" then env.ADMIN_PASSWORD else env.SERVER_PASSWORD end)'
fi

tmp=$(mktemp "$data/config.XXXXXX")
trap 'rm -f "$tmp"' EXIT
jq "$filter" "$repo/azure/enshrouded_server.json" > "$tmp"
chown 10000:10000 "$tmp"
chmod 640 "$tmp"
mv -f "$tmp" "$config"

if [ -z "$(find "$data/savegame" -maxdepth 1 -type f -name '*.ksd')" ]; then
  echo "No world found in $data/savegame, so the server will start a new one." >&2
  echo "To use your Azure world, press Ctrl+C now and extract a backup there first." >&2
  sleep 10
fi

"${compose[@]}" pull
"${compose[@]}" up --detach --force-recreate

echo "Waiting for the server. The first start downloads about 8 GB, so it can take a while."
started=$(docker inspect --format '{{.State.StartedAt}}' enshrouded-server)
deadline=$((SECONDS + 30 * 60))
until docker logs --since "$started" enshrouded-server 2>&1 | grep -q "Server is up"; do
  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "The server isn't up after 30 minutes. Check: sudo docker logs enshrouded-server" >&2
    exit 1
  fi
  sleep 10
done
echo "Server is up"
