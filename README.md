# loom

[![CI](https://github.com/nerima-lisp/loom/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/loom/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-0a7a5a)](https://nerima-lisp.github.io/loom/)

`loom` is a terminal text editor for SBCL with Emacs-style keybindings. It
combines raw-mode editing, window management, interactive PTY terminal sessions,
shell commands, Git status, diff, and staging commands, code-formatting integration,
auto-save, feature slices, and a bounded concurrent file-tree runtime.

## Quick Start

With [Nix](https://nixos.org/download) and flakes enabled:

```sh
nix run github:nerima-lisp/loom -- path/to/file.lisp
```

Omit the path to start with the current directory as the file-tree root.
Use `M-x terminal` for a PTY-backed child process and `M-x auto-save-mode` to
enable sidecar auto-save for modified file-backed buffers. The
[core concepts guide](docs/src/guide/core-concepts.md) covers search, the
kill ring and clipboard, windows, language modes, sessions, and LSP.

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

For release archives, follow the [archive installation instructions](INSTALL.md).
Archives include the Nix runtime closure and require Nix; they are not standalone
executables.

## Documentation

- [Getting started](https://nerima-lisp.github.io/loom/getting-started/)
- [API reference](https://nerima-lisp.github.io/loom/reference/api/)
- [Architecture](https://nerima-lisp.github.io/loom/reference/architecture/)
- [Roadmap](https://nerima-lisp.github.io/loom/project/roadmap/)
- [Development](https://nerima-lisp.github.io/loom/project/development/)

The public export declarations are maintained in
[`src/package-exports.lisp`](src/package-exports.lisp). The current command catalogue is in
feature-owned command specification files, registered through
[`packages/core/command/src/command-registry-registration.lisp`](packages/core/command/src/command-registry-registration.lisp).
Default Emacs-style bindings are declared in
[`packages/core/command/src/application-commands-emacs-defaults.lisp`](packages/core/command/src/application-commands-emacs-defaults.lisp).

## Development

```sh
nix build
nix develop
nix develop -c loom-test
nix fmt -- --ci
nix run .#e2e
nix build .#docs
nix flake check --print-build-logs
```

See the [development guide](docs/src/project/development.md) for check details,
PTY sandbox limits, coverage, and benchmarking.

## Contributing

Please read the [nerima-lisp contribution guide](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
and the [package standard](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md).

## Support

Open an [issue](https://github.com/nerima-lisp/loom/issues) or consult the
[nerima-lisp support guide](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).

## License

MIT. See [LICENSE](LICENSE).
