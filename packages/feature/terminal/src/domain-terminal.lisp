(in-package #:loom/feature/terminal)

(defun %terminal-blank-row (width)
  (make-string width :initial-element #\Space))

(defun %terminal-blank-rows (width height)
  (coerce (loop repeat height collect (%terminal-blank-row width))
          'vector))

(defun %terminal-copy-rows (rows width height)
  (let ((result (%terminal-blank-rows width height)))
    (loop for row below (min height (length rows))
          for source = (aref rows row)
          do (replace (aref result row)
                      source
                      :end1 (min width (length source))))
    result))

(defstruct (terminal-screen
            (:constructor %make-terminal-screen
                (width height rows cursor-row cursor-column parser-state
                 csi-parameters csi-private saved-row saved-column
                 main-rows main-cursor-row main-cursor-column alternate-p
                 wrap-pending)))
  "The small, stateful screen model used to render a PTY transcript.

It deliberately models the cursor and the common CSI editing operations used
by interactive terminal programs.  It is not intended to be a complete VT
parser, but keeping state here means cursor-addressed output is rendered in
the same order it was received instead of being reduced to a styled string."
  width
  height
  rows
  cursor-row
  cursor-column
  parser-state
  csi-parameters
  csi-private
  saved-row
  saved-column
  main-rows
  main-cursor-row
  main-cursor-column
  alternate-p
  wrap-pending)

(defun make-terminal-screen (&key (width 80) (height 24))
  "Create a blank terminal screen with WIDTH columns and HEIGHT rows."
  (unless (and (integerp width) (plusp width))
    (error "Terminal width must be a positive integer: ~S" width))
  (unless (and (integerp height) (plusp height))
    (error "Terminal height must be a positive integer: ~S" height))
  (%make-terminal-screen width
                         height
                         (%terminal-blank-rows width height)
                         0
                         0
                         :ground
                         ""
                         nil
                         0
                         0
                         nil
                         0
                         0
                         nil
                         nil))

(defun %terminal-clamp (value minimum maximum)
  (max minimum (min maximum value)))

(defun %terminal-screen-clamp-cursor (screen)
  (setf (terminal-screen-cursor-row screen)
        (%terminal-clamp (terminal-screen-cursor-row screen)
                         0
                         (1- (terminal-screen-height screen)))
        (terminal-screen-cursor-column screen)
        (%terminal-clamp (terminal-screen-cursor-column screen)
                         0
                         (1- (terminal-screen-width screen)))))

(defun %terminal-screen-scroll-up (screen &optional (count 1))
  (let* ((height (terminal-screen-height screen))
         (width (terminal-screen-width screen))
         (count (%terminal-clamp count 0 height))
         (rows (terminal-screen-rows screen)))
    (when (plusp count)
      (loop for row below (- height count)
            do (replace (aref rows row)
                        (aref rows (+ row count))))
      (loop for row from (- height count) below height
            do (setf (aref rows row) (%terminal-blank-row width)))))
  screen)

(defun %terminal-screen-scroll-down (screen &optional (count 1))
  (let* ((height (terminal-screen-height screen))
         (width (terminal-screen-width screen))
         (count (%terminal-clamp count 0 height))
         (rows (terminal-screen-rows screen)))
    (when (plusp count)
      (loop for row from (1- height) downto count
            do (replace (aref rows row)
                        (aref rows (- row count))))
      (loop for row below count
            do (setf (aref rows row) (%terminal-blank-row width)))))
  screen)

(defun %terminal-screen-line-feed (screen)
  (if (= (terminal-screen-cursor-row screen)
         (1- (terminal-screen-height screen)))
      (%terminal-screen-scroll-up screen)
      (incf (terminal-screen-cursor-row screen)))
  (setf (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-carriage-return (screen)
  (setf (terminal-screen-cursor-column screen) 0
        (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-next-line (screen)
  (%terminal-screen-carriage-return screen)
  (%terminal-screen-line-feed screen))

(defun %terminal-screen-prepare-write (screen)
  (when (terminal-screen-wrap-pending screen)
    (%terminal-screen-next-line screen))
  screen)

(defun %terminal-screen-write-character (screen character)
  (%terminal-screen-prepare-write screen)
  (setf (char (aref (terminal-screen-rows screen)
                    (terminal-screen-cursor-row screen))
              (terminal-screen-cursor-column screen))
        character)
  (if (= (terminal-screen-cursor-column screen)
         (1- (terminal-screen-width screen)))
      (setf (terminal-screen-wrap-pending screen) t)
      (incf (terminal-screen-cursor-column screen)))
  screen)

(defun %terminal-screen-clear-row (screen row start end)
  (let ((line (aref (terminal-screen-rows screen) row)))
    (loop for column from start below end
          do (setf (char line column) #\Space)))
  screen)

(defun %terminal-screen-clear-all (screen)
  (loop for row below (terminal-screen-height screen)
        do (%terminal-screen-clear-row
            screen row 0 (terminal-screen-width screen)))
  (setf (terminal-screen-cursor-row screen) 0
        (terminal-screen-cursor-column screen) 0
        (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-clear-display (screen mode)
  (let* ((row (terminal-screen-cursor-row screen))
         (column (terminal-screen-cursor-column screen))
         (height (terminal-screen-height screen))
         (width (terminal-screen-width screen)))
    (case mode
      ((0 nil)
       (%terminal-screen-clear-row screen row column width)
       (loop for current from (1+ row) below height
             do (%terminal-screen-clear-row screen current 0 width)))
      (1
       (loop for current below row
             do (%terminal-screen-clear-row screen current 0 width))
       (%terminal-screen-clear-row screen row 0 (1+ column)))
      ((2 3)
       (%terminal-screen-clear-all screen))))
  (setf (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-clear-line (screen mode)
  (let ((column (terminal-screen-cursor-column screen))
        (width (terminal-screen-width screen)))
    (case mode
      ((0 nil) (%terminal-screen-clear-row screen
                                      (terminal-screen-cursor-row screen)
                                      column
                                      width))
      (1 (%terminal-screen-clear-row screen
                                     (terminal-screen-cursor-row screen)
                                     0
                                     (1+ column)))
      ((2 3) (%terminal-screen-clear-row screen
                                      (terminal-screen-cursor-row screen)
                                      0
                                      width))))
  (setf (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-save-cursor (screen)
  (setf (terminal-screen-saved-row screen) (terminal-screen-cursor-row screen)
        (terminal-screen-saved-column screen)
        (terminal-screen-cursor-column screen))
  screen)

(defun %terminal-screen-restore-cursor (screen)
  (setf (terminal-screen-cursor-row screen) (terminal-screen-saved-row screen)
        (terminal-screen-cursor-column screen)
        (terminal-screen-saved-column screen)
        (terminal-screen-wrap-pending screen) nil)
  (%terminal-screen-clamp-cursor screen)
  screen)

(defun %terminal-screen-enter-alternate (screen)
  (unless (terminal-screen-alternate-p screen)
    (setf (terminal-screen-main-rows screen)
          (%terminal-copy-rows (terminal-screen-rows screen)
                               (terminal-screen-width screen)
                               (terminal-screen-height screen))
          (terminal-screen-main-cursor-row screen)
          (terminal-screen-cursor-row screen)
          (terminal-screen-main-cursor-column screen)
          (terminal-screen-cursor-column screen)
          (terminal-screen-rows screen)
          (%terminal-blank-rows (terminal-screen-width screen)
                                (terminal-screen-height screen))
          (terminal-screen-cursor-row screen) 0
          (terminal-screen-cursor-column screen) 0
          (terminal-screen-wrap-pending screen) nil
          (terminal-screen-alternate-p screen) t))
  screen)

(defun %terminal-screen-leave-alternate (screen)
  (when (terminal-screen-alternate-p screen)
    (setf (terminal-screen-rows screen)
          (or (terminal-screen-main-rows screen)
              (%terminal-blank-rows (terminal-screen-width screen)
                                    (terminal-screen-height screen)))
          (terminal-screen-cursor-row screen)
          (terminal-screen-main-cursor-row screen)
          (terminal-screen-cursor-column screen)
          (terminal-screen-main-cursor-column screen)
          (terminal-screen-main-rows screen) nil
          (terminal-screen-alternate-p screen) nil
          (terminal-screen-wrap-pending screen) nil)
    (%terminal-screen-clamp-cursor screen))
  screen)

(defun %terminal-screen-parameter (parameters index default)
  (let ((value (nth index parameters)))
    (if (and (integerp value) (plusp value)) value default)))

(defun %terminal-screen-parse-parameter (string)
  (unless (zerop (length string))
    (multiple-value-bind (number end)
        (parse-integer string :junk-allowed t)
      (when (and number (= end (length string)))
        number))))

(defun %terminal-screen-parse-parameters (string)
  (if (zerop (length string))
      nil
      (loop with start = 0
            with parameters = nil
            for separator = (position #\; string :start start)
            for end = (or separator (length string))
            do (push (%terminal-screen-parse-parameter
                      (subseq string start end))
                     parameters)
               (if separator
                   (setf start (1+ separator))
                   (return (nreverse parameters))))))

(defun %terminal-screen-delete-characters (screen count)
  (let* ((row (aref (terminal-screen-rows screen)
                    (terminal-screen-cursor-row screen)))
         (column (terminal-screen-cursor-column screen))
         (width (terminal-screen-width screen))
         (count (%terminal-clamp count 0 (- width column))))
    (when (plusp count)
      (replace row row
               :start1 column
               :end1 (- width count)
               :start2 (+ column count)
               :end2 width)
      (loop for current from (- width count) below width
            do (setf (char row current) #\Space))))
  (setf (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-insert-characters (screen count)
  (let* ((row (aref (terminal-screen-rows screen)
                    (terminal-screen-cursor-row screen)))
         (column (terminal-screen-cursor-column screen))
         (width (terminal-screen-width screen))
         (count (%terminal-clamp count 0 (- width column))))
    (when (plusp count)
      (replace row row
               :start1 (+ column count)
               :end1 width
               :start2 column
               :end2 (- width count))
      (loop for current from column below (+ column count)
            do (setf (char row current) #\Space))))
  (setf (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-erase-characters (screen count)
  (let* ((row (aref (terminal-screen-rows screen)
                    (terminal-screen-cursor-row screen)))
         (column (terminal-screen-cursor-column screen))
         (end (min (terminal-screen-width screen) (+ column count))))
    (loop for current from column below end
          do (setf (char row current) #\Space)))
  (setf (terminal-screen-wrap-pending screen) nil)
  screen)

(defun %terminal-screen-insert-lines (screen count)
  (let* ((height (terminal-screen-height screen))
         (width (terminal-screen-width screen))
         (row (terminal-screen-cursor-row screen))
         (count (%terminal-clamp count 0 (- height row)))
         (rows (terminal-screen-rows screen)))
    (when (plusp count)
      (loop for current from (1- height) downto (+ row count)
            do (replace (aref rows current)
                        (aref rows (- current count))))
      (loop for current from row below (+ row count)
            do (setf (aref rows current) (%terminal-blank-row width)))))
  screen)

(defun %terminal-screen-delete-lines (screen count)
  (let* ((height (terminal-screen-height screen))
         (width (terminal-screen-width screen))
         (row (terminal-screen-cursor-row screen))
         (count (%terminal-clamp count 0 (- height row)))
         (rows (terminal-screen-rows screen)))
    (when (plusp count)
      (loop for current from row below (- height count)
            do (replace (aref rows current)
                        (aref rows (+ current count))))
      (loop for current from (- height count) below height
            do (setf (aref rows current) (%terminal-blank-row width)))))
  screen)

(defun %terminal-screen-csi (screen final)
  (let* ((parameters (%terminal-screen-parse-parameters
                     (terminal-screen-csi-parameters screen)))
         (first (%terminal-screen-parameter parameters 0 1)))
    (case final
      (#\A
       (decf (terminal-screen-cursor-row screen)
             (%terminal-screen-parameter parameters 0 1)))
      (#\B
       (incf (terminal-screen-cursor-row screen)
             (%terminal-screen-parameter parameters 0 1)))
      (#\C
       (incf (terminal-screen-cursor-column screen)
             (%terminal-screen-parameter parameters 0 1)))
      (#\D
       (decf (terminal-screen-cursor-column screen)
             (%terminal-screen-parameter parameters 0 1)))
      (#\E
       (incf (terminal-screen-cursor-row screen)
             (%terminal-screen-parameter parameters 0 1))
       (setf (terminal-screen-cursor-column screen) 0))
      (#\F
       (decf (terminal-screen-cursor-row screen)
             (%terminal-screen-parameter parameters 0 1))
       (setf (terminal-screen-cursor-column screen) 0))
      ((#\G #\`)
       (setf (terminal-screen-cursor-column screen) (1- first)))
      (#\H
       (setf (terminal-screen-cursor-row screen)
             (1- (%terminal-screen-parameter parameters 0 1))
             (terminal-screen-cursor-column screen)
             (1- (%terminal-screen-parameter parameters 1 1))))
      (#\f
       (setf (terminal-screen-cursor-row screen)
             (1- (%terminal-screen-parameter parameters 0 1))
             (terminal-screen-cursor-column screen)
             (1- (%terminal-screen-parameter parameters 1 1))))
      (#\d
       (setf (terminal-screen-cursor-row screen)
             (1- (%terminal-screen-parameter parameters 0 1))))
      (#\a
       (incf (terminal-screen-cursor-column screen)
             (%terminal-screen-parameter parameters 0 1)))
      (#\e
       (incf (terminal-screen-cursor-row screen)
             (%terminal-screen-parameter parameters 0 1)))
      (#\J
       (%terminal-screen-clear-display screen
                                       (nth 0 parameters)))
      (#\K
       (%terminal-screen-clear-line screen
                                    (nth 0 parameters)))
      (#\m nil)
      (#\P
       (%terminal-screen-delete-characters screen first))
      (#\@
       (%terminal-screen-insert-characters screen first))
      (#\X
       (%terminal-screen-erase-characters screen first))
      (#\L
       (%terminal-screen-insert-lines screen first))
      (#\M
       (%terminal-screen-delete-lines screen first))
      (#\S
       (%terminal-screen-scroll-up screen first))
      (#\T
       (%terminal-screen-scroll-down screen first))
      (#\s
       (%terminal-screen-save-cursor screen))
      (#\u
       (%terminal-screen-restore-cursor screen))
      ((#\h #\l)
       (when (terminal-screen-csi-private screen)
         (dolist (parameter parameters)
           (case parameter
             ((47 1047 1049)
              (if (char= final #\h)
                  (%terminal-screen-enter-alternate screen)
                  (%terminal-screen-leave-alternate screen)))))))
      (#\r nil))
  (%terminal-screen-clamp-cursor screen)
  (setf (terminal-screen-wrap-pending screen) nil)
  screen))

(defun %terminal-screen-handle-escape (screen character)
  (case character
    (#\[
     (setf (terminal-screen-parser-state screen) :csi
           (terminal-screen-csi-parameters screen) ""
           (terminal-screen-csi-private screen) nil))
    (#\]
     (setf (terminal-screen-parser-state screen) :osc))
    (#\7
     (%terminal-screen-save-cursor screen)
     (setf (terminal-screen-parser-state screen) :ground))
    (#\8
     (%terminal-screen-restore-cursor screen)
     (setf (terminal-screen-parser-state screen) :ground))
    (#\D
     (%terminal-screen-line-feed screen)
     (setf (terminal-screen-parser-state screen) :ground))
    (#\E
     (%terminal-screen-next-line screen)
     (setf (terminal-screen-parser-state screen) :ground))
    (#\M
     (if (plusp (terminal-screen-cursor-row screen))
         (decf (terminal-screen-cursor-row screen))
         (%terminal-screen-scroll-down screen))
     (setf (terminal-screen-parser-state screen) :ground))
    (#\c
     (%terminal-screen-clear-all screen)
     (setf (terminal-screen-parser-state screen) :ground))
    (otherwise
     (setf (terminal-screen-parser-state screen) :ground))))

(defun %terminal-screen-feed-character (screen character)
  (case (terminal-screen-parser-state screen)
    (:ground
     (case character
       (#\Esc (setf (terminal-screen-parser-state screen) :escape))
       (#\Return (%terminal-screen-carriage-return screen))
       (#\Newline (%terminal-screen-line-feed screen))
       (#\Backspace
        (setf (terminal-screen-cursor-column screen)
              (max 0 (1- (terminal-screen-cursor-column screen)))
              (terminal-screen-wrap-pending screen) nil))
       (#\Tab
        (setf (terminal-screen-cursor-column screen)
              (min (1- (terminal-screen-width screen))
                   (* 8
                      (1+ (floor (terminal-screen-cursor-column screen)
                                 8))))
              (terminal-screen-wrap-pending screen) nil))
       (#\Bell nil)
       (otherwise
        (when (and (>= (char-code character) 32)
                   (/= (char-code character) 127))
          (%terminal-screen-write-character screen character)))))
    (:escape
     (%terminal-screen-handle-escape screen character))
    (:csi
     (cond
       ((and (zerop (length (terminal-screen-csi-parameters screen)))
             (char= character #\?))
        (setf (terminal-screen-csi-private screen) t))
       ((<= 64 (char-code character) 126)
        (%terminal-screen-csi screen character)
        (setf (terminal-screen-parser-state screen) :ground))
       ((or (digit-char-p character)
            (char= character #\;)
            (char= character #\:))
        (setf (terminal-screen-csi-parameters screen)
              (concatenate 'string
                           (terminal-screen-csi-parameters screen)
                           (string character))))
       (t
        (setf (terminal-screen-parser-state screen) :ground))))
    (:osc
     (cond
       ((char= character #\Bell)
        (setf (terminal-screen-parser-state screen) :ground))
       ((char= character #\Esc)
        (setf (terminal-screen-parser-state screen) :osc-escape))))
    (:osc-escape
     (setf (terminal-screen-parser-state screen) :ground)))
  screen)

(defun terminal-screen-feed (screen text)
  "Apply terminal TEXT to SCREEN and return SCREEN.

The parser keeps partial escape sequences between calls, which is important
because PTY reads may split a CSI sequence across several chunks."
  (check-type text string)
  (loop for character across text
        do (%terminal-screen-feed-character screen character))
  screen)

(defun %terminal-screen-row-content-p (row)
  (position-if-not (lambda (character) (char= character #\Space)) row))

(defun terminal-screen-text (screen)
  "Return the visible screen as newline-separated, trimmed terminal rows."
  (let ((last-row
          (loop for row downfrom (1- (terminal-screen-height screen)) downto 0
                when (%terminal-screen-row-content-p
                      (aref (terminal-screen-rows screen) row))
                  return row)))
    (if (null last-row)
        ""
        (with-output-to-string (output)
          (loop for row below (1+ last-row)
                do (when (plusp row)
                     (write-char #\Newline output))
                   (write-string
                    (string-right-trim " "
                                       (aref (terminal-screen-rows screen)
                                             row))
                    output))))))

(defun terminal-screen-resize (screen width height)
  "Resize SCREEN while retaining the top-left visible content."
  (unless (and (integerp width) (plusp width))
    (error "Terminal width must be a positive integer: ~S" width))
  (unless (and (integerp height) (plusp height))
    (error "Terminal height must be a positive integer: ~S" height))
  (let ((old-width (terminal-screen-width screen))
        (old-height (terminal-screen-height screen)))
    (declare (ignore old-width old-height))
    (setf (terminal-screen-width screen) width
          (terminal-screen-height screen) height
          (terminal-screen-rows screen)
          (%terminal-copy-rows (terminal-screen-rows screen) width height))
    (when (terminal-screen-main-rows screen)
      (setf (terminal-screen-main-rows screen)
            (%terminal-copy-rows (terminal-screen-main-rows screen)
                                 width
                                 height)))
    (%terminal-screen-clamp-cursor screen))
  screen)

(defstruct (terminal-session
            (:constructor %make-terminal-session
                (name program args directory buffer pty)))
  "A running PTY process and the Loom buffer displaying its screen."
  name
  program
  args
  directory
  buffer
  pty
  (screen (make-terminal-screen))
  (raw-output "" :type string)
  (alive-p t)
  exit-code)

(defun terminal-session-feed-output (session text)
  "Append PTY TEXT to SESSION and apply it to the terminal screen."
  (check-type text string)
  (setf (terminal-session-raw-output session)
        (concatenate 'string (terminal-session-raw-output session) text))
  (terminal-screen-feed (terminal-session-screen session) text)
  session)

(defun terminal-session-output (session)
  "Return SESSION's current visible screen as editor buffer text."
  (terminal-screen-text (terminal-session-screen session)))
