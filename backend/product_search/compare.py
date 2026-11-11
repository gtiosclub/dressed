"""Run fresh Lens queries and the existing catalog text baseline for the same photos.

Input images must be prepared JPEG crops <= 500 KB. Use reviewed descriptions,
not known product IDs/titles leaked from ground truth, for the text baseline.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "catalog"))
from catalog import CatalogDatabase


def compare(samples: list, root: Path, catalog: CatalogDatabase, port: int) -> list:
    rows = []
    for sample in samples:
        image = (root / sample["imagePath"]).read_bytes()
        if not image.startswith(b"\xff\xd8\xff") or not 0 < len(image) <= 500_000:
            raise ValueError("Each sample must be a prepared JPEG crop <= 500 KB")
        row = {"sampleId": sample["id"], "imageHash": hashlib.sha256(image).hexdigest(),
               "category": sample["category"], "query": sample["query"], "judgments": []}
        started = time.perf_counter()
        request = Request(f"http://127.0.0.1:{port}/product-search", data=image,
                          headers={"Content-Type": "image/jpeg", "X-Request-ID": str(uuid.uuid4())})
        try:
            with urlopen(request, timeout=65) as response:
                row["lens"] = json.load(response)
        except (URLError, TimeoutError, ValueError):
            row["lens"] = {"error": "Request failed; include this miss in the comparison."}
        row["lensSeconds"] = time.perf_counter() - started
        started = time.perf_counter()
        row["catalogTextBaseline"] = catalog.search(sample["query"], sample["category"], limit=5)
        row["catalogSeconds"] = time.perf_counter() - started
        rows.append(row)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--db", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--port", type=int, default=8767)
    args = parser.parse_args()
    if not args.db.is_file():
        parser.error("Import an approved feed into the catalog database first")
    samples = json.loads(args.manifest.read_text())
    if not isinstance(samples, list) or not 1 <= len(samples) <= 100:
        parser.error("Manifest must contain 1...100 samples")
    catalog = CatalogDatabase(args.db)
    try:
        rows = compare(samples, args.manifest.parent, catalog, args.port)
    finally:
        catalog.close()
    report = {"createdAt": datetime.now(timezone.utc).isoformat(),
              "manifestHash": hashlib.sha256(args.manifest.read_bytes()).hexdigest(),
              "catalogHash": hashlib.sha256(args.db.read_bytes()).hexdigest(),
              "note": "Catalog uses reviewed text/category, not image embeddings. Human judgments required. "
                      "Catalog status alone does not establish current stock/price; inspect lastCheckedAt.",
              "samples": rows}
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Wrote {len(rows)} paired results. Preserve misses; review links, freshness and relevance manually.")


if __name__ == "__main__":
    main()
