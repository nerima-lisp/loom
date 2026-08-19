;;;; src/application/editor-state-support.lisp
;;;;
;;;; Application layer: editor-state-adjacent shared globals.
(in-package #:loom)

(defparameter *editor-recent-file-limit* 50
  "Maximum number of file paths retained by the in-memory recent-file list.")

(defvar *editor-state* nil
  "The single, dynamically-bound EDITOR-STATE struct that every command
function (see application/commands-*.lisp) reads and mutates. Bound to a
freshly created EDITOR-STATE by loom's entry point (see MAIN in src/main.lisp)
before any command runs, and NIL otherwise.")
