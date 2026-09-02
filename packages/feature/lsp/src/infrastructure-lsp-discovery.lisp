;;;; packages/feature/lsp/src/infrastructure-lsp-discovery.lisp
;;;;
;;;; Infrastructure helpers for discovering a project-local LSP command.
(in-package #:loom/feature/lsp)

(defparameter +lsp-config-file-name+ ".loom-lsp"
  "The project-local file used to discover an LSP server command.")

(defun %lsp-config-command (contents)
  "Return the first non-empty, non-comment command line in CONTENTS.

Comment lines begin with `#` after leading whitespace.  The complete line is
preserved after trimming surrounding whitespace so shell commands can retain
their arguments and quoting."
  (when (stringp contents)
    (with-input-from-string (stream contents)
      (loop for line = (read-line stream nil nil)
            while line
            for candidate = (string-trim '(#\Space #\Tab #\Return) line)
            unless (or (string= candidate "")
                       (char= (char candidate 0) #\#))
              do (return candidate)))))

(defun %lsp-config-path (path)
  (let ((root
          (loom/feature/project:project-root-for-path
           path
           (lambda (directory)
             (probe-file
              (merge-pathnames +lsp-config-file-name+ directory))))))
    (when root
      (values root (merge-pathnames +lsp-config-file-name+ root)))))

(defun %lsp-read-config-command (configuration)
  (let ((contents
          (handler-case
              (host-kit:read-file-string configuration)
            (file-error (condition)
              (declare (ignore condition))
              nil)
            (pathname-error (condition)
              (declare (ignore condition))
              nil))))
    (%lsp-config-command contents)))

(defun lsp-discover-command (path)
  "Discover a project-local LSP command for PATH.

The nearest ancestor containing `.loom-lsp` is used.  Its first non-empty,
non-comment line is treated as a shell command.  Return three values: the
command, the project root, and the configuration pathname.  Return three NIL
values when no usable configuration is found.  Reading a malformed or
unreadable configuration is intentionally treated as no discovery so the
interactive command can continue to offer its explicit prompt."
  (multiple-value-bind (root configuration)
      (%lsp-config-path path)
    (let ((command (and configuration
                        (%lsp-read-config-command configuration))))
      (if command
          (values command root configuration)
          (values nil nil nil)))))
