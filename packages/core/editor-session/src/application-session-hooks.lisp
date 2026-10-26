(in-package #:loom/core/editor-session)

(defparameter +session-hook-kinds+
  (quote
   (:tick :resize :key-input
          :input-event
          :render
          :terminal-modes
          :before-save
          :after-save
          :buffer-close
          :startup
          :signal
          :suspend
          :resume
          :shutdown
          :exit-status)))

(defparameter +session-hook-owner-order+
  '(:core/buffer :core/window-tree
                 :core/command
                 :core/minibuffer
                 :core/editor-session
                 :feature/lifecycle
                 :feature/files
                 :feature/buffers
                 :feature/file-tree
                 :feature/minibuffer-ui
                 :feature/completion
                 :feature/help
                 :feature/kill-ring
                 :feature/clipboard
                 :feature/mouse
                 :feature/search
                 :feature/project
                 :feature/mode
                 :feature/syntax-highlighting
                 :feature/lisp-structure
                 :feature/lang-lisp
                 :feature/lang-nix
                 :feature/lang-web
                 :feature/lang-markup
                 :feature/bookmark
                 :feature/window
                 :feature/workspace
                 :feature/session
                 :feature/register
                 :feature/keyboard-macro
                 :feature/lsp
                 :feature/terminal
                 :feature/shell
                 :feature/format
                 :feature/git
                 :feature/evaluation
                 :feature/auto-save
                 :feature/user-init))

(defvar *session-hooks*
  (make-hash-table :test #'eq))

(defstruct
    (frame-snapshot
     (:constructor %make-frame-snapshot (width height cells cursor))
     (:copier nil)
     (:conc-name %frame-snapshot-))
  width
  height
  cells
  cursor)

(defstruct
    (render-operation
     (:constructor %make-render-operation
                   (kind x y value style style-supplied-p))
     (:copier nil)
     (:conc-name %render-operation-))
  kind
  x
  y
  value
  style
  style-supplied-p)

(defun %copy-frame-value (value)
  (typecase value
    (string (copy-seq value))
    (cons
     (cons (%copy-frame-value (car value)) (%copy-frame-value (cdr value))))
    (vector (map 'vector #'%copy-frame-value value))
    (t value)))

(defun %frame-cell-copy (cell)
  (unless (and (listp cell) (= (length cell) 2))
    (error "Frame cells must be (glyph style) pairs: ~S" cell))
  (unless (or (null (first cell)) (stringp (first cell)))
    (error "Frame cell glyphs must be strings or NIL: ~S" (first cell)))
  (list (%copy-frame-value (first cell)) (%copy-frame-value (second cell))))

(defun %validated-cursor (width height cursor)
  (when cursor
    (unless
        (and (listp cursor)
             (= (length cursor) 3)
             (integerp (first cursor))
             (integerp (second cursor))
             (<= 0 (first cursor))
             (< (first cursor) width)
             (<= 0 (second cursor))
             (< (second cursor) height)
             (member (third cursor) '(nil t)))
      (error "Frame cursor must be an in-bounds (x y visible-p) triple: ~S"
             cursor)))
  (%copy-frame-value cursor))

(defun make-frame-snapshot (width height row-major-cells &key cursor)
  (unless (and (integerp width) (plusp width) (integerp height) (plusp height))
    (error "Frame dimensions must be positive integers: ~S by ~S" width height))
  (unless
      (and (typep row-major-cells 'sequence)
           (= (length row-major-cells) (* width height)))
    (error "Frame cell count must be WIDTH times HEIGHT."))
  (%make-frame-snapshot width
                        height
                        (map 'vector #'%frame-cell-copy row-major-cells)
                        (%validated-cursor width height cursor)))

(defun frame-snapshot-width (snapshot)
  (check-type snapshot frame-snapshot)
  (%frame-snapshot-width snapshot))

(defun frame-snapshot-height (snapshot)
  (check-type snapshot frame-snapshot)
  (%frame-snapshot-height snapshot))

(defun frame-snapshot-cell (snapshot x y)
  (check-type snapshot frame-snapshot)
  (if (and (integerp x)
           (integerp y)
           (<= 0 x)
           (< x (%frame-snapshot-width snapshot))
           (<= 0 y)
           (< y (%frame-snapshot-height snapshot)))
      (let ((cell
             (aref (%frame-snapshot-cells snapshot)
                   (+ (* y (%frame-snapshot-width snapshot)) x))))
        (values (%copy-frame-value (first cell))
                (%copy-frame-value (second cell))))
      nil))

(defun frame-snapshot-cursor (snapshot)
  (check-type snapshot frame-snapshot)
  (let ((cursor (%frame-snapshot-cursor snapshot)))
    (if cursor
        (values (first cursor) (second cursor) (third cursor))
        (values nil nil nil))))

(defun make-render-operation (kind x y value &key (style nil style-supplied-p))
  (unless (and (integerp x) (integerp y) (<= 0 x) (<= 0 y))
    (error "Render operation coordinates must be non-negative integers."))
  (case kind
    (:text
     (unless (stringp value)
       (error "Text render operations require a string: ~S" value)))
    (:cursor
      (unless (member value '(nil t))
        (error "Cursor visibility must be true or false: ~S" value))
      (when style-supplied-p
        (error "Cursor render operations do not accept a style.")))
    (otherwise (error "Unknown render operation kind: ~S" kind)))
  (%make-render-operation kind
                          x
                          y
                          (%copy-frame-value value)
                          (%copy-frame-value style)
                          style-supplied-p))

(defun render-operation-kind (operation)
  (check-type operation render-operation)
  (%render-operation-kind operation))

(defun render-operation-x (operation)
  (check-type operation render-operation)
  (%render-operation-x operation))

(defun render-operation-y (operation)
  (check-type operation render-operation)
  (%render-operation-y operation))

(defun render-operation-text (operation)
  (check-type operation render-operation)
  (and (eq (%render-operation-kind operation) :text)
       (%copy-frame-value (%render-operation-value operation))))

(defun render-operation-style (operation)
  (check-type operation render-operation)
  (%copy-frame-value (%render-operation-style operation)))

(defun render-operation-visible-p (operation)
  (check-type operation render-operation)
  (and (eq (%render-operation-kind operation) :cursor)
       (%render-operation-value operation)))

(defun %render-layout (text glyph-layout-function)
  (multiple-value-bind (glyphs widths)
      (funcall glyph-layout-function text)
    (unless
        (and (vectorp glyphs)
             (not (stringp glyphs))
             (vectorp widths)
             (not (stringp widths))
             (= (length glyphs) (length widths))
             (every (function stringp) glyphs)
             (every
              (lambda (width)
                (and (integerp width) (plusp width)))
              widths))
      (error
       "Glyph layout must return equal vectors of strings and positive widths."))
    (values glyphs widths)))

(defun %frame-cell-index (snapshot x y)
  (+ (* y (%frame-snapshot-width snapshot)) x))

(defun %apply-text-operation (snapshot cells operation glyph-layout-function)
  (labels ((clear-overlapping-glyphs (x y glyph-width)
             (let ((frame-width (%frame-snapshot-width snapshot)))
               (loop for candidate from 0 below frame-width
                     for candidate-index = (%frame-cell-index snapshot candidate y)
                     for candidate-cell = (aref cells candidate-index)
                     for old-glyph = (first candidate-cell)
                     when (and (stringp old-glyph) (plusp (length old-glyph)))
                       do (multiple-value-bind (old-glyphs old-widths)
                              (%render-layout old-glyph glyph-layout-function)
                            (when (plusp (length old-glyphs))
                              (let ((old-width
                                      (reduce (function +) old-widths
                                              :initial-value 0)))
                                (when (and (< candidate (+ x glyph-width))
                                           (< x (+ candidate old-width)))
                                  (loop for column from candidate
                                          below (min frame-width
                                                     (+ candidate old-width))
                                        for index =
                                          (%frame-cell-index snapshot column y)
                                        for old-cell = (aref cells index)
                                        do (setf (aref cells index)
                                                 (list
                                                  " "
                                                  (%copy-frame-value
                                                   (second old-cell)))))))))))))
    (let ((x (%render-operation-x operation))
          (y (%render-operation-y operation)))
      (unless (and (< x (%frame-snapshot-width snapshot))
                   (< y (%frame-snapshot-height snapshot)))
        (error "Render operation starts outside the frame: (~D, ~D)" x y))
      (multiple-value-bind (glyphs widths)
          (%render-layout (%render-operation-value operation)
                          glyph-layout-function)
        (loop for glyph across glyphs
              for glyph-width across widths
              while (< x (%frame-snapshot-width snapshot))
              do (when (<= (+ x glyph-width) (%frame-snapshot-width snapshot))
                   (clear-overlapping-glyphs x y glyph-width)
                   (let* ((index (%frame-cell-index snapshot x y))
                          (old-cell (aref cells index))
                          (style
                            (if (%render-operation-style-supplied-p operation)
                                (%copy-frame-value
                                 (%render-operation-style operation))
                                (second old-cell))))
                     (setf (aref cells index) (list (copy-seq glyph) style))
                     (loop for offset from 1 below glyph-width
                           for continuation-index =
                             (%frame-cell-index snapshot (+ x offset) y)
                           do (setf (aref cells continuation-index)
                                    (list nil
                                          (%copy-frame-value style))))))
                 (incf x glyph-width))))))

(defun apply-render-operations (snapshot operations glyph-layout-function)
  (check-type snapshot frame-snapshot)
  (unless (and (listp operations) (every #'render-operation-p operations))
    (error "Render operations must be a list of render-operation values."))
  (check-type glyph-layout-function function)
  (let ((cells (copy-seq (%frame-snapshot-cells snapshot)))
        (cursor (%copy-frame-value (%frame-snapshot-cursor snapshot))))
    (dolist (operation operations)
      (case (%render-operation-kind operation)
        (:text
         (%apply-text-operation snapshot cells operation glyph-layout-function))
        (:cursor
          (unless
              (and
               (< (%render-operation-x operation)
                  (%frame-snapshot-width snapshot))
               (< (%render-operation-y operation)
                  (%frame-snapshot-height snapshot)))
            (error "Cursor render operation starts outside the frame."))
          (setf cursor (list (%render-operation-x operation)
                             (%render-operation-y operation)
                             (%render-operation-value operation))))
        (otherwise
         (error "Unknown render operation kind: ~S"
                (%render-operation-kind operation)))))
    (%make-frame-snapshot (%frame-snapshot-width snapshot)
                          (%frame-snapshot-height snapshot)
                          cells
                          cursor)))

(defun register-session-hook (kind owner function)
  (unless (member kind +session-hook-kinds+ :test (function eq))
    (error "Unknown session hook kind: ~S" kind))
  (unless (keywordp owner)
    (error "Session hook owner must be a keyword: ~S" owner))
  (unless (member owner +session-hook-owner-order+ :test (function eq))
    (error "Unknown session hook owner: ~S" owner))
  (when
      (and
       (member kind
               (quote
                (:startup :signal :suspend :resume :shutdown :exit-status))
               :test
               (function eq))
       (not (eq owner :feature/lifecycle)))
    (error "Lifecycle hook ~S must be owned by :FEATURE/LIFECYCLE." kind))
  (check-type function function)
  (let ((hooks (gethash kind *session-hooks*)))
    (unless
        (find-if
         (lambda (hook)
           (and (eq owner (car hook)) (eq function (cdr hook))))
         hooks)
      (setf (gethash kind *session-hooks*) (append hooks
                                                   (list (cons owner function)))))
    function))

(defun %session-hook-owner-index (owner)
  (or (position owner +session-hook-owner-order+ :test #'eq)
      (length +session-hook-owner-order+)))

(defun %ordered-session-hooks (kind)
  (stable-sort (copy-list (gethash kind *session-hooks*))
               #'<
               :key
               (lambda (hook)
                 (%session-hook-owner-index (car hook)))))

(defun %validate-session-hook-result (kind value)
  (case kind
    ((:key-input :input-event)
     (unless (member value (quote (:pass :handled)) :test (function eq))
       (error "~S hooks must return :PASS or :HANDLED, got ~S" kind value)))
    (:render
     (unless (and (listp value) (every (function render-operation-p) value))
       (error "Render hooks must return a list of render operations.")))
    (:terminal-modes
     (unless
         (and (listp value)
              (every
               (lambda (mode)
                 (member mode
                         (quote
                          (:mouse-sgr :mouse-button-event :bracketed-paste))
                         :test
                         (function eq)))
               value))
       (error "Terminal mode hooks returned invalid modes: ~S" value)))
    (:signal
     (unless (member value (quote (:continue :terminate)) :test (function eq))
       (error "Signal hooks must return :CONTINUE or :TERMINATE, got ~S" value)))
    (:exit-status
     (unless (and (integerp value) (<= 0 value 255))
       (error
        "Exit-status hooks must return an integer from 0 through 255, got ~S"
        value))))
  value)

(defun run-session-hooks (kind session &rest arguments)
  (unless (member kind +session-hook-kinds+ :test #'eq)
    (error "Unknown session hook kind: ~S" kind))
  (check-type session editor-session)
  (let ((results nil))
    (dolist (hook (%ordered-session-hooks kind))
      (let ((result
             (%validate-session-hook-result kind
                                            (apply (cdr hook) session arguments))))
        (when
            (and (member kind '(:key-input :input-event) :test #'eq)
                 (eq result :handled))
          (return-from run-session-hooks
            :handled))
        (push result results)))
    (if (member kind '(:key-input :input-event) :test #'eq)
        :pass
        (nreverse results))))
