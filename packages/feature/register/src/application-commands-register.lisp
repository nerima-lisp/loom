;;;; packages/feature/register/src/application-commands-register.lisp
;;;;
;;;; Application layer: Emacs-style register commands.  The domain register
;;;; bank owns values; these commands only obtain the current buffer/point and
;;;; coordinate asynchronous minibuffer prompts.
(in-package #:loom)

(defun %register-bank-for-editor ()
  "Return the current state's register bank, creating it for older fixtures."
  (or (editor-state-registers *editor-state*)
      (setf (editor-state-registers *editor-state*)
            (make-register-bank))))

(defun %parse-register-name (input)
  "Parse one register name from minibuffer INPUT."
  (let ((name (string-trim '(#\Space #\Tab) input)))
    (unless (= (length name) 1)
      (error "Register name must be exactly one character"))
    (char name 0)))

(defun %register-input-error (minibuffer condition)
  (minibuffer-message minibuffer (format nil "~A" condition))
  nil)

(defun copy-to-register ()
  "Copy the active region to a named register without changing the buffer."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "Copy region to register: "))
    (handler-case
        (let ((name (%parse-register-name input))
              (buffer (%selected-buffer)))
          (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
            (if (null mark-line)
                (minibuffer-message minibuffer "The mark is not set")
                (multiple-value-bind (start-line start-column end-line end-column)
                    (%order-region (buffer-point-line buffer)
                                   (buffer-point-column buffer)
                                   mark-line mark-column)
                  (register-bank-put-text
                   (%register-bank-for-editor)
                   name
                   (buffer-region-string buffer
                                         start-line start-column
                                         end-line end-column))
                  (minibuffer-message
                   minibuffer
                   (format nil "Copied region to register ~A" name))))))
      (error (condition)
        (%register-input-error minibuffer condition)))))

(defun insert-register ()
  "Insert the text stored in a named register at point."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "Insert register: "))
    (handler-case
        (let* ((name (%parse-register-name input))
               (text (register-bank-text (%register-bank-for-editor) name)))
          (if text
              (buffer-insert-string (%selected-buffer) text)
              (minibuffer-message
               minibuffer
               (format nil "Register ~A does not contain text" name))))
      (error (condition)
        (%register-input-error minibuffer condition)))))

(defun point-to-register ()
  "Store the selected buffer's current point in a named register."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "Point to register: "))
    (handler-case
        (let ((name (%parse-register-name input))
              (buffer (%selected-buffer)))
          (register-bank-put-position
           (%register-bank-for-editor)
           name
           (buffer-point-line buffer)
           (buffer-point-column buffer))
          (minibuffer-message
           minibuffer
           (format nil "Point stored in register ~A" name)))
      (error (condition)
        (%register-input-error minibuffer condition)))))

(defun jump-to-register ()
  "Move point to the position stored in a named register."
  (with-prompts (minibuffer (editor-state-minibuffer *editor-state*)
                 :on-cancel (minibuffer-message minibuffer "Quit"))
      ((input "Jump to register: "))
    (handler-case
        (let ((name (%parse-register-name input))
              (buffer (%selected-buffer)))
          (multiple-value-bind (line column)
              (register-bank-position (%register-bank-for-editor) name)
            (if line
                (buffer-set-point buffer line column)
                (minibuffer-message
                 minibuffer
                 (format nil "Register ~A does not contain a position" name)))))
      (error (condition)
        (%register-input-error minibuffer condition)))))
