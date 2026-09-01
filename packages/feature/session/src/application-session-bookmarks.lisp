;;;; packages/feature/session/src/application-session-bookmarks.lisp
;;;;
;;;; Application-layer bookmark conversion shared by session snapshot and
;;;; restore flows.
(in-package #:loom/feature/session)

(defun %session-path-string (path)
  "Return PATH as a namestring, or NIL when PATH is NIL."
  (and path (namestring (pathname path))))

(defun %session-bookmark-snapshot (bookmark)
  "Convert one live bookmark to a serializable snapshot."
  (make-session-bookmark-snapshot
   :name (editor-bookmark-name bookmark)
   :path (%session-path-string (editor-bookmark-path bookmark))
   :buffer-name (or (editor-bookmark-buffer-name bookmark)
                    (and (editor-bookmark-buffer bookmark)
                         (buffer-name (editor-bookmark-buffer bookmark))))
   :line (editor-bookmark-line bookmark)
   :column (editor-bookmark-column bookmark)))

(defun %session-bookmark-snapshots ()
  "Return the current named bookmarks in deterministic order."
  (let ((bookmarks (editor-state-bookmarks *editor-state*)))
    (cond
      ((null bookmarks) nil)
      ((hash-table-p bookmarks)
       (sort
        (loop for bookmark being the hash-values of bookmarks
              collect (%session-bookmark-snapshot bookmark))
        (lambda (left right)
          (let ((left-name (session-bookmark-snapshot-name left))
                (right-name (session-bookmark-snapshot-name right)))
            (or (string< (string-downcase left-name)
                         (string-downcase right-name))
                (and (string= (string-downcase left-name)
                              (string-downcase right-name))
                     (string< left-name right-name)))))))
      (t
       (error "session snapshot: bookmarks must be a hash table")))))

(defun %restore-session-bookmark-buffer (snapshot buffers)
  "Find the restored buffer associated with bookmark SNAPSHOT."
  (or (and (session-bookmark-snapshot-path snapshot)
           (find (session-bookmark-snapshot-path snapshot)
                 buffers
                 :key (lambda (buffer)
                        (%session-path-string (buffer-path buffer)))
                 :test #'string=))
      (and (session-bookmark-snapshot-buffer-name snapshot)
           (find (session-bookmark-snapshot-buffer-name snapshot)
                 buffers
                 :key #'buffer-name
                 :test #'string=))))

(defun %restore-session-bookmarks (snapshots buffers)
  "Build a named bookmark table and reconnect bookmarks to BUFFERS when possible."
  (when snapshots
    (let ((bookmarks (make-hash-table :test #'equal)))
      (dolist (snapshot snapshots bookmarks)
        (let ((buffer (%restore-session-bookmark-buffer snapshot buffers)))
          (setf (gethash (session-bookmark-snapshot-name snapshot) bookmarks)
                (make-editor-bookmark
                 :name (session-bookmark-snapshot-name snapshot)
                 :buffer buffer
                 :path (and (session-bookmark-snapshot-path snapshot)
                            (pathname (session-bookmark-snapshot-path snapshot)))
                 :buffer-name (or (session-bookmark-snapshot-buffer-name snapshot)
                                  (and buffer (buffer-name buffer)))
                 :line (session-bookmark-snapshot-line snapshot)
                 :column (session-bookmark-snapshot-column snapshot))))))))
