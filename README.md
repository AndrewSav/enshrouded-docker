# Dockerized Enshrouded dedicated server in an Ubuntu 24.04 container with GE-Proton

[![GitHub Actions](https://github.com/AndrewSav/enshrouded-docker/actions/workflows/main.yml/badge.svg)](https://github.com/AndrewSav/enshrouded-docker/actions)
[![Docker Image Version (latest semver)](https://img.shields.io/docker/v/andrewsav/enshrouded?sort=semver)](https://hub.docker.com/r/andrewsav/enshrouded/tags)

This is not an official project and I'm not affiliated with developers or publishers of the game. Head to https://enshrouded.zendesk.com/hc/en-us/articles/16055441447709-Dedicated-Server-Configuration for official information about the dedicated server configuration. This image is versioned separately and the image version is not in sync with either the game or the dedicated server.

Checked that it's working with 1.0.0.0 (Steam build 26083076) on 25 October 2026.

## Environment variables


| Variable    | Description                                                  |
| ----------- | ------------------------------------------------------------ |
| SKIP_UPDATE | if provided, skips the Steam update process on container startup |
| PUID | UID to run the server process as. Defaults to 1000. Set this to match your host user UID if you want to conveniently access the `./server` files (configs, saves, logs) on the host without `sudo`. The container operates correctly regardless. See `On accessing server files without sudo` below for more details |
| PGID | GID to run the server process as. Defaults to 1000. Same as above but for group |

## Ports


| Exposed Container port | Type |
| ------------------------ | ------ |
| 15637                | UDP  |

In order for others to connect to your server you will most likely need to configure port forwarding on your router.

## Volumes


| Volume             | Container path              | Description                             |
| -------------------- | ----------------------------- | ----------------------------------------- |
| Steam install path | /server   | the server files are downloaded into this directory, and the settings file is created here on the first start. server logs are located under /server/logs and saves under /server/savegame |
| Wine prefix | /wineprefix-volume | Used when `PUID` is not `1000`. See `On accessing server files without sudo` below for more details |

## Starting the server

In the folder containing `docker-compose.yml` run

```bash
docker compose up -d --force-recreate
```

You can watch the logs with:

```bash
docker compose logs -f
```

*Note: this readme assumes that you are using the supplied `docker-compose.yml` to start the server. Some parts of this readme may be inaccurate if your settings differ from the provided.*

## Server configuration

On the first start the server creates `./server/enshrouded_server.json` with the default settings and keeps running. The default settings include four user groups (Admin, Friend, Guest and Visitor), each with a randomly generated password, so nobody can join until you hand out a password. Look them up in the file.

To change the settings, stop the container, edit the file and start the container again:

```bash
docker compose stop
# edit ./server/enshrouded_server.json
docker compose up -d --force-recreate
```

Only edit the file while the server is stopped. The server rewrites it on start, and saves bans made in game into it, so changes made while it is running can be lost.

All the settings are described in `./server/enshrouded_server_readme.txt` that comes with the server files, and in the official documentation linked at the top of this README.

Logs are found in `./server/logs/` directory, and Saves are in `./server/savegame/` directory. The server keeps a few rotating backups of the world in `./server/savegame/backup/`.

## Connecting to the server

In game, go to "Join", find your server in the list by its name, and enter the password of the user group you want to join as. You can also add the server to the Steam server browser favourites (View > Game Servers > Favorites) as `<server ip>:15637`.

## Updating the server

Restart the container. It will check Steam for a newer server version on start and update if required. My preferred method of restarting is running `docker compose up -d --force-recreate` but simple `docker restart enshrouded` would suffice.

## Additional Information

### Changing port

If you want to use a port other than `15637`, change it on both sides of the mapping in `docker-compose.yml`, e.g.:

```yaml
    ports:
      - '12345:12345/udp'
```

and update `queryPort` in `enshrouded_server.json` to the same value (while the container is stopped):

```json
	"queryPort": 12345,
```

The server tells Steam which port it is listening on, so mapping a different external port to `15637` inside the container (e.g. `12345:15637/udp`) is not going to work.

### Port forwarding

Detailed port forwarding guide is out of scope of this document, there are a lot of variations between routers in how this is done. However, here are a few important points to keep in mind:

- You need to forward port `15637` (unless you changed it to something else) on UDP protocol. Without this your server won't be accessible from the internet. You can use <https://mcheck.bat.nz/> to check if your server is accessible.
- It is possible that the server is accessible from the internet but not from the same (home) network where your server is in. This is called a hairpin NAT problem. Either google how to configure it on your router (if it supports it), or use local IP address for connecting to the server within the same network (as opposed to your external IP address).
- Some internet providers employ [CGNAT](https://en.wikipedia.org/wiki/Carrier-grade_NAT). If yours does, you won't be able to make your server accessible externally, unless you and other users use a VPN or a tunneling service such as <https://playit.gg/> (this is not an endorsement, I have never used this service myself).

### Graceful termination

`docker compose stop` and `docker compose down` send `SIGINT` to the server (see `stop_signal` in `docker-compose.yml`). The server treats it as Ctrl+C: it saves the world, logs off from Steam and exits, normally within a few seconds.

If the server cannot reach Steam when it is stopped (e.g. Steam is down), it still saves the world, but then never exits. Docker kills it after `stop_grace_period`, which is 90 seconds in the supplied `docker-compose.yml`.

### On accessing server files without sudo

When running a container as non-root, the file ownership outside of the container is the same as inside, `PUID=1000` by default. If your logged on user has a different PUID (e.g. 1001), you won't be able to modify the server files (such as `enshrouded_server.json` or save files) without `sudo`. If that's fine by you, or if you are normally working as `root` anyway, you can skip the rest of this section. You can set up PUID/PGID in the container to match your user to work around this issue, allowing you to access the server files directly. In `docker-compose.yml` uncomment all the commented out lines below:

```yaml
    #environment:
    #  - PUID=1001
    #  - PGID=1001
    volumes:
      - './server:/server'
    #  - './wineprefix:/wineprefix-volume'    
```

Set PUID and PGID to match your user's UID and GID. You can find those out by running the `id` command.

The rest of this section explains why we need the volume when PUID and PGID have non-default values; it is not necessary to know this to operate the container.

The wine prefix is a directory containing the Windows runtime environment wine uses to run the server. It is built into the image at build time, owned by uid 1000. When a different `PUID` is used, the container needs to `chown` those files to the new uid before starting the server. Docker uses an overlay filesystem: the image layers are read-only, and any modifications (including ownership changes) are written to a thin writable layer on top. Changing ownership of thousands of files in the wine prefix causes each of them to be copied from the read-only image layer into the writable layer — this is the copy-on-write cost, and it makes startup noticeably slow. By placing the wine prefix on a bind mount (a real directory on the host filesystem) instead, there is no overlay involved and `chown` is fast. The copy from the image to the bind mount only happens once on first start; subsequent starts just run `chown` against the already-copied files on the host filesystem.

The wine prefix is built into the image at `/wineprefix-template`. At container startup it is made available to wine at `/home/steam/.wine` via a symlink or copy, depending on `PUID`:

- **`PUID=1000` (default):** A symlink is created from `/home/steam/.wine` to `/wineprefix-template` in the image. No files are copied and no ownership changes are needed, so startup is fast.
- **`PUID` other than `1000`:** On the first start the prefix is copied to the `./wineprefix` bind mount and ownership is set to the specified `PUID`/`PGID`. This one-time copy is the slow path. On subsequent starts only `chown` is run against the bind mount (fast, since it is a real filesystem with no copy-on-write overhead), and a symlink is created as above.

A `.timestamp` file inside `./wineprefix` records the build timestamp of the image the volume was populated from. On each start this is compared against the timestamp baked into the image — if they differ (first run or image upgrade), the volume is cleared and re-copied from the new template.

### Bind mounts vs volumes

There are three ways to persist data for a Docker container:

- Bind-mount, where you map a path outside of the container to a path inside the container
- Volume mount, where you create a Docker volume and map that volume to a path inside the container
- Anonymous volume, where you get docker to auto-create the volume for you and map it to a path inside the container

I personally prefer the first option (this is the option showcased in the supplied `docker-compose.yml`), because it makes everything explicit. If I delete the game folder, all the game data is gone too, it does not hang around in a volume that is not directly visible, or worse an anonymous volume I won't be able to remember which it was for later. However, some people have different preferences and all three ways will work, in particular, both volumes this container intends to use are specified in the `Dockerfile`, so an anonymous volume will be created if a user does not specify another option manually. If you use the other two options, I trust in your ability to adjust what's written on this page to your custom setup.

## Credits

Other Enshrouded docker images I looked at while making this one:

- https://github.com/jsknnr/enshrouded-server
- https://github.com/mornedhels/enshrouded-server
- https://github.com/mbround18/enshrouded-docker

## License

[MIT](LICENSE)
