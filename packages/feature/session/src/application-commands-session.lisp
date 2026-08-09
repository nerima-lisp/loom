;;;; packages/feature/session/src/application-commands-session.lisp
;;;;
;;;; Application layer: convert the live editor state to and from the
;;;; validated session snapshot owned by domain/session.lisp. The store itself
;;;; remains an infrastructure concern; these commands only choose the state
;;;; to persist and install a fully rebuilt state after a successful read.
(in-package #:loom/feature/session)

(defun %session-path-string (path)
  "Return PATH as a namestring, or NIL when PATH is NIL."
  (and path (namestring (pathname path))))

(defun %session-buffer-snapshot (buffer)
  "Convert BUFFER's public state to a serializable snapshot."
  (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
    (make-session-buffer-snapshot
     :name (buffer-name buffer)
     :path (%session-path-string (buffer-path buffer))
     :text (buffer-text buffer)
     :point-line (buffer-point-line buffer)
     :point-column (buffer-point-column buffer)
     :mark-line mark-line
     :mark-column mark-column
     :modified-p (buffer-modified-p buffer))))

(defun %session-indexed-layout (layout buffers)
  "Replace each buffer in LAYOUT with its index in BUFFERS."
  (case (first layout)
    (:leaf
     (let ((index (position (second layout) buffers :test #'eq)))
       (unless index
         (error "session snapshot: layout references an unregistered buffer ~S"
                (second layout)))
       (list :leaf index (third layout))))
    (:split
     (list :split
           (second layout)
           (%session-indexed-layout (third layout) buffers)
           (%session-indexed-layout (fourth layout) buffers)))
    (otherwise
     (error "session snapshot: unknown window layout node ~S" layout))))

(defun %session-snapshot-from-state ()
  "Return a validated snapshot of the current editor state."
  (let* ((tree (editor-state-window-tree *editor-state*))
         (visible (mapcar #'loom/feature/window:window-buffer
                          (loom/feature/window:window-tree-windows tree)))
         (buffers (remove-duplicates
                   (append (copy-list (%editor-buffers)) visible)
                   :test #'eq)))
    (validate-session-snapshot
     (make-session-snapshot
      :buffers (mapcar #'%session-buffer-snapshot buffers)
      :layout (%session-indexed-layout
               (loom/feature/window:window-tree-layout tree) buffers)
      :selected-window-index
      (loom/feature/window:window-tree-selected-index tree)))))

(defun %restore-session-buffer (snapshot)
  "Build a fresh buffer from one validated session buffer SNAPSHOT."
  (let ((buffer
          (make-buffer
           :name (session-buffer-snapshot-name snapshot)
           :path (and (session-buffer-snapshot-path snapshot)
                      (pathname (session-buffer-snapshot-path snapshot)))
           :initial-content (session-buffer-snapshot-text snapshot))))
    (buffer-set-point buffer
                      (session-buffer-snapshot-point-line snapshot)
                      (session-buffer-snapshot-point-column snapshot))
    (when (session-buffer-snapshot-mark-line snapshot)
      (buffer-set-mark buffer
                       (session-buffer-snapshot-mark-line snapshot)
                       (session-buffer-snapshot-mark-column snapshot)))
    (when (session-buffer-snapshot-modified-p snapshot)
      (buffer-mark-modified buffer))
    buffer))

(defun %restore-session-layout (layout buffers)
  "Replace buffer indexes in indexed LAYOUT with restored BUFFERS."
  (case (first layout)
    (:leaf
     (list :leaf (nth (second layout) buffers) (third layout)))
    (:split
     (list :split
           (second layout)
           (%restore-session-layout (third layout) buffers)
           (%restore-session-layout (fourth layout) buffers)))
    (otherwise
     (error "session restore: unknown window layout node ~S" layout))))

(defun %restore-session-snapshot (snapshot)
  "Install SNAPSHOT after rebuilding every buffer and window in advance."
  (validate-session-snapshot snapshot)
  (let* ((old-tree (editor-state-window-tree *editor-state*))
         (buffers (mapcar #'%restore-session-buffer
                          (session-snapshot-buffers snapshot)))
         (layout (%restore-session-layout (session-snapshot-layout snapshot)
                                          buffers))
         (tree (loom/feature/window:make-window-tree-from-layout
                layout
                (loom/feature/window:window-tree-width old-tree)
                (loom/feature/window:window-tree-height old-tree)
                :selected-index
                (session-snapshot-selected-window-index snapshot))))
    (setf (editor-state-buffers *editor-state*) buffers
          (editor-state-window-tree *editor-state*) tree)
    tree))

(defun %session-path-present-p (path)
  "Return true when PATH contains a non-whitespace character."
  (and (stringp path)
       (plusp (length (string-trim '(#\Space #\Tab) path)))))

(defun save-session ()
  "Prompt for a path and save the current editor session there."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Save session to: "))
    (if (not (%session-path-present-p path))
        (minibuffer-message minibuffer "Session path cannot be empty")
        (handler-case
            (progn
              (session-store-write path (%session-snapshot-from-state))
              (minibuffer-message
               minibuffer
               (format nil "Session saved: ~A" path)))
          (error (condition)
            (minibuffer-message
             minibuffer
             (format nil "Could not save session: ~A" condition)))))))

(defun load-session ()
  "Prompt for a session path and restore it after a successful read."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((path "Load session: "))
    (if (not (%session-path-present-p path))
        (minibuffer-message minibuffer "Session path cannot be empty")
        (handler-case
            (progn
              (%restore-session-snapshot (session-store-read path))
              (minibuffer-message
               minibuffer
               (format nil "Session loaded: ~A" path)))
          (error (condition)
            (minibuffer-message
             minibuffer
             (format nil "Could not load session: ~A" condition)))))))
