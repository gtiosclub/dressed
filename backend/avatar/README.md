# Avatar try-on bridge (development only)

`avatar_service.py` is a loopback-only service for Debug simulator builds. The app sends the owner's
reference photo and up to six piece photos. The service adds the OpenAI key, calls `POST /v1/images/edits`
and returns the generated image. **The key never goes into the app.** Release builds have no backend yet
(a Cloud Function with Secret Manager is TBD; see `docs/eric-avatar-aiimg.md`).

```sh
# Paid calls. Key from OPENAI_API_KEY, else ~/.config/dressed/openai.env (OPENAI_API_KEY=..., mode 600).
python3 backend/avatar/avatar_service.py --live
# Options: --model (default gpt-image-2.6-sunburst) --quality low|medium|high --max-requests 25 --port 8766

# No key, no network: returns the given image for every request after a short delay.
python3 backend/avatar/avatar_service.py --fixture path/to/image.jpg
```

- `GET /health` reports mode, model, prompt version and remaining paid requests.
- `POST /avatar` takes `{"reference": base64, "pieces": [{"image": base64, "label": "navy tee (top)"}]}`.
  It returns `{"image": base64 JPEG, "model", "promptVersion"}`, or `{"error": code, "message"}` where the
  code is one of `invalid_request`, `content_policy`, `rate_limited`, `limit_reached`, `auth`, `upstream`
  or `unavailable`.
- Logs show piece counts, timings and error codes only. They never include images, labels or the key.
- The style prompt lives in `STYLE_PROMPT`. Bump `PROMPT_VERSION` when you change it.
- Tests: `cd backend/avatar && python3 -m unittest test_avatar_service` (no network).

Use only your own photo or a consented test photo. Never send real users' photos from this bridge.
