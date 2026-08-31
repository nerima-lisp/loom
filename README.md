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
nix develop -c sbcl --script run-tests.lisp
nix flake check --print-build-logs
nix fmt -- --ci
```

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
