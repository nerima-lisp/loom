"""Read path ledger S-expressions from the repository's test directories."""

from pathlib import Path


_PATH_FIELDS = {
    "commands",
    "entry",
    "id",
    "lane",
    "observe",
    "outcome",
    "rule",
    "scenario",
    "state",
}
_REQUIRED_PATH_FIELDS = _PATH_FIELDS - {"lane"}
_EXCLUDE_FIELDS = {"evidence", "id", "reason"}


class PathLedgerError(ValueError):
    """An S-expression or path ledger record is malformed."""


class _Keyword:
    def __init__(self, name):
        self.name = name


class _Symbol:
    def __init__(self, name):
        self.name = name


class _List(list):
    def __init__(self, items, line, column):
        super().__init__(items)
        self.line = line
        self.column = column


class _Reader:
    def __init__(self, text, source):
        self.text = text
        self.source = source
        self.offset = 0
        self.line = 1
        self.column = 1

    def read_all(self):
        forms = []
        while True:
            self._skip_space_and_comments()
            if self.offset == len(self.text):
                return forms
            forms.append(self._read_form())

    def _advance(self):
        character = self.text[self.offset]
        self.offset += 1
        if character == "\n":
            self.line += 1
            self.column = 1
        else:
            self.column += 1
        return character

    def _skip_space_and_comments(self):
        while self.offset < len(self.text):
            character = self.text[self.offset]
            if character.isspace():
                self._advance()
            elif character == ";":
                while self.offset < len(self.text) and self._advance() != "\n":
                    pass
            else:
                return

    def _read_form(self):
        self._skip_space_and_comments()
        if self.offset == len(self.text):
            raise self._error("expected an S-expression")

        character = self.text[self.offset]
        if character == "(":
            return self._read_list()
        if character == ")":
            raise self._error("unexpected ')'")
        if character == '"':
            return self._read_string()
        return self._read_atom()

    def _read_list(self):
        line, column = self.line, self.column
        self._advance()
        items = []
        while True:
            self._skip_space_and_comments()
            if self.offset == len(self.text):
                raise self._error("unterminated list", line, column)
            if self.text[self.offset] == ")":
                self._advance()
                return _List(items, line, column)
            items.append(self._read_form())

    def _read_string(self):
        line, column = self.line, self.column
        self._advance()
        characters = []
        while self.offset < len(self.text):
            character = self._advance()
            if character == '"':
                return "".join(characters)
            if character == "\\":
                if self.offset == len(self.text):
                    raise self._error("unterminated escape in string", line, column)
                characters.append(self._advance())
            else:
                characters.append(character)
        raise self._error("unterminated string", line, column)

    def _read_atom(self):
        line, column = self.line, self.column
        start = self.offset
        while self.offset < len(self.text):
            character = self.text[self.offset]
            if character.isspace() or character in "();":
                break
            self._advance()
        token = self.text[start : self.offset]
        if not token:
            raise self._error("expected an atom", line, column)
        if token.startswith(":"):
            if len(token) == 1:
                raise self._error("empty keyword", line, column)
            return _Keyword(token[1:])
        return _Symbol(token)

    def _error(self, message, line=None, column=None):
        return PathLedgerError(
            f"{self.source}:{line or self.line}:{column or self.column}: {message}"
        )


def _location(source, form):
    return f"{source}:{form.line}:{form.column}"


def _keyword_name(value):
    if isinstance(value, _Keyword):
        return value.name.lower()
    return None


def _parse_plist(items, source, form, offset=0):
    pairs = items[offset:]
    if len(pairs) % 2:
        raise PathLedgerError(
            f"{_location(source, form)}: plist has a key without a value"
        )

    fields = {}
    for index in range(0, len(pairs), 2):
        key = pairs[index]
        name = _keyword_name(key)
        if name is None:
            raise PathLedgerError(
                f"{_location(source, form)}: plist key {key!r} is not a keyword"
            )
        if name in fields:
            raise PathLedgerError(
                f"{_location(source, form)}: duplicate plist key :{name}"
            )
        fields[name] = pairs[index + 1]
    return fields


def _require_string(fields, field, source, form, *, allow_empty=False):
    value = fields[field]
    if not isinstance(value, str) or (not allow_empty and not value):
        expectation = "a string" if allow_empty else "a non-empty string"
        raise PathLedgerError(
            f"{_location(source, form)}: :{field} must be {expectation}"
        )
    return value


def _normalize_names(value, field, source, form):
    if not isinstance(value, _List):
        raise PathLedgerError(
            f"{_location(source, form)}: :{field} must be a list"
        )
    names = []
    for item in value:
        if isinstance(item, _Keyword):
            name = item.name.lower()
        elif isinstance(item, _Symbol):
            name = item.name.lower()
        elif isinstance(item, str):
            name = item
        else:
            raise PathLedgerError(
                f"{_location(source, form)}: :{field} items must be names"
            )
        if not name:
            raise PathLedgerError(
                f"{_location(source, form)}: :{field} contains an empty name"
            )
        names.append(name)
    return names


def _parse_path(form, source):
    if not isinstance(form, _List):
        raise PathLedgerError(f"{source}: expected a path plist")
    fields = _parse_plist(form, source, form)
    unknown = fields.keys() - _PATH_FIELDS
    missing = _REQUIRED_PATH_FIELDS - fields.keys()
    if unknown:
        names = ", ".join(f":{name}" for name in sorted(unknown))
        raise PathLedgerError(f"{_location(source, form)}: unknown path keys: {names}")
    if missing:
        names = ", ".join(f":{name}" for name in sorted(missing))
        raise PathLedgerError(f"{_location(source, form)}: missing path keys: {names}")

    path_id = _require_string(fields, "id", source, form)
    rule = fields["rule"]
    if isinstance(rule, _Keyword):
        rule = rule.name.lower()
    elif isinstance(rule, str):
        rule = rule.lower()
    else:
        rule = None
    if rule not in {f"r{number}" for number in range(1, 9)}:
        raise PathLedgerError(
            f"{_location(source, form)}: :rule must be one of :r1 through :r8"
        )

    lane = (
        _require_string(fields, "lane", source, form, allow_empty=True)
        if "lane" in fields
        else ""
    )
    return {
        "id": path_id,
        "commands": _normalize_names(fields["commands"], "commands", source, form),
        "rule": rule,
        "entry": _require_string(fields, "entry", source, form),
        "state": _require_string(fields, "state", source, form),
        "outcome": _require_string(fields, "outcome", source, form),
        "observe": _normalize_names(fields["observe"], "observe", source, form),
        "scenario": _require_string(fields, "scenario", source, form),
        "lane": lane,
    }


def _parse_exclusion(form, source):
    fields = _parse_plist(form, source, form, offset=1)
    unknown = fields.keys() - _EXCLUDE_FIELDS
    missing = _EXCLUDE_FIELDS - fields.keys()
    if unknown:
        names = ", ".join(f":{name}" for name in sorted(unknown))
        raise PathLedgerError(
            f"{_location(source, form)}: unknown exclusion keys: {names}"
        )
    if missing:
        names = ", ".join(f":{name}" for name in sorted(missing))
        raise PathLedgerError(
            f"{_location(source, form)}: missing exclusion keys: {names}"
        )
    return {
        "id": _require_string(fields, "id", source, form),
        "reason": _require_string(fields, "reason", source, form),
        "evidence": _require_string(fields, "evidence", source, form),
    }


def _ledger_forms(forms):
    if (
        len(forms) == 1
        and isinstance(forms[0], _List)
        and (not forms[0] or all(isinstance(item, _List) for item in forms[0]))
    ):
        return list(forms[0])
    return forms


def _ledger_files(repo_root):
    files = []
    root_ledger = repo_root / "t" / "paths.sexp"
    if root_ledger.is_file():
        files.append(root_ledger)
    package_root = repo_root / "packages"
    if package_root.is_dir():
        files.extend(sorted(package_root.glob("**/t/paths.sexp")))
    return files


def read_path_ledgers(repo_root):
    """Return normalized path records and exclusions from all ledger files."""
    root = Path(repo_root).resolve()
    paths = []
    exclusions = []
    declared_ids = {}

    for path in _ledger_files(root):
        source = path.relative_to(root).as_posix()
        reader = _Reader(path.read_text(encoding="utf-8"), source)
        forms = _ledger_forms(reader.read_all())
        for form in forms:
            if not isinstance(form, _List):
                raise PathLedgerError(f"{source}: expected a path or exclusion plist")
            if form and _keyword_name(form[0]) == "exclude":
                record = _parse_exclusion(form, source)
                exclusions.append(record)
            else:
                record = _parse_path(form, source)
                paths.append(record)

            record_id = record["id"]
            location = _location(source, form)
            if record_id in declared_ids:
                previous = declared_ids[record_id]
                raise PathLedgerError(
                    f"{location}: duplicate id {record_id!r}; first declared at {previous}"
                )
            declared_ids[record_id] = location

    return paths, exclusions
