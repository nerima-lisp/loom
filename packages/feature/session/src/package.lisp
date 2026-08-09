;;;; packages/feature/session/src/package.lisp
;;;;
;;;; Session snapshots are persisted infrastructure for the window feature.
(defpackage #:loom/feature/session
  (:use #:cl #:loom #:loom/application #:loom/feature/window)
  (:export
   ;; Domain and infrastructure API
   #:session-buffer-snapshot
   #:make-session-buffer-snapshot
   #:session-buffer-snapshot-name
   #:session-buffer-snapshot-path
   #:session-buffer-snapshot-text
   #:session-buffer-snapshot-point-line
   #:session-buffer-snapshot-point-column
   #:session-buffer-snapshot-mark-line
   #:session-buffer-snapshot-mark-column
   #:session-buffer-snapshot-modified-p
   #:session-snapshot
   #:make-session-snapshot
   #:session-snapshot-buffers
   #:session-snapshot-layout
   #:session-snapshot-selected-window-index
   #:validate-session-snapshot
   #:session-store-read
   #:session-store-write
   ;; Application API
   #:save-session
   #:load-session))
