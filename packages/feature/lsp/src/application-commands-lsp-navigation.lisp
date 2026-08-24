;;;; packages/feature/lsp/src/application-commands-lsp-navigation.lisp
;;;;
;;;; Completion and definition commands. Both ask the server and return
;;;; immediately: the reply arrives on a later LSP-SESSION-DRAIN, which the
;;;; event loop runs between frames, so the effect of these commands shows up
;;;; on a subsequent frame rather than before they return.
(in-package #:loom/feature/lsp)

(defun %lsp-navigation-session ()
  (loom:editor-state-lsp-session loom:*editor-state*))

(defun %lsp-navigation-minibuffer ()
  (loom:editor-state-minibuffer loom:*editor-state*))

(defun %lsp-navigation-message (text)
  (let ((minibuffer (%lsp-navigation-minibuffer)))
    (when minibuffer
      (loom:minibuffer-message minibuffer text)))
  nil)

(defun %lsp-navigation-context ()
  "Return (VALUES SESSION BUFFER URI LINE CHARACTER) when a request can be sent.

A request needs an initialized session and a file-backed buffer: a server
addresses documents by URI, and a buffer that was never saved has none."
  (let* ((session (%lsp-navigation-session))
         (buffer (loom/application:%selected-buffer))
         (path (and buffer (loom:buffer-path buffer))))
    (when (and session
               (lsp-session-initialized-p session)
               (not (lsp-session-closed-p session))
               path)
      (values session buffer (lsp-path-uri path)
              (loom:buffer-point-line buffer)
              (loom:buffer-point-column buffer)))))

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

(defun %lsp-push-jump-origin (buffer line column)
  (push (list buffer line column)
        (loom:editor-state-jump-origins loom:*editor-state*)))

(defun %lsp-goto-location (location)
  "Move point to LOCATION, opening its file when it is not already shown."
  (let* ((path (lsp-uri-path (lsp-location-uri location)))
         (position (lsp-range-start (lsp-location-range location)))
         (buffer (and path
                      (or (let ((selected (loom/application:%selected-buffer)))
                            (and (loom:buffer-path selected)
                                 (equal (namestring
                                         (pathname (loom:buffer-path selected)))
                                        (namestring (pathname path)))
                                 selected))
                          (loom/feature/file-tree:visit-file path)))))
    (cond
      ((null path)
       (%lsp-navigation-message
        (format nil "Definition is not a local file: ~A"
                (lsp-location-uri location))))
      ((null buffer)
       (%lsp-navigation-message (format nil "Cannot open ~A" path)))
      (t
       (loom:buffer-set-point buffer
                              (lsp-position-line position)
                              (lsp-position-character position))
       buffer))))

(defun lsp-find-definition ()
  "Jump to the definition of the symbol at point (M-.).

The position point occupied is pushed first, so LSP-POP-DEFINITION can put it
back even when the jump crossed into another file."
  (multiple-value-bind (session buffer uri line character)
      (%lsp-navigation-context)
    (cond
      ((null session) (%lsp-navigation-message "No LSP session for this buffer"))
      ((not (lsp-session-capability session "definitionProvider"))
       (%lsp-navigation-message "Server does not provide definitions"))
      (t
       (lsp-request-definition
        session uri line character
        (lambda (locations error-message)
          (cond
            (error-message
             (%lsp-navigation-message
              (format nil "Definition failed: ~A" error-message)))
            ((null locations) (%lsp-navigation-message "No definition found"))
            (t
             (%lsp-push-jump-origin buffer line character)
             (%lsp-goto-location (first locations))))))
       nil))))

(defun lsp-pop-definition ()
  "Return point to where the last definition jump started (M-,)."
  (let ((origin (pop (loom:editor-state-jump-origins loom:*editor-state*))))
    (if origin
        (destructuring-bind (buffer line column) origin
          (loom/feature/window:window-set-buffer
           (loom/application:%selected-window) buffer)
          (loom:buffer-set-point buffer line column))
        (%lsp-navigation-message "No jump to return from")))
  nil)
