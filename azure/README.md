# Azure deployment

Settings for the Enshrouded server running on the Azure VM. The infrastructure is defined in the `phipcode/terraform` repo, under `environments/game`.

The home server in [../home](../home/README.md) uses the same `enshrouded_server.json` and `fast-start.sh`, so a change here applies to both.

## Changing settings

1. Edit `enshrouded_server.json` and push to `main`. It holds the server name, player slots and game settings.
2. Run the **Game Server Power** workflow in the Terraform repo and choose `update`, or run `sudo /opt/enshrouded/repo/azure/update.sh` on the VM. On the home server, run `git pull && docker compose up -d --force-recreate` in `home/`.

This restarts the server, so players are disconnected.

**This repo is public, so never commit a password.** Leave `password` empty in `enshrouded_server.json`. `update.sh` fills it in on the VM from `/opt/enshrouded/secrets.env`:

- The `Admin` group gets `ADMIN_PASSWORD`, and can kick and ban players.
- Every other group gets `SERVER_PASSWORD`, and can build and open chests, but not kick or ban.

If `ADMIN_PASSWORD` isn't set, the `Admin` group is left out, so nobody gets admin powers.

## Updates

- **Game:** updates by itself every time the container starts. `fast-start.sh` skips the image's full check of all 8 GB of game files, so Steam only downloads what changed. After a game patch Steam often fails the first try, so it tries once more. If that fails too, the next start runs the full check once to repair the install.
- **Container image:** `update.sh` pulls the latest image.

## Backups

`enshrouded-backup.timer` runs `backup.sh` 5 minutes after boot and every 5 minutes after that. It uploads to Azure Storage only if the world has changed. `update.sh` installs the timer.

After each upload, `backup.sh` deletes old backups using the rules in `backups-to-delete.sh`:

- Everything from the last hour is kept.
- Older backups are thinned to one every 30 minutes.
- Only the newest 50 are kept.

## Files on the VM

| Path | Purpose |
|---|---|
| `/opt/enshrouded/repo` | Clone of this repo |
| `/opt/enshrouded/secrets.env` | Server password, written by Terraform |
| `/opt/enshrouded/enshrouded_server.json` | Finished config, including the password |
| `/mnt/gamedata/savegame` | World saves |
| `/mnt/gamedata/install` | Downloaded game files |
