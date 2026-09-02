;;;; t/integration/commands-lsp-completion-popup-test.lisp
(in-package #:loom/test)

(describe
  "completion popup keys"
  (it
    "reports no active popup before completion starts"
    (%with-lsp-navigation (transport session buffer :content "foo")
      (expect (loom::%completion-popup-active-p) :to-be nil)
      (expect (loom::%completion-popup-handle-key (%char-key #\x))
              :to-be nil)))

  (it
    "does not handle acceptance keys without an active popup"
    (%with-lsp-navigation (transport session buffer :content "foo")
      (expect (loom::%completion-popup-handle-key (%special-key :enter))
              :to-be nil)
      (expect (buffer-text buffer) :to-equal "foo")))

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
    "accepts with Tab and dismisses with Escape"
    (%with-lsp-navigation (transport session buffer :content "foo")
      (buffer-set-point buffer 0 3)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobar\"}]}"
               (%lsp-last-request-id transport)))
      (expect (loom::%completion-popup-handle-key (%special-key :tab))
              :to-be-truthy)
      (expect (buffer-text buffer) :to-equal "foobar")
      (buffer-set-point buffer 0 6)
      (loom/feature/lsp:lsp-completion-at-point)
      (%fake-push-and-drain
       transport session
       (format nil
               "{\"jsonrpc\":\"2.0\",\"id\":~D,\"result\":[{\"label\":\"foobarbaz\"}]}"
               (%lsp-last-request-id transport)))
      (expect (loom::%completion-popup-handle-key (%special-key :escape))
              :to-be-truthy)
      (expect (editor-state-completion *editor-state*) :to-be nil)
      (expect (buffer-text buffer) :to-equal "foobar")))

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
    "does not insert a candidate anchored in another buffer"
    (%with-selected-buffer-state (buffer "foo")
      (buffer-set-point buffer 0 3)
      (let ((other-buffer (make-buffer :initial-content "bar")))
        (setf (editor-state-completion *editor-state*)
              (make-editor-completion other-buffer 0 3
                                       '(("barbaz" . "barbaz"))))
        (expect (loom::%completion-popup-handle-key (%special-key :enter))
                :to-be-truthy)
        (expect (buffer-text buffer) :to-equal "foo")
        (expect (buffer-text other-buffer) :to-equal "bar")
        (expect (editor-state-completion *editor-state*) :to-be nil))))

  (it
    "does not insert a candidate anchored on another line"
    (%with-selected-buffer-state (buffer "foo\nbar")
      (buffer-set-point buffer 0 3)
      (setf (editor-state-completion *editor-state*)
            (make-editor-completion buffer 1 0
                                     '(("baz" . "baz"))))
      (expect (loom::%completion-popup-handle-key (%special-key :enter))
              :to-be-truthy)
      (expect (buffer-text buffer) :to-equal "foo\nbar")
      (expect (editor-state-completion *editor-state*) :to-be nil)))

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

