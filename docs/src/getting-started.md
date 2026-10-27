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

Release archives contain the complete Nix runtime closure, rather than a
standalone executable. See the
[archive installation instructions](https://github.com/nerima-lisp/loom/blob/main/INSTALL.md)
for checksum verification, import, and profile installation.

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

`C-x d` toggles the file-tree sidebar; `C-x C-f` prompts for a path and opens
it in the selected window; `C-x C-s` saves the selected buffer; `C-x C-c`
quits. Press `M-x` to search the command catalogue by name.

`C-x r` provides named registers, `C-x (` and `C-x )` record keyboard macros,
and `C-u`, `M-0` … `M-9`, and `M--` apply numeric prefixes to the next command.

## Everyday commands

- Search forward with `C-s` and backward with `C-r`. Use `C-M-s` and `C-M-r`
  for regular-expression search.
- Set a region, then use `C-w` to kill it or `M-w` to copy it to the kill ring.
  `C-y` inserts the most recent entry; `M-y` cycles through earlier entries.
- Run `M-x clipboard-yank` to insert text from the system clipboard when a
  clipboard provider is available. If it is unavailable, loom uses the kill
  ring.
- Split below with `C-x 2`, split right with `C-x 3`, switch windows with
  `C-x o`, delete the selected window with `C-x 0`, or keep only the selected
  window with `C-x 1`.

## Language modes and sessions

Opening a file selects a major mode from its path when a matching mode is
registered. Run `M-x set-major-mode` to choose a mode for the selected buffer.

Run `C-x r S` to save the current session to a path, or `M-x load-session` to
restore one from a path.

## Language server support

Run `M-x lsp-start` in a file-backed buffer to start a language server. loom
looks for the nearest project-local `.loom-lsp` file and presents any discovered
command for review; type `yes` at the confirmation prompt to run it. Without a
discovered command, enter the server command at the prompt.

After starting a server, run `M-x lsp-diagnostics` to refresh and display
diagnostics. Use `C-M-i` for completion, `M-.` to jump to a definition, and
`M-,` to return to the previous location. Run `M-x lsp-hover-at-point` to show
hover information when the server supports it. References, rename, and LSP
formatting are not implemented. The [core concepts guide](guide/core-concepts.md)
describes these workflows and the separate external formatter command.

## Build from source

loom builds with [SBCL](http://www.sbcl.org/) and ASDF. SBCL is the supported
implementation: the executable image uses SBCL's native command-line and image
dumping interfaces, while the editor logic remains testable independently of
that binary entry point. The supported build path is Nix. See the
[development guide](project/development.md) for source builds, the test suite,
PTY checks, coverage, and the REPL workflow.
