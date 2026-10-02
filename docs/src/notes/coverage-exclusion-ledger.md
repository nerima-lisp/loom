# Coverage exclusion ledger

This ledger records only branches introduced by an external macro expansion.
Branches in Loom source functions remain in the coverage denominator and must
be covered by tests.

## Baseline

The reproducible command is:

```text
nix develop -c timeout --signal=TERM --kill-after=15s 1800s \
  sbcl --script scripts/coverage.lisp
```

The baseline from CI run 37049435388 is:

```text
COVERAGE-EXPRESSIONS 19779/20684 (95.62%)
COVERAGE-BRANCHES 1876/2000 (93.80%)
```

The local macOS reproduction was also attempted with the same outer timeout;
it stopped during the Nix dependency build before the runner emitted markers.
The CI result is the reproducible baseline because it completed the canonical
Linux flake check.

## Exclusions

No exclusion is accepted in this initial ledger. Each future entry must name
the macro, the generated branch shape, the source location reported by the
coverage tool, the reason it cannot be exercised by Loom, and the exact
reproduction command. A missing entry is a coverage failure, not an implicit
exclusion.
