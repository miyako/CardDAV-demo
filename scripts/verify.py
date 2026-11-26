#!/usr/bin/env python3
"""Assert the headless report from Demo_HeadlessSmoke.

    python3 scripts/verify.py /tmp/CardDAV-demo-smoke.json

Every check is a fact the demo teaches, so a changed component version or a
regression in escaping shows up here rather than in a screenshot later.
"""
import json
import sys

CODES = {
    "invalid_request", "unsupported_version", "invalid_vcard", "unsafe_url",
    "invalid_argument", "unsupported_architecture",
}


def lines_of(text):
    """Physical CRLF lines of a vCard, as raw bytes."""
    return [line for line in text.split("\r\n")]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/CardDAV-demo-smoke.json"
    with open(path, encoding="utf-8") as handle:
        report = json.load(handle)

    checks = []

    def check(name, ok, detail=""):
        checks.append((name, bool(ok), detail))

    studio = report.get("studio", {})
    lab = report.get("lab", {})
    sample = studio.get("sample", {})
    build4 = studio.get("build4", {})
    build3 = studio.get("build3", {})
    round_trip = studio.get("roundTrip", {})

    check("report passed", report.get("passed") is True)
    check("run made no network call", report.get("offlineOnly") is True)
    check("source, not compiled", report.get("compiled") is False)

    component = report.get("component", {})
    check("component loads", component.get("ok") is True, component.get("code"))
    check("component version", component.get("version") == "0.1.2",
          component.get("version"))

    check("sample parses", sample.get("ok") is True)
    check("sample raw Text preserved", sample.get("lossless") is True)
    check("raw comparison is case and accent sensitive",
          sample.get("strictCompare") is True)
    check("sample exposes 10 properties", sample.get("properties") == 10,
          sample.get("properties"))
    audit = sample.get("audit", {})
    check("sample uses CRLF only", audit.get("bareLfCount") == 0)
    check("sample has no BOM", audit.get("hasBom") is False)

    check("4.0 build succeeds", build4.get("ok") is True, build4.get("code"))
    vcard = build4.get("vcard", "")
    check("4.0 build starts a card", vcard.startswith("BEGIN:VCARD\r\n"))
    check("4.0 build declares VERSION:4.0", "\r\nVERSION:4.0\r\n" in vcard)
    check("4.0 build emits a URN UUID", "\r\nUID:urn:uuid:" in vcard)
    check("4.0 build ends the card", vcard.endswith("END:VCARD\r\n"))
    check("4.0 build keeps CRLF framing", build4.get("crlfOk") is True)
    check("4.0 build folds within 75 octets", build4.get("foldingOk") is True)
    check("4.0 build escapes a comma", build4.get("escapedComma") is True)
    check("4.0 build escapes a semicolon",
          build4.get("escapedSemicolon") is True)
    check("4.0 build escapes a newline", build4.get("escapedNewline") is True)
    check("4.0 build still parses into the properties panel",
          (build4.get("properties") or 0) >= 5, build4.get("properties"))
    physical = lines_of(vcard)
    check("no physical line exceeds 75 octets",
          all(len(line.encode("utf-8")) <= 75 for line in physical),
          max((len(line.encode("utf-8")) for line in physical), default=0))

    check("3.0 build succeeds", build3.get("ok") is True, build3.get("code"))
    check("3.0 build generates a UID", build3.get("generatedUID") is True)
    check("3.0 build writes empty structured N",
          build3.get("emptyStructuredN") is True)

    check("round-trip succeeds", round_trip.get("ok") is True,
          round_trip.get("code"))
    check("round-trip names what a rebuild drops",
          round_trip.get("lostNamed") is True)
    fidelity = round_trip.get("fidelity", "")
    check("round-trip reports uid + FN of 10 properties",
          "uid + FN" in fidelity and "of 10 properties" in fidelity)

    presets = lab.get("presets", [])
    check("five build presets", len(presets) == 5, len(presets))
    for row in presets:
        check(f"preset {row.get('id')} builds",
              row.get("verdict") == "PASS",
              row.get("code") or row.get("verdict"))

    atlas = lab.get("atlas", [])
    check("fifteen catalogue rows", len(atlas) == 15, len(atlas))
    for row in atlas:
        check(f"{row.get('id')} returns {row.get('expect')}",
              row.get("actual") == row.get("expect"),
              f"expected {row.get('expect')} got {row.get('actual')}")
    seen = {row.get("actual") for row in atlas}
    check("catalogue covers the refusal codes", seen <= CODES, sorted(seen))
    seen_layers = {row.get("layer") for row in atlas}
    check("catalogue covers component and CLI layers",
          {"component", "cli", "prelaunch"} <= seen_layers, sorted(seen_layers))

    gates = report.get("gates", {})
    if gates:
        for name in sorted(gates):
            check(f"gate {name}", gates[name] is True, gates[name])

    forms = report.get("forms", {})
    for name in ("Studio", "Lab"):
        entry = forms.get(name, {})
        check(f"{name} form loads", entry.get("ok") is True,
              entry.get("error") or "loaded")
        check(f"{name} form has no missing objects",
              entry.get("missing") == [], entry.get("missing"))

    failed = [row for row in checks if not row[1]]
    for name, ok, detail in checks:
        print(f"{'PASS' if ok else 'FAIL'}  {name}"
              + (f"  ({detail})" if detail not in ("", None) else ""))
    print(f"\n{len(checks) - len(failed)} of {len(checks)} checks passed")
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
