"""Record where a scenario's wall-clock time went, for timeout diagnostics."""

# Bound at import time: deadline tests patch time.monotonic with finite side
# effects, and diagnostic clock reads must not consume those values.
from time import monotonic as _clock


class PhaseTimeline:
    """Consecutive named phases of one scenario run plus point-in-time events.

    Each mark closes the current phase, so phase durations always add up to
    the wall time since the timeline started.
    """

    def __init__(self, first_phase="fixture setup"):
        now = _clock()
        self.started = now
        self._phases = [{"name": first_phase, "start": now, "paused": False}]
        self._events = []
        self._paused = False
        self.step_depth = 0
        self.session_count = 0
        self.snapshot = None

    def mark(self, name):
        now = _clock()
        self._phases[-1]["end"] = now
        self._phases.append({"name": name, "start": now, "paused": self._paused})

    def set_paused(self, paused):
        if paused != self._paused:
            self._paused = paused
            self.mark(self._phases[-1]["name"])

    def note(self, text):
        self._events.append((_clock(), text))

    def record_snapshot(self, text):
        if self.snapshot is None:
            self.snapshot = text

    def records(self):
        now = _clock()
        return [
            {
                "phase": phase["name"],
                "start_seconds": round(phase["start"] - self.started, 3),
                "elapsed_seconds": round(
                    phase.get("end", now) - phase["start"], 3
                ),
                "budget_paused": phase["paused"],
            }
            for phase in self._phases
        ]

    def event_records(self):
        return [
            {"event": text, "at_seconds": round(at - self.started, 3)}
            for at, text in self._events
        ]

    def format_report(self, execution_seconds, cleanup_seconds):
        now = _clock()
        events = list(self._events)
        lines = [
            "--- scenario phase timeline "
            f"(execution budget {execution_seconds:g}s, "
            f"cleanup reserve {cleanup_seconds:g}s) ---",
            "   start  elapsed  phase",
        ]
        paused_total = 0.0
        for index, phase in enumerate(self._phases):
            end = phase.get("end", now)
            elapsed = end - phase["start"]
            if phase["paused"]:
                paused_total += elapsed
            is_last = index == len(self._phases) - 1
            inside = [
                text
                for at, text in events
                if phase["start"] <= at < end or (is_last and at >= end)
            ]
            suffix = " [budget paused]" if phase["paused"] else ""
            if inside:
                suffix += "  <- " + "; ".join(inside)
            lines.append(
                f"{phase['start'] - self.started:+8.3f}s "
                f"{elapsed:7.3f}s  {phase['name']}{suffix}"
            )
        lines.append(
            f"total {now - self.started:.3f}s wall, "
            f"{paused_total:.3f}s budget-paused"
        )
        lines.append(
            self.snapshot
            if self.snapshot is not None
            else "--- no live session when the deadline expired; "
            "screen and trace unavailable ---"
        )
        return "\n".join(lines)
