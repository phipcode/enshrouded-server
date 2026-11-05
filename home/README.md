# Run the server at home

A backup plan if the Azure server is down. It uses Docker Compose only, with the same
server settings ([../azure/enshrouded_server.json](../azure/enshrouded_server.json))
and the same quick start as Azure. There's nothing to build: it uses the upstream image.

Needs a Linux machine with Docker and Docker Compose. Run the commands below as a user who
can use Docker, or put `sudo` in front of the `docker` commands.

## Set it up

1. Get the repo:

   ```bash
   sudo git clone https://github.com/phipcode/enshrouded-server /opt/enshrouded-repo
   sudo chown -R "$USER" /opt/enshrouded-repo
   cd /opt/enshrouded-repo/home
   ```

2. Make the data folders. The game runs as user 10000 inside the container, so it must own them:

   ```bash
   sudo mkdir -p /srv/enshrouded/install /srv/enshrouded/savegame
   sudo chown -R 10000:10000 /srv/enshrouded
   ```

3. Add the passwords (the same ones as the GitHub `game` secrets). No quotes needed:

   ```bash
   cp secrets.env.example secrets.env
   chmod 600 secrets.env
   nano secrets.env
   ```

4. Copy your world in. If the Azure server is still up, run the `backup` action first. Then download the newest backup in PowerShell on your PC
   (the list and download commands are in the Terraform repo's
   [Back up and restore your world](https://github.com/phipcode/terraform/blob/main/environments/game/docs/backup-restore.md#restore-from-azure) guide),
   copy it to this machine's home folder, extract it into the savegame folder, and give it to user 10000:

   ```bash
   sudo tar -xzf ~/enshrouded-<date>.tgz -C /srv/enshrouded/savegame
   sudo chown -R 10000:10000 /srv/enshrouded/savegame
   ls /srv/enshrouded/savegame    # should list .ksd files
   ```

   Keep the `.tgz` outside the repo folder.

5. Start it. The first start downloads about 8 GB of game files:

   ```bash
   docker compose up -d
   docker compose logs -f
   ```

   It's ready when the log says **Server is up**. Press Ctrl+C to stop watching the log (the server keeps running).

6. Let friends in. Forward UDP ports **15637** and **27015** on your router to this machine,
   and allow them through its firewall:

   ```bash
   sudo ufw allow 15637/udp && sudo ufw allow 27015/udp
   ```

   Friends join on your public IP.

The server starts again by itself after a reboot.

To keep the data somewhere other than `/srv/enshrouded`, create `home/.env` with
`ENSHROUDED_DATA=/path/to/folder`, and use that path in steps 2 and 4.

## Connect

The server has the same name as the Azure one (set in `../azure/enshrouded_server.json`).
In Enshrouded, go to **Play**, then **Join Game**, search for the name, and join with the player password.
Friends need the router forward and firewall from step 6.

If this machine runs it in WSL with mirrored networking, Windows also has to let the ports through to WSL.
In an admin PowerShell on Windows:

```powershell
New-NetFirewallHyperVRule -Name Enshrouded -DisplayName "Enshrouded" -Direction Inbound -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}' -Protocol UDP -LocalPorts 15637,27015
```

## Everyday use

Run these from `/opt/enshrouded-repo/home`.

| To | Run |
| --- | --- |
| Update the game | `docker compose restart` |
| Apply new settings or passwords | `git pull && docker compose up -d --force-recreate` |
| Get a newer container image | `docker compose pull && docker compose up -d` |
| See the log | `docker compose logs --tail 50` |
| Stop | `docker compose stop` |

There are no automatic backups at home. Copy `/srv/enshrouded/savegame` somewhere safe yourself.

**Don't run the world in both places.** Before going back to Azure, stop the home server and
upload `/srv/enshrouded/savegame` back, or you'll lose what you played at home.
