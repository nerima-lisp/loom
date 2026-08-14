# Development

loom is built and checked with Nix flakes. The repository's `flake.nix` is the
source of truth for the package, development shell, and checks.

## Development shell

Enter the shell before running local Common Lisp commands:

```sh
nix develop
```

The shell provides SBCL, ASDF dependencies, and the test runner. The source
tree is organized by shared editor layers and feature packages; see the
[architecture](../reference/architecture.md) page for the composition
boundaries.

Nix pins the library revisions in `flake.lock`, while `loom.asd` remains
versionless. When upgrading a library, inspect its ASDF `:depends-on` list and
keep the corresponding sibling inputs explicit in `flake.nix`; this keeps the
development shell, package build, and test system on the same dependency
graph.

It also provides `cl-weave` for the test DSL and `paredit` for structural
Common Lisp inspection and editing. The flake's `paredit-lint` check parses the
Lisp source set before packaging, so the same structural syntax gate is
available locally and in CI.

## Verification

Run the focused commands directly when iterating:

```sh
nix build
nix develop -c sbcl --script run-tests.lisp
nix fmt -- --ci
paredit inspect workspace --output json .
```

`loom/test` loads the Lisp unit and integration tiers declared in `loom.asd` in
serial order. `t/unit/` verifies pure domain and application behavior, while
`t/integration/` verifies package boundaries and external-system seams. The
executable tier in `t/e2e/` is a separate Unix PTY suite run against the built
binary:

```sh
LOOM_BINARY="$PWD/result/bin/loom" python3 t/e2e/loom-test.py
```

The ordinary test process has a 600-second outer timeout and each cl-weave
example has a 40-second timeout. Coverage has a 1,800-second outer timeout;
the PTY suite gives each interaction 10 seconds. These limits are part of the
development contract and should be changed only with a measured reason.

Run the full CI-equivalent check, including the strict MkDocs build, with:

```sh
nix flake check --all-systems --print-build-logs
```

## Coverage

Coverage is generated outside the checkout:

```sh
LOOM_COVERAGE_DIR=/tmp/loom-coverage nix develop -c sbcl --script scripts/coverage.lisp
```

The cl-weave runner covers Loom's `src/` and `packages/` trees and writes
`coverage.data` plus the HTML report under the selected coverage directory.
It rejects a no-test run and an empty source-expression selection. Record
SB-COVER's expression and branch totals separately; branch coverage does not
establish full expression coverage. SB-COVER is process-local, so top-level
declarations and the child-process-only `loom:main` path can remain unexecuted
in the report. Those forms are reported rather than hidden.

## REPL workflow

Inside the development shell, load the system into a REPL:

```lisp
(asdf:load-system "loom")
(loom:main)
```

The test system can also be loaded from a REPL with
`(asdf:load-system "loom/test")`; its public runner is
`loom/test:run-tests`.

## Concurrency benchmark

The benchmark compares synchronous directory listing with the bounded
file-tree prefetch and render-lane drain path:

```sh
nix develop -c sbcl --script scripts/benchmark-concurrency.lisp
```

It reports timings, accepted tasks, and derived speedup. The benchmark is
observational and does not define a performance target.
