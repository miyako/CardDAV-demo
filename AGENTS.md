# AGENTS.md

Notes for anyone (or any agent) changing this demo.

## Laws of the demo

1. **No invented results.** A live view shows the component envelope as
   returned. If a call fails, the failure is the content.
2. **No stored credentials.** The password field is memory-only; nothing is
   written, logged or passed on a command line.
3. **Offline means offline.** The headless smoke and every Lab row must work
   with the network down. Only `discover`, `query`, `get`, `create`, `update`,
   `delete` and `probeAnonymous` may dial.
4. **Send the raw Text.** `update()` takes the editor's text; never a rebuilt
   card. The Lab window exists to show why.

## Change map

| You changed | Regenerate / verify |
| --- | --- |
| A form layout | `python3 scripts/make_forms.py`, then `tools/4dform/boon .agents/schemas/4dform/formsSchema.json Project/Sources/Forms/<Name>/form.4DForm` and `tools/4dform/fourdform ... -o docs/<name>-preview.png` |
| A class method | `tools/4dlsp/tool4d-lsp-stdio validate --workspace Project/ <absolute .4dm paths>` — `cs.CardDAV is unknown` is the only acceptable diagnostic |
| The component tag | update `Project/Sources/dependencies.json`, the pinned SHA256 in `scripts/fetch_dependency.py` and the provenance block in `README.md` |
| A refusal code | `cs.Lab._atlas()` expectation *and* `README.md` / `docs/FINDINGS.md` tables |
| The smoke assertions | `scripts/verify.py` (one check per fact the demo teaches) |

## Done gate

```sh
scripts/smoke.sh /tmp/report.json      # must print "N of N checks passed", N == total
```

The run must also load both forms and report an empty `missing` list. Add a
line to the README status matrix for anything that stays `not_run`.

## Conventions

* `compatibilityVersion` 2102, `tokenizedText: false` — plain 4D code, no
  `:C123` / `:K12:34` tokens.
* The form owns pixels; the class owns the component. Form methods dispatch on
  `FORM Event.code` / `objectName` and never branch on the form's name.
* One behavioural change per commit, with the smoke result in the message.
* **Never ask the user to approve commands** during automated runs; use the
  defaults and record what you did.
