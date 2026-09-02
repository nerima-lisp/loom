;;;; t/integration/commands-lsp-navigation-test-support.lisp
(in-package #:loom/test)

;;; A macro lambda-list default is evaluated when the macro expands, which for
;;; a form in this same file is during its compilation -- before a plain
;;; DEFPARAMETER at the top of the file has run. EVAL-WHEN is what makes the
;;; value exist early enough to be defaulted to.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter +lsp-navigation-capabilities+
    "{\"capabilities\":{\"completionProvider\":{},\"definitionProvider\":true}}"))

(defun %lsp-navigation-state (&key (content "foo") (path "/tmp/main.lisp"))
  "An editor state whose selected buffer is file-backed, as a request needs."
  (let* ((buffer (make-buffer :name "main.lisp"
                              :path path
                              :initial-content content))
         (tree (make-window-tree buffer 80 24)))
    (make-editor-state :window-tree tree
                       :workspaces (make-workspace-manager tree :name "main")
                       :minibuffer (make-minibuffer)
                       :keymap (make-keymap)
                       :file-tree nil
                       :renderer nil
                       :buffers (list buffer)
                       :kill-ring nil)))

(defmacro %with-lsp-navigation ((transport session buffer
                                 &key (content "foo")
                                      (capabilities
                                       +lsp-navigation-capabilities+))
                                &body body)
  "Run BODY with an initialized fake session attached to a file-backed buffer."
  (let ((buffer-binding (gensym "BUFFER-")))
    `(let* ((*editor-state* (%lsp-navigation-state :content ,content))
            (,buffer-binding (%selected-test-buffer)))
       (let ((,buffer ,buffer-binding))
         (declare (ignorable ,buffer))
         (%with-started-fake-lsp-session ((,transport ,session))
           (%fake-push-initialize-response ,transport ,capabilities)
           (lsp-session-drain ,session)
           (setf (editor-state-lsp-session *editor-state*) ,session)
           ,@body)))))

(defun %lsp-last-request-method (transport)
  (let ((messages (%fake-sent-in-order transport)))
    (gethash "method" (%parse-lsp-json (car (last messages))))))

(defun %lsp-last-request-id (transport)
  (let ((messages (%fake-sent-in-order transport)))
    (gethash "id" (%parse-lsp-json (car (last messages))))))


