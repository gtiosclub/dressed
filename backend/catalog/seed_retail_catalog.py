"""Build a reviewable catalog seed from locally saved public Shopify feeds.

Network acquisition is separate. This command never writes to Firebase.
"""
import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
from html.parser import HTMLParser
import json
from pathlib import Path
import re

from retail_product import empty_product, empty_offer, photos

SOURCES = {
    'princess-polly': ('Princess Polly', 'https://us.princesspolly.com'),
    'tentree': ('tentree', 'https://www.tentree.com'),
    'allbirds': ('Allbirds', 'https://www.allbirds.com'),
    'lucy-and-yak': ('Lucy & Yak', 'https://lucyandyak.com'),
}
CATEGORIES = ('tops', 'pants', 'skirts', 'dresses', 'shoes', 'outerwear', 'accessories', 'other')

class PlainText(HTMLParser):
    def __init__(self):
        super().__init__(); self.parts = []
    def handle_data(self, data):
        self.parts.append(data.strip())

def category_for(raw):
    kind = raw.get('product_type', '').lower()
    # Broad gender labels need the garment name; never classify arbitrary unknowns as Other.
    text = raw['title'].lower() if kind in ('mens', 'womens') else kind
    patterns = (
        ('other', r'\b(dungarees?|jumpsuits?|playsuits?|pyjamas|rompers?)\b'),
        ('shoes', r'\b(shoes?|boots?|heels?|flats|sandals?|sneakers?)\b'),
        ('dresses', r'\b(dresses|dress|gown)\b'),
        ('skirts', r'\bskirts?\b'),
        ('outerwear', r'\b(jackets?|coats?|parkas?|fleeces?|puffers?|anoraks?|vests?)\b'),
        ('pants', r'\b(pants|trousers|jeans|shorts|joggers|leggings)\b'),
        ('tops', r'\b(tops?|tees|shirts?|t-shirts?|sweaters?|sweatshirts?|hoodies?|cardigans?|jumpers?|bodysuits?|henley|crew|tanks?|blouses?)\b'),
        ('accessories', r'\b(accessories|bags?|belts?|hats?|caps?|socks|hosiery|sunglasses|purses|gloves|scarves|beanies?)\b'),
    )
    return next((cat for cat, pattern in patterns if re.search(pattern, text)), None)

def convert(raw, source, observed, currency):
    merchant, base = SOURCES[source]
    url = base + '/products/' + raw['handle']
    result = empty_product('shopify-public', base + ':' + str(raw['id']), url, observed)
    parser = PlainText(); parser.feed(raw.get('body_html') or '')
    result.update(productURL=url, title=raw['title'], brand=raw.get('vendor'),
                  description=' '.join(p for p in parser.parts if p),
                  sourceCategory=raw.get('product_type'),
                  identifiers={'shopifyProductId': str(raw['id'])})
    result['photos'] = photos([im['src'] for im in raw.get('images', []) if im.get('src', '').startswith('https://')], url)
    options = raw.get('options', [])
    result['variantOptions'] = {o['name']: o['values'] for o in options}
    for v in raw.get('variants', []):
        variant_url = url + '?variant=' + str(v['id'])
        attrs = {o['name']: str(v['option'+str(i+1)]) for i, o in enumerate(options)
                 if v.get('option'+str(i+1)) is not None}
        image = (v.get('featured_image') or {}).get('src')
        result['variants'].append({'sourceId': str(v['id']), 'title': v.get('title'),
            'productURL': variant_url, 'attributes': attrs,
            'imageURLs': [image] if image else [], 'selected': False})
        offer = empty_offer(observed)
        offer.update(merchant=merchant, productURL=variant_url, amount=v.get('price'),
                     currency=currency, availability='inStock' if v.get('available') else 'outOfStock')
        result['offers'].append(offer)
    evidence = {'method': 'shopify.public_products_json', 'sourceURL': base+'/products.json?limit=250'}
    result['evidence'] = {k: dict(evidence) for k in ('title','brand','description','photos','variants','offers','sourceCategory')}
    result['warnings'].append('product_page_not_verified')
    if not currency: result['warnings'].append('currency_unknown')
    return {'id': result['id'], 'category': category_for(raw), 'retailer': merchant,
            'productURL': url, 'title': result['title'], 'imageURL': result['photos'][0]['url'] if result['photos'] else None,
            'retailProduct': result, 'source': source, 'status': 'needsReview'}

def build(root, per_category=10):
    groups = defaultdict(lambda: defaultdict(list)); all_products = []
    for source in SOURCES:
        path = root / (source+'.json')
        currency_path = root / (source+'-currency.json')
        currency = json.loads(currency_path.read_text()).get('currency') if currency_path.exists() else None
        observed = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()
        for raw in json.loads(path.read_text())['products']:
            if not category_for(raw) or not raw.get('images') or not any(v.get('available') for v in raw.get('variants', [])):
                continue
            product = convert(raw, source, observed, currency)
            if not product['retailProduct']['description']: continue
            all_products.append(product); groups[product['category']][source].append(product)
    selected = []; seen_titles = set()
    for category in CATEGORIES:
        buckets = groups[category]; count = 0
        while count < per_category:
            progress = False
            for source, items in buckets.items():
                while items and (source, items[0]['title'].casefold()) in seen_titles:
                    items.pop(0)
                if items and count < per_category:
                    product = items.pop(0)
                    seen_titles.add((source, product['title'].casefold()))
                    selected.append(product); count += 1; progress = True
            if not progress: raise ValueError(f'Only {count} usable products in {category}')
    summary = {'total': len(selected), 'categories': dict(Counter(p['category'] for p in selected)),
               'retailers': dict(Counter(p['retailer'] for p in selected))}
    return all_products, selected, summary

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    args = parser.parse_args()
    all_products, selected, summary = build(args.directory)
    for filename, data in [('normalized-products.json', all_products), ('seed-manifest.json', selected), ('summary.json', summary)]:
        (args.directory / filename).write_text(json.dumps(data, indent=2)+'\n')
    print(json.dumps(summary))

if __name__ == '__main__': main()
