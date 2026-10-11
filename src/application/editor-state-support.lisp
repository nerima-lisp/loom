(in-package #:loom)

(defparameter *editor-recent-file-limit* 50
  "Maximum number of file paths retained by the in-memory recent-file list.")

(defvar *editor-state* nil
  "The editor state used by commands, initialized by %INITIALIZE-EDITOR-STATE.")
