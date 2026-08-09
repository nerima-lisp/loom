# Editor core

The editor core owns buffer storage and the editing/movement command family.
Its files retain DDD names in the package-local `src/` directory while the
root `src/application/editor-state.lisp` composes them into a running editor.
