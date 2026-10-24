(in-package #:loom/test)

(describe "buffer registry"
          (it
           "deduplicates by EQ, keeps newest buffers first, and unregisters buffers"
           (let* ((session
                   (loom/core/editor-session:make-editor-session
                    '(:feature/buffers)))
                  (older (make-buffer :name "older"))
                  (newer (make-buffer :name "newer")))
             (loom/feature/buffers:register-buffer session older)
             (loom/feature/buffers:register-buffer session newer)
             (loom/feature/buffers:register-buffer session older)
             (let ((registered
                    (loom/feature/buffers:registered-buffers session)))
               (expect (length registered) :to-equal 2)
               (expect (first registered) :to-be newer)
               (expect (second registered) :to-be older)
               (setf (cdr registered) nil)
               (let ((registered-copy
                      (loom/feature/buffers:registered-buffers session)))
                 (expect (length registered-copy) :to-equal 2)
                 (expect (first registered-copy) :to-be newer)
                 (expect (second registered-copy) :to-be older)))
             (expect (loom/feature/buffers:unregister-buffer session older)
                     :to-be
                     older)
             (let ((registered
                    (loom/feature/buffers:registered-buffers session)))
               (expect (length registered) :to-equal 1)
               (expect (first registered) :to-be newer))))
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
                   (setf (symbol-function constructor-name) (lambda (session)
                                                              (declare (ignore
                                                                        session))
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
