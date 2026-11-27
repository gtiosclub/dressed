import base64
import json
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen

import avatar_service
from avatar_service import AvatarError, Handler, build_multipart, build_prompt, load_api_key, map_openai_error, parse_request

PNG = b"\x89PNG\r\n\x1a\nfake"
JPEG = b"\xff\xd8\xff\xe0fake"


def b64(data: bytes) -> str:
    return base64.b64encode(data).decode()


class ParsingTests(unittest.TestCase):
    def test_parse_request_reads_reference_and_labelled_pieces(self):
        reference, pieces = parse_request({"reference": b64(JPEG),
                                           "pieces": [{"image": b64(PNG), "label": "navy t-shirt (top)"}]})
        self.assertEqual(reference, JPEG)
        self.assertEqual(pieces, [(PNG, "navy t-shirt (top)")])

    def test_parse_request_rejects_missing_pieces_and_bad_base64(self):
        with self.assertRaises(AvatarError):
            parse_request({"reference": b64(JPEG), "pieces": []})
        with self.assertRaises(AvatarError):
            parse_request({"reference": "not base64!", "pieces": [{"image": b64(PNG)}]})
        with self.assertRaises(AvatarError):
            parse_request({"reference": b64(JPEG), "pieces": [{"image": b64(PNG)}] * 7})

    def test_prompt_numbers_pieces_after_the_person(self):
        prompt = build_prompt(["black jeans (pants)", "white sneakers (shoes)"])
        self.assertIn("Image 1: the person.", prompt)
        self.assertIn("Image 2: black jeans (pants).", prompt)
        self.assertIn("Image 3: white sneakers (shoes).", prompt)

    def test_multipart_repeats_image_field_with_types(self):
        body, content_type = build_multipart({"model": "m"}, [JPEG, PNG])
        self.assertTrue(content_type.startswith("multipart/form-data; boundary="))
        self.assertEqual(body.count(b'name="image[]"'), 2)
        self.assertIn(b"Content-Type: image/png", body)
        self.assertIn(b"Content-Type: image/jpeg", body)

    def test_errors_map_to_stable_codes(self):
        self.assertEqual(map_openai_error(429, b"{}").code, "rate_limited")
        self.assertEqual(map_openai_error(401, b"{}").code, "auth")
        self.assertEqual(map_openai_error(400, b'{"error":{"code":"moderation_blocked"}}').code, "content_policy")
        self.assertEqual(map_openai_error(500, b"oops").code, "upstream")

    def test_key_prefers_environment_then_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "openai.env"
            path.write_text("OPENAI_API_KEY=from-file\n")
            self.assertEqual(load_api_key({"OPENAI_API_KEY": "from-env"}, path), "from-env")
            self.assertEqual(load_api_key({}, path), "from-file")
            self.assertIsNone(load_api_key({}, Path(directory) / "missing"))


class ServiceTests(unittest.TestCase):
    def setUp(self):
        Handler.api_key = None
        Handler.fixture = JPEG
        Handler.fixture_delay = 0
        Handler.request_count = 0
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        Handler.api_key = None

    def post(self, body: dict):
        request = Request(f"http://127.0.0.1:{self.server.server_port}/avatar",
                          data=json.dumps(body).encode(), method="POST",
                          headers={"Content-Type": "application/json"})
        return urlopen(request)

    def test_fixture_returns_image_without_a_key(self):
        with self.post({"reference": b64(JPEG), "pieces": [{"image": b64(PNG), "label": "top"}]}) as response:
            result = json.load(response)
        self.assertEqual(base64.b64decode(result["image"]), JPEG)
        self.assertEqual(result["model"], "fixture")
        self.assertEqual(result["promptVersion"], avatar_service.PROMPT_VERSION)

    def test_invalid_request_is_400_with_code(self):
        with self.assertRaises(HTTPError) as context:
            self.post({"reference": b64(JPEG), "pieces": []})
        self.assertEqual(context.exception.code, 400)
        self.assertEqual(json.load(context.exception)["error"], "invalid_request")

    def test_live_mode_stops_at_request_limit(self):
        Handler.api_key = "test-key"
        Handler.request_limit = 1
        body = {"reference": b64(JPEG), "pieces": [{"image": b64(PNG), "label": "top"}]}
        with patch.object(avatar_service, "generate_with_openai", return_value=PNG) as generate:
            with self.post(body) as response:
                self.assertEqual(base64.b64decode(json.load(response)["image"]), PNG)
            with self.assertRaises(HTTPError) as context:
                self.post(body)
        self.assertEqual(generate.call_count, 1)
        self.assertEqual(context.exception.code, 429)
        self.assertEqual(json.load(context.exception)["error"], "limit_reached")
        Handler.request_limit = 25


if __name__ == "__main__":
    unittest.main()
