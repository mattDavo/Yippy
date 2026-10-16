# Sync server

A small relay that lets the Mac and Windows apps sync their clipboard history and favourites. It only ever sees encrypted records: each device encrypts with the sync key before sending, and the server can't read the key or the content. The protocol is in [PROTOCOL.md](PROTOCOL.md).

It is an ASP.NET Core minimal API on .NET 8 that keeps everything in one SQLite file, run with Docker Compose. There are two ways to deploy it:

- **Behind the reverse proxy you already run** (`docker-compose.prod.yml` + `deploy.sh`), the same way as the personal assistant: the container joins the external `web-proxy` Docker network and your nginx serves the domain.
- **On its own** (`docker-compose.yml`), with a bundled [Caddy](https://caddyserver.com) that gets the HTTPS certificate itself. Use this on a server with nothing else on ports 80 and 443.

## Deploying behind your reverse proxy

```sh
cd /var/www && git clone <this repository> cairn && cd cairn/sync-server
cp .env.example .env && chmod 600 .env
# Set SYNC_DOMAIN, and an access key so strangers can't store data on your server:
#   SYNC_ACCESS_KEY=$(openssl rand -base64 24)
nano .env
docker network create web-proxy 2>/dev/null || true   # already there if the assistant is deployed
sh deploy.sh --check   # checks everything, changes nothing
sh deploy.sh
```

`deploy.sh` pulls, builds while the old container keeps serving, starts the new one and checks it answers on `http://127.0.0.1:18090/v1/health` (`SYNC_HOST_PORT`). If the new release doesn't come up healthy it puts the previous one back; `sh deploy.sh --rollback` does the same by hand, and `--no-pull` deploys the checkout as it is. The data stays in the `sync_data` volume throughout.

### Cloudflare

Add an `A` record (and `AAAA` for IPv6) for the sync domain pointing at the VPS. Proxied (orange cloud) works: Cloudflare's 100 MB request limit and 100 second timeout are both above what sync uses (25 MB records, 25 second waits). Set SSL/TLS to **Full (strict)** with a Let's Encrypt or Cloudflare origin certificate on your nginx.

### nginx

The container is `cairn_sync` on port 8080, on the `web-proxy` network, and also on the host at `127.0.0.1:18090`. Whichever nginx you use, it must allow bodies up to the record limit (`client_max_body_size 30m`; nginx's default of 1 MB would refuse most images) and keep requests open for long polling (`proxy_read_timeout 90s`).

- **nginx-proxy** (reads `VIRTUAL_HOST`/`LETSENCRYPT_HOST`): the host appears by itself. Add the limits in a file named after the domain in its `vhost.d` folder, e.g. `/etc/nginx/vhost.d/sync.example.com` containing `client_max_body_size 30m; proxy_read_timeout 90s;`.
- **Nginx Proxy Manager**: add a proxy host for the domain, forward to `cairn_sync` port `8080` over `http`, request an SSL certificate with Force SSL, and paste `client_max_body_size 30m; proxy_read_timeout 90s;` into Advanced.
- **nginx on the host**: start from [`nginx.conf.example`](nginx.conf.example), which proxies to `127.0.0.1:18090`.

Check it from anywhere: `curl https://sync.example.com/v1/health` answers `{"ok":true,"accessKeyRequired":true}`.

## Deploying on its own (Caddy)

You need ports 80 and 443 free and the domain's DNS pointing at the server (with Cloudflare, use DNS only, grey cloud, so Caddy can get its certificate).

```sh
cp .env.example .env && chmod 600 .env && nano .env
docker compose up -d --build
```

To update: `git pull && docker compose up -d --build`.

## Setting up the apps

In each app, open Settings > Sync:

1. Enter `https://sync.example.com` and the access key.
2. On the first computer, leave the sync key empty and press Turn On Sync. A new key is made; press Copy.
3. On every other computer, paste that key with the same server and access key, and turn sync on.

Anyone with the sync key can read what is synced, so send it to yourself privately (a password manager is ideal). Settings > Sync > Erase Synced Data deletes everything the key stored on the server.

## Backups

Everything is in `/data/sync.db` inside the data volume (`<folder>_sync_data` with `docker-compose.prod.yml`, `<folder>_sync-data` with `docker-compose.yml`; `docker volume ls` shows it). Stop the server, copy the file out, start it again:

```sh
docker stop cairn_sync
docker run --rm -v sync-server_sync_data:/data -v "$PWD":/backup alpine cp /data/sync.db /backup/
docker start cairn_sync
```

The records are encrypted with keys only the devices have, so a backup is only useful together with the sync key.

## Settings

Set these in `.env`:

| Variable | Default | Meaning |
| --- | --- | --- |
| `SYNC_DOMAIN` | (required) | The sync domain: what the reverse proxy routes to the container, or what Caddy gets a certificate for. |
| `SYNC_HOST_PORT` | 18090 | `docker-compose.prod.yml` only: the port on `127.0.0.1` that `deploy.sh` (and an nginx on the host) reaches the server through. |
| `SYNC_ACCESS_KEY` | none | If set, devices must send it (`X-Access-Key`); without it anyone who finds the server can store data on it. |
| `SYNC_MAX_RECORD_MB` | 25 | Largest record (one item, e.g. a big image) the server accepts. |
| `SYNC_SPACE_QUOTA_MB` | 512 | Most each sync key may store. Over it, the oldest history items are dropped; favourites never are. |
| `SYNC_HISTORY_DAYS` | 30 | History items older than this are dropped from the server (not from devices). |
| `SYNC_DELETION_DAYS` | 30 | How long deletions are remembered. A device offline for longer starts again from what the server has. |

`SYNC_DB_PATH` (default `/data/sync.db`) is where the database is kept inside the container.

## Running it locally

```sh
docker build -t sync-server .
docker run --rm -p 8080:8080 -e SYNC_ACCESS_KEY=letmein sync-server
```

The apps accept plain `http://` only for `localhost` and local network addresses, e.g. `http://192.168.1.20:8080`.

## Development

```sh
dotnet test SyncServer.sln
```

- `src/SyncServer/Domain`: identifiers and changes.
- `src/SyncServer/Application`: `SyncService` (the rules: who owns a space, quotas, change pages), the `ISyncStore` port, options and the long-poll `ChangeSignal`.
- `src/SyncServer/Infrastructure`: `SqliteSyncStore` and the `RetentionWorker` that drops old records.
- `src/SyncServer/Api`: the HTTP endpoints.
- `test-vectors.json` holds a sync key with its derived keys, record ids and sealed records. The Windows tests write it (`SYNC_WRITE_TEST_VECTORS=1 dotnet test` in `windows/`) and both apps' tests check against it, so they agree on the keys, ids and encryption.
