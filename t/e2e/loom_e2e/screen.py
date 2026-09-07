"""Reconstruct loom's terminal frame from raw PTY bytes via pyte."""

import pyte


class Screen:
    def __init__(self, columns=80, rows=24):
        self._screen = pyte.Screen(columns, rows)
        # cl-tty-kit ends every drawn row with a bare LF, not CRLF, and pads
        # rows to the full terminal width. pyte's autowrap defers the wrap
        # of a full-width row until the *next* printable character is
        # drawn; a bare LF (linefeed() without LNM) advances the row but
        # leaves that pending-wrap flag armed, so the first character of
        # the following row silently wraps an extra time. Over ~20 rows
        # this misplaces later rows by one relative to the app's own
        # coordinates (confirmed against cl-tty-kit's own CUP sequences).
        # Setting LNM makes linefeed() also emit a carriage return, which
        # clears the pending-wrap flag before it can double-fire.
        self._screen.set_mode(pyte.modes.LNM)
        self._stream = pyte.ByteStream(self._screen)

    def feed(self, data):
        if data:
            self._stream.feed(data)

    def text(self, row):
        return self._screen.display[row]

    def lines(self):
        return list(self._screen.display)

    @property
    def cursor(self):
        return (self._screen.cursor.y, self._screen.cursor.x)

    def find(self, substring):
        for row, line in enumerate(self._screen.display):
            column = line.find(substring)
            if column != -1:
                return (row, column)
        return None

    def dump(self):
        return "\n".join(f"{row:2d}: {line!r}" for row, line in enumerate(self._screen.display))
