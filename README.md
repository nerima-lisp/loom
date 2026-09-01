# loom

[![CI](https://github.com/nerima-lisp/loom/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/loom/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-0a7a5a)](https://nerima-lisp.github.io/loom/)

`loom` is a terminal text editor for SBCL with Emacs-style keybindings. It
combines raw-mode editing, window management, interactive PTY terminal sessions,
shell commands, Git status, diff, and staging commands, code-formatting integration,
auto-save, feature slices, and a bounded concurrent file-tree runtime.

The full documentation is published at
[nerima-lisp.github.io/loom](https://nerima-lisp.github.io/loom/).

## Quick Start

With [Nix](https://nixos.org/download) and flakes enabled:

```sh
nix run github:nerima-lisp/loom -- path/to/file.lisp
```

Omit the path to start with the current directory as the file-tree root.
Use `M-x terminal` for a PTY-backed child process and `M-x auto-save-mode` to
enable sidecar auto-save for modified file-backed buffers.

## Install

Pin a reviewed commit when adding loom to another flake:

```nix
inputs.loom = {
  url = "github:nerima-lisp/loom/<reviewed-commit>";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

For a profile installation from the default branch, run `nix profile install
github:nerima-lisp/loom`.

## Documentation

- [Getting started](https://nerima-lisp.github.io/loom/getting-started/)
- [API reference](https://nerima-lisp.github.io/loom/reference/api/)
- [Architecture](https://nerima-lisp.github.io/loom/reference/architecture/)
- [Roadmap](https://nerima-lisp.github.io/loom/project/roadmap/)
- [Development](https://nerima-lisp.github.io/loom/project/development/)

The complete public export list is maintained in
[`src/package.lisp`](src/package.lisp). The current command catalogue is in
[`src/application/command-definitions.lisp`](src/application/command-definitions.lisp),
and M-x lookup is implemented by
[`src/application/command-registry.lisp`](src/application/command-registry.lisp).

## Development

```sh
nix develop
nix build
nix develop -c loom-test
nix flake check --print-build-logs
nix fmt -- --ci

# Release-oriented checks
LOOM_COVERAGE_DIR=/tmp/loom-coverage nix develop -c loom-coverage
LOOM_BINARY="$PWD/result/bin/loom" python3 t/e2e/loom-test.py
```

Coverage can be promoted to a quality gate with optional percentage thresholds:

```sh
LOOM_COVERAGE_MIN_EXPRESSIONS=95 \
LOOM_COVERAGE_MIN_BRANCHES=92 \
LOOM_COVERAGE_DIR=/tmp/loom-coverage nix develop -c loom-coverage
```

Thresholds accept values from 0 to 100. The command fails when a configured
threshold is not met, so the gate can be raised incrementally toward 100%.

The Nix coverage output is a report directory, not an executable. Build it
with `nix build .#coverage` (or run `nix flake check`); use the development
command above when the report should be written to a local directory. Inside
an interactive shell, `test` and `coverage` remain available as convenience
aliases; `loom-test` and `loom-coverage` are the portable executable commands.

The [development guide](docs/src/project/development.md) covers the unit and
integration suite, PTY checks, coverage, and the concurrency benchmark.

## Contributing

Please read the [nerima-lisp contribution guide](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
and the [package standard](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md).

## Support

Open an [issue](https://github.com/nerima-lisp/loom/issues) or consult the
[nerima-lisp support guide](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).

## License

MIT. See [LICENSE](LICENSE).
