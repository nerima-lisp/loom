(in-package #:loom/core/minibuffer)

(defun %control-g-key-p (key-event)
  "True when KEY-EVENT is a Ctrl-G combination. CL-TTY-KIT reports a plain C0
Ctrl-G byte as a :SPECIAL :CONTROL-G event, but its kitty-protocol CSI-u path
reports letter keys -- Ctrl-G included -- as a :CHARACTER event with :CONTROL
in its modifiers instead (see keys-decode-internals.lisp's %CSI-U-EVENT), so
both shapes are recognized here."
  (or (and (eq (cl-tty-kit:key-event-type key-event) :special)
           (eq (cl-tty-kit:key-event-code key-event) :control-g))
      (and (eq (cl-tty-kit:key-event-type key-event) :character)
           (eql (cl-tty-kit:key-event-code key-event) #\g)
           (member :control (cl-tty-kit:key-event-modifiers key-event)))))

(defun %minibuffer-special-key-kind (code)
  "Return the minibuffer action for a special key CODE, or NIL."
  (case code
    (:control-a :move-beginning)
    (:control-e :move-end)
    (:control-f :move-forward)
    (:control-b :move-backward)
    (:control-k :kill-to-end)
    (:control-y :yank)
    (:backspace :backspace)
    (:up :history-previous)
    (:down :history-next)
    (:tab :complete)
    (:enter :confirm)
    (otherwise nil)))

(defun %minibuffer-key-kind (key-event type code)
  "Classify KEY-EVENT as a minibuffer action, insertion, or ignore."
  (let ((modifiers (cl-tty-kit:key-event-modifiers key-event)))
    (cond
      ((%control-g-key-p key-event) :cancel)
      ((and (eq type :special)
            (eq code :backspace)
            (equal modifiers '(:alt)))
       :kill-word-backward)
      ((and (eq type :character)
            (equal modifiers '(:control))
            (characterp code))
       (case (char-downcase code)
         (#\a :move-beginning)
         (#\e :move-end)
         (#\f :move-forward)
         (#\b :move-backward)
         (#\k :kill-to-end)
         (#\y :yank)
         (otherwise :ignore)))
      ((and (eq type :character)
            (equal modifiers '(:alt))
            (characterp code))
       (case (char-downcase code)
         (#\p :history-previous)
         (#\n :history-next)
         (otherwise :ignore)))
      ((and (eq type :special) (null modifiers))
       (or (%minibuffer-special-key-kind code) :ignore))
      ((and (eq type :character) (null modifiers))
       :character)
      (t :ignore))))

(defun %minibuffer-recall-history (minibuffer direction)
  "Replace MINIBUFFER's input with the history entry one step DIRECTION away:
:PREVIOUS drives CL-HISTORY-KIT:HISTORY-PREVIOUS, handing it the current input
so a partly typed line comes back on the way down again, and :NEXT drives
HISTORY-NEXT. A MINIBUFFER created without a history object, and a step that
ran off the end of the history, both leave the input untouched."
  (let* ((history (%minibuffer-history minibuffer))
         (recalled (when history
                     (ecase direction
                       (:previous (history-kit:history-previous
                                   history (%minibuffer-input minibuffer)))
                       (:next (history-kit:history-next history))))))
    (when recalled
      (setf (%minibuffer-input minibuffer) recalled
            (%minibuffer-point minibuffer) (length recalled)))))

(defun %minibuffer-consume-key (minibuffer key-event)
  "Offer KEY-EVENT to MINIBUFFER's ON-KEY hook and return true when it took it."
  (let ((on-key (%minibuffer-on-key minibuffer)))
    (and on-key (funcall on-key key-event) t)))

(defun %minibuffer-notify-change (minibuffer previous-input)
  "Refresh completion state and notify MINIBUFFER's on-change hook when input changes."
  (unless (string= previous-input (%minibuffer-input minibuffer))
    (when (%minibuffer-completion-function minibuffer)
      (%minibuffer-refresh-completion-candidates minibuffer))
    (let ((on-change (%minibuffer-on-change minibuffer)))
      (when on-change
        (funcall on-change (%minibuffer-input minibuffer)))))
  minibuffer)

(defmacro %with-minibuffer-change ((minibuffer) &body body)
  "Apply an input mutation and notify the prompt's change hook once."
  (let ((previous-input (gensym "PREVIOUS-INPUT-")))
    `(let ((,previous-input (%minibuffer-input ,minibuffer)))
       ,@body
       (%minibuffer-notify-change ,minibuffer ,previous-input))))

(defun %minibuffer-cancel (minibuffer)
  (when (%minibuffer-on-cancel minibuffer)
    (funcall (%minibuffer-on-cancel minibuffer)))
  (%minibuffer-deactivate minibuffer))

(defun %minibuffer-delete-backward (minibuffer)
  (let* ((input (%minibuffer-input minibuffer))
         (point (%minibuffer-point minibuffer)))
    (when (plusp point)
      (setf (%minibuffer-input minibuffer)
            (concatenate 'string
                         (subseq input 0 (1- point))
                         (subseq input point))
            (%minibuffer-point minibuffer) (1- point)))))

(defun %minibuffer-confirm (minibuffer)
  (let ((input (%minibuffer-input minibuffer))
        (history (%minibuffer-history minibuffer))
        (on-confirm (%minibuffer-on-confirm minibuffer)))
    (when history
      (history-kit:history-add history input))
    (%minibuffer-deactivate minibuffer)
    (when on-confirm
      (funcall on-confirm input))))

(defun %minibuffer-insert-character (minibuffer code)
  (let* ((input (%minibuffer-input minibuffer))
         (point (%minibuffer-point minibuffer)))
    (setf (%minibuffer-input minibuffer)
          (concatenate 'string
                       (subseq input 0 point)
                       (string code)
                       (subseq input point))
          (%minibuffer-point minibuffer) (1+ point))))

(defun %minibuffer-dispatch-key (minibuffer kind code)
  (labels ((word-character-p (character)
             (or (alphanumericp character) (char= character #\_)))
           (space-character-p (character)
             (member character '(#\Space #\Tab #\Newline #\Return #\Page)))
           (backward-word-start (input point)
             (let ((start point))
               (loop while (and (plusp start)
                                (space-character-p (char input (1- start))))
                     do (decf start))
               (loop while (and (plusp start)
                                (word-character-p (char input (1- start))))
                     do (decf start))
               (when (= start point)
                 (when (plusp start)
                   (decf start)))
               start)))
    (case kind
      (:cancel (%minibuffer-cancel minibuffer))
      (:backspace
       (%with-minibuffer-change (minibuffer)
         (%minibuffer-delete-backward minibuffer)))
      (:history-previous
       (%with-minibuffer-change (minibuffer)
         (%minibuffer-recall-history minibuffer :previous)))
      (:history-next
       (%with-minibuffer-change (minibuffer)
         (%minibuffer-recall-history minibuffer :next)))
      (:move-beginning
       (%with-minibuffer-change (minibuffer)
         (setf (%minibuffer-point minibuffer) 0)))
      (:move-end
       (%with-minibuffer-change (minibuffer)
         (setf (%minibuffer-point minibuffer)
               (length (%minibuffer-input minibuffer)))))
      (:move-forward
       (%with-minibuffer-change (minibuffer)
         (setf (%minibuffer-point minibuffer)
               (min (length (%minibuffer-input minibuffer))
                    (1+ (%minibuffer-point minibuffer))))))
      (:move-backward
       (%with-minibuffer-change (minibuffer)
         (setf (%minibuffer-point minibuffer)
               (max 0 (1- (%minibuffer-point minibuffer))))))
      (:kill-to-end
       (%with-minibuffer-change (minibuffer)
         (let* ((input (%minibuffer-input minibuffer))
                (point (%minibuffer-point minibuffer)))
           (setf (%minibuffer-kill-text minibuffer) (subseq input point)
                 (%minibuffer-input minibuffer) (subseq input 0 point)))))
      (:yank
       (%with-minibuffer-change (minibuffer)
         (loop for character across (%minibuffer-kill-text minibuffer)
               do (%minibuffer-insert-character minibuffer character))))
      (:kill-word-backward
       (%with-minibuffer-change (minibuffer)
         (let* ((input (%minibuffer-input minibuffer))
                (point (%minibuffer-point minibuffer))
                (start (backward-word-start input point)))
           (when (< start point)
             (setf (%minibuffer-kill-text minibuffer)
                   (subseq input start point)
                   (%minibuffer-input minibuffer)
                   (concatenate 'string (subseq input 0 start)
                                (subseq input point))
                   (%minibuffer-point minibuffer) start)))))
      (:complete
       (%with-minibuffer-change (minibuffer)
         (minibuffer-complete minibuffer)))
      (:confirm (%minibuffer-confirm minibuffer))
      (:character
       (%with-minibuffer-change (minibuffer)
         (%minibuffer-insert-character minibuffer code)))
      (t nil))))

(defun minibuffer-handle-key (minibuffer key-event)
  "Feed one KEY-EVENT to an active MINIBUFFER. Ordinary characters insert at
point. C-a/C-e move to the beginning or end, C-f/C-b move one character, C-k
kills from point to the end, C-y yanks the last killed text, and M-DEL kills
the previous word. M-p/M-n and Up/Down traverse history. RET confirms, Tab
completes, and C-g cancels. Returns MINIBUFFER."
  (when (and (%minibuffer-active-p minibuffer)
             (not (%minibuffer-consume-key minibuffer key-event)))
    (let* ((type (cl-tty-kit:key-event-type key-event))
           (code (cl-tty-kit:key-event-code key-event))
           (kind (%minibuffer-key-kind key-event type code)))
      (%minibuffer-dispatch-key minibuffer kind code)))
  minibuffer)
