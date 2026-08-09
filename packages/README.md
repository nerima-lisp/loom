# Package-by-feature layout

Loom keeps `src/<DDD>/` as the composition root. The root owns the shared
editor wiring and the final presentation loop; feature-specific code lives
under `packages/` so a feature can be located without scanning every DDD
layer.

Each package source filename carries its layer explicitly:

- `domain-*` contains domain state and invariants.
- `application-*` contains commands and use-case orchestration.
- `infrastructure-*` contains external-process and filesystem adapters.
- `presentation-*` contains feature-specific rendering or styling.

`loom.asd` is the single composition manifest and preserves the dependency
order across these slices.
