"""PTY scenarios using the real nixd language server."""

import os
import shlex
import signal
import shutil
import subprocess
import tempfile

from loom_e2e import keys
from loom_e2e.deadline import scenario_preparation
from loom_e2e.registry import scenario
from loom_e2e.session import Session

from .scenario_helpers import assert_exit_zero, write_buffer

def _nixd_command():
    command = shutil.which("nixd")
    if command:
        return command
    store_path = subprocess.check_output(
        ["nix", "eval", "--raw", "nixpkgs#nixd"], text=True
    ).strip()
    executable = os.path.join(store_path, "bin", "nixd")
    if not os.path.isfile(executable) or not os.access(executable, os.X_OK):
        raise RuntimeError(
            "nixd package output does not contain an executable bin/nixd"
        )
    return executable


def _fixture(contents=b"# no definition here\nlet\n  value = 1;\nin\n  value\n"):
    directory = tempfile.TemporaryDirectory(prefix="loom-e2e-lsp-")
    with open(os.path.join(directory.name, "flake.nix"), "wb") as handle:
        handle.write(b"{}\n")
    with open(os.path.join(directory.name, ".loom-lsp"), "w", encoding="utf-8") as handle:
        handle.write("exec " + _nixd_command() + "\n")
    path = write_buffer(directory.name, "main.nix", contents)
    return directory, path


def _typescript_fixture(contents):
    if not shutil.which("typescript-language-server"):
        raise RuntimeError("typescript-language-server is missing from the E2E PATH")
    directory = tempfile.TemporaryDirectory(prefix="loom-e2e-typescript-lsp-")
    directory_path = os.path.realpath(directory.name)
    pid_file = os.path.join(directory_path, "typescript-language-server.pid")
    server = os.path.join(directory_path, "lsp-server")
    script = (
        "#!/bin/sh\n"
        "printf '%s\\n' \"$$\" > " + shlex.quote(pid_file) + "\n"
        "exec typescript-language-server --stdio\n"
    )
    write_buffer(directory_path, "lsp-server", script.encode("utf-8"))
    os.chmod(server, 0o755)
    with open(os.path.join(directory_path, ".loom-lsp"), "w", encoding="utf-8") as handle:
        handle.write("exec " + shlex.quote(server) + "\n")
    path = write_buffer(directory_path, "main.ts", contents.encode("utf-8"))
    return directory, path, pid_file


def _typescript_pid(session, pid_file):
    session.wait_until(
        lambda _screen: os.path.exists(pid_file),
        what="typescript-language-server PID file to appear",
    )
    pid_data = session.observe_file_bytes(pid_file, purpose="precondition")
    pid = int(pid_data.decode("ascii").strip())
    session.assert_external_state(
        "typescript-language-server PID is greater than 1", pid > 1, True
    )
    return pid


def _warm_up_typescript_server(session):
    # The first hover waits for TypeScript's project service to load the file.
    session.send(keys.ctrl("n"))
    session.wait_for_region_cursor("body", 0, index=1)
    session.extended_command("lsp-hover-at-point")
    session.wait_for_region_text("minibuffer", "targetValue")
    session.assert_screen_text(
        "targetValue",
        match="contains",
        region="minibuffer",
        purpose="precondition",
    )
    session.send(keys.ctrl("p"))
    session.wait_for_region_cursor("body", 0, index=0)


def _move_to_buffer_position(session, line, column):
    session.extended_command("beginning-of-buffer")
    session.send(keys.ctrl("n") * line + keys.ctrl("f") * column)
    session.wait_for_region_cursor("body", column, index=line)


def _wait_for_nixd_diagnostics(session):
    # This indicator follows nixd's publishDiagnostics for the opened file.
    session.wait_for_region_text("mode-line", "Diag:")


def _assert_typescript_server_running(session, pid, command):
    session.assert_external_state(
        "typescript-language-server is running after " + command,
        _process_running(pid),
        True,
    )


def _server_exit_fixture():
    directory = tempfile.TemporaryDirectory(prefix="loom-e2e-lsp-")
    command = os.path.join(directory.name, "lsp-server")
    status_path = os.path.join(directory.name, "lsp-server-exit-status")
    script = (
        "#!/bin/sh\n"
        "printf '17\\n' > " + shlex.quote(status_path) + "\n"
        "exit 17\n"
    )
    write_buffer(directory.name, "lsp-server", script.encode("utf-8"))
    os.chmod(command, 0o755)
    with open(os.path.join(directory.name, ".loom-lsp"), "w", encoding="utf-8") as handle:
        handle.write("exec " + shlex.quote(command) + "\n")
    path = write_buffer(directory.name, "notes.txt", b"still usable\n")
    return directory, path, status_path


def _missing_server_fixture():
    directory = tempfile.TemporaryDirectory(prefix="loom-e2e-missing-lsp-")
    command = os.path.join(directory.name, "typescript-language-server-missing")
    with open(os.path.join(directory.name, ".loom-lsp"), "w", encoding="utf-8") as handle:
        handle.write("exec " + shlex.quote(command) + "\n")
    path = write_buffer(directory.name, "main.ts", b"const value = 1;\nvalue;\n")
    return directory, path, command


def _start(session):
    session.extended_command("lsp-start")
    session.wait_for_text("LSP command [RET for")
    session.key("RET")
    session.wait_for_text("Run discovered LSP command? Type yes: ")
    session.type("yes")
    session.key("RET")
    session.wait_for_text("LSP started.")


def _select_main_buffer(session, expected_text):
    session.extended_command("lsp-diagnostics")
    session.wait_for_text("LSP diagnostics refreshed.")
    session.extended_command("switch-to-buffer")
    session.wait_for_text("Switch to buffer: ")
    session.type("main.nix")
    session.key("RET")
    session.wait_for_text(expected_text)


def _assert_path_exists(session, label, path, expected):
    return session.assert_external_state(label, os.path.exists(path), expected)


def _assert_minibuffer(session, expected):
    return session.assert_screen_text(
        expected.rstrip(),
        region="minibuffer",
        strip_right=True,
    )


def _wait_for_body_viewport(session, expected, description):
    expected_text = "\n".join(expected)

    def read_viewport():
        return session.screen.lines()[:session.layout.body_height]

    try:
        session.wait_until(
            lambda _screen: read_viewport() == expected,
            what=description,
        )
    except TimeoutError:
        session.observe_screen_text(
            expected=expected_text,
            match="exact",
            region="body",
            index=None,
            purpose="precondition",
        )
        raise
    return session.observe_screen_text(
        expected=expected_text,
        match="exact",
        region="body",
        index=None,
    )


def _process_running(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


def _supervised_server_fixture(server_argv, filename, contents, prefix):
    directory = tempfile.TemporaryDirectory(prefix=f"loom-e2e-{prefix}-")
    directory_path = os.path.realpath(directory.name)
    child_pid_file = os.path.join(directory_path, "lsp-server-child.pid")
    wrapper_pid_file = os.path.join(directory_path, "lsp-server-wrapper.pid")
    exit_status_file = os.path.join(directory_path, "lsp-server-exit-status")
    server = os.path.join(directory_path, "lsp-server")
    script = "\n".join(
        (
            "#!/bin/sh",
            "printf '%s\\n' \"$$\" > " + shlex.quote(wrapper_pid_file),
            shlex.join(server_argv) + " <&0 >&1 2>&2 &",
            "child=$!",
            "printf '%s\\n' \"$child\" > " + shlex.quote(child_pid_file),
            "wait \"$child\"",
            "status=$?",
            "printf '%s\\n' \"$status\" > " + shlex.quote(exit_status_file),
            "exit \"$status\"",
        )
    ) + "\n"
    write_buffer(directory_path, "lsp-server", script.encode("utf-8"))
    os.chmod(server, 0o755)
    with open(os.path.join(directory_path, ".loom-lsp"), "w", encoding="utf-8") as handle:
        handle.write("exec " + shlex.quote(server) + "\n")
    if filename.endswith(".nix"):
        with open(os.path.join(directory_path, "flake.nix"), "wb") as handle:
            handle.write(b"{}\n")
    contents_bytes = contents.encode("utf-8") if isinstance(contents, str) else contents
    path = write_buffer(directory_path, filename, contents_bytes)
    return directory, path, child_pid_file, wrapper_pid_file, exit_status_file


def _supervised_child_pid(session, child_pid_file, wrapper_pid_file):
    pids = []
    for description, pid_file in (
        ("child", child_pid_file),
        ("wrapper", wrapper_pid_file),
    ):
        session.wait_for_external_state(
            f"language server {description} PID file exists",
            lambda pid_file=pid_file: os.path.exists(pid_file),
            True,
        )
        pid_data = session.observe_file_bytes(pid_file, purpose="precondition")
        pid = int(pid_data.decode("ascii").strip())
        session.assert_external_state(
            f"language server {description} PID is greater than 1",
            pid > 1,
            True,
        )
        pids.append(pid)
    return tuple(pids)


def _assert_supervised_exit(session, exit_status_file, wrapper_pid, expected_status):
    session.wait_for_external_state(
        "language server child exit status exists",
        lambda: os.path.exists(exit_status_file),
        True,
    )
    session.wait_for_external_state(
        "language server wrapper has exited",
        lambda: not _process_running(wrapper_pid),
        True,
    )
    with open(exit_status_file, encoding="ascii") as handle:
        actual_status = handle.read().strip()
    session.assert_external_state(
        "language server child exit status", actual_status, expected_status
    )


def _run_lsp_command(binary, command, expected):
    directory, path = _fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            if command not in ("lsp-diagnostics", "lsp-stop"):
                _select_main_buffer(session, "let")
            session.extended_command(command)
            session.wait_for_text(expected)
            output, code = session.quit()
        assert_exit_zero(command, output, code)
    finally:
        directory.cleanup()


@scenario("lsp/start", commands=["lsp-start"])
def lsp_start(binary):
    directory, path = _fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            output, code = session.quit()
        assert_exit_zero("lsp-start", output, code)
    finally:
        directory.cleanup()


@scenario("lsp/trust-reject", commands=["lsp-start"])
def lsp_trust_reject(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-lsp-") as directory:
        # Discovery canonicalizes paths, including macOS's /tmp symlink.
        directory = os.path.realpath(directory)
        configuration = os.path.join(directory, ".loom-lsp")
        marker = os.path.join(directory, "spawned")
        server = os.path.join(directory, "lsp-server")
        script = "#!/bin/sh\nprintf spawned > " + shlex.quote(marker) + "\n"
        write_buffer(directory, "lsp-server", script.encode("utf-8"))
        os.chmod(server, 0o755)
        command = "exec " + shlex.quote(server)
        with open(configuration, "w", encoding="utf-8") as handle:
            handle.write(command + "\n")
        path = write_buffer(directory, "main.lisp", b"(+ 1 2)\n")
        review_lines = (
            "Config: " + configuration,
            "Directory: " + directory,
            "Command: " + server,
        )
        # Screen.find searches individual rows; retain the complete provenance
        # assertions even when the platform's temporary pathname exceeds 80 cells.
        columns = max(80, max(map(len, review_lines)) + 1)
        with Session(binary, [path], columns=columns) as session:
            session.wait_ready()
            for answer in ("", "no", None):
                session.extended_command("lsp-start")
                session.wait_for_text("LSP command [RET for")
                session.key("RET")
                session.wait_for_text("Run discovered LSP command? Type yes: ")
                for line in review_lines:
                    session.wait_for_text(line)
                if answer is None:
                    session.send(keys.ctrl("g"))
                    session.wait_for_text("Quit")
                else:
                    session.type(answer)
                    session.key("RET")
                    session.wait_for_text("LSP start cancelled.")
                session.wait_for_text("(+ 1 2)")
                _assert_path_exists(
                    session, "rejected LSP marker exists", marker, False
                )
            output, code = session.quit()
        assert_exit_zero("lsp-trust-reject", output, code)


@scenario("lsp/trust-review", commands=["lsp-start", "lsp-stop"])
def lsp_trust_review(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-lsp-") as directory:
        directory = os.path.realpath(directory)
        configuration = os.path.join(directory, ".loom-lsp")
        marker = os.path.join(directory, "spawned")
        pid_file = os.path.join(directory, "nixd.pid")
        tail_fragments = ("REVIEW_END_", "UNIQUE")
        tail = "".join(tail_fragments)
        tail_forms = (tail, "\n".join(tail_fragments))
        nixd_command = _nixd_command()
        server = os.path.join(directory, "lsp-server")
        command = (
            "exec " + shlex.quote(server) + " " + "review-content " * 120 + tail
        )
        script = (
            "#!/bin/sh\n"
            "printf spawned > " + shlex.quote(marker) + "\n"
            "printf '%s\\n' $$ > " + shlex.quote(pid_file) + "\n"
            "exec " + shlex.quote(nixd_command) + "\n"
        )
        write_buffer(directory, "lsp-server", script.encode("utf-8"))
        os.chmod(server, 0o755)
        with open(configuration, "w", encoding="utf-8") as handle:
            handle.write(command + "\n")
        write_buffer(directory, "flake.nix", b"{}\n")
        source = "let value = 1; in missingValue"
        path = write_buffer(directory, "main.nix", (source + "\n").encode("utf-8"))
        prompt = "Run discovered LSP command? Type yes: "
        with Session(binary, [path], columns=80, rows=10) as session:
            session.wait_ready()
            session.wait_for_text(source)
            original = session.screen.lines()[:session.layout.body_height]

            def wait_for_review_tail():
                def displayed_tail():
                    body = session.region_contents("body")
                    return next(
                        (form for form in tail_forms if form in body), None
                    )

                try:
                    session.wait_until(
                        lambda _screen: displayed_tail() is not None,
                        what="trust-review tail marker to appear",
                    )
                except TimeoutError:
                    session.observe_screen_text(
                        expected=tail,
                        match="contains",
                        region="body",
                        index=None,
                        purpose="precondition",
                    )
                    raise
                form = displayed_tail()
                if form is None:
                    raise AssertionError("trust-review tail marker disappeared")
                session.observe_screen_text(
                    expected=form,
                    match="contains",
                    region="body",
                    index=None,
                    purpose="precondition",
                )

            for answer in ("yes", ""):
                session.extended_command("lsp-start")
                session.wait_for_text("LSP command [RET for")
                session.key("RET")
                session.wait_for_text(prompt)
                session.wait_for_text("PageDown/C-v: next; PageUp/M-v: previous")
                session.type(answer)
                session.wait_for_region_exact_text(
                    "minibuffer", (prompt + answer).rstrip()
                )
                for forward, backward in (
                    (b"\x1b[6~", b"\x1b[5~"),
                    (keys.ctrl("v"), keys.meta("v")),
                ):
                    session.send(forward * 12)
                    wait_for_review_tail()
                    _assert_minibuffer(session, prompt + answer)
                    _assert_path_exists(
                        session, "reviewed LSP marker remains absent", marker, False
                    )
                    _assert_path_exists(
                        session, "reviewed LSP PID file remains absent", pid_file, False
                    )
                    session.send(backward * 12)
                    session.wait_for_text("Discovered LSP command")
                    _assert_minibuffer(session, prompt + answer)
                    _assert_path_exists(
                        session, "reviewed LSP marker remains absent", marker, False
                    )
                    _assert_path_exists(
                        session, "reviewed LSP PID file remains absent", pid_file, False
                    )
                session.send(keys.ctrl("g") if answer else session.profile.key("RET"))
                session.wait_for_text("Quit" if answer else "LSP start cancelled.")
                _wait_for_body_viewport(
                    session, original, "original buffer viewport restored"
                )
                _assert_path_exists(
                    session, "rejected LSP marker remains absent", marker, False
                )
                _assert_path_exists(
                    session, "rejected LSP PID file remains absent", pid_file, False
                )
            session.extended_command("lsp-start")
            session.wait_for_text("LSP command [RET for")
            session.key("RET")
            session.wait_for_text(prompt)
            session.wait_for_text("PageDown/C-v: next; PageUp/M-v: previous")
            session.type("yes")
            session.wait_for_region_exact_text(
                "minibuffer", prompt + "yes"
            )
            session.send(b"\x1b[6~" * 12)
            wait_for_review_tail()
            _assert_minibuffer(session, prompt + "yes")
            _assert_path_exists(
                session, "unconfirmed LSP marker remains absent", marker, False
            )
            _assert_path_exists(
                session, "unconfirmed LSP PID file remains absent", pid_file, False
            )
            session.send(b"\x1b[5~" * 12)
            session.wait_for_text("Discovered LSP command")
            _assert_minibuffer(session, prompt + "yes")
            _assert_path_exists(
                session, "unconfirmed LSP marker remains absent", marker, False
            )
            _assert_path_exists(
                session, "unconfirmed LSP PID file remains absent", pid_file, False
            )
            session.key("RET")

            session.wait_for_file(marker, b"spawned")
            session.wait_for_text("LSP started.")
            pid_data = session.observe_file_bytes(pid_file)
            pid = int(pid_data.decode("ascii").strip())
            session.assert_external_state(
                "nixd PID is greater than 1", pid > 1, True
            )
            session.assert_external_state(
                "nixd process is running", _process_running(pid), True
            )
            _wait_for_body_viewport(
                session, original,
                "original buffer viewport restored after confirmation",
            )

            session.wait_for_region_text("mode-line", "Diag:")

            session.extended_command("lsp-stop")
            session.wait_for_text("LSP stopped.")
            session.wait_for_external_state(
                "nixd process exited after lsp-stop",
                lambda: not _process_running(pid),
                True,
            )
            _wait_for_body_viewport(
                session, original,
                "original buffer viewport preserved after LSP cleanup",
            )
            output, code = session.quit()
        assert_exit_zero("lsp-trust-review", output, code)


@scenario("lsp/stop", commands=["lsp-stop"])
def lsp_stop(binary):
    directory, path = _fixture()
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            session.extended_command("lsp-stop")
            session.wait_for_text("LSP stopped.")
            output, code = session.quit()
        assert_exit_zero("lsp-stop", output, code)
    finally:
        directory.cleanup()


@scenario("lsp/diagnostics", commands=["lsp-diagnostics"])
def lsp_diagnostics(binary):
    malformed_nix = b"let\n  value = ;\nin\n  value\n"
    directory, path = _fixture(malformed_nix)
    directory_path = os.path.realpath(directory.name)
    pid_file = os.path.join(directory_path, "nixd.pid")
    server = os.path.join(directory_path, "lsp-server")
    script = (
        "#!/bin/sh\n"
        "printf '%s\\n' \"$$\" > " + shlex.quote(pid_file) + "\n"
        "exec " + shlex.quote(_nixd_command()) + "\n"
    )
    write_buffer(directory_path, "lsp-server", script.encode("utf-8"))
    os.chmod(server, 0o755)
    with open(os.path.join(directory_path, ".loom-lsp"), "w", encoding="utf-8") as handle:
        handle.write("exec " + shlex.quote(server) + "\n")
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            session.wait_for_region_text("mode-line", "Diag:")
            session.wait_for_external_state(
                "nixd PID file exists", lambda: os.path.exists(pid_file), True
            )
            pid_data = session.observe_file_bytes(
                pid_file, purpose="precondition"
            )
            pid = int(pid_data.decode("ascii").strip())
            session.extended_command("lsp-diagnostics")
            session.wait_for_text("LSP diagnostics refreshed.")
            session.wait_for_region_text("body", "Diagnostics for main.nix")
            session.wait_for_region_text(
                "body", "expected binding expression", index=1
            )
            session.assert_screen_text(
                "expected binding expression",
                match="contains",
                region="body",
                index=1,
            )
            session.assert_external_state(
                "nixd process is running after diagnostics",
                _process_running(pid),
                True,
            )
            session.extended_command("switch-to-buffer")
            session.wait_for_text("Switch to buffer: ")
            session.type("main.nix")
            session.key("RET")
            session.wait_for_text("let")
            session.extended_command("lsp-stop")
            session.wait_for_text("LSP stopped.")
            session.wait_for_external_state(
                "nixd process exited after lsp-stop",
                lambda: not _process_running(pid),
                True,
            )
            output, code = session.quit()
        assert_exit_zero("lsp-diagnostics", output, code)
    finally:
        directory.cleanup()


@scenario("lsp/r5-typescript-success/start", commands=["lsp-start"])
def lsp_typescript_start_success(binary):
    directory, path, pid_file = _typescript_fixture("const serverStarts = true;\n")
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            pid = _typescript_pid(session, pid_file)
            session.assert_external_state(
                "typescript-language-server is running after lsp-start",
                _process_running(pid),
                True,
            )
            output, code = session.quit()
        assert_exit_zero("lsp-typescript-start-success", output, code)
    finally:
        directory.cleanup()


@scenario(
    "lsp/r5-typescript-success/hover-completion",
    commands=[
        "lsp-start",
        "lsp-hover-at-point",
        "lsp-completion-at-point",
    ],
)
def lsp_typescript_hover_completion_success(binary):
    source = (
        "const targetValue = 1;\n"
        "targetValue;\n"
        "targetV\n"
        "targetValue;\n"
    )
    directory, path, pid_file = _typescript_fixture(source)
    try:
        with Session(binary, [path]) as session:
            with scenario_preparation():
                session.wait_ready()
                _start(session)
                pid = _typescript_pid(session, pid_file)
                _warm_up_typescript_server(session)

            session.send(keys.ctrl("n"))
            session.wait_for_region_cursor("body", 0, index=1)
            session.extended_command("lsp-hover-at-point")
            session.wait_for_region_text("minibuffer", "targetValue")
            session.assert_screen_text(
                "targetValue", match="contains", region="minibuffer"
            )
            _assert_typescript_server_running(session, pid, "lsp-hover-at-point")

            session.send(keys.ctrl("n") + keys.ctrl("e"))
            session.wait_for_region_cursor("body", len("targetV"), index=2)
            session.send(b"\x1b[105;7u")
            session.wait_until(
                lambda _screen: session.region_contents("body")
                .splitlines()[3]
                .rstrip()
                == "targetValue",
                what="TypeScript completion popup to display targetValue",
            )
            session.assert_screen_text(
                "targetValue",
                match="exact",
                region="body",
                index=3,
                strip_right=True,
            )
            _assert_typescript_server_running(
                session, pid, "lsp-completion-at-point"
            )

            output, code = session.quit()
        assert_exit_zero("lsp-typescript-hover-completion-success", output, code)
    finally:
        directory.cleanup()


@scenario(
    "lsp/r5-typescript-success/definition",
    commands=["lsp-start", "lsp-find-definition"],
)
def lsp_typescript_definition_success(binary):
    source = "const targetValue = 1;\ntargetValue;\n"
    directory, path, pid_file = _typescript_fixture(source)
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            pid = _typescript_pid(session, pid_file)
            _move_to_buffer_position(session, 1, 1)
            session.send(keys.meta("."))
            session.wait_for_region_cursor("body", len("const "), index=0)
            session.assert_screen_text(
                "const targetValue = 1;",
                match="contains",
                region="body",
                index=0,
            )
            _assert_typescript_server_running(session, pid, "lsp-find-definition")
            output, code = session.quit()
        assert_exit_zero("lsp-typescript-definition-success", output, code)
    finally:
        directory.cleanup()


@scenario(
    "lsp/r5-typescript-success/editing",
    commands=[
        "lsp-start",
        "lsp-hover-at-point",
        "lsp-rename",
        "lsp-format-buffer",
        "lsp-find-references",
    ],
)
def lsp_typescript_editing_success(binary):
    source = (
        "const targetValue = 1;\n"
        "targetValue;\n"
        "const formatProbe={answer:42}\n"
    )
    directory, path, pid_file = _typescript_fixture(source)
    try:
        with Session(binary, [path]) as session:
            with scenario_preparation():
                session.wait_ready()
                _start(session)
                pid = _typescript_pid(session, pid_file)
                _warm_up_typescript_server(session)

            session.send(keys.ctrl("f") * len("const "))
            session.wait_for_region_cursor("body", len("const "))
            session.extended_command("lsp-rename")
            session.wait_for_text("Rename to: ")
            session.type("renamedTarget")
            session.key("RET")
            session.wait_until(
                lambda _screen: "const renamedTarget = 1;"
                in session.region_contents("body"),
                what="TypeScript rename to update the declaration",
            )
            session.assert_screen_text(
                "const renamedTarget = 1;",
                match="contains",
                region="body",
                index=0,
            )
            session.assert_screen_text(
                "renamedTarget;", match="contains", region="body", index=1
            )
            _assert_typescript_server_running(session, pid, "lsp-rename")

            session.extended_command("lsp-format-buffer")
            session.wait_until(
                lambda _screen: "const formatProbe = { answer: 42 }"
                in session.region_contents("body"),
                what="TypeScript formatting to add standard spacing",
            )
            session.assert_screen_text(
                "const formatProbe={answer:42}",
                match="not_contains",
                region="body",
                index=None,
            )
            session.assert_screen_text(
                "const formatProbe = { answer: 42 }",
                match="contains",
                region="body",
                index=None,
            )
            _assert_typescript_server_running(session, pid, "lsp-format-buffer")

            session.extended_command("save-buffer")
            session.extended_command("lsp-find-references")
            session.wait_for_region_text("minibuffer", "References found:")
            session.assert_screen_text(
                "References found:", match="contains", region="minibuffer"
            )
            session.assert_screen_text(
                "renamedTarget",
                match="contains",
                region="body",
                index=None,
            )
            _assert_typescript_server_running(session, pid, "lsp-find-references")

            output, code = session.quit()
        assert_exit_zero("lsp-typescript-editing-success", output, code)
    finally:
        directory.cleanup()


@scenario(
    "lsp/r5-typescript-success/stop",
    commands=["lsp-start", "lsp-stop"],
)
def lsp_typescript_stop_success(binary):
    directory, path, pid_file = _typescript_fixture("const serverStops = true;\n")
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            pid = _typescript_pid(session, pid_file)
            session.observe_external_state(
                "typescript-language-server is running before lsp-stop",
                _process_running(pid),
                True,
                purpose="precondition",
            )
            session.extended_command("lsp-stop")
            session.wait_for_text("LSP stopped.")
            session.wait_until(
                lambda _screen: not _process_running(pid),
                what="typescript-language-server process to exit after lsp-stop",
            )
            session.assert_external_state(
                "typescript-language-server exited after lsp-stop",
                _process_running(pid),
                False,
            )
            output, code = session.quit()
        assert_exit_zero("lsp-typescript-stop-success", output, code)
    finally:
        directory.cleanup()


@scenario("lsp/completion", commands=["lsp-completion-at-point"])
def lsp_completion(binary):
    _run_lsp_command(binary, "lsp-completion-at-point", "No completions")


@scenario("lsp/completion-success", commands=["lsp-completion-at-point"])
def lsp_completion_success(binary):
    source = "let completionValue = 1; in comp"
    directory, path = _fixture((source + "\n").encode("utf-8"))
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            _select_main_buffer(session, source)
            # Diagnostics arrive after initialization and didOpen, not just spawn.
            session.wait_for_region_text("mode-line", "Diag:")
            session.send(keys.ctrl("f") * len(source))
            session.wait_for_region_cursor("body", len(source))
            session.extended_command("lsp-completion-at-point")
            session.wait_for_region_text("body", "completionValue", index=1)
            session.key("RET")
            completed = "let completionValue = 1; in completionValue"
            session.wait_for_region_text("body", completed)
            session.wait_for_region_cursor("body", len(completed))
            session.extended_command("save-buffer")
            session.wait_for_file(path, (completed + "\n").encode("utf-8"))
            output, code = session.quit()
        assert_exit_zero("lsp-completion-success", output, code)
    finally:
        directory.cleanup()


@scenario("lsp/find-definition", commands=["lsp-find-definition"])
def lsp_find_definition(binary):
    _run_lsp_command(binary, "lsp-find-definition", "No definition found")


@scenario(
    "lsp/find-definition-success",
    commands=["lsp-find-definition", "lsp-pop-definition"],
)
def lsp_find_definition_success(binary):
    directory, path = _fixture(b"let\n  value = 1;\nin\n  value\n")
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            _select_main_buffer(session, "let")
            session.send(keys.ctrl("n") * 3 + keys.ctrl("f") * 2)
            session.wait_for_region_cursor("body", 2, index=3)
            session.extended_command("lsp-find-definition")
            session.wait_for_region_cursor("body", 2, index=1)
            session.wait_for_region_text("body", "value = 1;", index=1)
            session.extended_command("lsp-pop-definition")
            session.wait_for_region_cursor("body", 2, index=3)
            session.wait_for_region_text("body", "value", index=3)
            output, code = session.quit()
        assert_exit_zero("lsp-find-definition-success", output, code)
    finally:
        directory.cleanup()


@scenario(
    "lsp/find-definition-unicode",
    commands=["lsp-find-definition", "lsp-pop-definition"],
)
def lsp_find_definition_unicode(binary):
    prefix = "  /* 😀 */ "
    source = f"let\n{prefix}value = 1;\nin\n{prefix}value\n"
    directory, path = _fixture(source.encode("utf-8"))
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            _start(session)
            _select_main_buffer(session, "let")
            # nixd rejects the identifier's first UTF-16 offsets after an
            # astral character; probe inside it while preserving the offset test.
            session.send(keys.ctrl("n") * 3 + keys.ctrl("f") * (len(prefix) + 2))
            # The emoji occupies one buffer character but two screen cells.
            column = len(prefix) + 1
            session.wait_for_region_cursor("body", column + 2, index=3)
            session.extended_command("lsp-find-definition")
            session.wait_for_region_cursor("body", column, index=1)
            session.wait_for_region_text("body", "value = 1;", index=1)
            session.extended_command("lsp-pop-definition")
            session.wait_for_region_cursor("body", column + 2, index=3)
            session.wait_for_region_text("body", "value", index=3)
            output, code = session.quit()
        assert_exit_zero("lsp-find-definition-unicode", output, code)
    finally:
        directory.cleanup()


@scenario("lsp/pop-definition", commands=["lsp-pop-definition"])
def lsp_pop_definition(binary):
    _run_lsp_command(binary, "lsp-pop-definition", "No jump to return from")


@scenario("lsp/server-nonzero-exit", commands=["lsp-start", "save-buffer"])
def lsp_server_nonzero_exit(binary):
    directory, path, status_path = _server_exit_fixture()
    message = "LSP start failed: server exited with status 17"
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("lsp-start")
            session.wait_for_text("LSP command [RET for")
            session.key("RET")
            session.wait_for_text("Run discovered LSP command? Type yes: ")
            session.type("yes")
            session.key("RET")
            session.wait_for_text(message)
            session.assert_screen_text(
                message,
                region="minibuffer",
                strip_right=True,
            )
            with open(status_path, encoding="utf-8") as handle:
                status = handle.read().strip()
            session.assert_external_state("lsp-server exit status", status, "17")
            session.send(keys.ctrl("e"))
            session.type(" updated")
            session.extended_command("save-buffer")
            session.wait_for_file(path, b"still usable updated\n")
            output, code = session.quit()
        assert_exit_zero("lsp-server-nonzero-exit", output, code)
    finally:
        directory.cleanup()


@scenario(
    "lsp/r5-missing-server",
    commands=[
        "lsp-start",
        "lsp-stop",
        "lsp-diagnostics",
        "lsp-completion-at-point",
        "lsp-find-definition",
        "lsp-find-references",
        "lsp-hover-at-point",
        "lsp-rename",
        "lsp-format-buffer",
    ],
)
def lsp_missing_server(binary):
    directory, path, command = _missing_server_fixture()
    no_session = "No LSP session for this buffer"
    no_session_plain = "No LSP session."
    try:
        with Session(binary, [path]) as session:
            session.wait_ready()
            session.extended_command("lsp-start")
            session.wait_for_text("LSP command [RET for")
            session.key("RET")
            session.wait_for_text("Run discovered LSP command? Type yes: ")
            session.type("yes")
            session.key("RET")
            session.wait_for_text("LSP start failed:")
            session.assert_screen_text(
                "LSP start failed:", match="contains", region="minibuffer"
            )
            session.assert_external_state(
                "configured TypeScript server executable is absent",
                os.path.exists(command),
                False,
            )

            for name, message in (
                ("lsp-stop", no_session_plain),
                ("lsp-diagnostics", no_session_plain),
                ("lsp-completion-at-point", no_session),
                ("lsp-find-definition", no_session),
                ("lsp-find-references", no_session),
                ("lsp-hover-at-point", no_session),
                ("lsp-rename", no_session),
                ("lsp-format-buffer", no_session),
            ):
                if name == "lsp-completion-at-point":
                    session.send(b"\x1b[105;7u")
                elif name == "lsp-find-definition":
                    session.send(keys.meta("."))
                else:
                    session.extended_command(name)
                session.wait_for_text(message)
                session.assert_screen_text(
                    message, match="contains", region="minibuffer"
                )
                session.assert_external_state(
                    "configured TypeScript server executable remains absent",
                    os.path.exists(command),
                    False,
                )

            output, code = session.quit()
        assert_exit_zero("lsp-missing-server", output, code)
    finally:
        directory.cleanup()


def _run_nixd_failure(binary, signal_number, expected_status, label):
    malformed_nix = b"let\n  value = ;\nin\n  value\n"
    directory, path, child_pid_file, wrapper_pid_file, exit_status_file = (
        _supervised_server_fixture(
            [_nixd_command()], "main.nix", malformed_nix, "nixd-" + label
        )
    )
    expected_error = f"server exited with status {expected_status}"
    try:
        with Session(binary, [path]) as session:
            with scenario_preparation():
                session.wait_ready()
                _start(session)
                child_pid, wrapper_pid = _supervised_child_pid(
                    session, child_pid_file, wrapper_pid_file
                )
                _wait_for_nixd_diagnostics(session)
            os.kill(child_pid, signal_number)
            _assert_supervised_exit(
                session, exit_status_file, wrapper_pid, expected_status
            )

            for name in (
                "lsp-diagnostics",
                "lsp-completion-at-point",
                "lsp-find-definition",
                "lsp-find-references",
                "lsp-hover-at-point",
                "lsp-rename",
                "lsp-format-buffer",
                "lsp-stop",
            ):
                if name == "lsp-completion-at-point":
                    session.send(b"\x1b[105;7u")
                elif name == "lsp-find-definition":
                    session.send(keys.meta("."))
                else:
                    session.extended_command(name)

                if name == "lsp-diagnostics":
                    expected_message = "LSP error:"
                elif name == "lsp-stop":
                    expected_message = "LSP stopped."
                else:
                    expected_message = expected_error

                if name == "lsp-rename":
                    session.wait_for_text("Rename to: ")
                    session.type("renamedValue")
                    session.key("RET")

                session.wait_for_region_text("minibuffer", expected_message)
                session.assert_screen_text(
                    expected_message,
                    match="contains",
                    region="minibuffer",
                )
                _assert_supervised_exit(
                    session, exit_status_file, wrapper_pid, expected_status
                )

            output, code = session.quit()
        assert_exit_zero("lsp-nixd-" + label, output, code)
    finally:
        directory.cleanup()


@scenario(
    "lsp/r5-nixd-nonzero",
    commands=[
        "lsp-start",
        "lsp-diagnostics",
        "lsp-completion-at-point",
        "lsp-find-definition",
        "lsp-find-references",
        "lsp-hover-at-point",
        "lsp-rename",
        "lsp-format-buffer",
        "lsp-stop",
    ],
)
def lsp_nixd_nonzero_exit(binary):
    _run_nixd_failure(binary, signal.SIGKILL, "137", "nonzero")


@scenario(
    "lsp/r5-nixd-interrupted",
    commands=[
        "lsp-start",
        "lsp-diagnostics",
        "lsp-completion-at-point",
        "lsp-find-definition",
        "lsp-find-references",
        "lsp-hover-at-point",
        "lsp-rename",
        "lsp-format-buffer",
        "lsp-stop",
    ],
)
def lsp_nixd_interrupted_exit(binary):
    _run_nixd_failure(binary, signal.SIGTERM, "143", "interrupted")
