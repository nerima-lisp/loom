;;;; src/application/command-definitions.lisp
;;;;
;;;; Composition-root catalogue for commands exposed by the editor.  The
;;;; registry implementation lives in application/command-registry.lisp;
;;;; keeping this data separate from command handlers makes the catalogue
;;;; readable and lets keybinding installation consume one declarative model.
(in-package #:loom)

(define-command-spec-catalog
  *movement-command-spec-groups*
  *editing-command-spec-groups*
  *files-command-spec-groups*
  *windows-command-spec-groups*
  *session-command-spec-groups*
  *macros-command-spec-groups*
  *tooling-command-spec-groups*
  *file-tree-command-spec-groups*
  *ui-command-spec-groups*)
