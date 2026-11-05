#!/bin/bash
# Runs inside the container on every start. Adds the passwords from secrets.env
# to the shared server settings, then starts the server with the quick start.
set -euo pipefail

template=/home/steam/enshrouded_server.template.json
config="${ENSHROUDED_CONFIG:-/home/steam/enshrouded/enshrouded_server.json}"

if [ -z "${SERVER_PASSWORD:-}" ]; then
  echo "SERVER_PASSWORD is not set in home/secrets.env, refusing to start a public server" >&2
  exit 1
fi

# The repo is public, so the passwords are only added here, on this machine.
# The Admin group gets its own password, and every other group gets the player password.
if [ -z "${ADMIN_PASSWORD:-}" ]; then
  # An Admin group without its own password would give admin powers to every player.
  echo "ADMIN_PASSWORD is not set in home/secrets.env, so the Admin group is left out" >&2
  filter='del(.userGroups[] | select(.name == "Admin")) | .userGroups[].password = env.SERVER_PASSWORD'
elif [ "$ADMIN_PASSWORD" = "$SERVER_PASSWORD" ]; then
  echo "ADMIN_PASSWORD must be different from SERVER_PASSWORD" >&2
  exit 1
else
  filter='.userGroups[] |= (.password = if .name == "Admin" then env.ADMIN_PASSWORD else env.SERVER_PASSWORD end)'
fi

umask 027
jq "$filter" "$template" > "$config.tmp"
mv -f "$config.tmp" "$config"
unset SERVER_PASSWORD ADMIN_PASSWORD

exec /bin/bash /home/steam/fast-start.sh
