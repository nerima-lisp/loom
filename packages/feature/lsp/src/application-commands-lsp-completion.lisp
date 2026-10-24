(in-package #:loom/feature/lsp)

(defvar *completion-popup-provider* nil)

(defun register-completion-popup-provider (owner function)
  "Register FUNCTION as the completion popup provider owned by OWNER.

FUNCTION receives BUFFER, LINE, COLUMN, and ITEMS. The first OWNER
registration installs FUNCTION; later registrations by OWNER leave it in
place. A different owner is rejected."
  (unless (functionp function)
    (error "Completion popup provider must be a function"))
  (when (and *completion-popup-provider*
             (not (equal (car *completion-popup-provider*) owner)))
    (error "Completion popup provider is already registered by ~S"
           (car *completion-popup-provider*)))
  (unless *completion-popup-provider*
    (setf *completion-popup-provider* (cons owner function)))
  function)

(defun %make-completion-popup (buffer line column items)
  (unless *completion-popup-provider*
    (error "Completion popup provider is not registered"))
  (funcall (cdr *completion-popup-provider*) buffer line column items))

(defun %lsp-symbol-character-p (character)
  (or (alphanumericp character)
      (find character "-_*+/<>=!?%&$." :test #'char=)))

(defun %lsp-completion-prefix-column (buffer line column)
  "Return the column the symbol ending at COLUMN starts on."
  (let ((text (buffer-line buffer line))
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

(defun %show-lsp-completion-response (buffer line anchor items error-message)
  "Apply a completion response to the editor state or report its failure."
  (cond
    (error-message
     (%lsp-navigation-message
      (format nil "Completion failed: ~A" error-message)))
    ((null items)
     (%lsp-navigation-message "No completions"))
    (t
     (setf (editor-state-completion *editor-state*)
           (%make-completion-popup
            buffer line anchor
            (%lsp-completion-popup-items items))))))

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
       (lsp-session-sync-buffer session buffer)
       (let ((anchor (%lsp-completion-prefix-column buffer line character)))
         (lsp-request-completion
          session uri line
          (lsp-column-to-character (buffer-line buffer line) character)
          (lambda (items error-message)
            (%show-lsp-completion-response
             buffer line anchor items error-message))))
       nil))))
