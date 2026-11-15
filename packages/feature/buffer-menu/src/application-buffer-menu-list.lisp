(in-package #:loom/feature/buffer-menu)

(defstruct (buffer-menu-state (:constructor %make-buffer-menu-state))
  "Per-list state; ENTRIES maps line N of the list buffer to its buffer."
  (entries (vector))
  (marks (make-hash-table :test #'eq))
  origin-window
  origin-buffer
  list-window
  created-p
  previous-buffer)

(defvar *buffer-menu-states* (make-hash-table :test #'eq)
  "Buffer-menu state keyed by its *Buffer List* buffer.")

(defun %forget-buffer-menu-state (session buffer reason)
  (declare (ignore session reason))
  (remhash buffer *buffer-menu-states*)
  nil)

(eval-when (:load-toplevel :execute)
  (register-session-hook :buffer-close
                         :feature/buffer-menu
                         #'%forget-buffer-menu-state))

(defun %buffer-menu-live-p (buffer)
  (and buffer
       (member buffer (registered-buffers *editor-session*) :test #'eq)))

(defun %buffer-menu-home ()
  (let ((home (or (uiop:getenv "HOME")
                  (namestring (user-homedir-pathname)))))
    (and home (plusp (length home)) home)))

(defun %buffer-menu-row (buffer state home)
  "Describe BUFFER without reading its text; the size is O(1)."
  (let ((path (buffer-path buffer))
        (mode (or (buffer-major-mode buffer) :fundamental)))
    (list (gethash buffer (buffer-menu-state-marks state))
          (eq buffer (buffer-menu-state-origin-buffer state))
          (buffer-read-only-p buffer)
          (buffer-modified-p buffer)
          (buffer-name buffer)
          ;; The visible region's size, which is the whole buffer unless narrowed.
          (- (buffer-narrow-end-offset buffer)
             (buffer-narrow-start-offset buffer))
          (or (major-mode-name mode) "Fundamental")
          (buffer-menu-abbreviate-path
           (and path (if (pathnamep path) (namestring path) path))
           home))))

(defun %replace-buffer-menu-text (list-buffer text)
  (buffer-set-read-only list-buffer nil)
  (unwind-protect
       (let ((last-line (1- (buffer-line-count list-buffer))))
         (buffer-delete-region list-buffer 0 0 last-line
                               (length (buffer-line list-buffer last-line)))
         (buffer-set-point list-buffer 0 0)
         (buffer-insert-string list-buffer text)
         (buffer-mark-saved list-buffer))
    (buffer-set-read-only list-buffer t)))

(defun %fill-buffer-menu (list-buffer state)
  "Rewrite LIST-BUFFER from the registry in registration order."
  (let* ((buffers (reverse (registered-buffers *editor-session*)))
         (live (make-hash-table :test #'eq))
         (marks (buffer-menu-state-marks state))
         (home (%buffer-menu-home)))
    (dolist (buffer buffers)
      (setf (gethash buffer live) t))
    (loop for buffer being the hash-keys of marks
          unless (gethash buffer live)
            do (remhash buffer marks))
    (let ((rows (mapcar (lambda (buffer) (%buffer-menu-row buffer state home))
                        buffers)))
      (setf (buffer-menu-state-entries state) (coerce buffers 'vector))
      (%replace-buffer-menu-text list-buffer (buffer-menu-format-lines rows)))))

(defun %refresh-buffer-menu (list-buffer state)
  "Rebuild LIST-BUFFER, keeping marks and point on the same buffer if it survives."
  (let* ((old-entries (buffer-menu-state-entries state))
         (line (buffer-point-line list-buffer))
         (point-buffer (and (< line (length old-entries))
                            (aref old-entries line))))
    (%fill-buffer-menu list-buffer state)
    (let* ((entries (buffer-menu-state-entries state))
           (new-line (or (position point-buffer entries :test #'eq)
                         (min line (1- (length entries))))))
      (buffer-set-point list-buffer new-line 0))))

(defun %select-window (tree window)
  (window-tree-select-index tree (position window (window-tree-windows tree))))

(defun %window-after (windows window)
  (let ((tail (rest (member window windows :test #'eq))))
    (if tail (first tail) (first windows))))

(defun %display-buffer-menu (tree origin list-buffer state)
  "Show LIST-BUFFER in a window other than ORIGIN and keep ORIGIN selected."
  (let ((windows (window-tree-windows tree)))
    (if (null (rest windows))
        (let ((window (window-split tree origin :horizontal)))
          (window-set-buffer window list-buffer)
          (%select-window tree origin)
          (setf (buffer-menu-state-list-window state) window
                (buffer-menu-state-created-p state) t
                (buffer-menu-state-previous-buffer state) nil))
        (let* ((others (remove origin windows :test #'eq))
               (window (or (find list-buffer others :key #'window-buffer :test #'eq)
                           (%window-after windows origin))))
          ;; Redisplaying the list in the window that still shows it keeps
          ;; the earlier record of what q should restore.
          (unless (and (eq window (buffer-menu-state-list-window state))
                       (eq (window-buffer window) list-buffer))
            (let ((previous (window-buffer window)))
              (setf (buffer-menu-state-list-window state) window
                    (buffer-menu-state-created-p state) nil
                    (buffer-menu-state-previous-buffer state)
                    (and (not (eq previous list-buffer)) previous))))
          (window-set-buffer window list-buffer)))))

(defun list-buffers ()
  "Show *Buffer List* in another window; the selected window and point stay."
  (let* ((tree (editor-state-window-tree *editor-state*))
         (origin (window-tree-selected-window tree))
         (list-buffer (ensure-result-buffer *editor-session* "*Buffer List*"))
         (state (or (gethash list-buffer *buffer-menu-states*)
                    (setf (gethash list-buffer *buffer-menu-states*)
                          (%make-buffer-menu-state)))))
    (buffer-set-major-mode list-buffer :buffer-menu)
    ;; Read-only before the rows are built, so the list's own row shows %.
    (buffer-set-read-only list-buffer t)
    (clrhash (buffer-menu-state-marks state))
    (setf (buffer-menu-state-origin-window state) origin
          (buffer-menu-state-origin-buffer state) (window-buffer origin))
    (%fill-buffer-menu list-buffer state)
    (buffer-set-point list-buffer 0 0)
    (%display-buffer-menu tree origin list-buffer state)
    list-buffer))
