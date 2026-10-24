(in-package #:loom/feature/bookmark)

(defstruct (editor-bookmark
            (:constructor make-editor-bookmark
                (&key name buffer path buffer-name line column)))
  name
  buffer
  path
  buffer-name
  line
  column)
