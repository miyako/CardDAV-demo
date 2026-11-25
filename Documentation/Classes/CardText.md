# CardText

`cs.CardText` — byte-level inspection of vCard `Text`, with no form state, no
component call and no disk access.

The component's contract is that the raw parser preserves the supplied vCard
`Text`: CRLF framing, 75-octet folding and unknown properties survive `parse()`
and are what `update()` sends back. These functions exist so the demo can show
that contract instead of asserting it, and so the headless report can audit
real builder output.

## Functions

| Function | Returns | Purpose |
| --- | --- | --- |
| `octets($text)` | Integer | UTF-8 octet count; `Length()` counts characters, folding limits are octets |
| `lines($text)` | Collection | Physical lines, split on CRLF or bare CR/LF |
| `crlfCount($text)` | Integer | Number of CR LF pairs |
| `bareLfCount($text)` | Integer | Line feeds not preceded by CR — the CLI rejects these in a vCard |
| `audit($text)` | Object | `{lineCount, longestLineOctets, linesOver75, foldedLines, crlfCount, bareLfCount, hasBom}` |
| `auditText($audit)` | Text | One-line summary for a form label |
| `visible($text)` | Text | CR and TAB made visible; the line feed stays a real break |
| `nameSet($properties)` | Object | Set of property names in a parse result |
| `lostProperties($before; $after)` | Collection | `{name, value}` per property present before a rebuild and absent after |

Every function accepts a `Variant` and returns a neutral empty value for
non-Text / non-Collection input, so a failed component call degrades to an
empty report instead of a runtime error.
