import json
import subprocess
import unittest
from unittest.mock import Mock, patch

from google_vision import recognize


class GoogleVisionTests(unittest.TestCase):
    def test_sends_one_object_localization_request_with_gcloud_token(self):
        response = Mock()
        response.read.return_value = b'{"responses":[{"localizedObjectAnnotations":[]}]}'
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=False)
        with patch("google_vision.subprocess.run", return_value=Mock(stdout="test-token\n")), \
                patch("google_vision.urlopen", return_value=response) as send:
            result = recognize(b"photo", "dressed-511821")
        self.assertEqual(result["responses"][0]["localizedObjectAnnotations"], [])
        request = send.call_args.args[0]
        self.assertEqual(request.get_header("X-goog-user-project"), "dressed-511821")
        self.assertEqual(request.get_header("Authorization"), "Bearer test-token")
        payload = json.loads(request.data)
        self.assertEqual(payload["requests"][0]["features"][0]["type"], "OBJECT_LOCALIZATION")

    def test_missing_google_sign_in_never_calls_provider(self):
        with patch("google_vision.subprocess.run", side_effect=subprocess.CalledProcessError(1, "gcloud")), \
                patch("google_vision.urlopen") as send:
            with self.assertRaisesRegex(RuntimeError, "gcloud auth login"):
                recognize(b"photo", "dressed-511821")
        send.assert_not_called()


if __name__ == "__main__":
    unittest.main()
