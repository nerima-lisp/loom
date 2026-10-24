(in-package #:loom/feature/buffers)

(defstruct
    (buffer-registry (:constructor %make-buffer-registry)
                     (:conc-name %buffer-registry-))
  (buffers nil))

(defun %make-buffer-registry-state (session)
  (declare (ignore session))
  (%make-buffer-registry))

(register-slice-state :feature/buffers #'%make-buffer-registry-state)

(defun registered-buffers (session)
  (copy-list
   (%buffer-registry-buffers (editor-session-slice session :feature/buffers))))

(defun register-buffer (session buffer)
  (pushnew buffer
           (%buffer-registry-buffers
            (editor-session-slice session :feature/buffers))
           :test
           #'eq)
  buffer)

(defun unregister-buffer (session buffer &key reason)
  (declare (ignore reason))
  (setf (%buffer-registry-buffers
         (editor-session-slice session :feature/buffers)) (remove buffer
                                                                  (%buffer-registry-buffers
                                                                   (editor-session-slice
                                                                    session
                                                                    :feature/buffers))
                                                                  :test
                                                                  #'eq))
  buffer)
