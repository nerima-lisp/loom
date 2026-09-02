;;;; t/integration/layout-isearch-test.lisp
;;;;
;;;; Incremental-search presentation drawing and viewport clipping.
(in-package #:loom/test)

 (describe
   "incremental-search layout drawing"
   (it
     "highlights matches and distinguishes the current match"
     (let* ((state (%fresh-layout-state :content "one two one" :width 20 :height 1))
            (window (%layout-window state))
            (buffer (window-buffer window))
            (session (make-isearch-session buffer 0)))
       (isearch-apply-pattern session "o")
       (setf (editor-state-isearch state) session)
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (let ((screen (%layout-screen state)))
         (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 0 0))
                 :to-equal '((:fg 0) (:bg 6)))
         (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 6 0))
                 :to-equal '((:fg 0) (:bg 3)))))))

   (it
     "does not paint a search session onto a different buffer"
     (let* ((state (%fresh-layout-state :content "one two one" :width 20 :height 1))
            (window (%layout-window state))
            (session (make-isearch-session (make-buffer :initial-content "one") 0)))
       (isearch-apply-pattern session "o")
       (setf (editor-state-isearch state) session)
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (expect (cl-tty-kit:cell-style
                (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
               :to-be nil)))

   (it
     "leaves the screen unchanged when no search session is active"
     (let* ((state (%fresh-layout-state :content "one two" :width 20 :height 1))
            (screen (%layout-screen state))
            (before (cl-tty-kit:screen-row-string screen 0)))
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) (%layout-window state) 0))
       (expect (cl-tty-kit:screen-row-string screen 0) :to-equal before)))

   (it
     "highlights a match on the wrapped row where its text is displayed"
     (let* ((state (%fresh-layout-state :content "abcdef" :width 3 :height 2))
            (window (%layout-window state))
            (buffer (window-buffer window))
            (session (make-isearch-session buffer 0)))
       (buffer-set-truncate-lines buffer nil)
       (isearch-apply-pattern session "de")
       (setf (editor-state-isearch state) session)
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (let ((screen (%layout-screen state)))
         (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 0 1))
                 :to-equal '((:fg 0) (:bg 6)))
         (expect (cl-tty-kit:cell-style (cl-tty-kit:screen-cell screen 1 1))
                 :to-equal '((:fg 0) (:bg 6))))))

   (it
     "highlights a search match spanning multiple logical lines"
     (let* ((state (%fresh-layout-state :content "one two\nthree\nfour" :width 20 :height 3))
            (window (%layout-window state))
            (buffer (window-buffer window))
            (session (make-isearch-session buffer 0)))
        (setf (loom/feature/search::%isearch-matches session)
              (list (make-buffer-span 4 15)))
       (setf (editor-state-isearch state) session)
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (let ((screen (%layout-screen state)))
         (expect (loop for row below 3
                       thereis (loop for column below 20
                                     thereis (cl-tty-kit:cell-style
                                              (cl-tty-kit:screen-cell
                                               screen column row))))
                 :to-be-truthy))))

   (it
     "does not draw a match scrolled above the window"
     (let* ((state (%fresh-layout-state :content "one two one" :width 20 :height 1))
            (window (%layout-window state))
            (buffer (window-buffer window))
            (session (make-isearch-session buffer 0)))
       (isearch-apply-pattern session "two")
       (setf (window-scroll-line window) 1
             (editor-state-isearch state) session)
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (expect (cl-tty-kit:cell-style
               (cl-tty-kit:screen-cell (%layout-screen state) 4 0))
               :to-be nil)))

   (it
     "draws a match at its horizontally scrolled position"
     (let* ((state (%fresh-layout-state :content "0123456789" :width 5 :height 1))
            (window (%layout-window state))
            (buffer (window-buffer window))
            (session (make-isearch-session buffer 0)))
       (isearch-apply-pattern session "67")
       (setf (window-scroll-column window) 4
             (editor-state-isearch state) session)
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (expect (cl-tty-kit:cell-style
                (cl-tty-kit:screen-cell (%layout-screen state) 2 0))
               :to-equal '((:fg 0) (:bg 6)))))

   (it
     "draws the visible tail of a match clipped by horizontal scrolling"
     (let* ((state (%fresh-layout-state :content "0123456789" :width 5 :height 1))
            (window (%layout-window state))
            (buffer (window-buffer window))
            (session (make-isearch-session buffer 0)))
       (isearch-apply-pattern session "2345")
       (setf (window-scroll-column window) 4
             (editor-state-isearch state) session)
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (expect (cl-tty-kit:cell-style
                (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
               :to-equal '((:fg 0) (:bg 6)))))

   (it
     "does not draw a truncated match that is fully left of the viewport"
     (let* ((state (%fresh-layout-state :content "0123456789" :width 5 :height 1))
            (window (%layout-window state))
            (buffer (window-buffer window))
            (session (make-isearch-session buffer 0)))
       (isearch-apply-pattern session "01")
       (setf (window-scroll-column window) 6
             (editor-state-isearch state) session)
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (expect (cl-tty-kit:cell-style
               (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
               :to-be nil)))

   (it
     "does not draw a truncated match that is fully below the viewport"
     (let* ((state (%fresh-layout-state :content "first\nmatch" :width 20 :height 1))
            (window (%layout-window state))
            (buffer (window-buffer window))
            (session (make-isearch-session buffer 0)))
       (isearch-apply-pattern session "match")
       (setf (editor-state-isearch state) session)
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (expect (cl-tty-kit:cell-style
                (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
               :to-be nil)))

   (it
     "does not draw a truncated match that is fully right of the viewport"
     (let* ((state (%fresh-layout-state :content "0123456789" :width 5 :height 1))
            (window (%layout-window state))
            (buffer (window-buffer window))
            (session (make-isearch-session buffer 0)))
       (isearch-apply-pattern session "89")
       (let ((*editor-state* state))
         (setf (editor-state-isearch state) session)
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (expect (cl-tty-kit:cell-style
               (cl-tty-kit:screen-cell (%layout-screen state) 4 0))
               :to-be nil)))

   (it
     "does not draw a match outside the buffer's visible region"
     (let* ((state (%fresh-layout-state :content "0123456789" :width 10 :height 1))
            (window (%layout-window state))
            (buffer (window-buffer window))
            (session (make-isearch-session buffer 0)))
       (buffer-narrow-to-region buffer 0 5 0 10)
       (setf (loom/feature/search::%isearch-matches session)
             (list (make-buffer-span 0 2))
             (editor-state-isearch state) session)
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (expect (cl-tty-kit:cell-style
                (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
               :to-be nil)))

   (it
     "does not draw isearch into a zero-sized window"
     (let* ((state (%fresh-layout-state :content "match" :width 0 :height 0
                                        :renderer-width 5 :renderer-height 1))
            (window (%layout-window state))
            (buffer (window-buffer window))
            (session (make-isearch-session buffer 0)))
       (isearch-apply-pattern session "match")
       (setf (editor-state-isearch state) session)
       (let ((*editor-state* state))
         (loom::%layout-draw-isearch
          (editor-state-renderer state) window 0))
       (expect (cl-tty-kit:cell-style
                (cl-tty-kit:screen-cell (%layout-screen state) 0 0))
               :to-be nil)))
