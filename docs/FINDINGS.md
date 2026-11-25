# Findings: building a CardDAV demo on the real component

Everything below was observed while building this project on macOS 27.2.1
arm64 with 4D 21.2 LTS (build 21.100694) and the CardDAV 0.1.2 release. Each
entry says what happened and what to do instead.

## 1. `Components/` goes beside `Project/`, not inside it

Staging the component at `Project/Components/CardDAV.4dbase` produced:

```
PackageManager No component to fetch dependencies ()
PackageManager Dependency 'CardDAV' cannot be found ()
tool4d.4DRT [-10716] Object or Collection Expected.
```

`cs.CardDAV` was `Null`, so `cs.CardDAV.Client.new(...)` failed on the next
call. The same files at the repository root — `Components/CardDAV.4dbase`,
a sibling of `Project/` — load on the first try.

```
Components/          <-- 4D and tool4d load components here
 |-- CardDAV.4dbase/
 |-- (other components)
Project/
 |-- CardDAV-demo.4DProject
```

`scripts/fetch_dependency.py` therefore defaults to `Components`;
`--destination Project/Components` is the path that does not work. The two
`PackageManager` warnings still print even on a successful run; they are
noise, not the failure.

## 2. Unpacking a release ZIP with Python loses the executable bit

`zipfile` restores names, not permissions. The component's bundled CLI then
fails at launch:

```
tool4d.POSX [13] Permission denied
```

and the envelope reports `launch_failed` for every operation that spawns the
binary — `build`, `parse`, `version`, even the atlas rows that are supposed
to fail *before* reaching the CLI. The fix is one line in the extractor:

```python
mode = (member.external_attr >> 16) & 0o777
if mode:
    target.chmod(mode)
```

Symptom to recognise: a launch failure that follows a successful component
load, with `Permission denied` in the tool4d output.

## 3. A bare LF inside a vCard is `invalid_vcard`

The CLI rejects vCard `Text` that contains a line feed not preceded by CR.
A card whose `NOTE` was built with `Char(10)` therefore failed to parse, and
because the demo binds that card at startup, the whole Studio sample showed
zero properties.

Correct raw text escapes the newline instead:

```
NOTE:Two lines\nand a comma\, a semicolon\; and a backslash \\
```

In 4D source that is `"...Two lines\\n and a comma\\, ..."` — a doubled
backslash, then the letter, because 4D string literals only escape `"` and
`\`. This is a genuinely useful demo fact: the escaping is the parser's
contract, not cosmetics.

## 4. Private and loopback addresses are refused before dialing

`unsafe_url` comes back for `https://127.0.0.1/` and other private ranges, so
a local mock CardDAV server is not possible. Two consequences:

* the live half of the demo needs a real server with a real certificate;
* the refusal itself is a demonstrable row in the atlas (`discover-private`),
  and the no-secret live evidence is an anonymous `discover` against a public
  endpoint (`https://contacts.icloud.com/`), whose `authentication_failed` is
  a real network answer.

Do not build the acceptance test around a mock server; it cannot exist.

## 5. Writing 4D code: three syntax traps that cost real time

| Trap | Signature | Fix |
| --- | --- | --- |
| A continuation line starting with `;` inside a multi-line call | `Syntax error` on every following line | Build objects statement by statement (`$o:=New object` then `$o.k:=v`) |
| `Function f()->$x : T` plus `var $x` | `Redefinition of the parameter $x` | The return variable **is** the declaration; drop the `var` |
| `$text[[$i]]` | Ambiguous parse | `Substring($text; $i; 1)` / `Character code(...)` |

The third one matters for byte-level auditing: this project compares CRLF and
octets character by character.

## 6. `FORM GET OBJECTS` takes no form name

`FORM GET OBJECTS($names; $types; "Studio")` does not compile:

```
error: Impossible to cast Text to Integer.
```

The command reads the current form only, so the pattern is `FORM LOAD(name)`,
then `FORM GET OBJECTS($names; $types)`, then `FORM UNLOAD` (also no
parameter). `FORM LOAD` validates the `.4DForm` JSON and the object tree but
does not run the form's `On Load` method, so headless acceptance checks the
layout here and the binding by calling `cs.Studio.bind()` directly.

## 7. A zero exit code is not a passing run

When the component was missing, tool4d printed a 4DRT error and **exited 0**.
The only reliable verdict is the report file the startup method writes, which
is why `scripts/smoke.sh` treats a missing or empty report as failure and
`scripts/verify.py` asserts facts rather than trusting the process.

## 8. LSP: expected noise, and an absolute-path requirement

`tool4d-lsp-stdio validate` reports:

```
Classes/Studio.4dm: error: The class cs.CardDAV is unknown.
```

This is expected for a dependency component compiled into a `.4DZ`: the
analyzer never sees its class store (the same limit documented in the skills'
`dependencies.md`; `Compile project` under tool4d has it too). Treat only the
other diagnostics as real — during this build the LSP caught three genuine
errors (two var redefinitions and every line of a mis-continued call).

Passing relative `.4dm` paths to the validator fails with
`file not found ... (os error 2)`; give absolute paths.

## 9. The component's error codes are precise and worth showing

Captured from real runs, not documentation:

| Input | Code | Layer |
| --- | --- | --- |
| `build` with no `formattedName` | `invalid_request` | CLI |
| `build` with version `2.1` | `unsupported_version` | CLI |
| `build` with an unknown contact key (`photo`) | `invalid_request` | CLI |
| `build` with a NUL in `uid` | `invalid_request` | CLI |
| `parse` of empty / UID-less / two-card text | `invalid_vcard` | CLI |
| `update` with `W/"weak"` or an unquoted ETag | `invalid_request` | CLI |
| `update` against `http://` | `invalid_request` | CLI |
| `discover` against `http://` | `invalid_request` | CLI |
| `discover` against `https://127.0.0.1/` | `unsafe_url` | CLI |
| `request(Null)` / unknown operation | `invalid_argument` | component |
| wrong native target on macOS | `unsupported_architecture` | `_CLI`, before launch |

`build` also rejects contact objects carrying keys outside the documented
summary, which is why the demo never passes a parsed `properties` collection
back into `build`.

## 10. What the demo cannot prove

* Live CRUD against a server: needs credentials nobody should commit.
* Compiled mode, Intel and Windows 4D: not exercised here.
* `FORM SCREENSHOT` needs 4D 21 R3 or later; the preview images in `docs/`
  are static renders of the `.4DForm` JSON, not screenshots of a running
  window.

State these as `not_run`, not as passed.
