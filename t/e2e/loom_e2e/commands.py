"""Parse the registered command-spec names out of the Lisp source, so the
runner can report scenario coverage against the full catalogue without
duplicating it by hand."""

import re
from pathlib import Path

_NAMED_SPEC = re.compile(r'\(command-spec\s+"([a-zA-Z0-9-]+)"')
_NIL_SPEC = re.compile(r'\(command-spec\s+nil\b')


def parse_command_names(repo_root):
    """Return the sorted, deduplicated command names declared across
    src/application/command-definitions*.lisp, with the single nil-named
    entry (M-x itself) counted as "execute-extended-command"."""
    names = set()
    saw_nil_entry = False
    directory = Path(repo_root) / "src" / "application"
    for path in sorted(directory.glob("command-definitions*.lisp")):
        text = path.read_text()
        names.update(_NAMED_SPEC.findall(text))
        if _NIL_SPEC.search(text):
            saw_nil_entry = True
    if saw_nil_entry:
        names.add("execute-extended-command")
    return sorted(names)
