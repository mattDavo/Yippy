# Sync server

A small relay that lets the Mac and Windows apps sync their clipboard history and favourites. It only ever sees encrypted records: each device encrypts with the sync key before sending, and the server can't read the key or the content. The protocol is in [PROTOCOL.md](PROTOCOL.md).

It is an ASP.NET Core minimal API on .NET 8 that keeps everything in one SQLite file, deployed with Docker Compose behind [Caddy](https://caddyserver.com), which gets and renews the HTTPS certificate by itself.

## Deploying on a VPS

You need a Linux server with Docker and the Compose plugin, ports 80 and 443 open, and a domain name (e.g. `sync.example.com`) with an A (and AAAA, for IPv6) record pointing at the server.

```sh
git clone <this repository> && cd <repository>/sync-server
cp .env.example .env
# Set SYNC_DOMAIN, and an access key so strangers can't store data on your server:
#   SYNC_ACCESS_KEY=$(openssl rand -base64 24)
nano .env
docker compose up -d --build
curl https://sync.example.com/v1/health   # {"ok":true,"accessKeyRequired":true}
```

Then in each app, open Settings > Sync:

1. Enter `https://sync.example.com` and the access key.
2. On the first computer, leave the sync key empty and press Turn On Sync. A new key is made; press Copy.
3. On every other computer, paste that key with the same server and access key, and turn sync on.

Anyone with the sync key can read what is synced, so send it to yourself privately (a password manager is ideal). Settings > Sync > Erase Synced Data deletes everything the key stored on the server.

To update: `git pull && docker compose up -d --build`. The data is in the `sync-data` Docker volume; back it up with `docker compose stop sync`, then copy `/data/sync.db` out of the volume (e.g. `docker run --rm -v sync-server_sync-data:/data -v "$PWD":/backup alpine cp /data/sync.db /backup/`).

## Settings

Set these in `.env`:

| Variable | Default | Meaning |
| --- | --- | --- |
| `SYNC_DOMAIN` | (required) | The domain Caddy gets a certificate for. |
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
