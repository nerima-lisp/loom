(in-package #:loom/test)

(describe "editor session slice registration"
  (it
   "re-registers a slice constructor by stable symbol after function redefinition"
   (let* ((slice-name (gensym "BUFFER-REGISTRY-RELOAD-"))
          (constructor-name (gensym "BUFFER-REGISTRY-STATE-"))
          (initial-constructor
            (lambda (session)
              (declare (ignore session))
              :initial)))
     (setf (symbol-function constructor-name) initial-constructor)
     (unwind-protect
         (progn
           (loom/core/editor-session:register-slice-state slice-name
                                                          constructor-name)
           (setf (symbol-function constructor-name)
                 (lambda (session)
                   (declare (ignore session))
                   :reloaded))
           (expect
            (loom/core/editor-session:register-slice-state slice-name
                                                           constructor-name)
            :to-be
            constructor-name)
           (expect
            (loom/core/editor-session:editor-session-slice
             (loom/core/editor-session:make-editor-session
              (list slice-name))
             slice-name)
            :to-be
            :reloaded))
       (fmakunbound constructor-name)))))
