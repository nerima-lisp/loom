;;;; t/unit/terminal-renderer-test.lisp
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
  "make-loom-renderer / private CL-TTY-KIT renderer"
  (it
    "wraps a real cl-tty-kit renderer of the requested size"
    (let* ((renderer (make-loom-renderer 10 4))
           (cl-tty-renderer (loom::%loom-renderer-cl-tty-renderer renderer)))
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
      (let ((screen (cl-tty-kit:renderer-screen
                     (loom::%loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-to-string screen)
                :to-equal
                (format nil "hello     ~%secon     ~%          ")))))

  (it
    "leaves rows past the buffer's line count untouched"
    (let* ((buffer (%lines-buffer "only line"))
           (renderer (make-loom-renderer 6 3)))
      (loom-renderer-draw-buffer renderer buffer 0 0 6 3)
      (let ((screen (cl-tty-kit:renderer-screen
                     (loom::%loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-to-string screen)
                :to-equal
                (format nil "only l~%      ~%      ")))))

  (it
    "draws a viewport beginning at the requested line"
    (let* ((buffer (%lines-buffer "zero" "one" "two"))
           (renderer (make-loom-renderer 4 2)))
      (loom-renderer-draw-buffer renderer buffer 0 0 4 2 :start-line 1)
      (let ((screen (cl-tty-kit:renderer-screen
                     (loom::%loom-renderer-cl-tty-renderer renderer))))
        (expect (cl-tty-kit:screen-to-string screen)
                :to-equal (format nil "one ~%two "))))))

(describe
  "loom-renderer-string-width / loom-renderer-truncate-string"
  (it
    "measures and clips text in terminal cells"
    (let ((renderer (make-loom-renderer 8 1)))
      (expect (loom-renderer-string-width renderer "aあb") :to-equal 4)
      (expect (loom-renderer-truncate-string renderer "aあb" 3)
              :to-equal "aあ")
      (expect (loom-renderer-truncate-string renderer "aあb" 2)
              :to-equal "a")
      (expect (loom-renderer-truncate-string renderer "aあb" 0)
              :to-equal ""))))

(describe
  "loom-renderer-clip-index"
  (it-each
      (("aあb" 0 0 0)
       ("aあb" 1 1 0)
       ("aあb" 2 2 1)
       ("aあb" 3 2 0)
       ("aあb" 4 3 0)
       ("aあb" 9 3 0)
       ("abc" 2 2 0)
       ("" 0 0 0)
       ("" 3 0 0))
      "clips ~S at column ~D to character ~D after ~D blank cells"
      (text start-column expected-index expected-blank)
    (let ((renderer (make-loom-renderer 8 1)))
      (multiple-value-bind (index blank)
          (loom-renderer-clip-index renderer text start-column)
        (expect index :to-equal expected-index)
        (expect blank :to-equal expected-blank)))))

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
  "loom-renderer drawing primitives"
  (it
    "writes, draws, clears, and presents a cursor"
    (let ((renderer (make-loom-renderer 6 3)))
      (expect (loom-renderer-width renderer) :to-equal 6)
      (expect (loom-renderer-height renderer) :to-equal 3)
      (expect (loom-renderer-write-string renderer 0 0 "x") :to-be renderer)
      (expect (loom-renderer-draw-horizontal-line renderer 1 1 3)
              :to-be renderer)
      (expect (loom-renderer-draw-vertical-line renderer 4 0 3)
              :to-be renderer)
      (expect (cl-tty-kit:screen-to-string
               (cl-tty-kit:renderer-screen
                (loom::%loom-renderer-cl-tty-renderer renderer)))
              :to-contain "x")
      (expect (loom-renderer-clear renderer) :to-be renderer)
      (expect (cl-tty-kit:screen-to-string
               (cl-tty-kit:renderer-screen
                (loom::%loom-renderer-cl-tty-renderer renderer)))
              :to-equal (format nil "      ~%      ~%      "))
      (let ((output (make-string-output-stream)))
        (expect
         (loom-renderer-present
          renderer
          :stream output
          :cursor (loom-renderer-make-cursor renderer
                                             :x 2
                                             :y 1
                                             :visible nil))
         :to-be renderer)
        (expect (> (length (get-output-stream-string output)) 0)
                :to-be-truthy)))))
