# Sync protocol, version 1

Clipboard sync between the macOS and Windows apps goes through a small relay server (this folder). The apps encrypt
everything before it leaves the device, so the server stores records it cannot read. Both apps implement this file;
`test-vectors.json` holds known inputs and outputs that both test suites check, so they stay compatible.

## The sync key

One random 32-byte secret shared by all of a user's devices. It is shown to the user as 52 characters of Crockford
base32 (no padding) in groups of four separated by `-`, e.g. `7J3K-…`. Parsing ignores case, spaces and dashes, and reads
`O` as `0` and `I`/`L` as `1`.

Everything else comes from the key with HKDF-SHA256 (RFC 5869, empty salt), with these `info` strings:

| Name | info | Length | Use |
| --- | --- | --- | --- |
| space id | `clipsync-v1 space` | 16 bytes, sent as 32 lowercase hex characters | which space on the server |
| auth token | `clipsync-v1 auth` | 32 bytes, sent as base64url without padding | proves the client may use the space |
| encryption key | `clipsync-v1 encrypt` | 32 bytes | AES-256-GCM key; never leaves the device |
| id key | `clipsync-v1 id` | 32 bytes | HMAC key for record ids; never leaves the device |

## Records

A space holds records, each under a key of the form `<kind>/<id>`:

- `h/<id>`: a clipboard history item.
- `f/<id>`: a favourite.

`<id>` is derived from the item's content, so the same copy made on two devices is one record:
base64url (no padding) of the first 16 bytes of HMAC-SHA256(id key, canonical content bytes), where the canonical
content bytes are, for each format in ordinal order of its name: the name's UTF-8 length as a 64-bit little-endian
integer, the name's UTF-8 bytes, the data's length as a 64-bit little-endian integer, then the data.

A device remembers which of its items belongs to which id, and uses that id for the item from then on, so converting
the content back and forth between platforms never makes a second record.

### Payload

A record's data is the encryption of a UTF-8 JSON object:

```json
{ "v": 1, "copiedAt": 1760600000000, "title": "optional, favourites only", "formats": { "text": "base64…" } }
```

- `copiedAt`: milliseconds since 1970-01-01 UTC when the item was last copied (or favourited).
- `formats`: the canonical formats below, each base64. Unknown formats are ignored, so later versions can add some.

| Canonical format | Content | macOS type | Windows format |
| --- | --- | --- | --- |
| `text` | UTF-8 text | `public.utf8-plain-text` | `CF_UNICODETEXT` |
| `rtf` | RTF | `public.rtf` | `Rich Text Format` |
| `html` | UTF-8 HTML | `public.html` | `HTML Format` (the fragment, without Windows' offset header) |
| `png` | PNG image | `public.png` (TIFF converted) | `PNG` (DIB converted), plus `CF_DIB` when written |

An item with none of these formats (e.g. only copied files) is not synced.

### Encryption

`data = 0x01 ‖ nonce (12 random bytes) ‖ ciphertext ‖ tag (16 bytes)`, AES-256-GCM with the encryption key and the
record key (e.g. `h/AbC…`) as UTF-8 additional data, so the server can't move a record under another key.

## Meaning of changes

- `h/` put: the item was copied (again) at `copiedAt`. A device adds it, or moves its copy to where `copiedAt` puts it.
- `h/` delete: the user deleted the item; every device deletes it.
- `f/` put: the item is a favourite, with this title. A changed favourite's text gets a new id: delete the old one.
- `f/` delete: the item is no longer a favourite.

Trimming to the history limit and automatic cleaning stay on each device. A history record the server dropped for
space (see below) disappears without a delete, and devices keep their copies.

## HTTP API

All under `/v1`. Requests about a space send `Authorization: Bearer <auth token>`. If the server is set up with an
access key, every request also sends `X-Access-Key: <access key>`. Errors are `{"error": "…"}` with a 4xx/5xx status.

| Request | Body | Response |
| --- | --- | --- |
| `GET /v1/health` | | `{"ok": true, "accessKeyRequired": bool}` |
| `PUT /v1/spaces/{space}/records/{kind}/{id}` | the encrypted data (`application/octet-stream`) | `{"seq": n}` |
| `DELETE /v1/spaces/{space}/records/{kind}/{id}` | | `{"seq": n}` |
| `POST /v1/spaces/{space}/clear/{kind}` | | `{"seq": n}`: deletes every record of that kind |
| `GET /v1/spaces/{space}/changes?since={seq}&wait={seconds}` | | see below |
| `DELETE /v1/spaces/{space}` | | `204`: forgets the space and all its records |

A space is created by its first write; from then on only that auth token may use it (`401` otherwise). Unknown spaces
answer reads with no changes. `seq` increases with every change in a space.

`changes` returns the records changed after `since`, oldest first, at most 200 or about 8 MB per page:

```json
{ "changes": [ { "key": "h/AbC", "seq": 12, "deleted": false, "data": "base64…" } ], "cursor": 12, "more": false, "reset": false }
```

Only the latest change of each key is kept. If nothing changed, the server waits up to `wait` seconds (at most 60)
for a change before answering. `reset: true` means the server can't answer from `since`: deletions after it were
forgotten (see below), or the space was deleted. The client asks again from `since=0`.

## Server limits

Set by environment variables (see README.md): the largest record (default 25 MB), each space's storage (default
512 MB; the oldest `h/` records are dropped first, favourites never), how long history records are kept (default 30
days) and how long deletions are remembered (default 30 days; a client that was away longer gets `reset`).
