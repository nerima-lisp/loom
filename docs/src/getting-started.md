# Getting started

## Run without installing

With [Nix](https://nixos.org/download) and flakes enabled:

```sh
nix run github:nerima-lisp/loom
```

Pass a file or directory after `--` to open a specific starting path:

```sh
nix run github:nerima-lisp/loom -- path/to/file.lisp
```

## Install

```sh
nix profile install github:nerima-lisp/loom
loom
```

Consumers inside the nerima-lisp organization should pin a reviewed commit or
release tag when one is available, rather than following the default branch:

```nix
# flake.nix
inputs.loom = {
  url = "github:nerima-lisp/loom/<reviewed-commit>";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

## First steps

Start loom with an optional starting directory for the file-tree sidebar:

```sh
loom
loom ~/project
```

`C-x C-t` toggles the file-tree sidebar; `C-x C-f` prompts for a path and
opens it in the selected window; `C-x C-s` saves the selected buffer; `C-x
C-c` quits. The full command catalogue is maintained in
[`src/application/command-definitions.lisp`](https://github.com/nerima-lisp/loom/blob/main/src/application/command-definitions.lisp).

`C-x r` provides named registers, `C-x (` and `C-x )` record keyboard macros,
and `C-u`, `M-0` … `M-9`, and `M--` apply numeric prefixes to the next command.

## Build from source

loom builds with [SBCL](http://www.sbcl.org/) and ASDF. SBCL is the supported
implementation: the executable image uses SBCL's native command-line and image
dumping interfaces, while the editor logic remains testable independently of
that binary entry point. The supported build path is Nix. See the
[development guide](project/development.md) for source builds, the test suite,
PTY checks, coverage, and the REPL workflow.
