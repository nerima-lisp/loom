"""Encode key input as the raw bytes loom's terminal decoder expects."""


def ctrl(ch):
    """Encode a control-chord byte, e.g. ctrl('x') -> b'\\x18' (C-x)."""
    return bytes([ord(ch.upper()) - 64])


def meta(ch):
    """Encode an ESC-prefixed meta chord, e.g. meta('x') -> b'\\x1bx' (M-x)."""
    return b"\x1b" + ch.encode("ascii")


def text(s):
    """Encode literal text as UTF-8 for typing into a buffer or prompt."""
    return s.encode("utf-8")


RET = b"\n"
TAB = b"\x09"
ESC = b"\x1b"

UP = b"\x1b[A"
DOWN = b"\x1b[B"
RIGHT = b"\x1b[C"
LEFT = b"\x1b[D"

NAMED = {
    "RET": RET,
    "TAB": TAB,
    "ESC": ESC,
    "UP": UP,
    "DOWN": DOWN,
    "RIGHT": RIGHT,
    "LEFT": LEFT,
}
