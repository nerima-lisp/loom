;;;; t/integration/main-initialize-test.lisp
(in-package #:loom/test)

(describe
  "%initialize-editor-state"
  (it
    "loads an existing file into the initial buffer and names it after the file"
    (host-kit:with-temporary-directory (dir)
      (let ((path (merge-pathnames "note.txt" dir))
            (*editor-state* nil))
        (host-kit:write-file-string "hello" path)
        (loom::%initialize-editor-state (namestring path))
        (expect (buffer-name (%selected-test-buffer)) :to-equal "note.txt")
        (expect (buffer-text (%selected-test-buffer)) :to-equal "hello"))))

  (it
    "opens an empty *scratch* buffer when given no path argument"
    (let ((*editor-state* nil))
      (loom::%initialize-editor-state nil)
      (expect (buffer-name (%selected-test-buffer)) :to-equal "*scratch*"))))

(describe
  "%loom-version"
  (it
    "returns the loom ASDF system's version string"
    (expect (loom::%loom-version) :to-equal (asdf:component-version (asdf:find-system "loom"))))

  (it
    "uses an explicit fallback when the ASDF system is unavailable"
    (with-replaced-function
        (asdf:find-system
         (lambda (name &optional error-p)
           (declare (ignore name error-p))
           nil))
      (expect (loom::%loom-version) :to-equal "unknown"))))

(describe
  "editor-state save hooks"
  (it
    "dispatches registered hooks in registration order and removes them"
    (let* ((state (make-editor-state))
           (events nil)
           (first-hook (lambda (buffer)
                         (declare (ignore buffer))
                         (push :first events)))
           (second-hook (lambda (buffer)
                          (declare (ignore buffer))
                          (push :second events))))
      (add-before-save-hook first-hook state)
      (add-before-save-hook second-hook state)
      (run-before-save-hooks :buffer state)
      (expect events :to-equal '(:second :first))
      (remove-before-save-hook first-hook state)
      (expect (editor-state-before-save-hooks state) :to-equal (list second-hook))))

  (it
    "isolates a dispatch pass when a hook changes registration"
    (let* ((state (make-editor-state))
           (events nil)
           (late-hook (lambda (buffer)
                        (declare (ignore buffer))
                        (push :late events)))
           (registering-hook (lambda (buffer)
                               (declare (ignore buffer))
                               (push :registering events)
                               (add-after-save-hook late-hook state))))
      (add-after-save-hook registering-hook state)
      (run-after-save-hooks :buffer state)
      (expect events :to-equal '(:registering))
      (run-after-save-hooks :buffer state)
      (expect events :to-equal '(:late :registering :registering)))))
