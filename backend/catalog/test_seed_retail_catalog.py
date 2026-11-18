import unittest
from seed_retail_catalog import category_for, convert

class SeedTests(unittest.TestCase):
    def test_unknown_nonclothing_does_not_fill_other(self):
        for kind in ['Event', 'Candle', 'Homeware', 'Climate+', '']:
            self.assertIsNone(category_for({'title': 'Gift', 'product_type': kind}))
        self.assertEqual(category_for({'title':'Cotton Dungarees','product_type':'Dungarees'}), 'other')
        self.assertEqual(category_for({'title':'Long Puffer','product_type':'Womens'}), 'outerwear')

    def test_variant_prices_and_unknown_currency_remain_honest(self):
        raw = {'id':1, 'handle':'shirt', 'title':'Shirt', 'vendor':'Test', 'product_type':'Tops',
               'body_html':'<p>Cotton &amp; linen</p>', 'images':[{'src':'https://cdn.shopify.com/photo.jpg'}],
               'options':[{'name':'Size','values':['S','M']}], 'variants':[
                   {'id':2,'title':'S','option1':'S','price':'10.00','available':True},
                   {'id':3,'title':'M','option1':'M','price':'12.00','available':False}]}
        p = convert(raw, 'tentree', '2026-11-18T00:00:00Z', None)['retailProduct']
        self.assertEqual(p['description'], 'Cotton & linen')
        self.assertEqual([o['amount'] for o in p['offers']], ['10.00','12.00'])
        self.assertIsNone(p['offers'][0]['currency'])
        self.assertFalse(p['variants'][0]['selected'])
        self.assertTrue(p['requiresReview'])
        self.assertEqual(p['photos'][0]['reuseStatus'], 'unreviewed')

if __name__ == '__main__': unittest.main()
