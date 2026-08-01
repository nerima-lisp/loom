;;;; t/terminal-renderer-test.lisp
;;;;
;;;; Infrastructure layer: LOOM-RENDERER-* against a real CL-TTY-KIT
;;;; renderer/screen pair.
;;;;
;;;; LOOM-RENDERER-DRAW-BUFFER is exercised against a tiny local test-double
;;;; buffer class rather than a real DOMAIN/BUFFER.LISP MAKE-BUFFER buffer:
;;;; at the time this file was written, domain/buffer.lisp's generics were
;;;; still their stub "not yet implemented" bodies. The double only
;;;; satisfies BUFFER-LINE-COUNT/BUFFER-LINE -- the two generics
;;;; LOOM-RENDERER-DRAW-BUFFER actually calls -- via DEFMETHOD specialized on
;;;; a test-only class, so once a real domain buffer exists these tests can
;;;; switch to MAKE-BUFFER without changing anything else.
(in-package #:loom/test)

(defclass fake-buffer ()
  ((lines :initarg :lines :reader fake-buffer-lines)))

(defmethod buffer-line-count ((buffer fake-buffer))
  (length (fake-buffer-lines buffer)))

(defmethod buffer-line ((buffer fake-buffer) line-number)
  (nth line-number (fake-buffer-lines buffer)))

(describe
  "make-loom-renderer / loom-renderer-cl-tty-renderer"
  (it
    "wraps a real cl-tty-kit renderer of the requested size"
    (let* ((renderer (make-loom-renderer 10 4))
           (cl-tty-renderer (loom-renderer-cl-tty-renderer renderer)))
      (expect (typep cl-tty-renderer 'cl-tty-kit:renderer) :to-be-truthy)
      (expect (cl-tty-kit:renderer-width cl-tty-renderer) :to-equal 10)
      (expect (cl-tty-kit:renderer-height cl-tty-renderer) :to-equal 4))))

(describe
  "loom-renderer-draw-buffer"
  (it
    "writes buffer lines into the renderer's screen at the given rect"
    (let* ((buffer (make-instance 'fake-buffer
                                   :lines (list "hello world" "second line, too long")))
           (renderer (make-loom-renderer 10 3)))
      (loom-renderer-draw-buffer renderer buffer 0 0 5 2)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-to-string screen)
                :to-equal
                (format nil "hello     ~%secon     ~%          ")))))

  (it
    "leaves rows past the buffer's line count untouched"
    (let* ((buffer (make-instance 'fake-buffer :lines (list "only line")))
           (renderer (make-loom-renderer 6 3)))
      (loom-renderer-draw-buffer renderer buffer 0 0 6 3)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-to-string screen)
                :to-equal
                (format nil "only l~%      ~%      "))))))

(describe
  "loom-renderer-present"
  (it
    "flushes to the given stream and returns the renderer"
    (let* ((buffer (make-instance 'fake-buffer :lines (list "hi")))
           (renderer (make-loom-renderer 4 1)))
      (loom-renderer-draw-buffer renderer buffer 0 0 4 1)
      (let ((output (make-string-output-stream)))
        (expect (loom-renderer-present renderer :stream output) :to-be renderer)
        (expect (> (length (get-output-stream-string output)) 0) :to-be-truthy)))))

(describe
  "loom-renderer-resize"
  (it
    "resizes the underlying cl-tty-kit renderer and returns the renderer"
    (let* ((renderer (make-loom-renderer 4 4)))
      (expect (loom-renderer-resize renderer 8 2) :to-be renderer)
      (let ((cl-tty-renderer (loom-renderer-cl-tty-renderer renderer)))
        (expect (cl-tty-kit:renderer-width cl-tty-renderer) :to-equal 8)
        (expect (cl-tty-kit:renderer-height cl-tty-renderer) :to-equal 2)))))
