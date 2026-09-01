;;;; t/integration/commands-lsp-navigation-test.lisp
;;;;
;;;; Completion and definition driven end to end: the request goes out, the
;;;; reply comes back on a drain, and the popup or the jump is the result.
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

(describe
  "LSP completion data transformations"
  (it-each
      (("foo" 3 0)
       ("foo-bar" 7 0)
       ("foo +" 5 4)
       ("" 0 0))
      "finds the symbol prefix boundary in ~S at column ~A"
      (content column expected)
    (let ((buffer (make-buffer :initial-content content)))
      (expect (loom/feature/lsp::%lsp-completion-prefix-column
               buffer 0 column)
              :to-equal expected)))

  (it
    "renders completion details without changing insertion text"
    (let ((item (make-lsp-completion-item
                 "map"
                 :insert-text "mapcar"
                 :detail "function")))
      (expect (loom/feature/lsp::%lsp-completion-popup-items (list item))
              :to-equal '(("map  function" . "mapcar")))))

  (it
    "uses the label when completion detail is absent"
    (let ((item (make-lsp-completion-item
                 "lambda"
                 :insert-text nil
                 :detail nil)))
      (expect (loom/feature/lsp::%lsp-completion-popup-items (list item))
              :to-equal '(("lambda" . "lambda")))))
  )

(describe
  "LSP completion at point"
  (it
    "reports the missing session without sending a request"
    (let ((*editor-state* (%lsp-navigation-state)))
      (loom/feature/lsp:lsp-completion-at-point)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No LSP session for this buffer")))

  (it
    "reports the missing file path without sending a request"
    (%with-lsp-navigation (transport session buffer)
      (setf (loom::%buffer-path buffer) nil)
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-completion-at-point)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "No LSP session for this buffer")
        (expect (length (%fake-sent-in-order transport)) :to-equal before))))

  (it
    "says so and sends nothing when the server does not provide completion"
    (%with-lsp-navigation (transport session buffer :capabilities "{}")
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-completion-at-point)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "Server does not provide completion")
        (expect (length (%fake-sent-in-order transport)) :to-equal before)
        (expect (editor-state-completion *editor-state*) :to-be nil))))

  (it
    "sends textDocument/completion and shows the reply as a popup"
    (%with-lsp-navigation (transport session buffer)
      (buffer-set-point buffer 0 3)
      (loom/feature/lsp:lsp-completion-at-point)
      (expect (%lsp-last-request-method transport)
              :to-equal "textDocument/completion")
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"},{\"label\":\"foobaz\"}]}"
               (%lsp-last-request-id transport)))
      (let ((completion (editor-state-completion *editor-state*)))
        (expect completion :to-be-truthy)
        (expect (mapcar #'editor-completion-item-label
                        (editor-completion-items completion))
                :to-equal '("foobar" "foobaz"))
        (expect (editor-completion-column completion) :to-equal 0))))

  (it
    "anchors the popup at the start of the symbol being completed"
    (%with-lsp-navigation (transport session buffer :content "(list foo")
      (buffer-set-point buffer 0 9)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"}]}"
               (%lsp-last-request-id transport)))
      (expect (editor-completion-column
               (editor-state-completion *editor-state*))
              :to-equal 6)))

  (it
    "reports an empty reply rather than opening an empty popup"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[]}"
               (%lsp-last-request-id transport)))
      (expect (editor-state-completion *editor-state*) :to-be nil)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No completions")))

  (it
    "reports a server error instead of leaving the request hanging"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"error\":{\"code\":-32603,\"message\":\"boom\"}}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "Completion failed: boom")
      (expect (editor-state-completion *editor-state*) :to-be nil))))

(describe
  "completion popup keys"
  (it
    "reports no active popup before completion starts"
    (%with-lsp-navigation (transport session buffer :content "foo")
      (expect (loom::%completion-popup-active-p) :to-be nil)
      (expect (loom::%completion-popup-handle-key (%char-key #\x))
              :to-be nil)))

  (it
    "ignores popup input when there is no editor state"
    (let ((loom::*editor-state* nil))
      (expect (loom::%completion-popup-active-p) :to-be nil)
      (expect (loom::%completion-popup-dismiss) :to-be nil)
      (expect (loom::%completion-popup-handle-key (%char-key #\x))
              :to-be nil)))

  (it
    "lets the active popup consume a key before ordinary dispatch"
    (%with-lsp-navigation (transport session buffer :content "foo")
      (buffer-set-point buffer 0 3)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"},{\"label\":\"foobaz\"}]}"
               (%lsp-last-request-id transport)))
      (let* ((event (%special-key :down))
             (decision (loom::%make-input-routing-decision
                        :minibuffer (editor-state-minibuffer *editor-state*)))
             (keymap-state (make-keymap-state (make-keymap))))
        (expect (loom::%dispatch-key-event-action event keymap-state decision)
                :to-equal :handled)
        (expect (editor-completion-item-label
                 (editor-completion-selected
                  (editor-state-completion *editor-state*)))
                :to-equal "foobaz"))))

  (it
    "moves the selection and inserts the chosen candidate over the prefix"
    (%with-lsp-navigation (transport session buffer :content "(list foo")
      (buffer-set-point buffer 0 9)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"},{\"label\":\"foobaz\"}]}"
               (%lsp-last-request-id transport)))
      (expect (loom::%completion-popup-handle-key (%control-key #\n))
              :to-be-truthy)
      (expect (loom::%completion-popup-handle-key (%control-key #\p))
              :to-be-truthy)
      (expect (loom::%completion-popup-handle-key (%control-key #\n))
              :to-be-truthy)
      (expect (loom::%completion-popup-handle-key (%special-key :enter))
              :to-be-truthy)
      (expect (buffer-text buffer) :to-equal "(list foobaz")
      (expect (editor-state-completion *editor-state*) :to-be nil)))

  (it
    "wraps the selection and returns to the first candidate"
    (%with-lsp-navigation (transport session buffer :content "foo")
      (buffer-set-point buffer 0 3)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"},{\"label\":\"foobaz\"}]}"
               (%lsp-last-request-id transport)))
      (loom::%completion-popup-handle-key (%special-key :down))
      (loom::%completion-popup-handle-key (%special-key :down))
      (expect (editor-completion-index (editor-state-completion *editor-state*))
              :to-equal 0)))

  (it
    "closes on C-g without touching the buffer"
    (%with-lsp-navigation (transport session buffer :content "foo")
      (buffer-set-point buffer 0 3)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"}]}"
               (%lsp-last-request-id transport)))
      (expect (loom::%completion-popup-handle-key (%special-key :control-g))
              :to-be-truthy)
      (expect (editor-state-completion *editor-state*) :to-be nil)
      (expect (buffer-text buffer) :to-equal "foo")))

  (it
    "dismisses a candidate whose insertion anchor is no longer current"
    (%with-lsp-navigation (transport session buffer :content "(list foo")
      (buffer-set-point buffer 0 9)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"}]}"
               (%lsp-last-request-id transport)))
      (buffer-set-point buffer 0 0)
      (expect (loom::%completion-popup-handle-key (%special-key :enter))
              :to-be-truthy)
      (expect (editor-state-completion *editor-state*) :to-be nil)
      (expect (buffer-text buffer) :to-equal "(list foo")))

  (it
    "does not consume an unrelated key, so typing keeps typing"
    (%with-lsp-navigation (transport session buffer :content "foo")
      (buffer-set-point buffer 0 3)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"}]}"
               (%lsp-last-request-id transport)))
      (expect (loom::%completion-popup-handle-key (%char-key #\x)) :to-be nil)
      (expect (editor-state-completion *editor-state*) :to-be nil)
      (expect (buffer-text buffer) :to-equal "foo"))))

(describe
  "LSP definition jump"
  (it
    "reports the missing session without sending a request"
    (let ((*editor-state* (%lsp-navigation-state)))
      (loom/feature/lsp:lsp-find-definition)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No LSP session for this buffer")))

  (it
    "reports the missing file path without sending a request"
    (%with-lsp-navigation (transport session buffer)
      (setf (loom::%buffer-path buffer) nil)
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-find-definition)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "No LSP session for this buffer")
        (expect (length (%fake-sent-in-order transport)) :to-equal before))))

  (it
    "says so and sends nothing when the server does not provide definitions"
    (%with-lsp-navigation (transport session buffer :capabilities "{}")
      (let ((before (length (%fake-sent-in-order transport))))
        (loom/feature/lsp:lsp-find-definition)
        (expect (minibuffer-message-string
                 (editor-state-minibuffer *editor-state*))
                :to-equal "Server does not provide definitions")
        (expect (length (%fake-sent-in-order transport)) :to-equal before))))

  (it
    "moves point within the same file and returns on a pop"
    (%with-lsp-navigation (transport session buffer
                           :content (format nil "one~%two~%three"))
      (buffer-set-point buffer 2 1)
      (loom/feature/lsp:lsp-find-definition)
      (expect (%lsp-last-request-method transport)
              :to-equal "textDocument/definition")
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":{\"uri\":\"~A\",\"range\":{\"start\":{\"line\":0,\"character\":2},\"end\":{\"line\":0,\"character\":3}}}}"
               (%lsp-last-request-id transport)
               (lsp-path-uri "/tmp/main.lisp")))
      (expect buffer :to-have-point (cons 0 2))
      (loom/feature/lsp:lsp-pop-definition)
      (expect buffer :to-have-point (cons 2 1))))

  (it
    "reports an empty result rather than jumping nowhere"
    (%with-lsp-navigation (transport session buffer)
      (buffer-set-point buffer 0 1)
      (loom/feature/lsp:lsp-find-definition)
      (%fake-push-and-drain
       transport session
       (format nil "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":null}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No definition found")
      (expect buffer :to-have-point (cons 0 1))))

  (it
    "declines a definition that is not a local file"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-find-definition)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":{\"uri\":\"jar:///a.class\",\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":1}}}}"
               (%lsp-last-request-id transport)))
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "Definition is not a local file: jar:///a.class")))

  (it
    "reports having nothing to return to"
    (%with-lsp-navigation (transport session buffer)
      (loom/feature/lsp:lsp-pop-definition)
      (expect (minibuffer-message-string
               (editor-state-minibuffer *editor-state*))
              :to-equal "No jump to return from"))))

(describe
  "LSP navigation keybindings"
  (it-each
      (("C-M-i" (((:control :alt) . #\i))
        loom/feature/lsp:lsp-completion-at-point)
       ("M-." (((:alt) . #\.)) loom/feature/lsp:lsp-find-definition)
       ("M-," (((:alt) . #\,)) loom/feature/lsp:lsp-pop-definition))
      "binds ~A to its default command" (label key-sequence command)
    (declare (ignore label))
    (let ((keymap (make-keymap)))
      (loom/application:install-default-keybindings keymap)
      (expect (keymap-lookup keymap key-sequence) :to-be command))))
