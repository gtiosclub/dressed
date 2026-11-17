"""Small Google Vision Object Localization client for local development.

Credentials come from each developer's gcloud sign-in. No credential file or
API key belongs in the iOS app or this repository.
"""

from __future__ import annotations

import base64
import json
import subprocess
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


VISION_URL = "https://vision.googleapis.com/v1/images:annotate"


def recognize(image: bytes, project: str) -> dict:
    if not project or not image:
        raise ValueError("a Google Cloud project and image are required")
    try:
        credential = subprocess.run(
            ["gcloud", "auth", "print-access-token", "--project", project],
            capture_output=True, text=True, check=True, timeout=20,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        raise RuntimeError("Google sign-in is unavailable; run gcloud auth login") from error
    if not credential:
        raise RuntimeError("Google sign-in returned no access token")
    payload = json.dumps({"requests": [{
        "image": {"content": base64.b64encode(image).decode("ascii")},
        "features": [{"type": "OBJECT_LOCALIZATION", "maxResults": 30}],
    }]}).encode("utf-8")
    request = Request(VISION_URL, data=payload, method="POST", headers={
        "Authorization": f"Bearer {credential}",
        "Content-Type": "application/json",
        "x-goog-user-project": project,
    })
    try:
        with urlopen(request, timeout=30) as response:
            result = json.load(response)
    except HTTPError as error:
        # Provider errors can contain request details; return the status only.
        raise RuntimeError(f"Google Vision returned HTTP {error.code}") from error
    except (URLError, TimeoutError, ValueError) as error:
        raise RuntimeError("Google Vision did not return a usable response") from error
    if not isinstance(result, dict):
        raise RuntimeError("Google Vision returned an invalid response")
    return result
