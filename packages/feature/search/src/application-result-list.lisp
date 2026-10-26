(in-package #:loom/feature/search)
(progn
  (defun %result-item-path-text (item)
    (let ((path (result-item-file-path item)))
      (or (typecase path
            (pathname (namestring path))
            (string path))
          (and (result-item-buffer item)
               (loom/core/buffer:buffer-name
                (result-item-buffer item)))
          "<buffer>")))

  (defun %result-item-display-line (item)
    (format nil "~A:~D:~D: ~A"
            (%result-item-path-text item)
            (1+ (result-item-line item))
            (1+ (result-item-column item))
            (with-output-to-string (output)
              (loop for character across (result-item-display-text item)
                    do (write-char
                        (if (member character (list #\Newline #\Return)
                                    :test (function char=))
                            #\Space
                            character)
                        output)))))

  (defun %replace-result-list-contents (buffer items)
    (let ((last-line (1- (loom/core/buffer:buffer-line-count buffer))))
      (loom/core/buffer:buffer-delete-region
       buffer 0 0 last-line
       (length (loom/core/buffer:buffer-line buffer last-line))))
    (loom/core/buffer:buffer-set-point buffer 0 0)
    (loop for item across items
          for row from 0
          do (when (plusp row)
               (loom/core/buffer:buffer-insert-string buffer (string #\Newline)))
             (loom/core/buffer:buffer-insert-string
              buffer
              (%result-item-display-line item)))
    (loom/core/buffer:buffer-set-point buffer 0 0)
    buffer))
(progn
  (defun %result-list-for-buffer (state buffer)
    (or (gethash buffer (search-result-state-lists state))
        (let ((active-buffer (search-result-state-active-buffer state)))
          (and active-buffer
               (gethash active-buffer (search-result-state-lists state))))))

  (defun %selected-result-buffer ()
    (let* ((editor-state loom/core/editor-session:*editor-state*)
           (window-tree
             (and editor-state
                  (loom/core/editor-session:editor-state-window-tree
                   editor-state)))
           (window (and window-tree
                        (loom/core/window-tree:window-tree-selected-window
                         window-tree))))
      (and window (loom/core/window-tree:window-buffer window))))

  (defun %visit-result-item (session item)
    (let ((loom/core/editor-session:*editor-session* session))
      (let* ((editor-state loom/core/editor-session:*editor-state*)
             (window-tree
               (and editor-state
                    (loom/core/editor-session:editor-state-window-tree
                     editor-state)))
             (window
               (and window-tree
                    (loom/core/window-tree:window-tree-selected-window
                     window-tree))))
        (when window
          (let* ((path (result-item-file-path item))
                 (buffer
                   (or (result-item-buffer item)
                       (and path
                            (loom/feature/buffers:find-buffer-by-path
                             session path))
                       (and path
                            (loom/feature/files:visit-file path)))))
            (when buffer
              (unless (eq (loom/core/window-tree:window-buffer window) buffer)
                (loom/core/window-tree:window-set-buffer window buffer))
              (buffer-set-point buffer
                                (result-item-line item)
                                (result-item-column item))
              buffer)))))))
(progn
  (defun publish-result-list (session name items)
    "Publish ITEMS to a named result buffer owned by SESSION."
    (let* ((item-vector (coerce items 'vector))
           (buffer (loom/feature/buffers:ensure-result-buffer session name))
           (state
             (loom/core/editor-session:editor-session-slice
              session :feature/search))
           (record (%make-search-result-list :buffer buffer
                                             :items item-vector)))
      (loop for item across item-vector
            do (check-type item result-item))
      (loom/core/buffer:buffer-set-read-only buffer nil)
      (unwind-protect
           (progn
             (%replace-result-list-contents buffer item-vector)
             (loom/core/buffer:buffer-set-major-mode buffer :loom-search-results)
             (setf (gethash buffer (search-result-state-lists state)) record
                   (search-result-state-active-buffer state) buffer)
             (loom/core/buffer:buffer-mark-saved buffer)
             buffer)
        (loom/core/buffer:buffer-set-read-only buffer t)))))
(progn
  (defun search-result-visit ()
    "Visit the result item on the selected row of a result list."
    (let* ((session loom/core/editor-session:*editor-session*)
           (selected-buffer (%selected-result-buffer))
           (state
             (and session
                  (loom/core/editor-session:editor-session-slice
                   session :feature/search)))
           (record
             (and state
                  (gethash selected-buffer (search-result-state-lists state))))
           (row (and selected-buffer
                     (loom/core/buffer:buffer-point-line selected-buffer))))
      (when (and record row
                 (<= 0 row)
                 (< row (length (search-result-list-items record))))
        (setf (search-result-list-cursor record) row
              (search-result-state-active-buffer state)
              (search-result-list-buffer record))
        (%visit-result-item session
                            (aref (search-result-list-items record) row))))))
(progn
  (defun %navigate-result-list (direction)
    (let* ((session loom/core/editor-session:*editor-session*)
           (selected-buffer (%selected-result-buffer))
           (state
             (and session
                  (loom/core/editor-session:editor-session-slice
                   session :feature/search)))
           (record
             (and state
                  (%result-list-for-buffer state selected-buffer)))
           (items (and record (search-result-list-items record)))
           (count (and items (length items)))
           (at-result-buffer-p
             (and record
                  (eq selected-buffer (search-result-list-buffer record))))
           (cursor
             (when record
               (if at-result-buffer-p
                   (loom/core/buffer:buffer-point-line selected-buffer)
                   (search-result-list-cursor record))))
           (row
             (cond
               ((null record) nil)
               (at-result-buffer-p cursor)
               ((minusp cursor)
                (if (eq direction :next) 0 (1- count)))
               ((eq direction :next) (1+ cursor))
               (t (1- cursor)))))
      (when (and row (<= 0 row) (< row count))
        (setf (search-result-list-cursor record) row
              (search-result-state-active-buffer state)
              (search-result-list-buffer record))
        (%visit-result-item session (aref items row)))))

  (defun next-error ()
    "Visit the next result in the active search result list."
    (%navigate-result-list :next))

  (defun previous-error ()
    "Visit the previous result in the active search result list."
    (%navigate-result-list :previous))

  (eval-when (:load-toplevel :execute)
    (loom/feature/mode:register-major-mode
     :loom-search-results
     :name "Search Results"
     :keybindings (list (cons :enter #'search-result-visit)))))
