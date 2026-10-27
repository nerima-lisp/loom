(in-package #:loom)

(progn
  (defun %write-terminal-clipboard-base64 (text stream)
    (let* ((octets (sb-ext:string-to-octets text :external-format :utf-8))
           (alphabet "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"))
      (loop for index from 0 below (length octets) by 3
            for remaining = (- (length octets) index)
            for first = (aref octets index)
            for second = (if (> remaining 1) (aref octets (1+ index)) 0)
            for third = (if (> remaining 2) (aref octets (+ index 2)) 0)
            for packed = (logior (ash first 16) (ash second 8) third)
            do (write-char (char alphabet (ldb (byte 6 18) packed)) stream)
               (write-char (char alphabet (ldb (byte 6 12) packed)) stream)
               (write-char (if (> remaining 1)
                               (char alphabet (ldb (byte 6 6) packed))
                               #\=)
                           stream)
               (write-char (if (> remaining 2)
                               (char alphabet (ldb (byte 6 0) packed))
                               #\=)
                           stream))))

  (defun %write-terminal-clipboard-request (stream text)
    (write-char (code-char 27) stream)
    (write-string "]52;c;" stream)
    (%write-terminal-clipboard-base64 text stream)
    (write-char (code-char 7) stream))

  (defun %drain-terminal-clipboard-requests (stream)
    (let ((requests
            (loom/core/editor-session:drain-terminal-clipboard-requests
             (editor-state-session *editor-state*))))
      (when requests
        (dolist (text requests)
          (loom/feature/clipboard:clipboard-copy-text text)
          (%write-terminal-clipboard-request stream text))
        (finish-output stream))))

  (defun %render-event-loop-frame (stream render-frame-function)
    "Refresh application state before presenting a frame through the root adapter."
    (loom/feature/file-tree:refresh-file-tree-runtime *editor-state*)
    (loom/feature/lsp:lsp-refresh-editor-state *editor-state*)
    (prog1 (funcall render-frame-function stream)
      (%drain-terminal-clipboard-requests stream))))

