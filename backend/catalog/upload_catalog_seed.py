"""Create a reviewed local seed in catalogProducts; never overwrite existing records.

Uses the operator's gcloud login. Saves the commit receipt and verifies every document.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess
import urllib.request
import urllib.error


def encode(value):
    if value is None: return {'nullValue': None}
    if isinstance(value, bool): return {'booleanValue': value}
    if isinstance(value, int): return {'integerValue': str(value)}
    if isinstance(value, str): return {'stringValue': value}
    if isinstance(value, list): return {'arrayValue': {'values': [encode(v) for v in value]}}
    if isinstance(value, dict): return {'mapValue': {'fields': {k: encode(v) for k, v in value.items()}}}
    raise ValueError('Unsupported Firestore value')


def decode(value):
    if 'nullValue' in value: return None
    for key in ('booleanValue', 'stringValue'):
        if key in value: return value[key]
    if 'integerValue' in value: return int(value['integerValue'])
    if 'arrayValue' in value: return [decode(v) for v in value['arrayValue'].get('values', [])]
    if 'mapValue' in value: return {k:decode(v) for k,v in value['mapValue'].get('fields', {}).items()}
    raise ValueError('Unsupported Firestore value')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--project', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    products = json.loads(args.manifest.read_text())
    if len(products) != 80 or len({p['id'] for p in products}) != 80:
        raise ValueError('Expected 80 unique products')
    counts = Counter(p['category'] for p in products)
    if len(counts) != 8 or set(counts.values()) != {10}: raise ValueError('Expected ten per category')
    for p in products:
        if not p['productURL'].startswith('https://') or not p['retailProduct']['photos']:
            raise ValueError('Missing link or photos')
    if not args.apply:
        print(json.dumps({'project':args.project,'collection':'catalogProducts','counts':counts}));return
    token = subprocess.check_output(['gcloud','auth','print-access-token'], text=True).strip()
    base = 'https://firestore.googleapis.com/v1/projects/'+args.project+'/databases/(default)/documents'
    def request(url, body=None):
        req = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(),
            headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'})
        with urllib.request.urlopen(req, timeout=45) as response: return json.load(response)
    writes = []; expected = {}
    for product in products:
        name = 'projects/'+args.project+'/databases/(default)/documents/catalogProducts/'+product['id']
        fields = {k: encode(v) for k,v in product.items()}; expected[product['id']] = fields
        try:
            existing = request(base+'/catalogProducts/'+product['id'])
        except urllib.error.HTTPError as error:
            if error.code != 404: raise
        else:
            if {k:decode(v) for k,v in existing.get('fields', {}).items()} != product: raise ValueError('Existing record differs; refusing overwrite: '+product['id'])
            continue
        writes.append({'update':{'name':name,'fields':fields},'currentDocument':{'exists':False}})
    if writes:
        receipt = request(base+':commit', {'writes':writes})
        (args.manifest.parent/'firebase-commit-receipt.json').write_text(json.dumps(receipt,indent=2))
    verified = []
    for product in products:
        actual = request(base+'/catalogProducts/'+product['id'])
        if {k:decode(v) for k,v in actual['fields'].items()} != product: raise ValueError('Readback mismatch: '+product['id'])
        verified.append(product['id'])
    report = {'project':args.project,'collection':'catalogProducts','created':len(writes),'verified':len(verified),
              'categories':dict(counts),'retailers':dict(Counter(p['retailer'] for p in products)),'ids':verified}
    (args.manifest.parent/'firebase-verification.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({k:v for k,v in report.items() if k!='ids'}))

if __name__ == '__main__': main()
