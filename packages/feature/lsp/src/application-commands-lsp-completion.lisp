;;;; packages/feature/lsp/src/application-commands-lsp-completion.lisp
;;;;
;;;; Completion command and its data transformation boundary. The request is
;;;; asynchronous; this command only schedules it and stores the result when
;;;; the session drain receives the reply.
(in-package #:loom/feature/lsp)

(defun %lsp-symbol-character-p (character)
  (or (alphanumericp character)
      (find character "-_*+/<>=!?%&$." :test #'char=)))

(defun %lsp-completion-prefix-column (buffer line column)
  "Return the column the symbol ending at COLUMN starts on."
  (let ((text (loom:buffer-line buffer line))
        (start column))
    (loop while (and (plusp start)
                     (%lsp-symbol-character-p (char text (1- start))))
          do (decf start))
    start))

(defun %lsp-completion-popup-items (items)
  "Turn LSP completion items into the (LABEL . TEXT) pairs the popup holds."
  (mapcar (lambda (item)
            (cons (let ((detail (lsp-completion-item-detail item)))
                    (if detail
                        (format nil "~A  ~A"
                                (lsp-completion-item-label item) detail)
                        (lsp-completion-item-label item)))
                  (lsp-completion-item-text item)))
          items))

(defun lsp-completion-at-point ()
  "Ask the language server what can follow point and show the candidates (C-M-i).

Does nothing but say so when the server never advertised completionProvider,
which is the difference between `this server cannot' and `this server found
nothing'."
  (multiple-value-bind (session buffer uri line character)
      (%lsp-navigation-context)
    (cond
      ((null session) (%lsp-navigation-message "No LSP session for this buffer"))
      ((not (lsp-session-capability session "completionProvider"))
       (%lsp-navigation-message "Server does not provide completion"))
      (t
       (let ((anchor (%lsp-completion-prefix-column buffer line character)))
         (lsp-request-completion
          session uri line character
          (lambda (items error-message)
            (cond
              (error-message
               (%lsp-navigation-message
                (format nil "Completion failed: ~A" error-message)))
              ((null items) (%lsp-navigation-message "No completions"))
              (t
               (setf (loom:editor-state-completion loom:*editor-state*)
                     (loom:make-editor-completion
                      buffer line anchor
                      (%lsp-completion-popup-items items))))))))
       nil))))
