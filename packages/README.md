# Package-by-feature layout

Loom keeps `src/<DDD>/` as the composition root. The root owns the shared
editor wiring and the final presentation loop; feature-specific code lives
under `packages/` so a feature can be located without scanning every DDD
layer.

Package implementation filenames carry their layer explicitly:

- `domain-*` contains domain state and invariants.
- `application-*` contains commands and use-case orchestration.
- `infrastructure-*` contains direct external-process and filesystem
  integrations.
- `presentation-*` contains feature-specific rendering or styling.

Namespace definitions use `src/package.lisp` without a layer prefix.

`loom.asd` is the single composition manifest and preserves the dependency
order across these slices.
