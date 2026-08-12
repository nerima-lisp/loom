;;;; src/application/editor-state-bookmarks.lisp
;;;;
;;;; Application-layer bookmark data stored inside EDITOR-STATE.
(in-package #:loom)

(defstruct (editor-bookmark
            (:constructor make-editor-bookmark
                (&key name buffer path buffer-name line column)))
  name
  buffer
  path
  buffer-name
  line
  column)
