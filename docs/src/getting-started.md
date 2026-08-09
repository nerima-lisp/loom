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

Consumers inside the nerima-lisp org pin a reviewed commit or an existing
release tag rather than following the default branch. Replace
`<reviewed-ref>` with the ref selected for the deployment:

```nix
# flake.nix
inputs.loom = {
  url = "github:nerima-lisp/loom/<reviewed-ref>";
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
nix fmt -- --ci      # verify Nix formatting without rewriting files
nix flake check --print-build-logs  # tests + binary + formatting + strict docs
nix develop          # dev shell with SBCL + cl-weave
nix develop -c sbcl --script run-tests.lisp
LOOM_BINARY="$PWD/result/bin/loom" python3 t/e2e/loom-test.py
LOOM_COVERAGE_DIR=/tmp/loom-coverage nix develop -c sbcl --script scripts/coverage.lisp
```

The integrated suite currently reports 427 passed tests with no skips, todos,
failures, or errors. `t/unit/` covers domain and boundary behavior,
`t/integration/` covers command and disk-backed editor flows, and the suite
includes an internal real-PTY smoke test. The separate `t/e2e/loom-test.py`
runner requires the `nix build` artifact and validates the built executable as
an external PTY process.

Named registers are available through `C-x r s`, `C-x r i`, `C-x r SPC`, and
`C-x r j`; keyboard macros use `C-x (`, `C-x )`, and `C-x e`.
`C-u`, `M-0` … `M-9`, and `M--` apply numeric prefixes to the next command.

The coverage command reports the measured SB-COVER expression and branch
totals separately. A branch result does not establish full expression
coverage; inspect the generated report for uncovered forms. SB-COVER is
process-local, so top-level declarations and the child-process-only
`loom:main` path can remain unexecuted in the report; these forms are exposed
instead of being excluded from the measurement.

Inside `nix develop`, load the system into a REPL:

```lisp
(asdf:load-system "loom")
(loom:main)
```
