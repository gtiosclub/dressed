"""Held-out matching check: can a different photo of a product find that product?

    python3 backend/catalog/evaluate_catalog_pack.py PACK_DIR --model ClothesParser.mlpackage

For sampled products, the query is the first gallery photo that was not used for
the index cutout and is not a generated square copy of another shot. It is cut out the way the app cuts a person's piece and
ranked against the same category. Gate: the product is in the top 3 at least 70%.
"""
from __future__ import annotations

import argparse
import json
import random
import struct
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

from build_catalog_pack import Tool, download

GATE = 0.7


def load_pack(directory: Path) -> tuple[list[dict], list[tuple[float, ...]]]:
    index = json.loads((directory / "index.json").read_text())
    size = index["dimension"]
    data = (directory / "vectors.bin").read_bytes()
    vectors = [struct.unpack_from(f"<{size}f", data, row * size * 4)
               for row in range(len(index["products"]))]
    return index["products"], vectors


def rank_of(target: int, query: list[float], products: list[dict], vectors: list) -> int:
    """1-based rank of the target among products of its category."""
    def similarity(row: int) -> float:
        return sum(a * b for a, b in zip(query, vectors[row]))

    own = similarity(target)
    category = products[target]["category"]
    return 1 + sum(1 for row, product in enumerate(products)
                   if row != target and product["category"] == category and similarity(row) > own)


def derived_view(url: str) -> bool:
    """Livostyle's generated square images repeat another gallery shot."""
    return "square" in url.rsplit("/", 1)[-1].lower()


def query_image(source: dict, include_derived: bool) -> str | None:
    """The first gallery photo that is not the indexed one (or, by default, a copy of a shot)."""
    return next((url for url in source["gallery"] if url != source["cutoutSource"]
                 and (include_derived or not derived_view(url))), None)


def summarize(ranks: dict[str, list[int]]) -> dict:
    def rates(values: list[int]) -> dict:
        return {"queries": len(values),
                "top1": round(sum(r == 1 for r in values) / len(values), 3),
                "top3": round(sum(r <= 3 for r in values) / len(values), 3)}

    everything = [rank for values in ranks.values() for rank in values]
    if not everything:
        raise ValueError("no query could be evaluated")
    overall = rates(everything)
    return {"overall": overall, "gatePassed": overall["top3"] >= GATE,
            "byCategory": {key: rates(value) for key, value in sorted(ranks.items())}}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=50)
    parser.add_argument("--include-derived", action="store_true",
                        help="also query with square copies of shots (overstates accuracy)")
    parser.add_argument("--save-queries", type=Path, help="keep query cutouts here")
    args = parser.parse_args()
    products, vectors = load_pack(args.pack)
    sources = {s["id"]: s for s in json.loads((args.pack / "sources.json").read_text())}
    order = list(range(len(products)))
    random.Random(11).shuffle(order)
    ranks: dict[str, list[int]] = defaultdict(list)
    cases = []
    with tempfile.TemporaryDirectory() as directory:
        tool = Tool(Path(directory), args.model)
        keep = args.save_queries or Path(directory)
        keep.mkdir(parents=True, exist_ok=True)
        for row in order:
            if len(cases) >= args.samples:
                break
            product = products[row]
            source = sources[product["id"]]
            url = query_image(source, args.include_derived)
            path = download(url, args.pack / "cache") if url else None
            if path is None:
                continue
            reply = tool.run(op="query", id=product["id"], category=product["category"],
                             images=[str(path)], cutout=str(keep / f"{product['id']}.png"),
                             canonical=str(keep / f"{product['id']}.canonical.png"))
            if "vector" not in reply:
                continue
            rank = rank_of(row, reply["vector"], products, vectors)
            ranks[product["category"]].append(rank)
            cases.append({"id": product["id"], "rank": rank, "method": reply["method"]})
        tool.close()
    report = summarize(ranks)
    report["catalogSize"] = len(products)
    report["includesDerivedViews"] = args.include_derived
    if args.save_queries:
        (args.save_queries / "cases.json").write_text(json.dumps(cases))
    print(json.dumps(report, indent=2))
    sys.exit(0 if report["gatePassed"] else 1)


if __name__ == "__main__":
    main()
