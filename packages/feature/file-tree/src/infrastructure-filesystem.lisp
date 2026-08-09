;;;; packages/feature/file-tree/src/infrastructure-filesystem.lisp
;;;;
;;;; Infrastructure layer: the file-tree protocol's disk-touching generics,
;;;; split out of the tree-state generics in domain/file-tree.lisp because
;;;; these operate on the real filesystem rather than on pure tree state.
;;;;
;;;; Most of them reach the disk through *LOOM-FILESYSTEM*, a CL-BOUNDARY-KIT
;;;; filesystem boundary, so t/unit/filesystem-test.lisp can rebind that one
;;;; variable to an in-memory fake instead of creating a real temporary
;;;; directory. Two operations deliberately stay on CL-HOST-KIT directly,
;;;; because routing them through the boundary would cost correctness rather
;;;; than buy testability:
;;;;
;;;;   LOOM-FS-LIST-DIRECTORY needs each entry classified as :DIRECTORY or
;;;;   :FILE. CL-BOUNDARY-KIT:FILESYSTEM-LIST-DIRECTORY returns bare
;;;;   pathnames with no classification, so the kind would have to be
;;;;   recovered with a second probe per entry, whereas
;;;;   CL-HOST-KIT:CALL-WITH-DIRECTORY-ENTRIES already reports it in one pass.
;;;;
;;;;   FILE-TREE-DELETE deletes a populated directory tree. The boundary's
;;;;   FILESYSTEM-DELETE-DIRECTORY removes only an already-empty directory, so
;;;;   the recursion would have to be written here on top of
;;;;   FILESYSTEM-LIST-DIRECTORY -- which is CL:DIRECTORY underneath and so
;;;;   RESOLVES SYMLINKS. Recursing over resolved entries walks *through* a
;;;;   symlink to a directory outside the tree and deletes its contents; the
;;;;   file-tree sidebar's delete command has no confirmation prompt, so that
;;;;   is unacceptable. CL-HOST-KIT:DELETE-PATH :RECURSIVE T does not follow
;;;;   symlinks and does the whole job in one call.
;;;;
;;;; SBCL's generic PATHNAME reader treats square brackets in a namestring as
;;;; wildcard syntax. For the default real filesystem, the helpers below use
;;;; SBCL's native namestring/POSIX APIs whenever such a pathname is passed;
;;;; the in-memory filesystem remains entirely on the boundary path.
(in-package #:loom)

(defparameter *loom-real-filesystem* (cl-boundary-kit:make-filesystem))

(defparameter *loom-filesystem* *loom-real-filesystem*
  "The CL-BOUNDARY-KIT filesystem boundary that every disk-touching operation
in this file goes through, except native literal-namestring operations and
LOOM-FS-LIST-DIRECTORY -- see this file's header comment for the reasons.
Tests rebind this to CL-BOUNDARY-KIT:MAKE-TEST-FILESYSTEM's in-memory fake so
they exercise the operations without touching a real temporary directory.")

(defun %native-path-operation-p (&rest paths)
  #+sbcl
  (and (eq *loom-filesystem* *loom-real-filesystem*)
       (some (lambda (path)
               (wild-pathname-p (pathname path)))
             paths))
  #-sbcl
  nil)

(defun %native-namestring (path)
  #+sbcl
  (sb-ext:native-namestring
   (sb-ext:parse-native-namestring (namestring (pathname path))))
  #-sbcl
  (namestring (pathname path)))

(defun %native-path-exists-p (path)
  #+sbcl
  (not (null (ignore-errors (sb-posix:lstat (%native-namestring path)))))
  #-sbcl
  nil)

#+sbcl
(defun %native-create-file (path)
  (let ((fd (sb-posix:open (%native-namestring path)
                           (logior sb-posix:o-wronly
                                   sb-posix:o-creat
                                   sb-posix:o-excl)
                           #o666)))
    (unwind-protect
         (progn
           (sb-posix:close fd)
           (setf fd nil)
           path)
      (when fd
        (ignore-errors (sb-posix:close fd))))))

#+sbcl
(defun %native-directory-prefixes (native-path)
  (let ((prefixes nil)
        (start 0)
        (size (length native-path)))
    (loop
      for separator = (position #\/ native-path :start start)
      for end = (or separator size)
      do (when (> end start)
           (push (subseq native-path 0 (if separator (1+ end) end))
                 prefixes))
         (if separator
             (setf start (1+ separator))
             (return (nreverse prefixes))))))

#+sbcl
(defun %native-directory-p (native-path)
  (let ((stat (ignore-errors (sb-posix:stat native-path))))
    (and stat
         (sb-posix:s-isdir (sb-posix:stat-mode stat)))))

#+sbcl
(defun %native-mkdir (native-path)
  (sb-posix:mkdir native-path #o777))

#+sbcl
(defun %native-make-directory (path)
  (let* ((prefixes (%native-directory-prefixes (%native-namestring path)))
         (target (car (last prefixes))))
    (dolist (prefix (butlast prefixes))
      (unless (%native-directory-p prefix)
        (handler-case
            (%native-mkdir prefix)
          (error (condition)
            (unless (%native-directory-p prefix)
              (error condition))))))
    (when target
      (%native-mkdir target)))
  path)

#+sbcl
(defun %native-rename (old-path new-path)
  (sb-posix:rename (%native-namestring old-path)
                   (%native-namestring new-path))
  new-path)

#+sbcl
(defun %native-read-file (path)
  (let ((fd (sb-posix:open (%native-namestring path) sb-posix:o-rdonly)))
    (unwind-protect
         (let ((stream (sb-sys:make-fd-stream fd
                                              :input t
                                              :element-type 'character
                                              :external-format :utf-8)))
           (setf fd nil)
           (unwind-protect
                (let ((chunk (make-string 4096))
                      (output (make-string-output-stream)))
                  (loop for count = (read-sequence chunk stream)
                        while (plusp count)
                        do (write-string chunk output :end count))
                  (get-output-stream-string output))
             (close stream)))
      (when fd
        (ignore-errors (sb-posix:close fd))))))

#+sbcl
(defun %native-write-file (path content)
  (let ((fd (sb-posix:open (%native-namestring path)
                           (logior sb-posix:o-wronly
                                   sb-posix:o-creat
                                   sb-posix:o-trunc)
                           #o666)))
    (unwind-protect
         (let ((stream (sb-sys:make-fd-stream fd
                                              :output t
                                              :element-type 'character
                                              :external-format :utf-8)))
           (setf fd nil)
           (unwind-protect
                (progn
                  (write-string content stream)
                  (finish-output stream))
             (close stream)))
      (when fd
        (ignore-errors (sb-posix:close fd))))))

#+sbcl
(defun %native-child-namestring (directory name)
  (cond
    ((zerop (length directory))
     name)
    ((char= (char directory (1- (length directory))) #\/)
     (concatenate 'string directory name))
    (t
     (format nil "~A/~A" directory name))))

#+sbcl
(defun %native-delete-path (path)
  ;; An explicit stack keeps deletion safe for deep trees without depending on
  ;; the Lisp call stack, while LSTAT makes symlinks leaf entries.
  (let ((stack (list (cons (%native-namestring path) nil))))
    (loop while stack
          for item = (pop stack)
          for native = (car item)
          do (if (cdr item)
                 (sb-posix:rmdir native)
                 (let ((mode (sb-posix:stat-mode (sb-posix:lstat native))))
                   (if (sb-posix:s-isdir mode)
                       (progn
                         (push (cons native t) stack)
                         (let ((directory (sb-posix:opendir native)))
                           (unwind-protect
                                (loop for entry = (sb-posix:readdir directory)
                                      until (or (null entry)
                                                (sb-alien:null-alien entry))
                                      for name = (sb-posix:dirent-name entry)
                                      unless (member name '("." "..")
                                                     :test #'string=)
                                        do (push (cons
                                                  (%native-child-namestring
                                                   native name)
                                                  nil)
                                                  stack))
                             (sb-posix:closedir directory))))
                       (sb-posix:unlink native)))))
  path))

;;; ---------------------------------------------------------------------
;;; LOOM-FS-LIST-DIRECTORY: the real, disk-backed "children lister" for a
;;; file-tree directory node.
;;;
;;; domain/file-tree.lisp is deliberately pure tree state (visibility,
;;; selection, expand/collapse, the flattened FILE-TREE-ENTRIES listing) with
;;; no dependency on CL-HOST-KIT -- see that file's header comment. That
;;; means whatever populates a directory node's children from disk has to
;;; live here in infrastructure/filesystem.lisp instead; domain/file-tree.lisp
;;; calls into it through the FILE-TREE-CHILD-LISTER slot, a swappable
;;; function-of-one-argument seam that defaults to a pure, no-filesystem-
;;; access stub (%DEFAULT-CHILD-LISTER) so a FILE-TREE stays usable in
;;; isolation, e.g. in domain-layer tests.
;;;
;;; LOOM-FS-LIST-DIRECTORY below is written against PATH in and children out
;;; only, matching that seam's contract exactly, so wiring it into the real,
;;; disk-backed tree src/main.lisp builds is a single SETF (see
;;; %INITIALIZE-EDITOR-STATE):
;;;
;;;   (setf (file-tree-child-lister file-tree) #'loom-fs-list-directory)
;;; ---------------------------------------------------------------------
(defun loom-fs-list-directory (path)
  "Return the direct children of the directory at PATH as a list of
(CHILD-PATH . KIND) conses, where CHILD-PATH is an absolute pathname (as
yielded by CL-HOST-KIT:CALL-WITH-DIRECTORY-ENTRIES) and KIND is :DIRECTORY or
:FILE. Directories sort before files; within each group, entries sort
alphabetically by their namestrings. Symbolic links and other special entries
are omitted."
  (let ((directories '())
        (files '()))
    (host-kit:call-with-directory-entries
     (lambda (child-path metadata)
       (case (host-kit:file-metadata-kind metadata)
         (:directory (push (cons child-path :directory) directories))
         (:regular-file (push (cons child-path :file) files))
         (t nil)))
     path)
    (flet ((by-namestring< (a b)
             (string< (namestring (car a)) (namestring (car b)))))
      (append (sort (nreverse directories) #'by-namestring<)
              (sort (nreverse files) #'by-namestring<)))))

;;; Each of the four generics below performs its disk operation for real --
;;; ordinary pathnames through *LOOM-FILESYSTEM*, literal namestring
;;; pathnames through the native adapter above, and FILE-TREE-DELETE through
;;; CL-HOST-KIT except for that same native adapter case. None of them needs
;;; to explicitly "refresh" TREE afterwards:
;;; FILE-TREE-ENTRIES (domain/file-tree.lisp's %FILE-TREE-FLATTEN) calls
;;; FILE-TREE-CHILD-LISTER fresh on every invocation rather than caching a
;;; previous listing, so the very next FILE-TREE-ENTRIES call -- e.g. the
;;; next frame's presentation/layout.lisp redraw -- already reflects whatever
;;; these methods just did to disk.

(defgeneric file-tree-create-file (tree path)
  (:documentation
   "Create a new, empty regular file on disk at PATH (via *LOOM-FILESYSTEM*).
Signals an error if PATH already exists. Returns PATH.")
  (:method (tree path)
    (declare (ignorable tree))
    (if (%native-path-operation-p path)
        (%native-create-file path)
        (cl-boundary-kit:filesystem-store-file *loom-filesystem* path ""
                                               :if-exists :error))
    path))

(defgeneric file-tree-create-directory (tree path)
  (:documentation
   "Create a new, empty directory on disk at PATH (via *LOOM-FILESYSTEM*). Signals
an error if PATH already exists. Returns PATH.")
  (:method (tree path)
    (declare (ignorable tree))
    (if (%native-path-operation-p path)
        (progn
          (when (%native-path-exists-p path)
            (error "file-tree-create-directory: ~A already exists" path))
          (%native-make-directory path))
        (progn
          ;; CL-BOUNDARY-KIT:FILESYSTEM-MAKE-DIRECTORY is ENSURE-DIRECTORIES-EXIST
          ;; underneath, so it succeeds silently on an already-existing
          ;; directory rather than signalling. The "already exists" half of
          ;; this generic's contract therefore has to be checked here.
          (when (cl-boundary-kit:filesystem-directory-exists-p
                  *loom-filesystem* path)
            (error "file-tree-create-directory: ~A already exists" path))
          (cl-boundary-kit:filesystem-make-directory *loom-filesystem* path)))
    path))

(defgeneric file-tree-rename (tree old-path new-path)
  (:documentation
   "Move/rename the file or directory at OLD-PATH to NEW-PATH on disk (via
*LOOM-FILESYSTEM*). Signals an error if OLD-PATH does not exist or
NEW-PATH already does. Returns NEW-PATH.")
  (:method (tree old-path new-path)
    (declare (ignorable tree))
    (if (%native-path-operation-p old-path new-path)
        (progn
          (unless (%native-path-exists-p old-path)
            (error "file-tree-rename: ~A does not exist" old-path))
          (when (%native-path-exists-p new-path)
            (error "file-tree-rename: ~A already exists" new-path))
          (%native-rename old-path new-path))
        (progn
          ;; Both halves of the contract are checked here rather than
          ;; delegated: CL-BOUNDARY-KIT:FILESYSTEM-RENAME-FILE is
          ;; CL:RENAME-FILE underneath, which on SBCL silently overwrites an
          ;; existing destination instead of signalling.
          (unless (cl-boundary-kit:filesystem-path-exists-p
                    *loom-filesystem* old-path)
            (error "file-tree-rename: ~A does not exist" old-path))
          (when (cl-boundary-kit:filesystem-path-exists-p
                  *loom-filesystem* new-path)
            (error "file-tree-rename: ~A already exists" new-path))
          (cl-boundary-kit:filesystem-rename-file
           *loom-filesystem* old-path new-path)))
    new-path))

(defgeneric file-tree-delete (tree path)
  (:documentation
   "Delete the file or directory at PATH from disk (via CL-HOST-KIT).
Signals an error if PATH does not exist. Returns TREE.")
  (:method (tree path)
    (if (%native-path-operation-p path)
        (%native-delete-path path)
        (progn
          ;; Not *LOOM-FILESYSTEM*: recursing over the boundary's list-directory
          ;; would follow symlinks out of the tree. See this file's header
          ;; comment.
          (host-kit:delete-path path :recursive t :if-does-not-exist :error)))
    tree))

;;; ---------------------------------------------------------------------
;;; BUFFER-LOAD / BUFFER-SAVE: the real, disk-backed :METHOD bodies for the
;;; generics declared (name, docstring, argument list only) in
;;; domain/buffer.lisp. domain/buffer.lisp is deliberately pure text-storage
;;; state with no dependency on CL-HOST-KIT -- see that file's header
;;; comment -- so the actual file I/O lives here instead, same split as
;;; FILE-TREE-CREATE-FILE and friends above.
;;; ---------------------------------------------------------------------

(defmethod buffer-load (path)
  (let ((content (if (%native-path-operation-p path)
                     (%native-read-file path)
                     (cl-boundary-kit:filesystem-read-file
                      *loom-filesystem* path))))
    (let ((buffer (make-buffer :name (file-namestring path)
                               :path path
                               :initial-content content)))
      (buffer-set-major-mode buffer (major-mode-for-path path))
      buffer)))

(defmethod buffer-save (buffer)
  (let ((path (buffer-path buffer)))
    (unless path
      (error "buffer-save: buffer ~A has no associated path" (buffer-name buffer)))
    (if (%native-path-operation-p path)
        (%native-write-file path (buffer-text buffer))
        (cl-boundary-kit:filesystem-store-file
         *loom-filesystem* path (buffer-text buffer)))
    (buffer-mark-saved buffer))
  buffer)
