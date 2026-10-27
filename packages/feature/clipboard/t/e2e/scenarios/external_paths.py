"""Exercise clipboard-yank's external read outcomes through a real PTY."""

import contextlib
import json
import os
import shlex
import tempfile
from pathlib import Path

from loom_e2e import keys
from loom_e2e.registry import scenario
from loom_e2e.session import Session


_OUTCOMES = ("success", "missing", "nonzero", "interrupted")
_READ_TEXT = b"external"
_INITIAL = b"tail\n"


@contextlib.contextmanager
def _clipboard_path(path):
    previous = os.environ.get("PATH")
    os.environ["PATH"] = str(path)
    try:
        yield
    finally:
        if previous is None:
            os.environ.pop("PATH", None)
        else:
            os.environ["PATH"] = previous


def _write_fake_copy_tool(bin_dir, result_path):
    script_path = bin_dir / "pbcopy"
    script_path.write_text(
        "\n".join(
            (
                "#!/bin/sh",
                "payload=",
                "IFS= read -r payload || :",
                f"printf '{{\"status\":\"success\",\"payload\":\"%s\"}}' \"$payload\" > {shlex.quote(str(result_path))}",
            )
        )
        + "\n",
        encoding="utf-8",
    )
    script_path.chmod(0o755)


def _write_fake_paste_tool(bin_dir, outcome, result_path):
    script_path = bin_dir / "pbpaste"
    script_path.write_text(
        "\n".join(
            (
                "#!/bin/sh",
                f"printf '{{\"status\":\"{outcome}\",\"payload\":\"{_READ_TEXT.decode('utf-8') if outcome == 'success' else ''}\"}}' > {shlex.quote(str(result_path))}",
                f"if [ \"{outcome}\" = success ]; then printf '%s' {shlex.quote(_READ_TEXT.decode('utf-8'))}; exit 0; fi",
                f"if [ \"{outcome}\" = nonzero ]; then exit 23; fi",
                f"if [ \"{outcome}\" = interrupted ]; then exit 143; fi",
            )
        )
        + "\n",
        encoding="utf-8",
    )
    script_path.chmod(0o755)


def _read_result(result_path):
    if not result_path.exists():
        return {"status": "missing", "payload": ""}
    return json.loads(result_path.read_text(encoding="utf-8"))


def _run_clipboard_yank(binary, outcome):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-clipboard-r5-") as directory:
        root = Path(directory)
        bin_dir = root / "bin"
        bin_dir.mkdir()
        path = root / "buffer.txt"
        path.write_bytes(_INITIAL)
        copy_result = root / "pbcopy-result.json"
        paste_result = root / "pbpaste-result.json"
        _write_fake_copy_tool(bin_dir, copy_result)
        if outcome != "missing":
            _write_fake_paste_tool(bin_dir, outcome, paste_result)

        with _clipboard_path(bin_dir), Session(binary, [str(path)]) as session:
            session.wait_ready()
            session.send(
                keys.ctrl("a")
                + keys.ctrl("@")
                + keys.ctrl("e")
                + keys.meta("w")
                + keys.ctrl("a")
            )
            session.wait_until(
                lambda _screen: b"\x1b]52;c;dGFpbA==\x07" in session.output_bytes,
                timeout=2,
                what="M-w to write the seeded kill-ring entry",
            )
            session.assert_external_state(
                "seeded local clipboard contents",
                json.loads(copy_result.read_text(encoding="utf-8")),
                {"status": "success", "payload": "tail"},
            )

            session.send(keys.meta("x") + keys.text("clipboard-yank"))
            session.key("RET")
            expected_body = (
                "externaltail" if outcome == "success" else "tailtail"
            )
            session.wait_for_region_exact_text(
                "body", expected_body, strip_right=True
            )
            session.assert_screen_text(
                expected_body, region="body", strip_right=True
            )
            session.assert_external_state(
                "external clipboard read result",
                _read_result(paste_result),
                {
                    "status": outcome,
                    "payload": _READ_TEXT.decode("utf-8")
                    if outcome == "success"
                    else "",
                },
            )
            if outcome == "missing":
                expected_message = "Clipboard unavailable; using kill ring"
            elif outcome == "nonzero":
                expected_message = (
                    "Clipboard read failed (pbpaste exited with status 23); "
                    "using kill ring"
                )
            elif outcome == "interrupted":
                expected_message = (
                    "Clipboard read failed (pbpaste exited with status 143); "
                    "using kill ring"
                )
            else:
                expected_message = None
            if expected_message is not None:
                session.wait_for_region_exact_text(
                    "minibuffer", expected_message
                )
                session.assert_screen_text(
                    expected_message, region="minibuffer", strip_right=True
                )

            expected_bytes = expected_body.encode("utf-8") + b"\n"
            session.send(keys.ctrl("x") + keys.ctrl("s"))
            session.wait_for_file(path, expected_bytes)
            session.assert_file_bytes(path, expected_bytes)


def _register(outcome):
    @scenario(
        f"r5/clipboard/clipboard-yank/{outcome}",
        commands=["clipboard-yank", "save-buffer"],
    )
    def run(binary):
        _run_clipboard_yank(binary, outcome)

    return run


for _outcome in _OUTCOMES:
    globals()[f"r5_clipboard_yank_{_outcome}"] = _register(_outcome)
