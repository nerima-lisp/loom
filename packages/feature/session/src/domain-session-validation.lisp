;;;; packages/feature/session/src/domain-session-validation.lisp
(in-package #:loom/feature/session)

(defun validate-session-snapshot (snapshot)
  "Validate SNAPSHOT's shape and cross-references, returning SNAPSHOT.

This is the single domain gate used both before writing a session and after
reading one. It rejects malformed or out-of-range state before any editor
state is replaced."
  (unless (typep snapshot 'session-snapshot)
    (error "validate-session-snapshot: not a session snapshot: ~S" snapshot))
  (let ((buffers (session-snapshot-buffers snapshot)))
    (unless (and (listp buffers) (plusp (length buffers)))
      (error "validate-session-snapshot: a session needs one or more buffers"))
    (dolist (buffer buffers)
      (%validate-session-buffer buffer))
    (%validate-session-metadata snapshot)
    (%validate-session-workspaces snapshot (length buffers))
    snapshot))
