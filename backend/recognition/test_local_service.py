import json
import subprocess
import sys
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from local_service import Handler


class LocalServiceTests(unittest.TestCase):
    def setUp(self):
        Handler.fixture = json.loads((Path(__file__).parent / "fixtures/object-localization-response.json").read_text())
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def request(self, image=b"sample", import_id="draft-1"):
        return Request(f"http://127.0.0.1:{self.server.server_port}/recognize",
                       data=image, headers={"X-Import-ID": import_id}, method="POST")

    def test_fixture_returns_unselected_separate_candidates(self):
        with urlopen(self.request()) as response:
            result = json.load(response)
        self.assertEqual(result["importId"], "draft-1")
        self.assertEqual([item["suggestedCategory"] for item in result["candidates"]],
                         ["tops", "pants"])
        self.assertTrue(all(item["selected"] is False for item in result["candidates"]))

    def test_rejects_empty_image_before_fixture_lookup(self):
        with self.assertRaises(HTTPError) as caught:
            urlopen(self.request(image=b""))
        self.assertEqual(caught.exception.code, 400)
        caught.exception.close()

    def test_cli_rejects_removed_live_mode(self):
        result = subprocess.run(
            [sys.executable, str(Path(__file__).parent / "local_service.py"), "--live"],
            capture_output=True, text=True, check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--fixture", result.stderr)


if __name__ == "__main__":
    unittest.main()
