import json
import asyncio
import pytest
from starlette.testclient import TestClient
from app.main import app
from app.db.base import Base
from app.db.session import engine

@pytest.fixture(autouse=True, scope="module")
def setup_database():
    async def init_models():
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    asyncio.run(init_models())
    yield
    async def drop_models():
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.drop_all)
    asyncio.run(drop_models())

def test_realtime_multiplayer_lifecycle_and_reconnect():
    client = TestClient(app)

    # 1. Login Host
    h_res = client.post("/api/v1/auth/guest", json={"device_id": "ws_host_1"})
    assert h_res.status_code == 200
    host_token = h_res.json()["access_token"]
    h_headers = {"Authorization": f"Bearer {host_token}"}

    # 2. Login Player 2
    p2_res = client.post("/api/v1/auth/guest", json={"device_id": "ws_p2_1"})
    assert p2_res.status_code == 200
    p2_token = p2_res.json()["access_token"]
    p2_headers = {"Authorization": f"Bearer {p2_token}"}

    # 3. Create room
    create_res = client.post("/api/v1/rooms", json={"mode": "CLASSIC", "max_players": 4}, headers=h_headers)
    assert create_res.status_code == 201
    room = create_res.json()
    room_id = room["id"]
    room_code = room["code"]

    # 4. Player 2 joins
    join_res = client.post("/api/v1/rooms/join", json={"code": room_code}, headers=p2_headers)
    assert join_res.status_code == 200

    # 5. Player 2 ready
    ready_res = client.post(f"/api/v1/rooms/{room_id}/ready", json={"is_ready": True}, headers=p2_headers)
    assert ready_res.status_code == 200

    # 6. Host starts match
    start_res = client.post(f"/api/v1/rooms/{room_id}/start", headers=h_headers)
    assert start_res.status_code == 200
    match_id = start_res.json()["match_id"]
    assert match_id is not None

    # 7. Connect Host and Player 2 WebSockets
    with client.websocket_connect(f"/ws/match/{match_id}?token={host_token}") as ws_host:
        h_ev1 = ws_host.receive_json()
        assert h_ev1["event"] == "AUTHENTICATED"
        assert h_ev1["payload"]["seatIndex"] == 0

        h_ev2 = ws_host.receive_json()
        assert h_ev2["event"] == "STATE_SNAPSHOT"

        h_ev3 = ws_host.receive_json()
        assert h_ev3["event"] == "PLAYER_JOINED"
        assert h_ev3["payload"]["seatIndex"] == 0

        # Now connect Player 2
        with client.websocket_connect(f"/ws/match/{match_id}?token={p2_token}") as ws_p2:
            p2_ev1 = ws_p2.receive_json()
            assert p2_ev1["event"] == "AUTHENTICATED"
            assert p2_ev1["payload"]["seatIndex"] == 1

            p2_ev2 = ws_p2.receive_json()
            assert p2_ev2["event"] == "STATE_SNAPSHOT"

            # Both receive PLAYER_JOINED for Player 2
            p2_ev3 = ws_p2.receive_json()
            assert p2_ev3["event"] == "PLAYER_JOINED"
            assert p2_ev3["payload"]["seatIndex"] == 1

            h_ev4 = ws_host.receive_json()
            assert h_ev4["event"] == "PLAYER_JOINED"
            assert h_ev4["payload"]["seatIndex"] == 1

            # Both receive MATCH_STARTED
            p2_ev4 = ws_p2.receive_json()
            assert p2_ev4["event"] == "MATCH_STARTED"

            h_ev5 = ws_host.receive_json()
            assert h_ev5["event"] == "MATCH_STARTED"

            # Both receive TURN_STARTED
            p2_ev5 = ws_p2.receive_json()
            assert p2_ev5["event"] == "TURN_STARTED"
            assert p2_ev5["payload"]["currentSeatIndex"] == 0

            h_ev6 = ws_host.receive_json()
            assert h_ev6["event"] == "TURN_STARTED"
            assert h_ev6["payload"]["currentSeatIndex"] == 0

            # 8. Test Heartbeat Ping/Pong
            ws_host.send_json({"type": "PING"})
            pong = ws_host.receive_json()
            assert pong["type"] == "PONG"

            # 9. Test In-Game Chat & Emoji
            ws_p2.send_json({"action": "CHAT", "message": "Good game!"})
            chat_h = ws_host.receive_json()
            assert chat_h["event"] == "CHAT_MESSAGE"
            assert chat_h["payload"]["message"] == "Good game!"

            chat_p2 = ws_p2.receive_json()
            assert chat_p2["event"] == "CHAT_MESSAGE"
            assert chat_p2["payload"]["message"] == "Good game!"

            ws_host.send_json({"action": "EMOJI", "emojiId": "fire"})
            emoji_h = ws_host.receive_json()
            assert emoji_h["event"] == "EMOJI_SENT"
            assert emoji_h["payload"]["emojiId"] == "fire"

            emoji_p2 = ws_p2.receive_json()
            assert emoji_p2["event"] == "EMOJI_SENT"
            assert emoji_p2["payload"]["emojiId"] == "fire"

            # 10. Test Server-Authoritative Dice Roll
            last_seq = emoji_h["sequence"]
            ws_host.send_json({"action": "ROLL_REQUEST"})

            roll_h = ws_host.receive_json()
            assert roll_h["event"] == "DICE_ROLLED"
            assert 1 <= roll_h["payload"]["value"] <= 6
            assert roll_h["sequence"] > last_seq
            assert roll_h["version"] == 1
            assert roll_h["matchId"] == match_id

            roll_p2 = ws_p2.receive_json()
            assert roll_p2["event"] == "DICE_ROLLED"
            assert roll_p2["payload"]["value"] == roll_h["payload"]["value"]

            # If roll == 6, move request
            if roll_h["payload"]["value"] == 6:
                legal_h = ws_host.receive_json()
                assert legal_h["event"] == "LEGAL_MOVES"
                legal_p2 = ws_p2.receive_json()
                assert legal_p2["event"] == "LEGAL_MOVES"

                ws_host.send_json({"action": "MOVE_REQUEST", "tokenId": 0})
                move_h = ws_host.receive_json()
                assert move_h["event"] == "MOVE_APPLIED"
                assert move_h["payload"]["seatIndex"] == 0
                move_p2 = ws_p2.receive_json()
                assert move_p2["event"] == "MOVE_APPLIED"
                assert move_p2["payload"]["seatIndex"] == 0

                bonus_h = ws_host.receive_json()
                assert bonus_h["event"] == "BONUS_TURN"
                bonus_p2 = ws_p2.receive_json()
                assert bonus_p2["event"] == "BONUS_TURN"

                turn_h = ws_host.receive_json()
                assert turn_h["event"] == "TURN_STARTED"
                turn_p2 = ws_p2.receive_json()
                assert turn_p2["event"] == "TURN_STARTED"

            # 11. Disconnect Player 2
            # Context manager exit closes Player 2's socket!

        # Host receives PLAYER_DISCONNECTED
        disc_ev = ws_host.receive_json()
        assert disc_ev["event"] == "PLAYER_DISCONNECTED"
        assert disc_ev["payload"]["seatIndex"] == 1

        # 12. Player 2 Reconnects
        with client.websocket_connect(f"/ws/match/{match_id}?token={p2_token}") as ws_p2_reconnect:
            rec_auth = ws_p2_reconnect.receive_json()
            assert rec_auth["event"] == "AUTHENTICATED"
            assert rec_auth["payload"]["seatIndex"] == 1

            rec_snap = ws_p2_reconnect.receive_json()
            assert rec_snap["event"] == "STATE_SNAPSHOT"

            # Both receive PLAYER_RECONNECTED
            p2_rec_ev = ws_p2_reconnect.receive_json()
            assert p2_rec_ev["event"] == "PLAYER_RECONNECTED"
            assert p2_rec_ev["payload"]["seatIndex"] == 1

            h_rec_ev = ws_host.receive_json()
            assert h_rec_ev["event"] == "PLAYER_RECONNECTED"
            assert h_rec_ev["payload"]["seatIndex"] == 1
