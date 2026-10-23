"""Encode key input as raw bytes for common terminal profiles."""

from dataclasses import dataclass
from types import MappingProxyType


def ctrl(ch):
    """Encode a control-chord byte, e.g. ctrl('x') -> b'\\x18' (C-x)."""
    return bytes([ord(ch.upper()) - 64])


def meta(ch):
    """Encode an ESC-prefixed meta chord, e.g. meta('x') -> b'\\x1bx' (M-x)."""
    return b"\x1b" + ch.encode("ascii")


def text(s):
    """Encode literal text as UTF-8 for typing into a buffer or prompt."""
    return s.encode("utf-8")


@dataclass(frozen=True)
class TerminalProfile:
    """A terminal's TERM value and named key byte sequences."""

    name: str
    term: str
    key_sequences: object

    def __post_init__(self):
        object.__setattr__(
            self,
            "key_sequences",
            MappingProxyType(dict(self.key_sequences)),
        )

    def key(self, name):
        try:
            return self.key_sequences[name]
        except KeyError as error:
            raise KeyError(f"terminal profile {self.name!r} has no key {name!r}") from error


_COMMON_KEYS = {
    "RET": b"\r",
    "LF": b"\n",
    "TAB": b"\x09",
    "ESC": b"\x1b",
    "UP": b"\x1b[A",
    "DOWN": b"\x1b[B",
    "RIGHT": b"\x1b[C",
    "LEFT": b"\x1b[D",
}

XTERM_256COLOR = TerminalProfile(
    "xterm-256color",
    "xterm-256color",
    {**_COMMON_KEYS, "END": b"\x1b[F"},
)
XTERM = TerminalProfile(
    "xterm",
    "xterm",
    {**_COMMON_KEYS, "END": b"\x1b[4~"},
)

PROFILES = MappingProxyType(
    {
        XTERM_256COLOR.name: XTERM_256COLOR,
        XTERM.name: XTERM,
    }
)
DEFAULT_PROFILE = XTERM_256COLOR


def get_profile(profile=DEFAULT_PROFILE):
    """Return a known terminal profile by name or preserve a profile object."""
    if isinstance(profile, TerminalProfile):
        return profile
    try:
        return PROFILES[profile]
    except KeyError as error:
        raise ValueError(f"unknown terminal profile: {profile!r}") from error


def key(name, profile=DEFAULT_PROFILE):
    """Return one named key sequence for PROFILE."""
    return get_profile(profile).key(name)


RET = DEFAULT_PROFILE.key("RET")
LF = DEFAULT_PROFILE.key("LF")
TAB = DEFAULT_PROFILE.key("TAB")
ESC = DEFAULT_PROFILE.key("ESC")

UP = DEFAULT_PROFILE.key("UP")
DOWN = DEFAULT_PROFILE.key("DOWN")
RIGHT = DEFAULT_PROFILE.key("RIGHT")
LEFT = DEFAULT_PROFILE.key("LEFT")
END = DEFAULT_PROFILE.key("END")

NAMED = {
    "RET": RET,
    "LF": LF,
    "TAB": TAB,
    "ESC": ESC,
    "UP": UP,
    "DOWN": DOWN,
    "RIGHT": RIGHT,
    "LEFT": LEFT,
    "END": END,
}
