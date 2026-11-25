#!/usr/bin/env python3
"""Generate the two demo forms.

The .4DForm JSON is the deliverable; this script keeps the layout readable and
consistent (shared palette, shared helpers, overlap check). Re-run after any
layout change, then validate:

    tools/4dform/boon .agents/schemas/4dform/formsSchema.json \
        Project/Sources/Forms/Studio/form.4DForm
    tools/4dform/fourdform Project/Sources/Forms/Studio/form.4DForm \
        -o docs/studio-preview.png

Studio is the live workbench; Lab is the offline showcase. Both forms only
dispatch: every result comes from cs.Studio / cs.Lab.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent / "Project/Sources/Forms"


def text(name, left, top, width, height, value, cls=None, align=None):
    o = {"type": "text", "left": left, "top": top, "width": width,
         "height": height, "text": value}
    if cls:
        o["class"] = cls
    if align:
        o["textAlign"] = align
    return o


def button(name, left, top, width, height, label, cls="action"):
    return {"type": "button", "left": left, "top": top, "width": width,
            "height": height, "text": label, "style": "roundedBevel",
            "class": cls, "events": ["onClick"]}


def input_(name, left, top, width, height, source, cls=None,
           multiline=False, enterable=True, border=None, hint=None,
           password=False):
    o = {"type": "input", "left": left, "top": top, "width": width,
         "height": height, "dataSource": source}
    if hint:
        o["dataSourceTypeHint"] = hint
    if cls:
        o["class"] = cls
    if multiline:
        o["multiline"] = "yes"
        o["wordwrap"] = "normal"
        o["scrollbarVertical"] = "automatic"
        o["events"] = ["onDataChange"]
    if not enterable:
        o["enterable"] = False
        o["focusable"] = True
        o["hideFocusRing"] = True
    if border:
        o["borderStyle"] = border
    if password:
        o["fontFamily"] = "%password"
    return o


def listbox(name, left, top, width, height, source, current, columns,
            cls="list"):
    return {
        "type": "listbox", "left": left, "top": top, "width": width,
        "height": height, "dataSource": source, "currentItemSource": current,
        "selectionMode": "single", "resizingMode": "legacy",
        "rowHeight": "26px", "headerHeight": "24px",
        "borderStyle": "solid", "class": cls,
        "scrollbarVertical": "automatic",
        "alternateFill": "automaticAlternate",
        "events": ["onClick"],
        "columns": columns,
    }


def col(name, source, width, align="left"):
    return {"name": name, "dataSource": source, "width": width,
            "truncateMode": "none", "textAlign": align,
            "verticalAlign": "middle"}


def form(width, height, title, events, objects):
    return {
        "$4d": {"version": "1", "kind": "form"},
        "windowSizingX": "fixed",
        "windowSizingY": "fixed",
        "windowMinWidth": width,
        "windowMinHeight": height,
        "windowMaxWidth": width,
        "windowMaxHeight": height,
        "width": width,
        "height": height,
        "events": events,
        "windowTitle": title,
        "destination": "detailScreen",
        "method": "method.4dm",
        "pages": [
            {"objects": {
                "canvas": {"type": "rectangle", "left": 0, "top": 0,
                           "width": width, "height": height,
                           "fill": "automatic", "stroke": "transparent"}}},
            {"objects": objects},
        ],
    }


# ------------------------------------------------------------------- Studio
W, H = 1260, 840
studio = {
    "title": text("title", 24, 16, 520, 34, "CardDAV", "appTitle"),
    "subtitle": text("subtitle", 24, 54, 760, 20,
                     "Point it at your own server — discovery, conditional "
                     "CRUD, and the raw vCard the server actually stores",
                     "appSubtitle"),
    "badge": text("badge", 820, 24, 416, 22, "resolving…", "badge", "right"),
    "rule": {"type": "rectangle", "left": 24, "top": 86, "width": 1212,
             "height": 1, "stroke": "transparent", "class": "rule"},

    # 1 · server + 2 · books + 3 · contacts (column A)
    "s1": text("s1", 24, 100, 372, 18, "1 · SERVER", "section"),
    "lblEndpoint": text("lblEndpoint", 24, 122, 372, 16,
                        "Endpoint — HTTPS is the trust anchor", "label"),
    "endpoint": input_("endpoint", 24, 140, 372, 26, "Form.endpoint",
                       cls="field", hint="text"),
    "lblUser": text("lblUser", 24, 172, 180, 16, "Username (optional)",
                    "label"),
    "lblPassword": text("lblPassword", 212, 172, 184, 16,
                        "App password (memory only)", "label"),
    "username": input_("username", 24, 190, 180, 26, "Form.username",
                       cls="field", hint="text"),
    "password": input_("password", 212, 190, 184, 26, "Form.password",
                       cls="field", password=True),
    "btnDiscover": button("btnDiscover", 24, 224, 150, 30, "Discover",
                          "secondary"),
    "btnProbe": button("btnProbe", 182, 224, 214, 30, "Anonymous probe",
                       "secondary"),
    "discoveryText": input_("discoveryText", 24, 262, 372, 64,
                            "Form.discoveryText", cls="console",
                            multiline=True, enterable=False, border="none"),

    "s2": text("s2", 24, 334, 372, 18, "2 · ADDRESS BOOKS", "section"),
    "bookList": listbox(
        "bookList", 24, 356, 372, 96, "Form.bookRows", "Form.selectedBook",
        [col("Book", "This.displayName", 190),
         col("vCard", "This.versions", 70),
         col("URL", "This.url", 100)]),
    "bookURL": input_("bookURL", 24, 458, 372, 26, "Form.bookURL",
                      cls="field", hint="text",

                      ),

    "s3": text("s3", 24, 492, 372, 18, "3 · CONTACTS", "section"),
    "filterProperty": input_("filterProperty", 24, 514, 180, 26,
                             "Form.filterProperty", cls="field",
                             hint="text"),
    "matchType": input_("matchType", 212, 514, 184, 26, "Form.matchType",
                        cls="field", hint="text"),
    "hintFilter": text("hintFilter", 24, 542, 372, 16,
                       "property: FN N EMAIL TEL ORG UID NOTE TITLE URL · "
                       "match: contains equals starts-with ends-with", "hint"),
    "filterText": input_("filterText", 24, 562, 250, 26, "Form.filterText",
                         cls="field", hint="text"),
    "limit": input_("limit", 282, 562, 114, 26, "Form.limit", cls="field",
                    hint="number"),
    "btnQuery": button("btnQuery", 24, 596, 120, 30, "Query", "secondary"),
    "url": input_("url", 24, 634, 372, 26, "Form.url", cls="field",
                  hint="text"),
    "etag": input_("etag", 24, 664, 372, 26, "Form.etag", cls="field",
                   hint="text"),
    "contactList": listbox(
        "contactList", 24, 696, 372, 88, "Form.contactRows",
        "Form.selectedContact",
        [col("Name", "This.name", 170),
         col("vCard", "This.version", 56),
         col("ETag", "This.shortETag", 130)]),
    "btnGet": button("btnGet", 24, 788, 84, 30, "GET", "secondary"),
    "btnCreate": button("btnCreate", 116, 788, 84, 30, "Create",
                        "secondary"),
    "btnUpdate": button("btnUpdate", 208, 788, 88, 30, "Update",
                        "secondary"),
    "btnDelete": button("btnDelete", 304, 788, 92, 30, "Delete",
                        "secondary"),

    # 4 · draft + 5 · raw (column B)
    "s4": text("s4", 416, 100, 380, 18, "4 · DRAFT CONTACT", "section"),
    "lblFN": text("lblFN", 416, 122, 380, 16, "Formatted name (FN)", "label"),
    "formattedName": input_("formattedName", 416, 140, 380, 26,
                            "Form.formattedName", cls="field", hint="text"),
    "lblName": text("lblName", 416, 172, 380, 16, "Family / given name",
                    "label"),
    "familyName": input_("familyName", 416, 190, 184, 26, "Form.familyName",
                         cls="field", hint="text"),
    "givenName": input_("givenName", 604, 190, 192, 26, "Form.givenName",
                        cls="field", hint="text"),
    "lblOrg": text("lblOrg", 416, 222, 380, 16, "Organization / title",
                   "label"),
    "organization": input_("organization", 416, 240, 184, 26,
                           "Form.organization", cls="field", hint="text"),
    "title": input_("title", 604, 240, 192, 26, "Form.title", cls="field",
                    hint="text"),
    "lblNote": text("lblNote", 416, 272, 380, 16,
                    "Note — commas, semicolons and newlines are escaped",
                    "label"),
    "note": input_("note", 416, 290, 380, 48, "Form.note", cls="field",
                   multiline=True),
    "lblEmail": text("lblEmail", 416, 342, 380, 16, "Email / phone", "label"),
    "email": input_("email", 416, 360, 184, 26, "Form.email", cls="field",
                    hint="text"),
    "phone": input_("phone", 604, 360, 192, 26, "Form.phone", cls="field",
                    hint="text"),
    "lblVersion": text("lblVersion", 416, 392, 96, 16, "vCard version",
                       "label"),
    "versionChoice": input_("versionChoice", 416, 408, 96, 26,
                            "Form.versionChoice", cls="field", hint="text"),
    "btnBuild": button("btnBuild", 520, 406, 110, 30, "Build",
                       "secondary"),
    "btnRoundTrip": button("btnRoundTrip", 636, 406, 160, 30,
                           "Round-trip → loss", "secondary"),
    "btnParse": button("btnParse", 416, 440, 110, 30, "Parse raw",
                       "secondary"),
    "btnSeed": button("btnSeed", 532, 440, 120, 30, "Server card",
                      "secondary"),

    "s5": text("s5", 416, 478, 380, 18,
               "5 · RAW vCARD — WHAT UPDATE SENDS", "section"),
    "rawEditor": input_("rawEditor", 416, 500, 380, 150, "Form.rawEditor",
                        cls="console", multiline=True),
    "auditText": text("auditText", 416, 654, 380, 16, "", "hint"),
    "lblFidelity": text("lblFidelity", 416, 674, 380, 16,
                        "Fidelity / loss", "label"),
    "fidelityText": input_("fidelityText", 416, 692, 380, 58,
                           "Form.fidelityText", cls="console",
                           multiline=True, enterable=False, border="none"),
    "lblStatus": text("lblStatus", 416, 754, 380, 16, "Status", "label"),
    "statusText": input_("statusText", 416, 772, 380, 44, "Form.statusText",
                         cls="console", multiline=True, enterable=False,
                         border="none"),

    # 6 · parse + 7 · envelope + 8 · notes (column C)
    "s6": text("s6", 820, 100, 436, 18,
               "6 · PARSE — PROPERTIES THE CLI SEES", "section"),
    "parseText": input_("parseText", 820, 122, 436, 150, "Form.parseText",
                        cls="console", multiline=True, enterable=False,
                        border="none"),
    "s7": text("s7", 820, 280, 436, 18,
               "7 · COMPONENT ENVELOPE (UNEDITED)", "section"),
    "envelopeText": input_("envelopeText", 820, 302, 436, 240,
                           "Form.envelopeText", cls="console",
                           multiline=True, enterable=False, border="none"),
    "s8": text("s8", 820, 550, 436, 18, "8 · WHAT IS REAL HERE", "section"),
    "notesText": input_("notesText", 820, 572, 436, 246,
                        "Form.notesText", cls="hint", multiline=True,
                        enterable=False, border="none"),
}

NOTES = (
    "LIVE — discovery, query and CRUD talk to a real CardDAV server over "
    "verified TLS. Credentials live in memory only: they are never written, "
    "logged or passed on a command line.\n\n"
    "ANONYMOUS PROBE — one discover against a public endpoint, no "
    "credentials. The refusal it returns is real network evidence, not a "
    "mock.\n\n"
    "OFFLINE — build, parse and round-trip run the bundled CLI with no "
    "socket at all, so every lesson on this window works without a server.\n\n"
    "ETAG — create is conditional on absence; update and delete need the "
    "current strong ETag. A stale ETag returns conflict, never an overwrite.\n\n"
    "LOSSLESS — the text in the raw editor is exactly what update sends. A "
    "rebuilt card keeps uid and FN only: PHOTO, grouped properties and X-* "
    "properties are gone."
)

# ---------------------------------------------------------------------- Lab
LW, LH = 1120, 800
lab = {
    "title": text("title", 24, 16, 420, 34, "vCard Lab", "appTitle"),
    "subtitle": text("subtitle", 24, 54, 780, 20,
                     "Five cards, one lossy rebuild, and a catalogue of "
                     "refusals — all offline", "appSubtitle"),
    "badge": text("badge", 820, 24, 276, 22, "", "badge", "right"),
    "rule": {"type": "rectangle", "left": 24, "top": 86, "width": 1072,
             "height": 1, "stroke": "transparent", "class": "rule"},

    "s1": text("s1", 24, 100, 380, 18, "BUILD PRESETS", "section"),
    "presetList": listbox(
        "presetList", 24, 122, 380, 220, "Form.presetRows",
        "Form.selectedPreset",
        [col("Preset", "This.name", 150),
         col("vCard", "This.version", 54),
         col("Verdict", "This.verdict", 64, "center"),
         col("Audit line", "This.auditLine", 230)]),
    "btnRun": button("btnRun", 24, 350, 100, 30, "Show", "secondary"),
    "btnRunAll": button("btnRunAll", 132, 350, 100, 30, "Run all",
                        "secondary"),
    "btnStudio": button("btnStudio", 240, 350, 164, 30, "Open Studio",
                        "secondary"),

    "s2": text("s2", 24, 392, 380, 18, "BUILD OUTPUT", "section"),
    "previewView": input_("previewView", 24, 414, 380, 190,
                          "Form.previewText", cls="console", multiline=True,
                          enterable=False, border="none"),
    "auditText": input_("auditText", 24, 610, 380, 32, "Form.auditText",
                        cls="hint", multiline=True, enterable=False,
                        border="none"),
    "lblNote": text("lblNote", 24, 648, 380, 16, "Why this card", "label"),
    "noteText": input_("noteText", 24, 666, 380, 52, "Form.noteText",
                       cls="hint", multiline=True, enterable=False,
                       border="none"),
    "summaryText": input_("summaryText", 24, 724, 380, 46, "Form.summaryText",
                          cls="hint", multiline=True, enterable=False,
                          border="none"),

    "s3": text("s3", 432, 100, 664, 18,
               "FIDELITY — WHAT A REBUILD DROPS", "section"),
    "lossView": input_("lossView", 432, 122, 664, 110, "Form.lossText",
                       cls="console", multiline=True, enterable=False,
                       border="none"),
    "s4": text("s4", 432, 240, 664, 18,
               "REFUSAL CATALOGUE — EXPECTED VS ACTUAL", "section"),
    "checkList": listbox(
        "checkList", 432, 262, 664, 230, "Form.checkRows",
        "Form.selectedCheck",
        [col("Scenario", "This.id", 220),
         col("Layer", "This.layer", 90),
         col("Expected", "This.expect", 120),
         col("Actual", "This.actual", 120),
         col("Verdict", "This.verdict", 80, "center")]),
    "btnAtlas": button("btnAtlas", 432, 500, 150, 30, "Run catalogue",
                       "secondary"),
    "s5": text("s5", 432, 540, 664, 18, "DETAIL", "section"),
    "detailView": input_("detailView", 432, 562, 664, 140,
                         "Form.detailText", cls="console", multiline=True,
                         enterable=False, border="none"),
    "closingText": text(
        "closingText", 432, 710, 664, 60,
        "Each catalogue row records the code the actual layer returned for "
        "input that layer rejects before any network request. Component "
        "rows never launch a process (invalid_argument); CLI rows return "
        "invalid_request / invalid_vcard / unsupported_version / unsafe_url "
        "with exit code 1; the prelaunch row is refused by _CLI before "
        "spawning (unsupported_architecture). Nothing here is mocked, and "
        "nothing here touches the network.", "hint"),
}

FORMS = {
    "Studio": form(W, H, "CardDAV — Studio", ["onLoad", "onUnload"], studio),
    "Lab": form(LW, LH, "CardDAV — vCard Lab", ["onLoad", "onUnload"], lab),
}


def check_overlap(name, objects):
    """Report pairs of positioned objects that intersect (not a 4D check)."""
    boxes = []
    for key, o in objects.items():
        if "left" not in o or o.get("type") == "rectangle":
            continue
        boxes.append((key, o["left"], o["top"],
                      o["left"] + o["width"], o["top"] + o["height"]))
    hits = []
    for i, a in enumerate(boxes):
        for b in boxes[i + 1:]:
            if a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]:
                hits.append((a[0], b[0]))
    return hits


def main():
    for name, data in FORMS.items():
        target = ROOT / name / "form.4DForm"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            json.dumps(data, indent="\t", ensure_ascii=False) + "\n",
            encoding="utf-8")
        hits = check_overlap(name, data["pages"][1]["objects"])
        print(f"wrote {target.relative_to(ROOT.parent.parent)} "
              f"({len(data['pages'][1]['objects'])} objects) "
              f"overlaps={hits if hits else 'none'}")


if __name__ == "__main__":
    main()
