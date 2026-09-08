"""Screen regions used by PTY scenarios."""


class Layout:
    def __init__(self, rows):
        self.rows = rows

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

