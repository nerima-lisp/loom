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
(defun %render-minibuffer-cursor (session snapshot)
  (labels ((grapheme-advance (grapheme column)
             (if (string= grapheme (string #\Tab))
                 (- 8 (mod column 8))
                 (max 1
                      (cl-tty-kit:grapheme-width grapheme)
                      (if (find (code-char #xFE0F) grapheme) 2 0))))
           (cell-width (text)
             (let ((column 0))
               (dolist (grapheme (cl-tty-kit:string-graphemes text) column)
                 (incf column (grapheme-advance grapheme column))))))
    (let ((state loom/core/editor-session:*editor-state*))
      (when (and state
                 (eq session
                     (loom/core/editor-session:editor-state-session state))
                 (loom/core/minibuffer:minibuffer-active-p
                  (loom/core/editor-session:editor-state-minibuffer state)))
        (let* ((minibuffer
                 (loom/core/editor-session:editor-state-minibuffer state))
               (prompt
                 (or (loom/core/minibuffer:minibuffer-prompt-string minibuffer)
                     ""))
               (input
                 (loom/core/minibuffer:minibuffer-input-string minibuffer))
               (point
                 (loom/core/minibuffer:minibuffer-input-point minibuffer))
               (prefix
                 (concatenate 'string prompt (subseq input 0 point)))
               (x
                 (min (1- (loom/core/editor-session:frame-snapshot-width snapshot))
                      (cell-width prefix)))
               (y
                 (1- (loom/core/editor-session:frame-snapshot-height snapshot))))
          (list
           (loom/core/editor-session:make-render-operation :cursor x y t)))))))
(eval-when (:load-toplevel :execute)
  (register-session-hook :render
                         :feature/minibuffer-ui
                         (function %minibuffer-completion-render-operations))
  (register-session-hook :render
                         :feature/minibuffer-ui
                         (function %render-minibuffer-cursor)))
