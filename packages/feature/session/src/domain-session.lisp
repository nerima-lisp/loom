;;;; packages/feature/session/src/domain-session.lisp
;;;;
;;;; Domain layer: validated, side-effect-free session snapshots. The snapshot
;;;; contains enough editor state to rebuild buffers and a window tree, but it
;;;; deliberately contains no pathname objects, streams, or terminal handles.
;;;; Serialization and filesystem policy live in infrastructure/session-store.lisp;
;;;; conversion to and from EDITOR-STATE lives in application/commands-session.lisp.
(in-package #:loom/feature/session)

(defstruct session-buffer-snapshot
  "Serializable state for one registered editor buffer."
  name
  path
  text
  point-line
  point-column
  mark-line
  mark-column
  modified-p)

(defstruct session-bookmark-snapshot
  "Serializable state for one named bookmark."
  name
  path
  buffer-name
  line
  column)

(defstruct session-workspace-snapshot
  "Serializable state for one named workspace.

LAYOUT uses the indexes of SESSION-SNAPSHOT-BUFFERS."
  name
  layout
  selected-window-index)

(defstruct session-snapshot
  "Validated, serializable state for one Loom editing session.

WORKSPACES contains the named workspace views. Each workspace's LAYOUT is a
nested (:LEAF BUFFER-INDEX SCROLL-LINE) / (:SPLIT DIRECTION CHILD-1 CHILD-2)
description. Buffer indexes refer to the order of SESSION-SNAPSHOT-BUFFERS,
and each workspace's SELECTED-WINDOW-INDEX refers to the depth-first order of
leaves in its LAYOUT."
  buffers
  recent-files
  bookmarks
  command-history
  workspaces
  current-workspace-index)

(defun %session-nonnegative-integer-p (value)
  (and (integerp value) (<= 0 value)))

(defun %session-nonempty-string-p (value)
  (and (stringp value)
       (plusp (length value))))

(defun %session-optional-string-p (value)
  (or (null value)
      (%session-nonempty-string-p value)))

(defun %session-mark-valid-p (line column)
  (or (and (null line) (null column))
      (and (%session-nonnegative-integer-p line)
           (%session-nonnegative-integer-p column))))

(defun %validate-session-buffer (buffer)
  (unless (typep buffer 'session-buffer-snapshot)
    (error "validate-session-snapshot: invalid buffer snapshot ~S" buffer))
  (unless (and (stringp (session-buffer-snapshot-name buffer))
               (or (null (session-buffer-snapshot-path buffer))
                   (stringp (session-buffer-snapshot-path buffer)))
               (stringp (session-buffer-snapshot-text buffer))
               (%session-nonnegative-integer-p
                (session-buffer-snapshot-point-line buffer))
               (%session-nonnegative-integer-p
                (session-buffer-snapshot-point-column buffer))
               (%session-mark-valid-p
                (session-buffer-snapshot-mark-line buffer)
                (session-buffer-snapshot-mark-column buffer))
               (member (session-buffer-snapshot-modified-p buffer)
                       '(nil t)
                       :test #'eq))
    (error "validate-session-snapshot: malformed buffer snapshot ~S" buffer))
  buffer)

(defun %validate-session-bookmark (bookmark)
  (unless (typep bookmark 'session-bookmark-snapshot)
    (error "validate-session-snapshot: invalid bookmark snapshot ~S"
           bookmark))
  (unless (and (%session-nonempty-string-p
                (session-bookmark-snapshot-name bookmark))
               (%session-optional-string-p
                (session-bookmark-snapshot-path bookmark))
               (%session-optional-string-p
                (session-bookmark-snapshot-buffer-name bookmark))
               (%session-nonnegative-integer-p
                (session-bookmark-snapshot-line bookmark))
               (%session-nonnegative-integer-p
                (session-bookmark-snapshot-column bookmark)))
    (error "validate-session-snapshot: malformed bookmark snapshot ~S"
           bookmark))
  bookmark)

(defun %validate-session-layout (layout buffer-count)
  "Validate indexed LAYOUT and return its number of leaf windows."
  (labels ((visit (node)
             (unless (listp node)
               (error "validate-session-snapshot: malformed layout node ~S" node))
             (case (first node)
               (:leaf
                (unless (and (= (length node) 3)
                             (%session-nonnegative-integer-p (second node))
                             (< (second node) buffer-count)
                             (%session-nonnegative-integer-p (third node)))
                  (error "validate-session-snapshot: malformed leaf ~S" node))
                1)
               (:split
                (unless (and (= (length node) 4)
                             (member (second node) '(:horizontal :vertical)))
                  (error "validate-session-snapshot: malformed split ~S" node))
                (+ (visit (third node))
                   (visit (fourth node))))
               (otherwise
                (error "validate-session-snapshot: unknown layout node ~S"
                       (first node))))))
    (visit layout)))

(defun %validate-session-workspace (workspace buffer-count)
  (unless (typep workspace 'session-workspace-snapshot)
    (error "validate-session-snapshot: invalid workspace snapshot ~S"
           workspace))
  (unless (%session-nonempty-string-p
          (session-workspace-snapshot-name workspace))
    (error "validate-session-snapshot: workspace names must be non-empty strings"))
  (let ((window-count
          (%validate-session-layout
           (session-workspace-snapshot-layout workspace)
           buffer-count))
        (selected-index
          (session-workspace-snapshot-selected-window-index workspace)))
    (unless (and (%session-nonnegative-integer-p selected-index)
                 (< selected-index window-count))
      (error "validate-session-snapshot: workspace selected window index ~S is out of range"
             selected-index)))
  workspace)

(defun %validate-session-metadata (snapshot)
  "Validate the session collections that do not describe window trees."
  (let ((recent-files (session-snapshot-recent-files snapshot))
        (bookmarks (session-snapshot-bookmarks snapshot))
        (command-history (session-snapshot-command-history snapshot)))
    (unless (and (listp recent-files)
                 (every #'%session-nonempty-string-p recent-files))
      (error "validate-session-snapshot: recent files must be a list of non-empty strings"))
    (unless (and (listp bookmarks)
                 (every #'%validate-session-bookmark bookmarks))
      (error "validate-session-snapshot: bookmarks must be a list of valid snapshots"))
    (let ((names (mapcar #'session-bookmark-snapshot-name bookmarks)))
      (unless (= (length names)
                 (length (remove-duplicates names :test #'string=)))
        (error "validate-session-snapshot: bookmark names must be unique: ~S"
               names)))
    (unless (and (listp command-history)
                 (every #'stringp command-history))
      (error "validate-session-snapshot: command history must be a list of strings")))
  snapshot)

(defun %validate-session-workspaces (snapshot buffer-count)
  "Validate workspace views and the active workspace index."
  (let ((workspaces (session-snapshot-workspaces snapshot)))
    (unless (and (listp workspaces) (plusp (length workspaces)))
      (error "validate-session-snapshot: workspaces must be a non-empty list"))
    (dolist (workspace workspaces)
      (%validate-session-workspace workspace buffer-count))
    (let ((names (mapcar #'session-workspace-snapshot-name workspaces))
          (current-index (session-snapshot-current-workspace-index snapshot)))
      (unless (= (length names)
                 (length (remove-duplicates names :test #'string-equal)))
        (error "validate-session-snapshot: workspace names must be unique: ~S"
               names))
      (unless (and (%session-nonnegative-integer-p current-index)
                   (< current-index (length workspaces)))
        (error "validate-session-snapshot: current workspace index ~S is out of range"
               current-index))))
  snapshot)

(defgeneric validate-session-snapshot (snapshot)
  (:documentation
   "Validate SNAPSHOT's shape and cross-references, returning SNAPSHOT.

This is the single domain gate used both before writing a session and after
reading one. It rejects malformed or out-of-range state before any editor
state is replaced.")
  (:method (snapshot)
    (unless (typep snapshot 'session-snapshot)
      (error "validate-session-snapshot: not a session snapshot: ~S" snapshot))
    (let ((buffers (session-snapshot-buffers snapshot)))
      (unless (and (listp buffers) (plusp (length buffers)))
        (error "validate-session-snapshot: a session needs one or more buffers"))
      (dolist (buffer buffers)
        (%validate-session-buffer buffer))
      (%validate-session-metadata snapshot)
      (%validate-session-workspaces snapshot (length buffers))
      snapshot)))
