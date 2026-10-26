(in-package #:loom/test)
;; Completion examples, styles, and display options follow the Emacs manual.
;; The application requirement keeps candidate display vertical.
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Example.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Styles.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Options.html
;; Icomplete documents vertical minibuffer candidate display.
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Icomplete.html
(describe
 "minibuffer candidate renderer"
 (it
  "draws candidates vertically through the registered render hook without changing the buffer completion popup"
  (let* ((buffer (loom/core/buffer:make-buffer :initial-content ""))
         (window-tree (loom/core/window-tree:make-window-tree buffer 80 24))
         (session
           (loom/core/editor-session:make-editor-session
            (list :core/window-tree)
            :initial-slices (list (cons :core/window-tree window-tree))))
         (minibuffer (loom/core/minibuffer:make-minibuffer))
         (popup (loom::make-editor-completion
                 buffer 0 0
                 (list (cons "alpha-one" "alpha-one")
                       (cons "alpha-two" "alpha-two"))))
         (state
           (loom/core/editor-session:make-editor-state
            :session session
            :window-tree window-tree
            :minibuffer minibuffer
            :workspaces :test
            :keyboard-macro :test
            :completion popup))
         (snapshot
           (loom/core/editor-session:make-frame-snapshot
            80 24
            (make-array (* 80 24) :initial-element (list " " nil)))))
    (setf (loom/core/minibuffer::%minibuffer-active-p minibuffer) t
          (loom/core/minibuffer::%minibuffer-completion-candidates minibuffer)
          (list "alpha-one" "alpha-two"))
    (let* ((loom/core/editor-session:*editor-state* state)
           (operations
             (loop for result
                   in (loom/core/editor-session:run-session-hooks
                       :render session snapshot)
                   append result)))
      (expect (mapcar (function loom/core/editor-session:render-operation-text)
                      operations)
              :to-equal
              (list (make-string 80 :initial-element #\Space)
                    "alpha-one"
                    (make-string 80 :initial-element #\Space)
                    "alpha-two"))
      (expect (mapcar (function loom/core/editor-session:render-operation-y)
                      operations)
              :to-equal (list 21 21 22 22))
      (expect (loom/core/editor-session:editor-state-completion state)
              :to-be popup)
      (expect (loom:editor-completion-selected popup)
              :to-equal (cons "alpha-one" "alpha-one")))))
 (it
  "draws no rows for empty matches or inactive minibuffers"
  (let* ((buffer (loom/core/buffer:make-buffer :initial-content ""))
         (window-tree (loom/core/window-tree:make-window-tree buffer 80 8))
         (session
           (loom/core/editor-session:make-editor-session
            '(:core/window-tree)
            :initial-slices (list (cons :core/window-tree window-tree))))
         (minibuffer (loom/core/minibuffer:make-minibuffer))
         (popup (loom::make-editor-completion
                 buffer 0 0 '(("alpha" . "alpha"))))
         (state
           (loom/core/editor-session:make-editor-state
            :session session
            :window-tree window-tree
            :minibuffer minibuffer
            :workspaces :test
            :keyboard-macro :test
            :completion popup))
         (snapshot
           (loom/core/editor-session:make-frame-snapshot
            80 8 (make-array (* 80 8) :initial-element '(" " nil)))))
    (setf (loom/core/minibuffer::%minibuffer-active-p minibuffer) t)
    (let ((loom/core/editor-session:*editor-state* state))
      (expect
       (loom/feature/minibuffer-ui::%minibuffer-completion-render-operations
        session snapshot)
       :to-equal nil)
      (setf (loom/core/minibuffer::%minibuffer-completion-candidates minibuffer)
            '("alpha"))
      (setf (loom/core/minibuffer::%minibuffer-active-p minibuffer) nil)
      (expect
       (loom/feature/minibuffer-ui::%minibuffer-completion-render-operations
        session snapshot)
       :to-equal nil)
      (expect (loom/core/editor-session:editor-state-completion state)
              :to-be popup)
      (expect (loom:editor-completion-selected popup)
              :to-equal '("alpha" . "alpha")))))
 (it
  "clears stale suffix cells when drawing minibuffer candidates"
  (let* ((width 80)
         (height 24)
         (candidates (list "alpha-one" "alpha-two"))
         (rows (list 21 22))
         (stale-texts
           (list "previous-completion-one-is-longer"
                 "previous-completion-two-is-longer"))
         (cells
           (let ((cells
                   (make-array (* width height)
                               :initial-element (list " " nil))))
             (loop for row in rows
                   for previous across (coerce stale-texts 'vector)
                   do (loop for column below (length previous)
                            do (setf (aref cells (+ (* row width) column))
                                     (list (string (char previous column)) nil))))
             cells))
         (buffer (loom/core/buffer:make-buffer :initial-content ""))
         (window-tree (loom/core/window-tree:make-window-tree buffer width height))
         (session
           (loom/core/editor-session:make-editor-session
            (list :core/window-tree)
            :initial-slices (list (cons :core/window-tree window-tree))))
         (minibuffer (loom/core/minibuffer:make-minibuffer))
         (state
           (loom/core/editor-session:make-editor-state
            :session session
            :window-tree window-tree
            :minibuffer minibuffer
            :workspaces :test
            :keyboard-macro :test
            :completion nil))
         (snapshot
           (loom/core/editor-session:make-frame-snapshot width height cells)))
    (setf (loom/core/minibuffer::%minibuffer-active-p minibuffer) t
          (loom/core/minibuffer::%minibuffer-completion-candidates minibuffer)
          candidates)
    (let* ((loom/core/editor-session:*editor-state* state)
           (operations
             (loop for result
                   in (loom/core/editor-session:run-session-hooks
                       :render session snapshot)
                   append result))
           (updated
             (loom/core/editor-session:apply-render-operations
              snapshot
              operations
              (lambda (text)
                (values (map 'vector (function string) text)
                        (make-array (length text) :initial-element 1))))))
      (loop for candidate in candidates
            for previous in stale-texts
            for row in rows
            do (expect
                (loop for column below (length candidate)
                      collect
                      (nth-value
                       0
                       (loom/core/editor-session:frame-snapshot-cell
                        updated column row)))
                :to-equal (map 'list (function string) candidate))
               (expect
                (loop for column from (length candidate) below width
                      collect
                      (nth-value
                       0
                       (loom/core/editor-session:frame-snapshot-cell
                        updated column row)))
                :to-equal
                (make-list (- width (length candidate))
                           :initial-element " "))
               (expect
                (loop for column below width
                      collect
                      (nth-value
                       0
                       (loom/core/editor-session:frame-snapshot-cell
                        snapshot column row)))
                :to-equal
                (append
                 (map 'list (function string) previous)
                 (make-list (- width (length previous))
                            :initial-element " "))))))))
