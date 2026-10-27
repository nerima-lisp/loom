(in-package #:loom/feature/lsp)

(progn
  (defparameter +lsp-config-file-name+ ".loom-lsp"
    "The project-local file used to discover an LSP server command.")
  (defparameter +lsp-config-max-characters+ 4096))

(progn
  (defun %lsp-command-argv (line)
  (when (stringp line)
    (let ((index 0)
          (length (length line))
          (arguments nil))
      (loop while (< index length)
            do (if (member (char line index) '(#\Space #\Tab) :test #'char=)
                   (incf index)
                   (let ((start index))
                     (loop while (and (< index length)
                                      (not (member (char line index)
                                                   '(#\Space #\Tab)
                                                   :test #'char=)))
                           do (let ((character (char line index)))
                                (when (or (< (char-code character) 32)
                                          (= (char-code character) 127)
                                          (member character
                                                  '(#\; #\| #\& #\< #\>
                                                    #\$ #\` #\' #\" #\\
                                                    #\* #\? #\( #\) #\[
                                                    #\] #\{ #\} #\#)
                                                  :test #'char=))
                                  (return-from %lsp-command-argv nil)))
                              (incf index))
                     (push (subseq line start index) arguments))))
      (let ((argv (nreverse arguments)))
        (if (and argv (string= (first argv) "exec"))
            (rest argv)
            argv)))))

  (defun %lsp-config-command (contents)
    (when (stringp contents)
      (with-input-from-string (stream contents)
        (loop for line = (read-line stream nil nil)
              while line
              for candidate = (string-trim '(#\Space #\Tab #\Return) line)
              unless (or (string= candidate "")
                         (char= (char candidate 0) #\#))
                do (return (%lsp-command-argv candidate))))))
)

(defun %lsp-config-path (path)
  (let ((root
          (loom/feature/project:project-root-for-path
           path
           (lambda (directory)
             (probe-file
              (merge-pathnames +lsp-config-file-name+ directory))))))
    (when root
      (values root (merge-pathnames +lsp-config-file-name+ root)))))

(progn
  (defun %lsp-read-config-contents (configuration)
  (handler-case
      (with-open-file (stream configuration
                              :direction :input
                              :external-format :utf-8)
        (let ((output (make-string-output-stream)))
          (loop for count from 0
                for character = (read-char stream nil nil)
                do (cond
                     ((null character)
                      (return-from %lsp-read-config-contents
                        (get-output-stream-string output)))
                     ((= count +lsp-config-max-characters+)
                      (return-from %lsp-read-config-contents nil))
                     (t (write-char character output))))))
    (error () nil)))

  (defun %lsp-read-config-command (configuration)
    (let ((contents (%lsp-read-config-contents configuration)))
      (values (%lsp-config-command contents) contents)))
)

(defun lsp-discover-command (path)
  "Return a project-local argv command, root, config path, and content identity."
  (handler-case
      (multiple-value-bind (root configuration)
          (%lsp-config-path path)
        (multiple-value-bind (command contents)
            (if configuration
                (%lsp-read-config-command configuration)
                (values nil nil))
          (if command
              (values command
                      root
                      configuration
                      (list (namestring (truename configuration)) contents))
              (values nil nil nil))))
    (file-error () (values nil nil nil))))
