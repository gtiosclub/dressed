"""Scores the link reader against hand-checked answers.

Manifest: JSON list of {"id", "url", "snapshot"?, "expected": {field: value|null}}.
- "snapshot" is a saved HTML file (relative to the manifest); the page is not fetched.
- Without "snapshot" the page is fetched live. Only list stores whose terms and
  robots rules allow it.
- In "expected", a value means the page states it; null means the page does not,
  so the field must stay open.
Per field: correct, wrong, missing (page states it, we left it open), correctly_open,
wrongly_filled (page does not state it, we filled it). Wrong and wrongly_filled both
count as wrong values.
"""

from __future__ import annotations

import argparse
import json
import statistics
from pathlib import Path

from reader import FIELDS, read_product_link

SCORED = [f for f in FIELDS if f not in ("link",)]


def value_of(field: dict):
    value = field["value"]
    if isinstance(value, dict):
        return f"{value['amount']} {value['currency']}"
    return value


def score(manifest_path: Path) -> dict:
    entries = json.loads(manifest_path.read_text())
    tallies = {f: dict(correct=0, wrong=0, missing=0, correctly_open=0, wrongly_filled=0) for f in SCORED}
    sources: dict[str, dict[str, int]] = {f: {} for f in SCORED}
    timings, per_link = [], []
    for entry in entries:
        fetcher = None
        if entry.get("snapshot"):
            html = (manifest_path.parent / entry["snapshot"]).read_text()
            status = entry.get("status", 200)
            fetcher = lambda url, resolver=None, html=html, status=status: (status, url, html)
        draft = (read_product_link(entry["url"], entry["id"], fetcher=fetcher) if fetcher
                 else read_product_link(entry["url"], entry["id"]))
        timings.append(draft["elapsedMs"])
        row = {"id": entry["id"], "status": draft["status"], "elapsedMs": draft["elapsedMs"]}
        for name in SCORED:
            expected = entry.get("expected", {}).get(name, None)
            got = value_of(draft["fields"][name])
            if expected is None and got is None:
                kind = "correctly_open"
            elif expected is None:
                kind = "wrongly_filled"
            elif got is None:
                kind = "missing"
            else:
                kind = "correct" if str(got) == str(expected) else "wrong"
            tallies[name][kind] += 1
            row[name] = kind
            if got is not None:
                source = draft["fields"][name]["source"]
                sources[name][source] = sources[name].get(source, 0) + 1
        per_link.append(row)
    filled = sum(t["correct"] + t["wrong"] + t["wrongly_filled"] for t in tallies.values())
    bad = sum(t["wrong"] + t["wrongly_filled"] for t in tallies.values())
    permitted = [r for r, e in zip(per_link, entries) if r["status"] == "ready"]
    name_image_ok = sum(1 for r in permitted if r["name"] == "correct" and r["image"] == "correct")
    ordered = sorted(timings)
    p95 = ordered[min(len(ordered) - 1, int(0.95 * len(ordered)))] if ordered else 0
    return {
        "links": len(entries),
        "perField": tallies,
        "sourcesUsed": sources,
        "autoFilledFields": filled,
        "wrongAmongAutoFilled": bad,
        "wrongRate": round(bad / filled, 4) if filled else 0,
        "nameAndImageFilledCorrectly": f"{name_image_ok}/{len(permitted)} ready pages",
        "timeMs": {"p50": int(statistics.median(timings)) if timings else 0, "p95": p95},
        "perLink": per_link,
        "gates": {
            "wrongRateAtMost2Percent": (bad / filled <= 0.02) if filled else None,
            "nameAndImageAtLeast80Percent": (name_image_ok / len(permitted) >= 0.8) if permitted else None,
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--out", type=Path, help="write the JSON report here")
    args = parser.parse_args()
    report = score(args.manifest)
    text = json.dumps(report, indent=2)
    if args.out:
        args.out.write_text(text)
    print(text)


if __name__ == "__main__":
    main()
