"""Reconstruct loom's terminal frame from raw PTY bytes via pyte."""

import pyte


class Screen:
    def __init__(self, columns=80, rows=24):
        self.columns = columns
        self.rows = rows
        self._screen = pyte.Screen(columns, rows)
        # pyte otherwise keeps a pending wrap after cl-tty-kit's padded LF.
        # LNM clears that state before the next row is drawn.
        self._screen.set_mode(pyte.modes.LNM)
        self._stream = pyte.ByteStream(self._screen)

    def feed(self, data):
        if data:
            self._stream.feed(data)

    def text(self, row):
        return self._screen.display[row]

    def lines(self):
        return list(self._screen.display)

    def has_content(self):
        return any(line.strip() for line in self._screen.display)

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
