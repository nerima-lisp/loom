"""Screen regions used by PTY scenarios."""


def validate_dimensions(columns, rows):
    for name, value in (("columns", columns), ("rows", rows)):
        if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
            raise ValueError(f"terminal {name} must be a positive integer")
    return columns, rows


class Layout:
    def __init__(self, rows, columns=80):
        self.rows = rows
        self.columns = columns

    @property
    def minibuffer_row(self):
        return max(0, self.rows - 1)

    @property
    def window_height(self):
        return max(0, self.rows - 1)

    @property
    def body_height(self):
        return max(0, self.window_height - 1)

    @property
    def mode_line_row(self):
        return max(0, self.window_height - 1)

    def body_row(self, index=0):
        if not 0 <= index < self.body_height:
            raise IndexError(f"body row index out of range: {index}")
        return index

    def row(self, region, index=0):
        if region == "body":
            return self.body_row(index)
        if region == "mode-line":
            if index != 0:
                raise IndexError(f"mode-line row index out of range: {index}")
            return self.mode_line_row
        if region == "minibuffer":
            if index != 0:
                raise IndexError(f"minibuffer row index out of range: {index}")
            return self.minibuffer_row
        raise ValueError(f"unknown screen region: {region}")

