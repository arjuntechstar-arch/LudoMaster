import pytest
from services.realtime.moderation import is_preset_message, sanitize_chat_message

def test_preset_messages():
    assert is_preset_message("Good game!") is True
    assert is_preset_message("Well played!") is True
    assert is_preset_message("Hurry up!") is True
    assert is_preset_message("Nice move!") is True
    assert is_preset_message("Oops!") is True
    assert is_preset_message("Good luck!") is True
    assert is_preset_message("Thanks!") is True

    # Trailing/leading whitespace should still match
    assert is_preset_message("  Good game!  ") is True

    # Non-presets
    assert is_preset_message("Hello world") is False
    assert is_preset_message("I am cheating") is False

def test_profanity_sanitization():
    # Mask offensive words
    dirty = "Hey you idiot, you are a noob"
    clean = sanitize_chat_message(dirty)
    assert "***" in clean
    assert "idiot" not in clean.lower()
    assert "noob" not in clean.lower()

    # Mask severe profanity
    dirty2 = "fuck this game"
    clean2 = sanitize_chat_message(dirty2)
    assert clean2 == "*** this game"

    # Benign words untouched
    assert sanitize_chat_message("Great game friend!") == "Great game friend!"

def test_message_length_limit():
    long_msg = "a" * 200
    cleaned = sanitize_chat_message(long_msg)
    assert len(cleaned) == 120
