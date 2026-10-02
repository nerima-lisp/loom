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

The initial run reached the Nix environment setup but did not produce a
coverage report before the outer process was interrupted after the runner
stopped producing child processes. No expression or branch percentage is
recorded until `COVERAGE-EXPRESSIONS` and `COVERAGE-BRANCHES` are emitted by
the command.

## Exclusions

No exclusion is accepted in this initial ledger. Each future entry must name
the macro, the generated branch shape, the source location reported by the
coverage tool, the reason it cannot be exercised by Loom, and the exact
reproduction command. A missing entry is a coverage failure, not an implicit
exclusion.
