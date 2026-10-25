"""Exercise key response when rendering a large buffer."""

import os
import tempfile
import time

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.results import record_observation
from loom_e2e.session import Session


@scenario("d13/20k-line-key-response", commands=["forward-char"])
def d13_20k_line_key_response(binary, *, benchmark_target_ms=None):
    line_count = 20_000
    with tempfile.TemporaryDirectory(prefix="loom-d13-") as directory:
        path = os.path.join(directory, "large.txt")
        with open(path, "wb") as handle:
            for index in range(line_count):
                handle.write(b"line-%05d " % index + b"x" * 20 + b"\n")

        with Session(binary, [path]) as session:
            session.wait_ready()
            session.wait_for_region_text("body", "line-00000")
            session.wait_for_region_cursor("body", 0)
            session.observe_external_state(
                "D13 input line count", line_count, expected=20_000
            )
            session.observe_external_state(
                "D13 input byte count",
                os.path.getsize(path),
                expected=640_000,
            )

            before = session.screen.cursor
            expected = (before[0], before[1] + 1)
            started = time.monotonic()
            session.send(keys.ctrl("f"))
            deadline = started + 8.0
            while session.screen.cursor != expected:
                if time.monotonic() >= deadline:
                    raise TimeoutError(
                        "20,000-line key input did not redraw within 8 seconds"
                    )
                session.pump(poll_timeout=0.001)

            elapsed_ms = (time.monotonic() - started) * 1000.0
            session.observe_external_state(
                "D13 redrawn cursor", session.screen.cursor, expected=expected
            )
            record_observation(
                "benchmark_measurement",
                round(elapsed_ms, 3),
                metric="D13 input-to-redraw",
                unit="ms",
            )
            if (
                benchmark_target_ms is not None
                and elapsed_ms > benchmark_target_ms
            ):
                raise AssertionError(
                    "20,000-line key response exceeded "
                    f"{benchmark_target_ms:g} ms: "
                    f"{elapsed_ms:.3f} ms"
                )

            output, code = session.quit()
            if code != 0:
                raise AssertionError(
                    f"d13/20k-line-key-response exited with {code}: {output!r}"
                )

    if benchmark_target_ms is not None:
        return {
            "d13_20k_line_key_response_milliseconds": round(elapsed_ms, 3)
        }
