(in-package #:loom/feature/file-tree)

(defun %file-tree-directory-key (path)
  (host-kit:ensure-directory-pathname (pathname path)))

(defun %file-tree-path-equal-p (first second &optional directory-p)
  (or (equal first second)
      (and directory-p first second
           (equal (%file-tree-directory-key first)
                  (%file-tree-directory-key second)))))
(defun %file-tree-child-kind (path children)
  (or (cdr (assoc path children :test (function equal)))
      (loop for (child-path . kind) in children
            thereis (when (and (eq kind :directory)
                               (%file-tree-path-equal-p path child-path t))
                      kind))))

(defun %file-tree-expanded-directory-key (tree path)
  (gethash (%file-tree-directory-key path)
           (file-tree-expanded-directory-index tree)))
(defun %file-tree-expanded-directory-p (tree path kind)
  (and (eq kind :directory)
       (%file-tree-expanded-directory-key tree path)))

(defun %file-tree-search-children (tree path children active-paths)
  (or (%file-tree-child-kind path children)
      (loop for (child-path . kind) in children
            thereis (when (%file-tree-expanded-directory-p tree child-path kind)
                      (%file-tree-search-directory tree path child-path
                                                   active-paths)))))

(defun %file-tree-search-directory (tree target-path directory-path active-paths)
  (unless (gethash directory-path active-paths)
    (setf (gethash directory-path active-paths) t)
    (unwind-protect
         (%file-tree-search-children
          tree target-path
          (%file-tree-children tree directory-path)
          active-paths)
      (remhash directory-path active-paths))))

(defun %file-tree-find-kind (tree path)
  "Search TREE, following only currently-expanded directories starting from
its root, for an entry whose path is EQUAL to PATH, and return its kind
  (:FILE or :DIRECTORY), or NIL if PATH is not found among the currently
  reachable (visible) entries."
  (%file-tree-search-directory tree path (file-tree-root-path tree)
                               (make-hash-table :test #'equal)))

(defun %file-tree-children (tree path)
  (multiple-value-call
      (lambda (children &optional (present-p t))
        (values children present-p))
    (funcall (file-tree-child-lister tree) path)))

(defun file-tree-entries (tree &key limit stop-after-path (trailing-rows 0))
  "Return display-order entries and whether every visited listing is available."
  (let ((entries nil)
        (count 0)
        (present-p t)
        (target-seen (null stop-after-path))
        (active-paths (make-hash-table :test #'equal)))
    (block collected
      (labels ((complete-p ()
                 (and limit (>= count limit) target-seen))
               (visit (path depth)
                 (when (complete-p) (return-from collected))
                 (unless (gethash path active-paths)
                   (setf (gethash path active-paths) t)
                   (unwind-protect
                        (multiple-value-bind (children available-p)
                            (%file-tree-children tree path)
                          (unless available-p (setf present-p nil))
                          (dolist (child children)
                            (when (complete-p) (return-from collected))
                            (let ((child-path (car child)))
                              (push (cons child-path depth) entries)
                              (incf count)
                              (when (and limit (not target-seen)
                                         (equal child-path stop-after-path))
                                (setf target-seen t
                                      limit (max limit (+ count trailing-rows))))
                              (when (%file-tree-expanded-directory-p
                                     tree child-path (cdr child))
                                (visit child-path (1+ depth))))))
                     (remhash path active-paths)))))
        (visit (file-tree-root-path tree) 0)))
    (values (nreverse entries) present-p)))

(defun file-tree-clamp-scroll-top (top count height)
  (max 0 (min top (max 0 (- count height)))))

(defun %file-tree-scroll-margin (height)
  (if (> height 3) 1 0))

(defun file-tree-scroll-top-for-selection (top index count height)
  (let* ((top (file-tree-clamp-scroll-top top count height))
         (margin (%file-tree-scroll-margin height)))
    (file-tree-clamp-scroll-top
     (cond
       ((or (null index) (zerop height)) top)
       ((< index (+ top margin)) (- index margin))
       ((>= index (- (+ top height) margin))
        (+ (- index height) margin 1))
       (t top))
     count height)))

(defun file-tree-scroll-top-for-wheel (top count height delta)
  (file-tree-clamp-scroll-top (+ top delta) count height))

(defun file-tree-selected-path (tree)
  "Return the path of TREE's currently selected entry, or NIL if nothing
is selected (e.g. an empty tree)."
  (file-tree-selection tree))

(defun file-tree-entry-kind (tree path)
  "Return :FILE or :DIRECTORY for PATH in TREE, or NIL when PATH is not
reachable in TREE."
  (%file-tree-find-kind tree path))

(defun %file-tree-selection-position (paths selected-path)
  (position selected-path paths :test #'equal))

(defun %file-tree-position-at-boundary (paths direction)
  (if (eq direction :down)
      0
      (1- (length paths))))

(defun %file-tree-move-selection-position (position count direction)
  (ecase direction
    (:down (min (1- count) (1+ position)))
    (:up (max 0 (1- position)))))

(defun %file-tree-next-position (paths selected-path direction)
  (let ((count (length paths)))
    (when (plusp count)
      (let ((position (%file-tree-selection-position paths selected-path)))
        (if position
            (%file-tree-move-selection-position position count direction)
            (%file-tree-position-at-boundary paths direction))))))

(defun %file-tree-next-selection (paths selected-path direction)
  "Return the visible PATH selected after moving in DIRECTION.

The calculation is independent of FILE-TREE state so callers can keep the
selection mutation at the boundary and test navigation as a pure operation."
  (let ((next-position (%file-tree-next-position paths selected-path direction)))
    (when next-position
      (nth next-position paths))))

(defun file-tree-move-selection (tree direction)
  "Move selection one entry in DIRECTION and request viewport following."
  (let* ((paths (mapcar #'car (file-tree-entries tree)))
         (old-selection (file-tree-selection tree))
         (selection (%file-tree-next-selection paths old-selection direction)))
    (setf (file-tree-selection tree) selection)
    (unless (equal selection old-selection)
      (setf (file-tree-scroll-follow-needed-p tree) t))
    selection))

(defun file-tree-select-path (tree path)
  "Select an already-resolved PATH and request viewport following."
  (setf (file-tree-selection tree) path
        (file-tree-scroll-follow-needed-p tree) t)
  path)


(defun file-tree-toggle-expand (tree path)
  "Toggle the directory at PATH and request viewport following."
  (unless (eq (%file-tree-find-kind tree path) :directory)
    (error "not a directory in tree: ~S" path))
  (let ((expanded-path (%file-tree-expanded-directory-key tree path))
        (key (%file-tree-directory-key path)))
    (setf (file-tree-scroll-follow-needed-p tree) t)
    (if expanded-path
        (progn
          (remhash expanded-path (file-tree-expanded tree))
          (remhash key (file-tree-expanded-directory-index tree))
          nil)
        (progn
          (setf (gethash key (file-tree-expanded-directory-index tree)) path)
          (setf (gethash path (file-tree-expanded tree)) t)))))
