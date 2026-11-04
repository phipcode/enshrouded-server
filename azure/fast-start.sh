#!/bin/bash
# Starts the server without the image's full check of all 8 GB of game files,
# which takes about 5 minutes on the data disk. compose.yaml runs this instead
# of the image's own entrypoint.sh, which still does everything else.
set -euo pipefail

original=/home/steam/entrypoint.sh
fast=/tmp/entrypoint-fast.sh
marker=/home/steam/enshrouded/.fast-start-failed

# The last quick start couldn't update the game, so run the full check once to repair it.
if [ -e "$marker" ]; then
  echo "The last quick start failed, so running the full game file check"
  rm -f "$marker"
  exec "$original"
fi

# Keep Steam's record of what's installed and drop "validate", so Steam only
# downloads what changed. After a game patch, Steam often reports "state is 0x6"
# on the first try and succeeds on the second, so retry the update once.
# The marker is cleared once the update succeeds.
sed -e '/appmanifest_/d' \
    -e 's/" validate /" /' \
    -e 's#^if ! "[$]{STEAMCMD_PATH}/steamcmd.sh"#if ! steamcmd_with_retry#' \
    -e '/^if ! steamcmd_with_retry/i steamcmd_with_retry() { "${STEAMCMD_PATH}/steamcmd.sh" "$@" || { echo "Steam update failed, trying once more"; "${STEAMCMD_PATH}/steamcmd.sh" "$@"; }; }' \
    -e "/^# Config handling/i rm -f \"$marker\"" \
    "$original" > "$fast"

# If the image's script has changed and these edits no longer apply, use it unchanged.
if grep -qE 'appmanifest_| validate ' "$fast" || ! grep -qF "$marker" "$fast" ||
   ! grep -q '^if ! steamcmd_with_retry' "$fast"; then
  echo "The image's entrypoint.sh has changed, so starting it unchanged"
  exec "$original"
fi

touch "$marker"
exec bash "$fast"
