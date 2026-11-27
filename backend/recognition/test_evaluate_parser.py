import unittest

from evaluate_parser import label_for, score


class EvaluateParserTests(unittest.TestCase):
    def test_counts_hits_misses_and_extras_per_label(self):
        samples = [{"image": "a", "expected": ["top", "pants"], "optional": ["shoes"]},
                   {"image": "b", "expected": ["top"]}]
        report = score(samples, [{"top", "shoes"}, {"top", "skirt"}])
        self.assertEqual(report["byLabel"]["top"], {"found": 2, "expected": 2})
        self.assertEqual(report["byLabel"]["pants"], {"found": 0, "expected": 1})
        self.assertEqual(report["extra"], {"skirt": 1})
        self.assertFalse(report["gatePassed"])

    def test_gate_needs_every_garment_label_at_ninety_percent(self):
        samples = [{"image": str(i), "expected": ["dress"]} for i in range(10)]
        self.assertTrue(score(samples, [{"dress"}] * 9 + [set()])["gatePassed"])
        self.assertFalse(score(samples, [{"dress"}] * 8 + [set()] * 2)["gatePassed"])

    def test_groups_accessories_and_rejects_unknown_labels(self):
        self.assertEqual(label_for("scarf"), "accessory")
        with self.assertRaises(ValueError):
            score([{"image": "a", "expected": ["person"]}], [set()])


if __name__ == "__main__":
    unittest.main()
