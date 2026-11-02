#!/bin/bash
# Reads backup names and prints the ones to delete. It deletes nothing itself.
#   - Keeps everything from the last hour.
#   - Before that, keeps the newest backup in each 30-minute period, so the end of a session survives.
#   - Keeps no more than the newest 50 of those.
set -euo pipefail

now=${1:-$(date +%s)}
keep_everything_for=3600
period_length=1800
max_backups=50

mapfile -t names < <(LC_ALL=C sort)

declare -A seen_periods
kept=0
for ((i = ${#names[@]} - 1; i >= 0; i--)); do
  name=${names[i]}
  # Leave anything that isn't named like a backup alone.
  [[ $name =~ ^enshrouded-([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2})([0-9]{2})([0-9]{2})Z\.tgz$ ]] || continue
  taken=$(date -u -d "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}:${BASH_REMATCH[3]}:${BASH_REMATCH[4]}" +%s)
  period=$((taken / period_length))

  if ((now - taken >= keep_everything_for)) && [[ -n ${seen_periods[$period]:-} ]]; then
    echo "$name"
    continue
  fi
  seen_periods[$period]=1

  kept=$((kept + 1))
  if ((kept > max_backups)); then
    echo "$name"
  fi
done
