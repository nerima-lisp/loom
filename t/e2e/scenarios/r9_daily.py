"""R9: one working day as one scenario over loom processes started in turn.

Every process shares the session's scratch HOME. Each scene observes its
effect before the next path command runs, so the path report can attribute
an observation to every command of r9:daily.
"""

import os
import shlex
import subprocess
import tempfile
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
        _scene_1100_buffer_list(session)
        _quit(session, "11:00")
    finally:
        directory.cleanup()


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
