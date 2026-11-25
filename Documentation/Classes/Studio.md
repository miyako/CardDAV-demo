# Studio

`cs.Studio` — the state and behaviour behind the CardDAV Studio window.

The form owns pixels; this class owns the component. Every method takes the
form object as its first parameter, so `Demo_HeadlessSmoke` can drive exactly
the same code with a plain object and no window open.

Two groups of behaviour are deliberately separated:

| Group | Methods | Network |
| --- | --- | --- |
| Offline | `build`, `parseRaw`, `roundTrip`, `seedServerCard` | none — the bundled CLI is spawned, but never dials |
| Live | `discover`, `query`, `get`, `create`, `update`, `delete` | verified TLS; HTTPS endpoint is the trust anchor |

A live method never invents success: the component envelope is shown as it
came back, including the CLI's own code (`conflict`, `authentication_failed`,
`unsafe_url`, …).

## Properties

| Property | Type | Meaning |
| --- | --- | --- |
| `client` | Object | `cs.CardDAV.Client` instance |
| `versionText` | Text | `version()` result, or `"unavailable"` |
| `statusText` | Text | One-line verdict for the status console |
| `envelopeText` | Text | Last envelope, unedited |
| `discoveryText` | Text | Discovery chain, one line per book |
| `parseText` | Text | Parsed properties, `group.NAME : value` |
| `auditText` | Text | Octet/CRLF/folding audit line |
| `fidelityText` | Text | Lossless vs rebuild-loss summary |
| `books` | Collection | `{displayName, url, versions}` rows |
| `contacts` | Collection | `{name, url, etag, shortETag, version}` rows |
| `properties` | Collection | Last parse result's properties |
| `losslessOK` | Boolean | Parsed raw Text equals what was sent |
| `cardText` | Object | `cs.CardText` helper |
| `lastResult` | Object | Last envelope |
| `PUBLIC_PROBE` | Text | `https://contacts.icloud.com/` — anonymous discovery |

## Offline methods

### `build($form) -> Object`

Builds a vCard from the draft fields and the chosen version (`3.0` / `4.0`).
On success the raw editor is replaced with the built text and re-parsed, so
the properties panel and the audit line always describe what is on screen.
Requires at least a formatted name; otherwise it returns `Null` without
touching the component.

### `parseRaw($form) -> Object`

Parses the raw editor content. Updates `properties`, `parseText`, `auditText`
and `losslessOK`.

### `roundTrip($form) -> Object`

The demo's central lesson, executable: parse the raw editor, rebuild a card
from the parsed summary (`uid` + `formattedName`), parse the rebuild, and name
every property the rebuild dropped.

Returns `Null` with a status line when the raw editor is not parsable — the
first refusal is a lesson too, not a crash.

### `seedServerCard($form)`

Replaces the raw editor with a card shaped like a server response: grouped
`EMAIL`, `PHOTO`, an `X-*` property, escaped comma/semicolon/newline.

## Live methods

All of them take the form, read `endpoint`/`username`/`password` from it, and
write `statusText`, `envelopeText` and the relevant console.

| Method | Component call |
| --- | --- |
| `discover($form)` | `discover()` |
| `probeAnonymous($form)` | `discover()` against `PUBLIC_PROBE`, no credentials |
| `query($form)` | `query(bookURL; {filter, limit})` |
| `get($form)` | `get(url)` |
| `create($form)` | `create(url; vcard)` — conditional on absence |
| `update($form)` | `update(url; vcard; etag)` — sends the raw editor text |
| `delete($form)` | `delete(url; etag)` |

`update` reports a 412 as `conflict` rather than as a generic failure, because
that is the condition the demo wants you to see: the same ETag, the same
button, a refused overwrite.

## Display helpers

`bind($form)` initialises the form object and parses the sample card;
`refresh($form)` pushes derived state back into it. `selectBook`,
`selectContact`, `preset`-style selection methods map a listbox row to state.
`code()`, `envelope()`, `_text()`, `_int()`, `_boolText()` and `_join()` keep
the formatting of a component envelope consistent everywhere.
