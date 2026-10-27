# Editor core

`packages/core/editor/` contains this README only; it has no ASDF system or package-local source directory.

The shared editor implementation is split across the packages listed in
[`packages/core/README.md`](../README.md): `buffer`, `command`,
`editor-session`, `minibuffer`, and `window-tree`. Their source lives in each
package's own directory under `packages/core/`.

The root system in `loom.asd` composes these packages with feature packages
and application startup code.
