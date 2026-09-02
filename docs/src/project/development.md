# Development

loom is built and checked with Nix flakes. The repository's `flake.nix` is the
source of truth for the package, development shell, and checks.

## Development shell

Enter the shell before running local Common Lisp commands:

```sh
nix develop -c loom-test
nix develop -c loom-coverage
```

The shell also provides `test` and `coverage` as interactive aliases. Use the
`loom-*` commands for scripts and CI because they are executable commands and
work with `nix develop -c`.

The shell provides SBCL, ASDF dependencies, the test runner, and the MkDocs
Material toolchain. The source tree is organized by shared editor layers and
feature packages; see the
[architecture](../reference/architecture.md) page for the composition
boundaries.

Nix pins the library revisions in `flake.lock`, while `loom.asd` declares the
package version consumed by ASDF and the executable. When upgrading a library,
inspect its ASDF `:depends-on` list and
keep the corresponding sibling inputs explicit in `flake.nix`; this keeps the
development shell, package build, and test system on the same dependency
graph.

Only release-tagged sibling packages are admitted to the production dependency
graph. A newer repository is evaluated separately, but remains out of `flake.nix`
until it publishes a release tag and its API is covered by a focused integration
test; this keeps upgrades reproducible and prevents an unstable package from
entering the build through a transitive dependency.

It also provides `cl-weave` for the test DSL and `paredit` for structural
Common Lisp inspection and editing. The flake's `paredit-lint` check parses the
Lisp source set before packaging, so the same structural syntax gate is
available locally and in CI.

The test system declares every package used directly by its tests, including
the `cl-weave` generators and package-specific integration helpers. Keep these
ASDF edges explicit when rearranging implementation dependencies; tests should
not become loadable only because an unrelated production dependency currently
re-exports them.

## Common Lisp authoring policy

Use `defmacro` for repetitive declarations whose variation is known at
compile time: command families, command-spec catalogs, codecs, and other
small declarative tables are generated from one readable source form. Keep
runtime state transitions and domain calculations as ordinary functions so
they remain directly callable, testable, and independent of macro expansion.
Do not introduce an adapter merely to rename or forward an operation already
provided by a `nerima-lisp` package; depend on that package at the owning
boundary instead.

Property and fuzz tests use `cl-weave` generators when an invariant spans a
large input space. Example-based `it-each` cases remain appropriate for
protocol tables and boundary contracts, while `it-property` and `it-fuzz`
should exercise pure data transformations and CPS callbacks. A green
coverage report does not justify adding tests for unreachable macroexpansion
forms or `defstruct` default initializers: report those SB-COVER limitations
separately and maximize executable expression and branch coverage.

## Worktree workflow

The `main` branch is the integration point for completed work. Before
integrating a worktree, inspect its staged, unstaged, and untracked files and
compare its commits with `main`. Integrate only a complete work unit, then
remove the worktree after confirming that `main` contains it. Empty or
duplicate worktrees should be removed without creating an additional branch.

For a detached worktree containing unstaged changes, first run the focused or
full test command, review the diff, and commit the complete work unit in that
worktree. Then fast-forward `main` to that commit, verify the commit and clean
status from a main checkout, and remove the worktree with `git worktree
remove`. Do not delete a worktree until its commit is reachable from `main`.

## Verification

Run the focused commands directly when iterating:

```sh
nix build
nix develop -c sbcl --script run-tests.lisp
nix fmt -- --ci
paredit inspect workspace --output json .
```

For a complete source lint, pass Lisp files in bounded batches (or one file at
a time) when the shell would otherwise exceed the operating system's argument
limit:

```sh
rg --files src packages t -g '*.lisp' | sort
paredit inspect lint --output json path/to/file.lisp
```

`loom/test` loads the Lisp unit and integration tiers declared in `loom.asd` in
serial order. `t/unit/` verifies pure domain and application behavior, while
`t/integration/` verifies package boundaries and external-system seams. The
executable tier in `t/e2e/` is a separate Unix PTY suite run against the built
binary:

```sh
LOOM_BINARY="$PWD/result/bin/loom" python3 t/e2e/loom-test.py
```

The ordinary test process has a 1,800-second outer timeout and cl-weave's test
runner gives each example a 40-second timeout. Coverage has a 1,800-second
outer timeout;
the PTY suite gives each interaction 10 seconds. These limits are part of the
development contract and should be changed only with a measured reason.

Feature code that invokes an external command uses `run-shell-command`, which
has a 30-second default timeout. Callers can pass `:timeout-seconds` when a
command needs a different bounded duration; a timeout is returned as a
structured result with exit code 124.

Git commands use `cl-vcs-kit` directly with an argv list and structured
process results; `cl-resilience-kit` adds a cooperative deadline around each
operation. Git paths are not assembled into shell command strings.

Run the full CI-equivalent check, including the test suite, package build,
formatter, paredit structural syntax check, coverage, and the strict MkDocs
build, with:

```sh
nix flake check --all-systems --print-build-logs
```

To build the documentation independently, pass the repository's MkDocs
configuration explicitly:

```sh
nix develop -c mkdocs build --strict -f docs/mkdocs.yml
```

`checks.default` and `checks.coverage` both build inside the same PTY-less Nix
sandbox, so both set `LOOM_SANDBOXED_CHECK`; tests that spawn a real child
process over a PTY or a pipe skip visibly (in cl-weave's "N skipped" count)
rather than hanging inside that sandbox. `apps.test` and the development
shell's `test` alias do not set it, so the same tests run for real outside Nix
builds.

## Coverage

Coverage is generated outside the checkout:

```sh
LOOM_COVERAGE_DIR=/tmp/loom-coverage nix develop -c sbcl --script scripts/coverage.lisp
```

The flake's `coverage` output is a report directory rather than a runnable
program. Use `nix build .#coverage` to materialize it in the Nix store, or use
the command above to choose a local output directory.

The cl-weave runner covers Loom's `src/` and `packages/` trees and writes
`coverage.data` plus the HTML report under the selected coverage directory.
It rejects a no-test run and an empty source-expression selection. Record
SB-COVER's expression and branch totals separately; branch coverage does not
establish full expression coverage. SB-COVER is process-local, so top-level
declarations and the child-process-only `loom:main` path can remain unexecuted
in the report. Those forms are reported rather than hidden.

Set `LOOM_COVERAGE_MIN_EXPRESSIONS` and/or `LOOM_COVERAGE_MIN_BRANCHES` to make
the corresponding percentage a failing quality gate. Values must be between 0
and 100; raise them incrementally as executable coverage improves toward 100%.

### Coverage debt triage

Treat an uncovered executable expression or branch as coverage debt. First map
the uncovered location back to its source form, then add a higher-level test
that exercises the user-visible behavior. Do not add tests solely to evaluate
`defstruct` slot declarations, type declarations, default forms, or other
top-level forms that SB-COVER instruments but that do not represent a runtime
decision in Loom. Do not lower a threshold or alter instrumentation to make a
report green; document a genuine harness limitation and keep the expression
and branch totals visible instead.

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
