"""Build a local catalog pack: cut-out product images plus a matching index.

    python3 backend/catalog/build_catalog_pack.py products.json OUTPUT_DIR \
        --model ClothesParser.mlpackage

Input is a saved Livostyle open-data snapshot (see README). Product images are
downloaded from the retailer's CDN for local evaluation; neither they nor their
cutouts are committed, uploaded or redistributed by this tool. Nothing is written
to Firebase. Runs on macOS only (Apple Vision).

Pack layout: index.json, vectors.bin (little-endian float32, one row per product,
same order), cutouts/<id>.png.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import shutil
import struct
import subprocess
import tempfile
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit

from livostyle import category_for, convert_dataset
from retail_product import empty_offer, empty_product, photos

MODEL = "apple-featureprint-2"
TARGETS = {"tops": 250, "pants": 250, "skirts": 250, "dresses": 250,
           "shoes": 250, "outerwear": 250, "accessories": 100}
# Hats, bags and jewelry, plus belts and eyewear which the parser also finds.
ACCESSORY_WORDS = ("hat", "cap", "bag", "necklace", "earring", "bracelet", "ring",
                   "belt", "sunglass", "scarf", "beanie")
COLORS = {"black": ("black",), "white": ("white", "ivory", "cream"), "denim": ("denim", "blue"),
          "neutral": ("beige", "brown", "gray", "grey", "khaki"),
          "bright": ("red", "pink", "green", "yellow", "orange", "purple")}
IMAGE_HOST = "cdn.shopify.com"
MAX_IMAGE_BYTES = 8_000_000
GALLERY_LIMIT = 6


def color_of(record: dict) -> str:
    words = {str(tag).lower() for tag in record.get("tags") or []}
    words |= set(str(record.get("title", "")).lower().split())
    return next((group for group, names in COLORS.items() if words & set(names)), "other")


def gallery(record: dict) -> list[str]:
    urls = []
    for image in record.get("images") or []:
        url = image.get("url") if isinstance(image, dict) else None
        if url and urlsplit(url).scheme == "https" and urlsplit(url).hostname == IMAGE_HOST:
            urls.append(url)
    return urls


def select(records: list[dict], targets: dict[str, int] = TARGETS, seed: int = 1) -> list[tuple[str, dict]]:
    """Up to the target per category, taking colors in turn so none dominates."""
    chosen = []
    shuffled = list(records)
    random.Random(seed).shuffle(shuffled)
    for category, target in targets.items():
        buckets: dict[str, list[dict]] = {}
        for record in shuffled:
            name = record["category"]["name"]
            if category_for(name) != category or not gallery(record):
                continue
            if category == "accessories" and not any(w in name.lower() for w in ACCESSORY_WORDS):
                continue
            buckets.setdefault(color_of(record), []).append(record)
        count = 0
        while count < target and any(buckets.values()):
            for bucket in buckets.values():
                if bucket and count < target:
                    chosen.append((category, bucket.pop()))
                    count += 1
    return chosen


def sized(url: str, width: int = 800) -> str:
    return url + ("&" if "?" in url else "?") + f"width={width}"


def download(url: str, cache: Path) -> Path | None:
    target = cache / (hashlib.sha256(url.encode()).hexdigest()[:24] + ".img")
    if target.exists():
        return target
    try:
        request = urllib.request.Request(sized(url), headers={"User-Agent": "catalog-pack-builder"})
        with urllib.request.urlopen(request, timeout=30) as response:
            if urlsplit(response.url).hostname != IMAGE_HOST:
                return None
            data = response.read(MAX_IMAGE_BYTES + 1)
    except OSError:
        return None
    if not data or len(data) > MAX_IMAGE_BYTES:
        return None
    partial = target.with_suffix(".part")
    partial.write_bytes(data)
    partial.rename(target)
    return target


def record_for(category: str, record: dict, observed: str) -> dict:
    """A RetailCatalogRecord, using the same envelope as the Shopify seed."""
    feed = convert_dataset([record])
    product = feed["products"][0]
    identifier = hashlib.sha256(f"livostyle-open-data:{record['id']}".encode()).hexdigest()[:24]
    url = product["productURL"]
    retail = empty_product("livostyle-open-data", identifier, url, observed)
    retail["id"] = identifier
    retail.update(productURL=url, title=product["title"], brand="Livostyle",
                  description=record.get("description"), sourceCategory=product["sourceCategory"],
                  identifiers={"shopifyProductId": str(record["id"])})
    retail["photos"] = photos(gallery(record), url)
    offer = empty_offer(observed)
    offer.update(merchant="Livostyle", productURL=url,
                 availability=product.get("availability", "unknown"))
    if "priceCents" in product:
        offer.update(amount=f"{product['priceCents'] / 100:.2f}", currency=product["currency"])
    retail["offers"] = [offer]
    return {"id": identifier, "category": category, "retailer": "Livostyle", "productURL": url,
            "title": product["title"], "imageURL": gallery(record)[0], "source": "livostyle-open-data",
            "status": "needsReview", "retailProduct": retail}


class Tool:
    """The compiled Swift helper, kept running so the model loads once."""

    def __init__(self, directory: Path, model: Path):
        root = Path(__file__).resolve().parents[2]
        binary = directory / "catalog_pack_tool"
        views = root / "dressed/Camera/ViewModels"
        subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-O", "-o", str(binary),
                        str(root / "backend/catalog/catalog_pack_tool.swift"),
                        str(views / "ClothesParser.swift"), str(views / "GarmentMask.swift"),
                        str(views / "CatalogEmbedding.swift"),
                        str(root / "dressed/Common/Models/ImportSchema.swift"),
                        str(root / "dressed/Common/Models/ClothingSchema.swift")], check=True)
        self.process = subprocess.Popen([str(binary), str(model.resolve())], text=True,
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE)

    def run(self, **request: object) -> dict:
        self.process.stdin.write(json.dumps(request) + "\n")
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        if not line:
            raise RuntimeError("catalog tool stopped")
        return json.loads(line)

    def close(self) -> None:
        self.process.stdin.close()
        self.process.wait(timeout=30)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dataset", type=Path)
    parser.add_argument("output", type=Path, help="pack directory, outside source control")
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--scale", type=float, default=1.0, help="fraction of each category target")
    args = parser.parse_args()
    targets = {key: max(1, round(value * args.scale)) for key, value in TARGETS.items()}
    chosen = select(json.loads(args.dataset.read_text()), targets)
    cache = args.output / "cache"
    cutouts = args.output / "cutouts"
    cache.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(cutouts, ignore_errors=True)
    cutouts.mkdir()
    urls = [url for _, record in chosen for url in gallery(record)[:GALLERY_LIMIT]]
    print(f"{len(chosen)} products, downloading up to {len(urls)} images", flush=True)
    with ThreadPoolExecutor(max_workers=6) as pool:
        files = dict(zip(urls, pool.map(lambda url: download(url, cache), urls)))
    observed = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    products, vectors, sources, skipped = [], [], [], Counter()
    with tempfile.TemporaryDirectory() as directory:
        tool = Tool(Path(directory), args.model)
        for index, (category, record) in enumerate(chosen):
            available = [(url, files.get(url)) for url in gallery(record)[:GALLERY_LIMIT]]
            available = [(url, path) for url, path in available if path]
            product = record_for(category, record, observed)
            cutout = cutouts / f"{product['id']}.png"
            reply = tool.run(op="catalog", id=product["id"], category=category,
                             images=[str(path) for _, path in available], cutout=str(cutout))
            if "vector" not in reply:
                skipped[category] += 1
                continue
            product["cutoutImageURL"] = f"cutouts/{product['id']}.png"
            products.append(product)
            vectors.append(reply["vector"])
            sources.append({"id": product["id"], "method": reply["method"],
                            "cutoutSource": available[reply["chosen"]][0],
                            "gallery": [url for url, _ in available]})
            if index % 100 == 99:
                print(f"  {index + 1}/{len(chosen)}", flush=True)
        tool.close()
    if not products:
        raise SystemExit("no product could be cut out")
    dimension = len(vectors[0])
    if any(len(vector) != dimension for vector in vectors):
        raise SystemExit("inconsistent vector sizes")
    with (args.output / "vectors.bin").open("wb") as out:
        for vector in vectors:
            out.write(struct.pack(f"<{dimension}f", *vector))
    (args.output / "index.json").write_text(json.dumps(
        {"model": MODEL, "dimension": dimension, "products": products}))
    summary = {"products": len(products), "categories": dict(Counter(p["category"] for p in products)),
               "targets": targets, "skippedNoCutout": dict(skipped),
               "methods": dict(Counter(s["method"] for s in sources)),
               "colors": dict(Counter(color_of(r) for _, r in chosen))}
    (args.output / "sources.json").write_text(json.dumps(sources))
    (args.output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
