"""Product link reader: URL in, reviewable draft out.

Every field carries {value, source, evidence, state}. A field is filled only
when the page states it. Price, availability and variant are never guessed.
Standard library only.
"""

from __future__ import annotations

import ipaddress
import json
import socket
import time
from html.parser import HTMLParser
from typing import Callable
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qsl, urlencode, urljoin, urlsplit, urlunsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

MAX_BYTES = 2_000_000
TIMEOUT_SECONDS = 10
MAX_REDIRECTS = 4
USER_AGENT = "DressedLinkImport/0.1 (student project; identifies itself)"
TRACKING_PREFIXES = ("utm_",)
TRACKING_KEYS = {"fbclid", "gclid", "igshid", "mc_cid", "mc_eid", "ref", "ref_"}
FIELDS = ("name", "retailer", "image", "category", "link", "price", "availability", "variant")
BLOCK_STATUSES = {401, 403, 429}
BOT_WALL_MARKERS = ("captcha", "are you a robot", "access denied", "verify you are human", "unusual traffic")

CATEGORY_MAP = {
    "tops": "tops", "top": "tops", "shirts": "tops", "shirt": "tops", "t-shirts": "tops",
    "pants": "pants", "jeans": "pants", "trousers": "pants",
    "skirts": "skirts", "skirt": "skirts",
    "dresses": "dresses", "dress": "dresses",
    "shoes": "shoes", "sneakers": "shoes", "boots": "shoes",
    "outerwear": "outerwear", "jackets": "outerwear", "jacket": "outerwear", "coats": "outerwear",
    "accessories": "accessories",
}
# Values match the app's ClothingCategory raw values. Broad labels such as
# "bottoms" are not mapped: they stay a suggestion for the person to choose.

AVAILABILITY = {
    "instock": "In stock", "outofstock": "Out of stock", "preorder": "Preorder",
    "limitedavailability": "Limited availability", "soldout": "Sold out",
    "backorder": "Backorder", "discontinued": "Discontinued",
}


class UnsafeURL(ValueError):
    pass


def empty_field() -> dict:
    return {"value": None, "source": None, "evidence": None, "state": "open"}


def filled(value, source: str, evidence: str | None = None, state: str = "from_page") -> dict:
    return {"value": value, "source": source, "evidence": evidence, "state": state}


def normalize_url(raw: str) -> str:
    """https only, no credentials, no odd ports; drops fragments and tracking params."""
    if not isinstance(raw, str) or len(raw) > 4096:
        raise UnsafeURL("link is too long or not text")
    parts = urlsplit(raw.strip())
    host = (parts.hostname or "").lower()
    if parts.scheme.lower() != "https" or not host:
        raise UnsafeURL("only https links are accepted")
    if parts.username or parts.password:
        raise UnsafeURL("links with credentials are refused")
    try:
        port = parts.port
    except ValueError:
        raise UnsafeURL("invalid port")
    if port not in (None, 443):
        raise UnsafeURL("only the default https port is accepted")
    if host == "localhost" or host.endswith((".localhost", ".local", ".internal")):
        raise UnsafeURL("local hosts are refused")
    query = [(k, v) for k, v in parse_qsl(parts.query, keep_blank_values=True)
             if k.lower() not in TRACKING_KEYS and not k.lower().startswith(TRACKING_PREFIXES)]
    return urlunsplit(("https", host, parts.path or "/", urlencode(query), ""))


def _is_public(address: str) -> bool:
    ip = ipaddress.ip_address(address)
    return not (ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_multicast
                or ip.is_reserved or ip.is_unspecified)


def assert_public_host(host: str, resolver: Callable = socket.getaddrinfo) -> None:
    try:
        ipaddress.ip_address(host)
        addresses = [host]
    except ValueError:
        try:
            addresses = [info[4][0] for info in resolver(host, 443, type=socket.SOCK_STREAM)]
        except OSError:
            raise UnsafeURL("host could not be resolved")
    if not addresses or not all(_is_public(a) for a in addresses):
        raise UnsafeURL("private or local addresses are refused")


class _GuardedRedirect(HTTPRedirectHandler):
    """Re-checks every redirect target; refuses non-https and non-public hosts."""
    max_redirections = MAX_REDIRECTS

    def __init__(self, resolver: Callable):
        self.resolver = resolver

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        target = normalize_url(urljoin(req.full_url, newurl))
        assert_public_host(urlsplit(target).hostname, self.resolver)
        return super().redirect_request(req, fp, code, msg, headers, target)


def fetch(url: str, resolver: Callable = socket.getaddrinfo) -> tuple[int, str, str]:
    """Returns (status, final_url, text). Plain GET, identifying user agent, no proxy rotation."""
    assert_public_host(urlsplit(url).hostname, resolver)
    opener = build_opener(_GuardedRedirect(resolver))
    request = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "text/html,application/xhtml+xml"})
    try:
        with opener.open(request, timeout=TIMEOUT_SECONDS) as response:
            body = response.read(MAX_BYTES + 1)
            if len(body) > MAX_BYTES:
                raise ValueError("page is larger than the size cap")
            charset = response.headers.get_content_charset() or "utf-8"
            return response.status, response.url, body.decode(charset, errors="replace")
    except HTTPError as error:
        return error.code, url, ""


VOID_TAGS = {"meta", "link", "img", "br", "hr", "input", "source", "area", "base", "col", "embed", "param", "track", "wbr"}


class _PageParser(HTMLParser):
    """Collects JSON-LD blocks, Open Graph/meta tags, Microdata Product/Offer, canonical link."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.json_ld: list[str] = []
        self.meta: dict[str, str] = {}
        self.canonical: str | None = None
        self.title = ""
        self._script_ld = False
        self._buffer: list[str] = []
        self._in_title = False
        self._scope_stack: list[tuple[str, int]] = []  # (itemtype, depth)
        self._depth = 0
        self._text_prop: tuple[str, str, int] | None = None  # (kind, prop, depth) awaiting element text
        self._text: list[str] = []
        self.micro: dict[str, dict[str, str]] = {"Product": {}, "Offer": {}}

    def handle_starttag(self, tag, attrs):
        a = {k: (v or "") for k, v in attrs}
        if tag not in VOID_TAGS:
            self._depth += 1
        if tag == "script" and a.get("type", "").lower() == "application/ld+json":
            self._script_ld, self._buffer = True, []
        elif tag == "meta":
            key = (a.get("property") or a.get("name") or "").lower()
            if key and "content" in a and key not in self.meta:
                self.meta[key] = a["content"].strip()
        elif tag == "link" and "canonical" in a.get("rel", "").lower().split() and a.get("href"):
            self.canonical = a["href"]
        elif tag == "title":
            self._in_title = True
        if "itemtype" in a:
            kind = a["itemtype"].rstrip("/").rsplit("/", 1)[-1]
            self._scope_stack.append((kind, self._depth))
        prop = a.get("itemprop")
        if prop and self._scope_stack:
            kind = self._scope_stack[-1][0]
            if kind in self.micro:
                value = a.get("content") or a.get("href") or a.get("src")
                if value and prop not in self.micro[kind]:
                    self.micro[kind][prop] = value.strip()
                elif not value and tag not in VOID_TAGS and prop not in self.micro[kind] and self._text_prop is None:
                    self._text_prop, self._text = (kind, prop, self._depth), []

    def handle_endtag(self, tag):
        if tag in VOID_TAGS:
            return
        if self._text_prop and self._text_prop[2] == self._depth:
            kind, prop, _ = self._text_prop
            text = " ".join("".join(self._text).split())
            if text and prop not in self.micro[kind]:
                self.micro[kind][prop] = text
            self._text_prop = None
        if tag == "script" and self._script_ld:
            self.json_ld.append("".join(self._buffer))
            self._script_ld = False
        elif tag == "title":
            self._in_title = False
        while self._scope_stack and self._scope_stack[-1][1] >= self._depth:
            self._scope_stack.pop()
        self._depth -= 1

    def handle_data(self, data):
        if self._text_prop:
            self._text.append(data)
        if self._script_ld:
            self._buffer.append(data)
        elif self._in_title:
            self.title += data


def _walk(node):
    if isinstance(node, list):
        for item in node:
            yield from _walk(item)
    elif isinstance(node, dict):
        yield node
        for value in node.values():
            if isinstance(value, (dict, list)):
                yield from _walk(value)


def _types(node: dict) -> set[str]:
    t = node.get("@type", [])
    return {t} if isinstance(t, str) else {x for x in t if isinstance(x, str)}


def _first_str(value):
    if isinstance(value, list):
        value = value[0] if value else None
    if isinstance(value, dict):
        value = value.get("url") or value.get("name")
    return value.strip() if isinstance(value, str) and value.strip() else None


def _json_ld_products(blocks: list[str]) -> list[dict]:
    products = []
    for block in blocks:
        try:
            data = json.loads(block)
        except ValueError:
            continue
        products += [n for n in _walk(data) if "Product" in _types(n)]
    return products


def _offers(product: dict) -> list[dict]:
    raw = product.get("offers")
    offers = [o for o in _walk(raw) if "Offer" in _types(o) or "price" in o or "lowPrice" in o]
    return offers


def _availability_text(raw: str | None) -> str | None:
    if not raw:
        return None
    return AVAILABILITY.get(raw.rsplit("/", 1)[-1].lower())


def _variant_from_link(url: str) -> str | None:
    for key, value in parse_qsl(urlsplit(url).query):
        if key.lower() == "variant" and value:
            return value
    return None


def extract(html: str, final_url: str, requested_url: str) -> dict:
    """Runs the extractor chain and returns the field map. No network."""
    page = _PageParser()
    page.feed(html)
    fields = {name: empty_field() for name in FIELDS}
    fields["link"] = filled(requested_url, "link", None, "from_link")
    host = urlsplit(requested_url).hostname or ""

    products = _json_ld_products(page.json_ld)
    product = products[0] if products else None
    micro_product, micro_offer = page.micro["Product"], page.micro["Offer"]

    # Name: JSON-LD, then Microdata, then og:title
    for source, value in (
        ("json-ld", _first_str(product.get("name")) if product else None),
        ("microdata", micro_product.get("name")),
        ("open-graph", page.meta.get("og:title")),
    ):
        if value:
            fields["name"] = filled(value, source, value)
            break

    # Image: JSON-LD, then og:image, then Microdata
    for source, value in (
        ("json-ld", _first_str(product.get("image")) if product else None),
        ("open-graph", page.meta.get("og:image")),
        ("microdata", micro_product.get("image")),
    ):
        if value:
            absolute = urljoin(final_url, value)
            if absolute.startswith("https://"):
                fields["image"] = filled(absolute, source, value)
                break

    # Retailer: og:site_name, else the domain labeled "from link"
    site = page.meta.get("og:site_name")
    fields["retailer"] = (filled(site, "open-graph", site) if site
                          else filled(host.removeprefix("www."), "link", None, "from_link"))

    # Category: exact match only
    raw_category = _first_str(product.get("category")) if product else None
    if raw_category:
        leaf = raw_category.replace(">", "/").split("/")[-1].strip().lower()
        if leaf in CATEGORY_MAP:
            fields["category"] = filled(CATEGORY_MAP[leaf], "json-ld", raw_category)
        else:
            fields["category"] = {"value": None, "source": "json-ld", "evidence": raw_category, "state": "suggested"}

    # Price and availability: one unambiguous offer with a stated currency
    offers = _offers(product) if product else []
    variant_in_link = _variant_from_link(requested_url)
    if len(offers) == 1:
        offer = offers[0]
        price, currency = offer.get("price"), offer.get("priceCurrency")
        if price not in (None, "") and currency:
            fields["price"] = filled({"amount": str(price), "currency": str(currency)}, "json-ld", f"{price} {currency}")
        status = _availability_text(offer.get("availability"))
        if status:
            fields["availability"] = filled(status, "json-ld", offer.get("availability"))
    elif not offers and micro_offer:
        price, currency = micro_offer.get("price"), micro_offer.get("priceCurrency")
        if price and currency:
            fields["price"] = filled({"amount": price, "currency": currency}, "microdata", f"{price} {currency}")
        status = _availability_text(micro_offer.get("availability"))
        if status:
            fields["availability"] = filled(status, "microdata", micro_offer.get("availability"))
    # Several offers (variants differ): price and availability stay open on purpose.

    # Variant: only from a variant parameter in the link; otherwise left open.
    if variant_in_link:
        fields["variant"] = filled(variant_in_link, "link", f"variant={variant_in_link}", "from_link")

    canonical = urljoin(final_url, page.canonical) if page.canonical else None
    return {"fields": fields, "canonicalLink": canonical, "multipleOffers": len(offers) > 1}


def read_product_link(raw_url: str, import_id: str, fetcher: Callable = fetch,
                      resolver: Callable = socket.getaddrinfo) -> dict:
    """Builds a draft. Status: ready | blocked | failed. Blocked and failed drafts keep the link."""
    started = time.monotonic()
    draft = {"importId": import_id, "status": "failed", "message": None, "fields": {},
             "canonicalLink": None, "elapsedMs": 0}
    try:
        url = normalize_url(raw_url)
    except UnsafeURL as error:
        draft["message"] = str(error)
        draft["fields"] = {name: empty_field() for name in FIELDS}
        return draft
    draft["fields"] = {name: empty_field() for name in FIELDS}
    draft["fields"]["link"] = filled(url, "link", None, "from_link")
    try:
        status, final_url, html = (fetcher(url, resolver) if fetcher is fetch else fetcher(url))
    except UnsafeURL as error:
        draft["message"] = str(error)
    except (URLError, TimeoutError, OSError, ValueError) as error:
        draft["message"] = f"could not load the page: {error}"
    else:
        lowered = html[:5000].lower()
        if status in BLOCK_STATUSES or any(m in lowered for m in BOT_WALL_MARKERS):
            draft["status"], draft["message"] = "blocked", "This store does not allow automatic reading. Enter details manually."
        elif status >= 400:
            draft["message"] = f"the page returned HTTP {status}"
        else:
            result = extract(html, final_url, url)
            draft["fields"], draft["canonicalLink"] = result["fields"], result["canonicalLink"]
            draft["status"] = "ready"
            draft["message"] = None if any(
                f["state"] in ("from_page",) for f in result["fields"].values()) else "No product details found on this page."
    draft["elapsedMs"] = int((time.monotonic() - started) * 1000)
    return draft
