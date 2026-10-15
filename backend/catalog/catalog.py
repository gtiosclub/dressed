"""Local prototype catalog ingestion and read-only HTTP API.

The input is a complete or partial product-feed snapshot from one reviewed
source. This module does not crawl websites or connect to Firebase.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import sys
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlsplit


CATEGORIES = {
    "tops", "pants", "skirts", "dresses", "shoes", "outerwear", "accessories", "other"
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def canonical_json(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def product_id(source_id: str, external_id: str) -> str:
    return hashlib.sha256(f"{source_id}\0{external_id}".encode()).hexdigest()[:24]


def required_string(value: object, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{name} must be a non-empty string")
    return value.strip()


def approved_url(value: object, hosts: set[str], name: str) -> str:
    url = required_string(value, name)
    parsed = urlsplit(url)
    if (parsed.scheme != "https" or not parsed.hostname or parsed.hostname.lower() not in hosts
            or parsed.username or parsed.password or parsed.port not in (None, 443)):
        raise ValueError(f"{name} must be an HTTPS URL on an approved host")
    return url


def validate_feed(feed: object) -> tuple[dict, list[dict], bool]:
    if not isinstance(feed, dict):
        raise ValueError("feed must be an object")
    source = feed.get("source")
    if not isinstance(source, dict):
        raise ValueError("source must be an object")
    source_id = required_string(source.get("id"), "source.id")
    name = required_string(source.get("name"), "source.name")
    hosts_value = source.get("allowedHosts")
    if not isinstance(hosts_value, list) or not hosts_value:
        raise ValueError("source.allowedHosts must be a non-empty array")
    hosts = {required_string(host, "allowed host").lower() for host in hosts_value}
    if any("/" in host or ":" in host or " " in host for host in hosts):
        raise ValueError("allowed hosts must be hostnames")
    image_hosts_value = source.get("imageHosts", [])
    if not isinstance(image_hosts_value, list):
        raise ValueError("source.imageHosts must be an array")
    image_hosts = hosts | {required_string(host, "image host").lower() for host in image_hosts_value}
    complete = feed.get("complete")
    if not isinstance(complete, bool):
        raise ValueError("complete must be true or false")
    products_value = feed.get("products")
    if not isinstance(products_value, list):
        raise ValueError("products must be an array")
    if len(products_value) > 5000:
        raise ValueError("feed exceeds the 5000-product prototype limit")

    products = []
    seen_ids = set()
    for index, raw in enumerate(products_value):
        if not isinstance(raw, dict):
            raise ValueError(f"products[{index}] must be an object")
        external_id = required_string(raw.get("externalId"), f"products[{index}].externalId")
        if external_id in seen_ids:
            raise ValueError(f"duplicate externalId: {external_id}")
        seen_ids.add(external_id)
        title = required_string(raw.get("title"), f"products[{index}].title")
        url = approved_url(raw.get("productURL"), hosts, f"products[{index}].productURL")
        category = raw.get("category", "other")
        if category not in CATEGORIES:
            raise ValueError(f"products[{index}].category is unknown")
        price = raw.get("priceCents")
        currency = raw.get("currency")
        if price is not None and (not isinstance(price, int) or isinstance(price, bool) or price < 0):
            raise ValueError(f"products[{index}].priceCents must be a non-negative integer")
        if (price is None) != (currency is None):
            raise ValueError(f"products[{index}] needs both priceCents and currency")
        if currency is not None and (not isinstance(currency, str) or len(currency) != 3 or not currency.isalpha()):
            raise ValueError(f"products[{index}].currency must be a three-letter code")
        availability = raw.get("availability", "unknown")
        if availability not in {"inStock", "outOfStock", "unknown"}:
            raise ValueError(f"products[{index}].availability is unknown")
        image_url = raw.get("imageURL")
        if image_url is not None:
            image_url = approved_url(image_url, image_hosts, f"products[{index}].imageURL")
        product = {
            "externalId": external_id,
            "title": title,
            "productURL": url,
            "category": category,
            "sourceCategory": raw.get("sourceCategory"),
            "brand": raw.get("brand"),
            "imageURL": image_url,
            "priceCents": price,
            "currency": currency.upper() if currency else None,
            "availability": availability,
        }
        for field in ("sourceCategory", "brand"):
            if product[field] is not None:
                product[field] = required_string(product[field], f"products[{index}].{field}")
        products.append(product)
    return {"id": source_id, "name": name, "hosts": sorted(hosts)}, products, complete


class CatalogDatabase:
    def __init__(self, path: str | Path):
        self.connection = sqlite3.connect(path, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        self.connection.execute("PRAGMA foreign_keys = ON")
        self.connection.executescript("""
            CREATE TABLE IF NOT EXISTS sources (
                id TEXT PRIMARY KEY, name TEXT NOT NULL, allowed_hosts TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS products (
                id TEXT PRIMARY KEY, source_id TEXT NOT NULL REFERENCES sources(id),
                external_id TEXT NOT NULL, title TEXT NOT NULL, product_url TEXT NOT NULL,
                category TEXT NOT NULL, source_category TEXT, brand TEXT, image_url TEXT,
                price_cents INTEGER, currency TEXT, availability TEXT NOT NULL,
                status TEXT NOT NULL, first_seen_at TEXT NOT NULL, last_seen_at TEXT NOT NULL,
                last_checked_at TEXT NOT NULL, content_hash TEXT NOT NULL,
                missing_scans INTEGER NOT NULL DEFAULT 0,
                UNIQUE(source_id, external_id)
            );
            CREATE INDEX IF NOT EXISTS products_search
                ON products(status, category, title, id);
            CREATE TABLE IF NOT EXISTS runs (
                id TEXT PRIMARY KEY, source_id TEXT, started_at TEXT NOT NULL,
                status TEXT NOT NULL, complete INTEGER, summary_json TEXT NOT NULL
            );
        """)
        self.connection.commit()

    def close(self) -> None:
        self.connection.close()

    def ingest(self, feed: object, *, now: str | None = None) -> dict:
        now = now or utc_now()
        run_id = str(uuid.uuid4())
        try:
            source, products, complete = validate_feed(feed)
        except ValueError as error:
            source_id = feed.get("source", {}).get("id") if isinstance(feed, dict) else None
            self.connection.execute(
                "INSERT INTO runs VALUES (?, ?, ?, 'failed', NULL, ?)",
                (run_id, source_id if isinstance(source_id, str) else None, now,
                 canonical_json({"error": str(error)})),
            )
            self.connection.commit()
            raise

        summary = {"runId": run_id, "sourceId": source["id"], "complete": complete,
                   "accepted": len(products), "created": 0, "changed": 0,
                   "unchanged": 0, "stale": 0, "unavailable": 0}
        with self.connection:
            self.connection.execute(
                "INSERT INTO sources VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, allowed_hosts=excluded.allowed_hosts",
                (source["id"], source["name"], canonical_json(source["hosts"])),
            )
            for product in products:
                id_ = product_id(source["id"], product["externalId"])
                fingerprint = hashlib.sha256(canonical_json(product).encode()).hexdigest()
                old = self.connection.execute(
                    "SELECT content_hash FROM products WHERE id=?", (id_,)
                ).fetchone()
                if old is None:
                    summary["created"] += 1
                elif old["content_hash"] != fingerprint:
                    summary["changed"] += 1
                else:
                    summary["unchanged"] += 1
                self.connection.execute("""
                    INSERT INTO products (
                        id, source_id, external_id, title, product_url, category,
                        source_category, brand, image_url, price_cents, currency,
                        availability, status, first_seen_at, last_seen_at,
                        last_checked_at, content_hash, missing_scans
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?, 0)
                    ON CONFLICT(id) DO UPDATE SET
                        title=excluded.title, product_url=excluded.product_url,
                        category=excluded.category, source_category=excluded.source_category,
                        brand=excluded.brand, image_url=excluded.image_url,
                        price_cents=excluded.price_cents, currency=excluded.currency,
                        availability=excluded.availability, status='active',
                        last_seen_at=excluded.last_seen_at,
                        last_checked_at=excluded.last_checked_at,
                        content_hash=excluded.content_hash, missing_scans=0
                """, (id_, source["id"], product["externalId"], product["title"],
                      product["productURL"], product["category"], product["sourceCategory"],
                      product["brand"], product["imageURL"], product["priceCents"],
                      product["currency"], product["availability"], now, now, now, fingerprint))

            if complete:
                ids = {product_id(source["id"], item["externalId"]) for item in products}
                query = "SELECT id, missing_scans FROM products WHERE source_id=?"
                for row in self.connection.execute(query, (source["id"],)).fetchall():
                    if row["id"] in ids:
                        continue
                    misses = row["missing_scans"] + 1
                    status = "unavailable" if misses >= 2 else "stale"
                    summary[status] += 1
                    self.connection.execute(
                        "UPDATE products SET status=?, missing_scans=?, last_checked_at=? WHERE id=?",
                        (status, misses, now, row["id"]),
                    )
            self.connection.execute(
                "INSERT INTO runs VALUES (?, ?, ?, 'succeeded', ?, ?)",
                (run_id, source["id"], now, int(complete), canonical_json(summary)),
            )
        return summary

    def search(self, query: str = "", category: str | None = None, limit: int = 20,
               offset: int = 0) -> dict:
        if category is not None and category not in CATEGORIES:
            raise ValueError("unknown category")
        if not 1 <= limit <= 100 or offset < 0:
            raise ValueError("limit must be 1...100 and offset must be non-negative")
        escaped = query.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        where = "p.status='active' AND (p.title LIKE ? ESCAPE '\\' OR p.brand LIKE ? ESCAPE '\\')"
        params: list[object] = [f"%{escaped}%", f"%{escaped}%"]
        if category:
            where += " AND p.category=?"
            params.append(category)
        total = self.connection.execute(
            f"SELECT COUNT(*) FROM products p WHERE {where}", params
        ).fetchone()[0]
        rows = self.connection.execute(f"""
            SELECT p.*, s.name AS source_name FROM products p
            JOIN sources s ON s.id=p.source_id WHERE {where}
            ORDER BY p.title COLLATE NOCASE, p.id LIMIT ? OFFSET ?
        """, params + [limit, offset]).fetchall()
        return {"products": [self._public_product(row) for row in rows], "total": total,
                "nextOffset": offset + limit if offset + limit < total else None}

    def get(self, id_: str) -> dict | None:
        row = self.connection.execute("""
            SELECT p.*, s.name AS source_name FROM products p
            JOIN sources s ON s.id=p.source_id WHERE p.id=?
        """, (id_,)).fetchone()
        return self._public_product(row) if row else None

    @staticmethod
    def _public_product(row: sqlite3.Row) -> dict:
        return {
            "id": row["id"], "sourceId": row["source_id"], "sourceName": row["source_name"],
            "externalId": row["external_id"], "title": row["title"],
            "productURL": row["product_url"], "category": row["category"],
            "brand": row["brand"], "imageURL": row["image_url"],
            "priceCents": row["price_cents"], "currency": row["currency"],
            "availability": row["availability"], "status": row["status"],
            "lastCheckedAt": row["last_checked_at"],
        }


def make_handler(database: CatalogDatabase):
    class CatalogHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            parsed = urlsplit(self.path)
            try:
                if parsed.path == "/products":
                    args = parse_qs(parsed.query)
                    result = database.search(
                        query=args.get("q", [""])[0],
                        category=args.get("category", [None])[0],
                        limit=int(args.get("limit", [20])[0]),
                        offset=int(args.get("offset", [0])[0]),
                    )
                    self._json(200, result)
                elif parsed.path.startswith("/products/"):
                    product = database.get(unquote(parsed.path.removeprefix("/products/")))
                    self._json(200, product) if product else self._json(404, {"error": "not found"})
                else:
                    self._json(404, {"error": "not found"})
            except ValueError as error:
                self._json(400, {"error": str(error)})

        def _json(self, status: int, value: object):
            data = canonical_json(value).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    return CatalogHandler


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", default="/private/tmp/dressed-catalog.sqlite")
    commands = parser.add_subparsers(dest="command", required=True)
    ingest = commands.add_parser("ingest")
    ingest.add_argument("feed", type=Path)
    serve = commands.add_parser("serve")
    serve.add_argument("--port", type=int, default=8766)
    query = commands.add_parser("search")
    query.add_argument("--query", default="")
    query.add_argument("--category")
    export = commands.add_parser("export-demo")
    export.add_argument("output", type=Path)
    args = parser.parse_args()
    db = CatalogDatabase(args.db)
    try:
        if args.command == "ingest":
            print(canonical_json(db.ingest(json.loads(args.feed.read_text()))))
        elif args.command == "search":
            print(canonical_json(db.search(args.query, args.category)))
        elif args.command == "export-demo":
            products = db.search(limit=100)["products"]
            payload = {"demoOnly": True, "products": products}
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
            print(f"Exported {len(products)} demo products to {args.output}")
        else:
            server = HTTPServer(("127.0.0.1", args.port), make_handler(db))
            print(f"Catalog API listening on http://127.0.0.1:{args.port}", flush=True)
            server.serve_forever()
    except (ValueError, sqlite3.Error, OSError) as error:
        print(f"catalog error: {error}", file=sys.stderr)
        raise SystemExit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()
