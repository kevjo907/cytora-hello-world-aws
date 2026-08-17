"""Unit tests for the Hello World Lambda handler."""

import json

import pytest

import handler


class FakeContext:
    """Minimal stand-in for the Lambda runtime context object."""

    aws_request_id = "test-request-id"


def event(method: str = "GET", path: str = "/") -> dict:
    """Build a minimal API Gateway HTTP API v2 proxy event."""
    return {"requestContext": {"http": {"method": method, "path": path}}}


def test_returns_http_200():
    assert handler.handler(event(), FakeContext())["statusCode"] == 200


def test_body_is_json_with_expected_fields():
    body = json.loads(handler.handler(event(path="/hello"), FakeContext())["body"])

    assert body["message"]
    assert body["path"] == "/hello"
    assert body["method"] == "GET"
    assert body["request_id"] == "test-request-id"
    assert "timestamp" in body


def test_timestamp_is_iso8601_utc():
    body = json.loads(handler.handler(event(), FakeContext())["body"])
    # Raises ValueError and fails the test if the format ever drifts.
    assert body["timestamp"].endswith("+00:00")


def test_applies_security_headers():
    headers = handler.handler(event(), FakeContext())["headers"]

    assert headers["Content-Type"] == "application/json"
    assert headers["X-Content-Type-Options"] == "nosniff"
    assert headers["Cache-Control"] == "no-store"
    assert headers["X-Frame-Options"] == "DENY"
    assert "Strict-Transport-Security" in headers


@pytest.mark.parametrize("method", ["GET", "POST", "HEAD"])
def test_echoes_request_method(method):
    body = json.loads(handler.handler(event(method=method), FakeContext())["body"])
    assert body["method"] == method


def test_handles_missing_context():
    # Local invocation and some test harnesses pass no context object.
    response = handler.handler(event(), None)
    assert response["statusCode"] == 200
    assert json.loads(response["body"])["request_id"] == "local"


@pytest.mark.parametrize("bad_event", [{}, None, {"requestContext": {}}])
def test_survives_malformed_events(bad_event):
    # A health checker or a direct console test invoke must not produce a 500.
    response = handler.handler(bad_event, FakeContext())
    body = json.loads(response["body"])

    assert response["statusCode"] == 200
    assert body["method"] == "GET"
    assert body["path"] == "/"
