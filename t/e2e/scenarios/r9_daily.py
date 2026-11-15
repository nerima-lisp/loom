"""R9: one working day as one scenario over loom processes started in turn.

Every process shares the session's scratch HOME. Each scene observes its
effect before the next path command runs, so the path report can attribute
an observation to every command of r9:daily.
"""

import os
import re
import shlex
import signal
import subprocess
import tempfile
import time
from pathlib import Path

from loom_e2e import keys
from loom_e2e.deadline import r9_scenario, scenario_preparation
from loom_e2e.registry import scenario
from loom_e2e.session import Session

from .lsp import (
    _assert_server_request_responses,
    _assert_supervised_exit,
    _assert_typescript_server_running,
    _move_to_buffer_position,
    _protocol_events,
    _server_request_response_counts,
    _start as _start_lsp,
    _supervised_child_pid,
    _supervised_server_fixture,
    _warm_up_typescript_server,
)


# Wide enough for the save prompt with a temporary directory's full path.
_COLUMNS = 160
_C_RIGHT = b"\x1b[1;5C"
_C_M_I = b"\x1b[105;7u"

_A_LISP = b"(defun a ()\n  :draft)\n"
_A_LISP_UNSAVED = b"(defun a () ; unsaved evening edit\n  :draft)\n"
_DAY_LISP = b"(defun day ()\n(list) :done)\n   (day)\n"
_DAY_AFTER_0910 = b"(defun day ()\n  (list :done)) ;\n\n   (day)\n"
_DAY_AFTER_0920 = (
    b"(defun day ()\n"
    b"  (list :done)) ;\n"
    b'(defun note () "first\n'
    b"MIDDLE_DOCSTRING\n"
    b'last")\n'
    b"#| note\n"
    b"BLOCK_COMMENT |#\n"
    b"(day)\n"
)
_DAY_AFTER_1800 = b";; evening review\n" + _DAY_AFTER_0920
_TODO = b"item one\nitem two\nitem three\nitem four\n"
_TODO_AFTER_1500 = b"done one\nitem two\ndone three\ndone four\n"
_TYPESCRIPT = "const targetValue = 1;\ntargetValue;\ntargetV\ntargetValue;\n"
_COMMIT_SUBJECT = "R9 daily commit"
_INBOX_ENTRIES = 200
# 10:30 reads "every request answered" as no request left waiting between
# loom and the server. typescript-language-server sends no server requests in
# this scene, so loom's own requests carry the check, and these must appear.
_REQUIRED_LOOM_REQUESTS = ("textDocument/completion", "textDocument/definition")
_UNIVERSAL_TIME_OFFSET = 2208988800
_META_TOKEN = re.compile(r'\s*(?:(\()|(\))|"((?:[^"\\]|\\.)*)"|([^\s()"]+))')


def _git(directory, *arguments):
    env = dict(os.environ)
    env.update(
        {
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
            "HOME": os.fspath(directory),
        }
    )
    result = subprocess.run(
        ["git", "-C", os.fspath(directory), *arguments],
        check=True,
        capture_output=True,
        text=True,
        timeout=5,
        env=env,
    )
    return result.stdout.strip()


def _write_executable(path, body):
    path.write_text("#!/bin/sh\n" + body, encoding="utf-8")
    path.chmod(0o755)
    return os.fspath(path)


def _lisp_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _make_project(root):
    work = root / "work"
    (work / "src").mkdir(parents=True)
    (work / "a.lisp").write_bytes(_A_LISP)
    (work / "src" / "day.lisp").write_bytes(_DAY_LISP)
    (work / "todo.txt").write_bytes(_TODO)
    _git(work, "init", "--quiet")
    _git(work, "config", "user.name", "loom E2E")
    _git(work, "config", "user.email", "loom-e2e@example.invalid")
    _git(work, "add", "-A")
    _git(work, "commit", "--quiet", "-m", "baseline")
    return work


def _make_inbox(root):
    inbox = root / "inbox"
    inbox.mkdir()
    for index in range(_INBOX_ENTRIES):
        (inbox / f"r9-{index:03d}.txt").write_bytes(
            f"R9 inbox {index:03d}\n".encode()
        )
    return inbox


def _launch(session, executable, arguments):
    """Run the next loom process of the day in the session's scratch HOME.

    The session's first process runs the first scene of the day; each later
    scene starts once the previous process has exited.
    """
    if not session.process.has_exited():
        if (session.binary, session.arguments) != (executable, list(arguments)):
            raise AssertionError("the previous loom process of the day is still running")
        return
    session.binary = executable
    session.arguments = list(arguments)
    session.restart()


def _wait_body_row(session, index, text):
    session.wait_for_region_exact_text("body", text, index=index)


def _assert_body_row(session, index, text):
    _wait_body_row(session, index, text)
    session.assert_screen_text(text, region="body", index=index, strip_right=True)


def _assert_minibuffer(session, text):
    session.wait_for_region_exact_text("minibuffer", text)
    session.assert_screen_text(text, region="minibuffer", strip_right=True)


def _assert_cursor(session, row, column):
    session.wait_for_region_cursor("body", column, index=row)
    if session.observe_cursor(expected=(row, column), region="body") is not True:
        raise AssertionError(
            f"body cursor was {session.region_cursor('body')!r}; "
            f"expected {(row, column)!r}"
        )


def _assert_word_color(session, word, foreground):
    def colored(_screen):
        position = session.screen.find(word)
        return (
            position is not None
            and session.screen.cell_attrs(*position)["fg"] == foreground
        )

    session.wait_until(colored, what=f"{word} to use foreground {foreground}")
    session.assert_cell_attrs(
        *session.screen.find(word), {"data": word[0], "fg": foreground}
    )


def _quit(session, scene):
    output, code = session.quit()
    if code != 0:
        raise AssertionError(f"{scene}: loom exited with {code}: {output!r}")


def _recovery_names(session):
    recovery = Path(session.home_dir) / ".loom" / "recovery"
    return sorted(entry.name for entry in recovery.iterdir()) if recovery.is_dir() else []


def _recovery_body_count(session):
    # loom counts every NAME.txt in the directory, whatever NAME is.
    return sum(1 for name in _recovery_names(session) if len(name) > 4 and name.endswith(".txt"))


def _recovery_entries_for(session, path):
    """Return (body, metadata path, metadata) for each entry recorded for PATH.

    Entries are found through the :path in their metadata, not their names."""
    recovery = Path(session.home_dir) / ".loom" / "recovery"
    entries = []
    for meta_path in sorted(recovery.glob("*.sexp")) if recovery.is_dir() else []:
        meta = _read_flat_plist(meta_path.read_text(encoding="utf-8"))
        if meta.get(":path") == str(path):
            entries.append((meta_path.with_suffix(".txt"), meta_path, meta))
    return entries


def _read_flat_plist(text):
    """Read recovery metadata as a dict with lowercase keyword names."""
    text = text.strip()
    tokens = []
    position = 0
    while position < len(text):
        match = _META_TOKEN.match(text, position)
        if match is None or match.end() == position:
            raise AssertionError(f"unreadable recovery metadata: {text!r}")
        tokens.append(match)
        position = match.end()
    if (
        len(tokens) < 2
        or tokens[0].group(1) is None
        or tokens[-1].group(2) is None
        or any(token.group(1) or token.group(2) for token in tokens[1:-1])
    ):
        raise AssertionError(f"recovery metadata is not one flat list: {text!r}")
    values = []
    for token in tokens[1:-1]:
        if token.group(3) is not None:
            values.append(re.sub(r"\\(.)", r"\1", token.group(3)))
        elif re.fullmatch(r"-?\d+", token.group(4)):
            values.append(int(token.group(4)))
        else:
            values.append(token.group(4).lower())
    if len(values) % 2:
        raise AssertionError(f"recovery metadata is not a plist: {text!r}")
    return dict(zip(values[0::2], values[1::2]))


def _scene_evening_sighup(session, binary, a_lisp):
    _launch(session, binary, [str(a_lisp)])
    session.wait_ready()
    _wait_body_row(session, 0, "(defun a ()")
    session.send(keys.ctrl("e"))
    session.wait_for_region_cursor("body", len("(defun a ()"), index=0)
    session.type(" ; unsaved evening edit")
    _wait_body_row(session, 0, "(defun a () ; unsaved evening edit")
    os.kill(session.process._pid, signal.SIGHUP)
    _output, code = session.process.wait(timeout=1.5)
    session.observe_exit_code(code, expected=129)
    session.assert_external_state("evening exit status after SIGHUP", code, 129)

    entries = _recovery_entries_for(session, a_lisp)
    session.assert_external_state(
        "evening recovery metadata files recording a.lisp", len(entries), 1
    )
    body, _meta_path, meta = entries[0]
    session.assert_external_state(
        "evening recovery body beside its metadata", body.is_file(), True
    )
    session.assert_external_state(
        "evening recovery body bytes", body.read_bytes(), _A_LISP_UNSAVED
    )
    session.assert_external_state(
        "evening recovery metadata fields",
        {key: meta.get(key) for key in (":version", ":buffer-name", ":reason")},
        {":version": 1, ":buffer-name": "a.lisp", ":reason": ":sighup"},
    )
    session.assert_external_state(
        "evening recovery metadata time is a universal time",
        isinstance(meta.get(":time"), int) and meta[":time"] > _UNIVERSAL_TIME_OFFSET,
        True,
    )


def _scene_0900_recover(session, binary, a_lisp):
    # File dates have whole-second resolution, so the entry must be at least
    # a second newer than a.lisp to count as unsaved work.
    now = int(time.time())
    os.utime(a_lisp, (now - 30, now - 30))
    for body, meta_path, _meta in _recovery_entries_for(session, a_lisp):
        os.utime(body, (now, now))
        os.utime(meta_path, (now, now))
    bodies = _recovery_body_count(session)
    session.assert_external_state(
        "09:00 recovery bodies before startup", bodies > 0, True, purpose="precondition"
    )

    _launch(session, binary, [])
    session.wait_ready()
    _assert_minibuffer(
        session, f"{bodies} recoverable file(s); M-x list-recoverable-files"
    )
    session.extended_command("list-recoverable-files")
    # The list is newest first, and the evening entry is the newest.
    session.wait_for_region_text("body", str(a_lisp))
    session.assert_screen_text(str(a_lisp), match="contains", region="body", index=0)
    session.assert_screen_text("  recovery  ", match="contains", region="body", index=0)
    session.key("RET")
    _assert_minibuffer(session, "Recover from recovery (<1 min newer)? (r, d, i, C-g)")
    _wait_body_row(session, 0, "(defun a ()")
    session.type("r")
    _assert_minibuffer(session, "Recovered from recovery; save to keep")
    _assert_body_row(session, 0, "(defun a () ; unsaved evening edit")
    _assert_cursor(session, 0, 0)
    session.save_buffer(str(a_lisp), _A_LISP_UNSAVED)
    session.assert_file_bytes(str(a_lisp), _A_LISP_UNSAVED)
    session.assert_external_state(
        "09:00 recovery entries recording a.lisp after the save",
        [meta_path.name for _body, meta_path, _meta in _recovery_entries_for(session, a_lisp)],
        [],
    )
    session.assert_external_state(
        "09:00 recovery bodies after the save", _recovery_body_count(session), bodies - 1
    )
    _quit(session, "09:00")


def _scene_0905_project_file(session, binary, a_lisp):
    _launch(session, binary, [str(a_lisp)])
    session.wait_ready()
    session.send(keys.ctrl("x") + b"pf")
    session.wait_for_region_text("minibuffer", "Project file: ")
    session.type("src/day.lisp")
    session.key("RET")
    _assert_body_row(session, 0, "(defun day ()")
    _wait_body_row(session, 1, "(list) :done)")


def _scene_0910_lisp_keys(session, day):
    session.send(keys.ctrl("n"))
    session.wait_for_region_cursor("body", 0, index=1)
    session.key("TAB")
    _assert_body_row(session, 1, "  (list) :done)")
    _assert_cursor(session, 1, 2)
    session.send(keys.ctrl("f") * 2)
    session.wait_for_region_cursor("body", 4, index=1)
    session.send(_C_RIGHT)
    _assert_body_row(session, 1, "  (list :done))")
    session.send(keys.ctrl("e"))
    session.wait_for_region_cursor("body", 15, index=1)
    session.send(keys.meta(";"))
    _assert_body_row(session, 1, "  (list :done)) ;")
    session.key("RET")
    _assert_cursor(session, 2, 0)
    session.save_buffer(str(day), _DAY_AFTER_0910)
    session.assert_file_bytes(str(day), _DAY_AFTER_0910)


def _scene_0915_docstring_and_block_comment(session):
    # Each opening parenthesis inserts its pair; a typed closer steps over it.
    for text, expected in (
        ("(", "()"),
        ("defun note ", "(defun note )"),
        ("(", "(defun note ())"),
    ):
        session.type(text)
        _wait_body_row(session, 2, expected)
    session.type(")")
    session.wait_for_region_cursor("body", 14, index=2)
    session.type(' "first')
    _wait_body_row(session, 2, '(defun note () "first)')
    # Inside the open string, RET keeps the previous line's indentation.
    session.key("RET")
    _wait_body_row(session, 3, ")")
    session.type("MIDDLE_DOCSTRING")
    _wait_body_row(session, 3, "MIDDLE_DOCSTRING)")
    session.key("RET")
    _wait_body_row(session, 4, ")")
    session.type('last"')
    _wait_body_row(session, 4, 'last")')
    session.type(")")
    session.wait_for_region_cursor("body", 6, index=4)
    session.key("RET")
    session.wait_for_region_cursor("body", 0, index=5)
    session.type("#| note")
    _wait_body_row(session, 5, "#| note")
    session.key("RET")
    session.wait_for_region_cursor("body", 0, index=6)
    session.type("BLOCK_COMMENT |#")
    _wait_body_row(session, 6, "BLOCK_COMMENT |#")
    _assert_word_color(session, "MIDDLE_DOCSTRING", "00cd00")
    _assert_word_color(session, "BLOCK_COMMENT", "7f7f7f")


def _scene_0920_indentation_keys(session, day):
    session.send(keys.ctrl("n"))
    session.send(keys.meta("m"))
    _assert_cursor(session, 7, 3)
    session.send(keys.meta("\\"))
    _assert_body_row(session, 7, "(day)")
    _assert_cursor(session, 7, 0)
    session.save_buffer(str(day), _DAY_AFTER_0920)
    session.assert_file_bytes(str(day), _DAY_AFTER_0920)


def _scene_0930_interrupt_evaluation(session, day, marker):
    # The screen cannot change during evaluation, so the evaluated form
    # creates MARKER to show that (loop) is running before C-g is sent.
    session.send(keys.meta(":"))
    session.wait_for_region_text("minibuffer", "Eval: ")
    session.type(
        f"(progn (close (open {_lisp_string(os.fspath(marker))}"
        " :direction :output :if-exists :supersede)) (loop))"
    )
    session.key("RET")
    session.wait_until(
        lambda _screen: marker.exists(), what="the evaluation start marker"
    )
    session.send(keys.ctrl("g"))
    _assert_minibuffer(session, "Evaluation interrupted")
    session.assert_file_bytes(str(day), _DAY_AFTER_0920)
    _assert_body_row(session, 7, "(day)")
    _quit(session, "09:30")


def _assert_sidebar_row(session, row, label):
    session.wait_until(
        lambda _screen: session.screen.lines()[row][:24] == label.ljust(24),
        what=f"file-tree row {row} to contain {label}",
    )
    session.assert_screen_text(label.ljust(24), match="starts_with", row=row)


def _selected_sidebar_row(session, label):
    return next(
        (
            row
            for row, line in enumerate(session.screen.lines()[:session.rows - 1])
            if label in line[:24] and session.screen.cell_attrs(row, 2)["reverse"]
        ),
        None,
    )


def _assert_selected(session, label, expected_row):
    session.wait_until(
        lambda _screen: _selected_sidebar_row(session, label) == expected_row,
        what=f"file-tree entry {label} to be selected on row {expected_row}",
    )
    session.assert_screen_text(label.ljust(24), match="starts_with", row=expected_row)
    session.assert_cell_attrs(expected_row, 2, {"reverse": True})


def _scene_1000_file_tree(session, binary, inbox):
    _launch(session, binary, [str(inbox)])
    session.wait_ready()
    session.send(keys.ctrl("x") + b"d")
    _assert_sidebar_row(session, 0, "r9-000.txt")
    height = session.rows - 1
    for index in range(_INBOX_ENTRIES):
        session.send(keys.ctrl("c") + b"n")
        last = index == _INBOX_ENTRIES - 1
        expected_row = height - 1 if last else min(index, height - 2)
        _assert_selected(session, f"r9-{index:03d}.txt", expected_row)
    _quit(session, "10:00")


def _scene_1030_typescript(session, binary):
    (
        directory, path, child_pid_file, wrapper_pid_file, exit_status_file,
        protocol_log, _stderr_file,
    ) = _supervised_server_fixture(
        ["typescript-language-server", "--stdio"], "main.ts", _TYPESCRIPT,
        "r9-typescript",
    )
    try:
        _launch(session, binary, [path])
        with scenario_preparation():
            session.wait_ready()
            _start_lsp(session)
            pid, wrapper_pid = _supervised_child_pid(
                session, child_pid_file, wrapper_pid_file,
            )
            _assert_typescript_server_running(session, pid, "lsp-start")
            _warm_up_typescript_server(session, pid)

        session.send(keys.ctrl("n") * 2 + keys.ctrl("e"))
        session.wait_for_region_cursor("body", len("targetV"), index=2)
        session.send(_C_M_I)
        session.wait_until(
            lambda _screen: session.region_contents("body")
            .splitlines()[3]
            .rstrip()
            == "targetValue",
            what="TypeScript completion popup to display targetValue",
        )
        session.assert_screen_text(
            "targetValue", region="body", index=3, strip_right=True
        )
        session.send(keys.ctrl("g"))
        _wait_body_row(session, 3, "targetValue;")

        _move_to_buffer_position(session, 1, 1)
        session.send(keys.meta("."))
        _assert_cursor(session, 0, len("const "))
        _assert_typescript_server_running(session, pid, "lsp-find-definition")

        session.extended_command("lsp-stop")
        session.wait_for_text("LSP stopped.")
        _assert_supervised_exit(session, exit_status_file, wrapper_pid, "0")
        _assert_server_request_responses(session, protocol_log, exit_status_file)
        _assert_loom_requests_answered(session, protocol_log)
        _scene_1100_buffer_list(session)
        _quit(session, "11:00")
    finally:
        directory.cleanup()


def _loom_request_responses(events):
    """Return each loom->server request with the count of responses to its ID."""
    requests = []
    latest_request = {}
    for event in events:
        message = event["message"]
        if "id" not in message:
            continue
        key = (type(message["id"]), message["id"])
        if event["direction"] == "loom->server" and "method" in message:
            request = {"id": message["id"], "method": message["method"], "responses": 0}
            requests.append(request)
            latest_request[key] = request
        elif (
            event["direction"] == "server->loom"
            and "method" not in message
            and ("result" in message or "error" in message)
            and key in latest_request
        ):
            latest_request[key]["responses"] += 1
    return requests


def _assert_loom_requests_answered(session, protocol_log):
    events = _protocol_events(protocol_log)
    requests = _loom_request_responses(events)
    methods = [request["method"] for request in requests]
    missing = [method for method in _REQUIRED_LOOM_REQUESTS if method not in methods]
    unanswered = [request for request in requests if request["responses"] != 1]
    sent = session.observe_external_state(
        "10:30 loom sent completion and definition requests", missing, []
    )
    answered = session.observe_external_state(
        "10:30 each loom request has exactly one response with its ID",
        unanswered,
        [],
    )
    server_methods = [
        request["method"] for request in _server_request_response_counts(events)
    ]
    session.observe_external_state(
        "10:30 server request methods", server_methods, purpose="precondition"
    )
    print(
        f"r9/daily 10:30: typescript-language-server sent {len(server_methods)} "
        f"server request(s); methods={server_methods!r}"
    )
    if sent is not True or answered is not True:
        raise AssertionError(
            f"10:30: missing loom requests {missing!r}; requests without exactly "
            f"one response {unanswered!r}; loom requests {methods!r}"
        )


def _scene_1100_buffer_list(session):
    session.send(keys.ctrl("x") + keys.ctrl("b"))
    session.wait_for_text("*Buffer List*")
    session.wait_for_text("  .   main.ts")
    row, _column = session.screen.find("  .   main.ts")
    session.assert_screen_text("  .   main.ts", match="contains", row=row)


def _scene_1400_git_commit(session, root, work, binary):
    _git(work, "add", "src/day.lisp")
    editor = _write_executable(
        root / "git-editor.sh", f'exec {shlex.quote(binary)} "$@"\n'
    )
    launcher = _write_executable(
        root / "git-commit.sh",
        f"cd {shlex.quote(os.fspath(work))}\n"
        "unset GIT_EDITOR\n"
        f"export EDITOR={shlex.quote(shlex.quote(editor))}\n"
        "exec git commit --quiet\n",
    )
    _launch(session, launcher, [])
    session.wait_ready()
    session.wait_for_region_text("body", "Please enter", index=1)
    message_path = work / ".git" / "COMMIT_EDITMSG"
    expected = f"{_COMMIT_SUBJECT}\n".encode() + message_path.read_bytes()
    session.type(f"{_COMMIT_SUBJECT}\n")
    session.save_buffer(str(message_path), expected)
    session.assert_file_bytes(str(message_path), expected)
    _quit(session, "14:00 git commit")
    session.assert_external_state(
        "14:00 commit subject", _git(work, "log", "-1", "--format=%s"), _COMMIT_SUBJECT
    )
    session.assert_external_state(
        "14:00 committed files",
        _git(work, "show", "--name-only", "--format=", "HEAD"),
        "src/day.lisp",
    )


def _scene_1500_query_replace(session, binary, todo):
    _launch(session, binary, [str(todo)])
    session.wait_ready()
    _wait_body_row(session, 0, "item one")
    session.send(keys.meta("%"))
    session.wait_for_region_text("minibuffer", "Query replace: ")
    session.type("item")
    session.key("RET")
    session.wait_for_region_text("minibuffer", "Query replace with: ")
    session.type("done")
    session.key("RET")
    session.wait_for_region_text("minibuffer", "Query replace: ")
    session.send(b"y")
    _wait_body_row(session, 0, "done one")
    session.send(b"n")
    session.send(b"!")
    _assert_minibuffer(session, "Replaced 3 occurrence(s)")
    for index, line in enumerate(_TODO_AFTER_1500.decode().splitlines()):
        _assert_body_row(session, index, line)


def _scene_1800_save_all_and_quit(session, day, todo):
    session.send(keys.ctrl("x") + keys.ctrl("f"))
    session.wait_for_region_text("minibuffer", "Find file: ")
    session.type(str(day))
    session.key("RET")
    _wait_body_row(session, 0, "(defun day ()")
    session.type(";; evening review")
    session.key("RET")
    _wait_body_row(session, 0, ";; evening review")
    _wait_body_row(session, 1, "(defun day ()")
    session.send(keys.ctrl("x") + b"s")
    session.wait_for_region_text("minibuffer", "? (y, n, !, q, C-g)")
    session.send(b"!")
    session.wait_for_prompted_file(str(todo), _TODO_AFTER_1500, "Saved 2 file(s)")
    session.assert_file_bytes(str(todo), _TODO_AFTER_1500)
    session.assert_file_bytes(str(day), _DAY_AFTER_1800)
    output, code = session.quit()
    session.assert_external_state("18:00 exit status after C-x C-c", code, 0)
    if code != 0:
        raise AssertionError(f"18:00: loom exited with {code}: {output!r}")


@scenario(
    "r9/daily",
    commands=[
        "list-recoverable-files",
        "recover-list-visit",
        "project-find-file",
        "indent-for-tab-command",
        "forward-slurp-sexp",
        "comment-line",
        "newline",
        "save-buffer",
        "back-to-indentation",
        "delete-horizontal-space",
        "eval-expression",
        "toggle-file-tree",
        "file-tree-select-next",
        "lsp-start",
        "lsp-completion-at-point",
        "lsp-find-definition",
        "lsp-stop",
        "list-buffers",
        "save-buffers-kill-terminal",
        "search-query-replace",
        "save-some-buffers",
    ],
)
@r9_scenario
def r9_daily(binary):
    with tempfile.TemporaryDirectory(prefix="loom-e2e-r9-") as directory:
        root = Path(directory).resolve()
        work = _make_project(root)
        inbox = _make_inbox(root)
        a_lisp = work / "a.lisp"
        day = work / "src" / "day.lisp"
        todo = work / "todo.txt"
        with Session(binary, [str(a_lisp)], columns=_COLUMNS) as session:
            _scene_evening_sighup(session, binary, a_lisp)
            _scene_0900_recover(session, binary, a_lisp)
            _scene_0905_project_file(session, binary, a_lisp)
            _scene_0910_lisp_keys(session, day)
            _scene_0915_docstring_and_block_comment(session)
            _scene_0920_indentation_keys(session, day)
            _scene_0930_interrupt_evaluation(
                session, day, root / "evaluation-started"
            )
            _scene_1000_file_tree(session, binary, inbox)
            _scene_1030_typescript(session, binary)
            _scene_1400_git_commit(session, root, work, binary)
            _scene_1500_query_replace(session, binary, todo)
            _scene_1800_save_all_and_quit(session, day, todo)
