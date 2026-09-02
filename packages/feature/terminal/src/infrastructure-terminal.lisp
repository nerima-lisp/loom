(in-package #:loom/feature/terminal)

(declaim (special loom:*editor-state*))

(defun %terminal-selected-buffer (state)
  (let ((window-tree (and state (editor-state-window-tree state))))
    (when window-tree
      (window-buffer (window-tree-selected-window window-tree)))))

(defun %terminal-directory-for-buffer (buffer)
  (let ((path (and buffer (buffer-path buffer))))
    (if path
        (namestring
         (make-pathname :name nil
                        :type nil
                        :version nil
                        :defaults (pathname path)))
        (uiop:getcwd))))

(defun %terminal-buffer-name (state)
  (let ((buffer-names (make-hash-table :test #'equal)))
    (dolist (buffer (editor-state-buffers state))
      (setf (gethash (buffer-name buffer) buffer-names) t))
    (loop for index from 1
          for name = (if (= index 1)
                         "*Loom-Terminal*"
                         (format nil "*Loom-Terminal<~D>*" index))
          unless (gethash name buffer-names)
            return name)))

(defun start-terminal-session (&key
                                  (program (or (uiop:getenv "SHELL") "/bin/sh"))
                                  (args nil)
                                  directory
                                  (state *editor-state*))
  "Start PROGRAM in a PTY and return its terminal session."
  (unless state
    (error "An editor state is required to start a terminal session."))
  (let* ((selected-buffer (%terminal-selected-buffer state))
         (working-directory
           (or directory
               (%terminal-directory-for-buffer selected-buffer)))
         (name (%terminal-buffer-name state))
         (pty (cl-tty-kit:make-pty :program program
                                   :args args
                                   :directory working-directory)))
    (handler-case
        (let ((buffer (make-buffer :name name)))
          (buffer-set-read-only buffer t)
          (%make-terminal-session name
                                  program
                                  args
                                  working-directory
                                  buffer
                                  pty))
      (error (condition)
        (cl-tty-kit:close-pty pty)
        (error condition)))))

(defun terminal-session-for-buffer (buffer &optional (state *editor-state*))
  (find buffer
        (and state (editor-state-terminal-sessions state))
        :key #'terminal-session-buffer
        :test #'eq))

(defun poll-terminal-sessions (&optional (state *editor-state*))
  "Poll every live terminal owned by STATE."
  (dolist (session (and state (copy-list (editor-state-terminal-sessions state))))
    (terminal-session-poll session))
  state)

(defun resize-terminal-sessions (columns rows &optional (state *editor-state*))
  "Resize every live terminal session owned by STATE."
  (dolist (session (and state (editor-state-terminal-sessions state)))
    (terminal-session-resize session columns rows))
  state)
