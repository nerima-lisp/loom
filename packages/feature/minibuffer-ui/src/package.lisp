(defpackage #:loom/feature/minibuffer-ui
  (:use #:cl)
  (:import-from #:loom/core/editor-session
                #:*editor-state*
                #:editor-state-minibuffer
                #:editor-state-session
                #:frame-snapshot-height
                #:frame-snapshot-width
                #:make-render-operation
                #:register-session-hook)
  (:import-from #:loom/core/minibuffer
                #:minibuffer-active-p
                #:minibuffer-completion-candidates))
(in-package #:loom/feature/minibuffer-ui)
(defun %minibuffer-completion-render-operations (session snapshot)
  "Overlay active minibuffer candidates above the prompt row."
  (let* ((state *editor-state*)
         (minibuffer
           (when (and state (eq (editor-state-session state) session))
             (editor-state-minibuffer state)))
         (candidates
           (when (and minibuffer (minibuffer-active-p minibuffer))
             (minibuffer-completion-candidates minibuffer)))
         (prompt-row (1- (frame-snapshot-height snapshot)))
         (visible-count (min (length candidates) 6 prompt-row))
         (first-row (- prompt-row visible-count)))
    (loop for candidate in candidates
          for index below visible-count
          for row = (+ first-row index)
          append (list (make-render-operation
                        :text 0 row
                        (make-string (frame-snapshot-width snapshot)
                                     :initial-element #\Space))
                       (make-render-operation :text 0 row candidate)))))
(eval-when (:load-toplevel :execute)
  (register-session-hook :render
                         :feature/minibuffer-ui
                         (function %minibuffer-completion-render-operations)))
