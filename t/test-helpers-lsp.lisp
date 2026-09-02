;;;; t/test-helpers-lsp.lisp
(in-package #:loom/test)

(defclass %fake-lsp-transport ()
  ((sent :initform nil :accessor %fake-sent)
   (incoming :initform nil :accessor %fake-incoming)
   (closed-p :initform nil :accessor %fake-closed-p)
   (send-error :initform nil :accessor %fake-send-error)))

(defmethod loom/feature/lsp::lsp-transport-send ((transport %fake-lsp-transport) json)
  (when (%fake-send-error transport)
    (error "~A" (%fake-send-error transport)))
  (push json (%fake-sent transport)))

(defmethod loom/feature/lsp::lsp-transport-receive ((transport %fake-lsp-transport))
  (when (%fake-incoming transport)
    (pop (%fake-incoming transport))))

(defmethod loom/feature/lsp::lsp-transport-close ((transport %fake-lsp-transport))
  (setf (%fake-closed-p transport) t)
  transport)

(defun %fake-push-incoming (transport json)
  (setf (%fake-incoming transport)
        (append (%fake-incoming transport) (list json))))

(defun %fake-push-and-drain (transport session json)
  (%fake-push-incoming transport json)
  (lsp-session-drain session)
  session)

(defun %fake-sent-in-order (transport)
  (reverse (%fake-sent transport)))

(defun %parse-lsp-json (json)
  (json-kit:parse
   json
   :object-type :hash-table
   :array-type :list
   :duplicate-key-policy :error
   :null-value json-kit:+json-null+
   :false-value nil))

(defun %fake-sent-message (transport index)
  (%parse-lsp-json (nth index (%fake-sent-in-order transport))))

(defun %fake-push-initialize-response (transport &optional (result "{}"))
  (%fake-push-incoming
   transport
   (format nil "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":~A}" result)))

(defun %fake-push-publish-diagnostics (transport path diagnostics-json)
  (%fake-push-incoming
   transport
   (format nil
           "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\",\"params\":{\"uri\":\"~A\",\"diagnostics\":~A}}"
           (lsp-path-uri path)
           diagnostics-json)))

(defun %expect-session-error-after-message (transport session json)
  (setf (lsp-session-last-error session) nil)
  (%fake-push-and-drain transport session json)
  (expect (lsp-session-last-error session)
          :to-be-truthy))

(defmacro %expect-ignored-message ((transport session) json &body assertions)
  `(progn
     (setf (lsp-session-last-error ,session) nil)
     (%fake-push-and-drain ,transport ,session ,json)
     (expect (lsp-session-last-error ,session) :to-be nil)
     ,@assertions))

(defmacro %expect-initialize-error ((transport session) json expected)
  `(progn
     (%fake-push-and-drain ,transport ,session ,json)
     (let ((expected-value ,expected))
       (if (eq expected-value t)
           (expect (lsp-session-last-error ,session) :to-be-truthy)
           (expect (lsp-session-last-error ,session) :to-equal expected-value)))
     (expect (lsp-session-initialized-p ,session) :to-be nil)))

(defmacro %with-fake-lsp-session (((transport session) &rest session-arguments)
                                  &body body)
  `(let* ((,transport (make-instance '%fake-lsp-transport))
          (,session (make-lsp-session :transport ,transport
                                      ,@session-arguments)))
     (unwind-protect
          (progn ,@body)
       (lsp-session-stop ,session))))

(defmacro %with-started-fake-lsp-session (((transport session)
                                           &rest session-arguments)
                                          &body body)
  `(%with-fake-lsp-session ((,transport ,session) ,@session-arguments)
     (lsp-session-start ,session)
     ,@body))

(defmacro %with-initialized-fake-lsp-session (((transport session)
                                               &rest session-arguments)
                                              &body body)
  `(%with-started-fake-lsp-session ((,transport ,session) ,@session-arguments)
     (%fake-push-initialize-response ,transport)
     (lsp-session-drain ,session)
     ,@body))
