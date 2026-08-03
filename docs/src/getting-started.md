# Getting started

## Run without installing

With [Nix](https://nixos.org/download) (flakes enabled):

```sh
nix run github:nerima-lisp/loom
```

## Install

```sh
nix profile install github:nerima-lisp/loom
loom
```

Consumers inside the nerima-lisp org pin a release tag rather than following
the default branch:

```nix
# flake.nix
inputs.loom = {
  url = "github:nerima-lisp/loom/v0.1.0";
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
C-c` quits. See
[`install-default-keybindings`](https://github.com/nerima-lisp/loom/blob/main/src/application/commands-keybindings.lisp)
for the full keybinding set.

## Build from source

loom builds with [SBCL](http://www.sbcl.org/) and ASDF. The supported and
tested path is Nix:

```sh
git clone https://github.com/nerima-lisp/loom
cd loom
nix build            # produces ./result/bin/loom
nix flake check      # tests + formatting + docs, the same gate CI uses
nix develop          # dev shell with SBCL + cl-weave
```

Inside `nix develop`, load the system into a REPL:

```lisp
(asdf:load-system "loom")
(loom:main)
```
