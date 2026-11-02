#!/bin/bash
# Uploads the world to Azure Storage if it has changed since the last backup.
# The storage details come from the VM's tags, which Terraform sets.
set -euo pipefail

saves=/mnt/gamedata/savegame
state=/var/lib/enshrouded-backup/last-hash
imds=http://169.254.169.254/metadata

tags=$(curl -fsS --max-time 10 -H Metadata:true "$imds/instance/compute/tagsList?api-version=2021-02-01")
tag() { jq -r --arg name "$1" '.[] | select(.name == $name).value' <<< "$tags"; }
account=$(tag BackupStorageAccount)
container=$(tag BackupContainer)
client_id=$(tag BackupIdentityClient)

if [ -z "$account" ] || [ -z "$container" ] || [ -z "$client_id" ]; then
  echo "The VM is missing its backup tags" >&2
  exit 1
fi

# Never replace good backups with an empty world, such as when the data disk isn't mounted.
if [ -z "$(find "$saves" -maxdepth 1 -type f -name '*.ksd' 2>/dev/null)" ]; then
  echo "No world found in $saves" >&2
  exit 1
fi

hash=$(find "$saves" -maxdepth 1 -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
if [ -f "$state" ] && [ "$(cat "$state")" = "$hash" ]; then
  echo "Backup complete: world unchanged"
  exit 0
fi

archive=$(mktemp)
trap 'rm -f "$archive"' EXIT
tar -czf "$archive" -C "$saves" .

token=$(curl -fsS --max-time 10 -H Metadata:true --get "$imds/identity/oauth2/token" \
  --data-urlencode "api-version=2018-02-01" \
  --data-urlencode "resource=https://storage.azure.com/" \
  --data-urlencode "client_id=$client_id" | jq -r .access_token)

# Stops before deleting anything if any part of the list can't be read.
prune_backups() {
  local page marker="" names="" name
  while :; do
    page=$(curl -fsS --max-time 60 --get \
      -H "Authorization: Bearer $token" \
      -H "x-ms-version: 2021-08-06" \
      --data-urlencode "restype=container" \
      --data-urlencode "comp=list" \
      --data-urlencode "prefix=enshrouded-" \
      --data-urlencode "marker=$marker" \
      "https://$account.blob.core.windows.net/$container") || return 1
    names+="$(grep -oP '(?<=<Name>)[^<]+' <<< "$page" || true)"$'\n'
    marker=$(grep -oP '(?<=<NextMarker>)[^<]+' <<< "$page" || true)
    [ -n "$marker" ] || break
  done

  grep . <<< "$names" | "$(dirname "$0")/backups-to-delete.sh" | while read -r name; do
    curl -fsS --max-time 30 -X DELETE \
      -H "Authorization: Bearer $token" \
      -H "x-ms-version: 2021-08-06" \
      "https://$account.blob.core.windows.net/$container/$name" || exit 1
  done
}

blob="enshrouded-$(date -u +%Y-%m-%dT%H%M%SZ).tgz"
curl -fsS --max-time 120 --upload-file "$archive" \
  -H "Authorization: Bearer $token" \
  -H "x-ms-version: 2021-08-06" \
  -H "x-ms-blob-type: BlockBlob" \
  -H "Content-Type: application/gzip" \
  "https://$account.blob.core.windows.net/$container/$blob"

# Only recorded after a successful upload, so a failed backup is retried next time.
mkdir -p "$(dirname "$state")"
echo "$hash" > "$state"

# A failed cleanup must not fail the backup, and it's tried again after the next one.
prune_backups || echo "Could not clean up old backups" >&2

echo "Backup complete: $blob"
