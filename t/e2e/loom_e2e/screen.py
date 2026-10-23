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

    def resize(self, columns, rows):
        if isinstance(columns, bool) or not isinstance(columns, int) or columns <= 0:
            raise ValueError("screen columns must be a positive integer")
        if isinstance(rows, bool) or not isinstance(rows, int) or rows <= 0:
            raise ValueError("screen rows must be a positive integer")
        self._screen.resize(lines=rows, columns=columns)
        self.columns = columns
        self.rows = rows

    def text(self, row):
        return self._screen.display[row]

    def cell_attrs(self, row, column):
        """Return the character and rendition attributes stored by pyte."""
        if not 0 <= row < self.rows:
            raise IndexError(f"screen row out of range: {row}")
        if not 0 <= column < self.columns:
            raise IndexError(f"screen column out of range: {column}")
        cell = self._screen.buffer[row][column]
        return {
            name: getattr(cell, name, None)
            for name in (
                "data",
                "fg",
                "bg",
                "bold",
                "italics",
                "underscore",
                "blink",
                "reverse",
                "strikethrough",
                "conceal",
            )
        }

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
