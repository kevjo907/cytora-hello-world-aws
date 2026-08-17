"""Hello World HTTP handler for AWS Lambda behind an API Gateway HTTP API.

Kept dependency-free on purpose: the deployment package is a few kilobytes,
cold starts stay fast, and there is no third-party CVE surface to track.

Contract: API Gateway HTTP API, payload format 2.0 (proxy integration).
"""

from __future__ import annotations

import json
import logging
import os
from datetime import UTC, datetime
from typing import Any

# Config arrives through environment variables so one build artifact can be
# promoted unchanged from dev to prod. Nothing secret belongs here.
GREETING = os.environ.get("GREETING_MESSAGE", "Hello, World!")
STAGE = os.environ.get("STAGE", "unknown")

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

# API Gateway terminates TLS for us, so HSTS is honest here. The rest are cheap
# defence-in-depth for anything that renders this response in a browser.
SECURITY_HEADERS: dict[str, str] = {
    "Content-Type": "application/json",
    "X-Content-Type-Options": "nosniff",
    "Cache-Control": "no-store",
    "Strict-Transport-Security": "max-age=63072000; includeSubDomains",
    "Referrer-Policy": "no-referrer",
    "X-Frame-Options": "DENY",
}


def _log(request_id: str, **fields: Any) -> None:
    """Emit one structured JSON line so CloudWatch Logs Insights can query it."""
    logger.info(json.dumps({"request_id": request_id, **fields}))


def _respond(status: int, body: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": status,
        "headers": SECURITY_HEADERS,
        "body": json.dumps(body),
    }


def handler(event: dict[str, Any] | None, context: Any = None) -> dict[str, Any]:
    """Lambda entrypoint.

    Args:
        event: API Gateway v2 proxy event.
        context: Lambda runtime context; ``None`` when invoked locally.

    Returns:
        A proxy response dict that API Gateway turns into an HTTP response.
    """
    request_id = getattr(context, "aws_request_id", "local")
    http = (event or {}).get("requestContext", {}).get("http", {})
    method = http.get("method", "GET")
    path = http.get("path", "/")

    _log(request_id, event="request_received", method=method, path=path, stage=STAGE)

    response = _respond(
        200,
        {
            "message": GREETING,
            "stage": STAGE,
            "path": path,
            "method": method,
            "timestamp": datetime.now(UTC).isoformat(),
            "request_id": request_id,
        },
    )

    _log(request_id, event="request_completed", status=200)
    return response
