;;;; packages/feature/session/src/domain-session-validation-layout.lisp
(in-package #:loom/feature/session)

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

(defun %validate-session-workspaces (snapshot buffer-count)
  "Validate workspace views and the active workspace index."
  (let ((workspaces (session-snapshot-workspaces snapshot)))
    (unless (consp workspaces)
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
