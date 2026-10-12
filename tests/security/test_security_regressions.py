import pytest
from starlette.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.main import app


client = TestClient(app)


@pytest.mark.parametrize(
    "path",
    [
        "/api/v1/auth/export-data",
        "/api/v1/friends",
    ],
)
def test_protected_endpoints_do_not_accept_anonymous_requests(path):
    response = client.get(path)
    assert response.status_code in (401, 403), (path, response.status_code, response.text)


def test_protected_endpoint_rejects_malformed_bearer_token():
    response = client.get(
        "/api/v1/auth/export-data",
        headers={"Authorization": "Bearer definitely-not-a-jwt"},
    )
    assert response.status_code in (401, 403)


def test_realtime_socket_rejects_invalid_token():
    with pytest.raises(WebSocketDisconnect):
        with client.websocket_connect(
            "/ws/match/non-existent-match?token=definitely-not-a-jwt"
        ):
            pass


def test_guest_auth_does_not_echo_sensitive_token_in_headers():
    response = client.post(
        "/api/v1/auth/guest",
        json={"device_id": "security-regression-device"},
    )
    assert response.status_code == 200
    token = response.json().get("access_token")
    assert token
    serialized_headers = "\n".join(f"{k}:{v}" for k, v in response.headers.items())
    assert token not in serialized_headers


def test_common_security_headers_are_not_dangerously_permissive():
    response = client.get("/health")
    allow_origin = response.headers.get("access-control-allow-origin")
    allow_credentials = response.headers.get("access-control-allow-credentials")
    assert not (allow_origin == "*" and allow_credentials == "true")
