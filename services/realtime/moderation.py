import re
from typing import Set

PRESET_CHAT_MESSAGES = {
    "Good game!",
    "Well played!",
    "Hurry up!",
    "Nice move!",
    "Oops!",
    "Good luck!",
    "Thanks!",
}

BLOCKED_WORDS = {
    "fuck", "shit", "bitch", "asshole", "cunt", "dick", "bastard",
    "fag", "nigger", "slut", "whore", "retard", "idiot", "loser",
    "scam", "cheat", "hacker", "trash", "noob",
}

_PROFANITY_PATTERN = re.compile(
    r"\b(" + "|".join(re.escape(w) for w in BLOCKED_WORDS) + r")\b",
    re.IGNORECASE,
)

def is_preset_message(message: str) -> bool:
    return message.strip() in PRESET_CHAT_MESSAGES

def sanitize_chat_message(message: str) -> str:
    """Masks profane words with asterisks and limits length to 120 chars."""
    trimmed = message[:120].strip()
    return _PROFANITY_PATTERN.sub("***", trimmed)
