;;;; t/terminal-renderer-test.lisp
;;;;
;;;; Infrastructure layer: LOOM-RENDERER-* against a real CL-TTY-KIT
;;;; renderer/screen pair and a real DOMAIN/BUFFER.LISP MAKE-BUFFER buffer --
;;;; LOOM-RENDERER-DRAW-BUFFER only ever calls BUFFER-LINE-COUNT/BUFFER-LINE,
;;;; both of which MAKE-BUFFER satisfies directly, so no test double is
;;;; needed here.
(in-package #:loom/test)

(defun %lines-buffer (&rest lines)
  "Return a fresh buffer whose content is LINES joined by newlines, for
LOOM-RENDERER-DRAW-BUFFER tests that only care about BUFFER-LINE-COUNT and
BUFFER-LINE, not point/mark/undo state."
  (make-buffer :initial-content (format nil "~{~A~^~%~}" lines)))

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
    (let* ((buffer (%lines-buffer "hello world" "second line, too long"))
           (renderer (make-loom-renderer 10 3)))
      (loom-renderer-draw-buffer renderer buffer 0 0 5 2)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-to-string screen)
                :to-equal
                (format nil "hello     ~%secon     ~%          ")))))

  (it
    "leaves rows past the buffer's line count untouched"
    (let* ((buffer (%lines-buffer "only line"))
           (renderer (make-loom-renderer 6 3)))
      (loom-renderer-draw-buffer renderer buffer 0 0 6 3)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-to-string screen)
                :to-equal
                (format nil "only l~%      ~%      ")))))

  (it
    "draws a viewport beginning at the requested line"
    (let* ((buffer (%lines-buffer "zero" "one" "two"))
           (renderer (make-loom-renderer 4 2)))
      (loom-renderer-draw-buffer renderer buffer 0 0 4 2 :start-line 1)
      (let ((screen (cl-tty-kit:renderer-screen (loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-to-string screen)
                :to-equal (format nil "one ~%two "))))))

(describe
  "loom-renderer-present"
  (it
    "flushes to the given stream and returns the renderer"
    (let* ((buffer (%lines-buffer "hi"))
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
