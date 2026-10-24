
(in-package #:loom/feature/syntax-highlighting)

(defvar *renderer-operation-provider* nil)

(defun register-renderer-operation-provider (owner function)
  "Register FUNCTION as the renderer operation provider owned by OWNER.

FUNCTION is called with RENDERER, OPERATION, and the operation arguments.
:CLIP-INDEX takes a line and start column; :TRUNCATE-STRING takes text
and a cell width; :STRING-WIDTH takes text; :WRITE-STRING takes x, y, text,
and :STYLE with its value. The first OWNER registration installs FUNCTION;
later registrations by OWNER leave it in place. A different owner is
rejected."
  (unless (functionp function)
    (error "Renderer operation provider must be a function"))
  (when *renderer-operation-provider*
    (unless (equal (car *renderer-operation-provider*) owner)
      (error "Renderer operation provider is already registered by ~S"
             (car *renderer-operation-provider*))))
  (unless *renderer-operation-provider*
    (setf *renderer-operation-provider* (cons owner function)))
  function)

(defun call-renderer-operation (renderer operation &rest arguments)
  "Return every value from the provider unchanged."
  (unless *renderer-operation-provider*
    (error "Renderer operation provider is not registered"))
  (unless
      (member operation
              (list :clip-index :truncate-string :string-width :write-string)
              :test (function eq))
    (error "Unsupported syntax renderer operation: ~S" operation))
  (apply (cdr *renderer-operation-provider*) renderer operation arguments))

(defparameter +layout-syntax-styles+
  '((:comment . (:fg 8))
    (:string . (:fg 2))
    (:keyword . (:bold (:fg 6)))
    (:number . (:fg 3))
    (:delimiter . (:fg 4)))
  "Terminal styles associated with syntax token kinds.")

(defun %layout-syntax-style (kind)
  "Return the syntax style for KIND, or NIL for no styling."
  (cdr (assoc kind +layout-syntax-styles+)))

(defun %syntax-token-visible-text (renderer token character-index start-index
                                            remaining)
  (let* ((text (syntax-token-text token))
         (end (+ character-index (length text)))
         (slice (if (> start-index character-index)
                    (subseq text (- start-index character-index))
                  text)))
    (values (call-renderer-operation renderer :truncate-string slice remaining)
            end)))

(defun %syntax-draw-visible-token (renderer token visible column y remaining end)
  (let ((visible-width (call-renderer-operation renderer :string-width visible)))
    (if (zerop visible-width)
        (values column remaining end)
      (progn
        (call-renderer-operation
         renderer
         :write-string
         column
         y
         visible
         :style
         (%layout-syntax-style (syntax-token-kind token)))
        (values (+ column visible-width)
                (- remaining visible-width)
                end)))))

(defun %syntax-draw-token (renderer token character-index start-index
                           column y remaining)
  (let ((end (+ character-index (length (syntax-token-text token)))))
    (if (and (plusp remaining) (> end start-index))
        (multiple-value-bind (visible visible-end)
            (%syntax-token-visible-text renderer token character-index
                                        start-index remaining)
          (%syntax-draw-visible-token renderer token visible column y
                                      remaining visible-end))
        (values column remaining end))))

(defun syntax-draw-highlighted-line (renderer line x y width
                                              &optional (mode :common-lisp)
                                              (start-column 0))
  "Draw LINE at (X, Y) within WIDTH screen cells.

START-COLUMN is a horizontal scroll offset in screen cells. The :CLIP-INDEX
operation calculates the first visible character without changing LINE and
reports a leading blank cell if a wide character crosses the viewport edge.
The full line is tokenized, then token text before that index is skipped.
Truncating LINE before tokenization can change token recognition at the
viewport edge."
  (multiple-value-bind (start-index leading-blank)
      (call-renderer-operation renderer :clip-index line start-column)
    (let ((column (+ x leading-blank))
          (remaining (max 0 (- width leading-blank)))
          (character-index 0))
      (dolist (token (syntax-highlight-line-for-mode line mode))
        (multiple-value-bind (next-column next-remaining next-index)
            (%syntax-draw-token renderer token character-index start-index
                                column y remaining)
          (setf column next-column
                remaining next-remaining
                character-index next-index)))))
  renderer)

(defun syntax-draw-buffer (renderer buffer x y width height
                           &key (start-line 0) (start-column 0))
  "Draw up to HEIGHT rows from BUFFER starting at START-LINE.

START-LINE is a zero-based index into the visible lines of BUFFER. START-COLUMN
is a horizontal offset in screen cells."
  (let ((line-count (buffer-visible-line-count buffer)))
    (dotimes (row height)
      (let ((line-number (+ start-line row)))
        (when (< line-number line-count)
          (syntax-draw-highlighted-line
           renderer
           (buffer-visible-line buffer line-number)
           x
           (+ y row)
           width
           (buffer-major-mode buffer)
           start-column)))))
  renderer)
