# Lab

`cs.Lab` — the offline vCard laboratory behind the vCard Lab window.

Everything here is deterministic and offline: `build`, `parse` and
`roundTrip` never open a socket, and the refusal catalogue records the code
each layer returns for input that the layer already rejects before any network
request.

## Layers, in call order

| Layer | Who refuses | Codes |
| --- | --- | --- |
| `component` | `cs.CardDAV.Client` before launching the CLI | `invalid_argument` |
| `cli` | the bundled Go `carddav` while validating the request | `invalid_request`, `invalid_vcard`, `unsupported_version`, `unsafe_url` |
| `prelaunch` | `_CLI` before spawning the process | `unsupported_architecture` |

## Properties

| Property | Type | Meaning |
| --- | --- | --- |
| `cardText` | Object | `cs.CardText` helper |
| `client` | Object | `cs.CardDAV.Client` instance |
| `presets` | Collection | Build presets (`id`, `name`, `version`, `note`, `contact` or `raw`) |
| `scenarios` | Collection | Refusal catalogue rows |
| `versionText` | Text | Filled by `runAll()` |
| `lastResult` | Object | Last envelope |

## Build presets

| Preset | Version | Shows |
| --- | --- | --- |
| `minimal` | 3.0 | A URN UUID is generated and `N:;;;;` written |
| `unicode` | 4.0 | Folding counts octets, not characters |
| `escapes` | 4.0 | `\,` `\;` `\n` survive a parse→raw round trip |
| `folding` | 4.0 | A 120-character name is folded at 75 octets |
| `server` | 4.0 | Grouped `EMAIL`, `PHOTO`, `X-*` — what a rebuild drops |

## Methods

### `runAll() -> Collection`

Builds every preset, audits the output, and rebuilds the server card from its
parsed summary to name the loss. Returns `{id, verdict, code, audit, lost}`
rows.

### `runPreset($preset) -> Object`

The same for one preset.

### `rebuildLoss() -> Collection`

Parses the server card, rebuilds it, and returns the dropped properties.

### `runAtlas() -> Collection`

Runs all fifteen refusal scenarios and returns
`{id, layer, expect, actual, message, verdict}`. A row passes when the code the
layer actually returned equals the expected code.

### `summary($rows) -> Text`

`"15 of 15 expectations matched"`.

## Refusal catalogue

| Scenario | Layer | Expected |
| --- | --- | --- |
| `build-no-fn` | cli | `invalid_request` |
| `build-version-2.1` | cli | `unsupported_version` |
| `build-extra-field` | cli | `invalid_request` |
| `build-nul-uid` | cli | `invalid_request` |
| `parse-empty` | cli | `invalid_vcard` |
| `parse-no-uid` | cli | `invalid_vcard` |
| `parse-two-cards` | cli | `invalid_vcard` |
| `update-weak-etag` | cli | `invalid_request` |
| `update-unquoted-etag` | cli | `invalid_request` |
| `update-http-endpoint` | cli | `invalid_request` |
| `discover-http` | cli | `invalid_request` |
| `discover-private` | cli | `unsafe_url` |
| `request-null` | component | `invalid_argument` |
| `request-unknown-op` | component | `invalid_argument` |
| `wrong-target` | prelaunch | `unsupported_architecture` |

## Display helpers

`bind($form)` initialises the form, `presetRows()` and `atlasInto($form)`
fill the listboxes, `selectPreset()` and `selectCheck()` map a row to the
preview/detail consoles, and `detailInto()` writes the selected row's
expectation, actual code and message.
