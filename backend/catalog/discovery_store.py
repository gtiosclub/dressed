"""Local discovery staging and replay archives; separate from the public catalog."""

import json
import re
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path

from retail_product import from_candidate, from_metadata


DEFAULT_ROOT = Path(__file__).resolve().parent / "local-data"


def sanitize(value, secret=None):
    if isinstance(value, dict):
        return {key: "[REDACTED]" if key.lower() in {
            "api_key", "apikey", "authorization", "access_token", "client_secret"
        } else sanitize(item, secret) for key, item in value.items()}
    if isinstance(value, list):
        return [sanitize(item, secret) for item in value]
    if isinstance(value, str):
        if secret:
            value = value.replace(secret, "[REDACTED]")
        return re.sub(r"(?i)([?&](?:api_key|apikey|access_token)=)[^&#\s]*", r"\1[REDACTED]", value)
    return value


def write_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, allow_nan=False) + "\n")
    temporary.replace(path)


class DiscoveryRun:
    """Archive each response immediately; upsert candidates and append observations."""

    def __init__(self, *, root=DEFAULT_ROOT, mode="live", secret=None):
        self.root = Path(root)
        self.id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:8]
        self.directory = self.root / "runs" / self.id
        self.directory.mkdir(parents=True, mode=0o700)
        self.secret = secret
        self.mode = mode
        self.responses = {"searches": {}, "details": {}, "links": {}, "redirects": {}, "errors": []}
        self.report = {"runId": self.id, "mode": mode, "status": "running", "runs": []}
        write_json(self.directory / "responses.json", self.responses)
        write_json(self.directory / "report.json", self.report)
        # Fixtures use a separate database so synthetic examples never pollute live data.
        self.database = self.root / ("discovery.sqlite" if mode == "live" else "fixture-discovery.sqlite")
        with sqlite3.connect(self.database) as connection:
            connection.executescript("""
                CREATE TABLE IF NOT EXISTS candidates (
                    provider TEXT NOT NULL, id TEXT NOT NULL,
                    first_seen_at TEXT NOT NULL, last_seen_at TEXT NOT NULL,
                    latest_run_id TEXT NOT NULL, state TEXT NOT NULL, data_json TEXT NOT NULL,
                    PRIMARY KEY (provider, id)
                );
                CREATE TABLE IF NOT EXISTS observations (
                    run_id TEXT NOT NULL, query TEXT NOT NULL, provider TEXT NOT NULL,
                    candidate_id TEXT NOT NULL, observed_at TEXT NOT NULL, data_json TEXT NOT NULL,
                    PRIMARY KEY (run_id, query, provider, candidate_id)
                );
            """)

    def capture(self, kind, key, action):
        try:
            result = action(key)
        except Exception as error:
            self.responses["errors"].append({"kind": kind, "input": sanitize(key, self.secret),
                                              "errorType": type(error).__name__})
            write_json(self.directory / "responses.json", self.responses)
            raise
        self.responses[kind][sanitize(key, self.secret)] = sanitize(result, self.secret)
        write_json(self.directory / "responses.json", self.responses)
        return result

    def record_query(self, query_result, observed_at=None, provider="serpapi"):
        safe = sanitize(query_result, self.secret)
        now = observed_at or datetime.now(timezone.utc).isoformat()
        for candidate in safe["candidates"]:
            if provider == "shared-link-html" and "metadata" in candidate and "fields" in candidate["metadata"]:
                candidate["retailProduct"] = from_metadata(candidate["metadata"])
            elif provider == "serpapi":
                candidate["retailProduct"] = from_candidate(candidate, now)
        query_result["candidates"] = safe["candidates"]
        self.report["runs"].append(safe)
        write_json(self.directory / "report.json", self.report)
        with sqlite3.connect(self.database) as connection:
            for candidate in safe["candidates"]:
                data = json.dumps(candidate, allow_nan=False)
                state = candidate.get("reviewState") or (
                    "needs_verification" if candidate["offers"] else "needs_merchant_url")
                connection.execute("""
                    INSERT INTO candidates VALUES (?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(provider, id) DO UPDATE SET
                        last_seen_at=excluded.last_seen_at, latest_run_id=excluded.latest_run_id,
                        state=excluded.state, data_json=excluded.data_json
                """, (provider, candidate["id"], now, now, self.id, state, data))
                connection.execute("INSERT OR REPLACE INTO observations VALUES (?, ?, ?, ?, ?, ?)",
                                   (self.id, safe["query"], provider, candidate["id"], now, data))

    def finish(self, report=None, status="completed"):
        if report is not None:
            self.report = sanitize(report, self.secret)
        self.report.update(runId=self.id, status=status)
        write_json(self.directory / "report.json", self.report)
        return self.directory / "report.json"
