# Run the server at home

A backup plan if the Azure server is down. It uses the same server settings
([../azure/enshrouded_server.json](../azure/enshrouded_server.json)) and the same quick start as Azure.

Needs a Linux machine with Docker, Docker Compose and `jq` (`sudo apt install jq`).

## Start it

1. Get the repo:
   ```bash
   sudo git clone https://github.com/phipcode/enshrouded-server /opt/enshrouded-repo
   cd /opt/enshrouded-repo
   ```
2. Run the setup once. It creates `/srv/enshrouded/secrets.env` and stops:
   ```bash
   sudo ./home/setup.sh
   ```
3. Add the passwords (the same ones as the GitHub `game` secrets):
   ```bash
   sudo nano /srv/enshrouded/secrets.env
   ```
4. Copy your world in. Extract the newest Azure backup (`enshrouded-<date>.tgz`) into the savegame folder:
   ```bash
   sudo tar -xzf enshrouded-<date>.tgz -C /srv/enshrouded/savegame
   ```
5. Start it. The first start downloads about 8 GB of game files:
   ```bash
   sudo ./home/setup.sh
   ```
   It finishes when it says **Server is up**.
6. Let friends in. Forward UDP ports **15637** and **27015** on your router to this machine,
   and allow them through its firewall (`sudo ufw allow 15637/udp && sudo ufw allow 27015/udp`).
   Friends join on your public IP.

The server starts again by itself after a reboot.

## Everyday use

| To | Run |
| --- | --- |
| Apply new settings | `sudo git pull && sudo ./home/setup.sh` |
| Update the game | `sudo docker restart enshrouded-server` |
| See the log | `sudo docker logs --tail 50 enshrouded-server` |
| Stop | `sudo docker stop enshrouded-server` |

There are no automatic backups at home. Copy `/srv/enshrouded/savegame` somewhere safe yourself.

**Don't run the world in both places.** Before going back to Azure, stop the home server and copy
`/srv/enshrouded/savegame` back, or you'll lose what you played at home.
