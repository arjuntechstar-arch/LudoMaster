from types import SimpleNamespace

from services.realtime.gateway import _is_current_socket


class FakeSocket:
    pass


def test_old_socket_is_not_current_after_reconnect_replacement():
    old_socket = FakeSocket()
    new_socket = FakeSocket()
    session = SimpleNamespace(
        user_to_seat={"user-1": 2},
        connections={2: new_socket},
    )

    assert _is_current_socket(session, "user-1", new_socket) is True
    assert _is_current_socket(session, "user-1", old_socket) is False


def test_unknown_user_socket_is_not_current():
    session = SimpleNamespace(user_to_seat={}, connections={})

    assert _is_current_socket(session, "missing-user", FakeSocket()) is False
