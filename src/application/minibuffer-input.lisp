;;;; src/application/minibuffer-input.lisp
;;;;
;;;; Application layer: minibuffer keystroke handling. This file keeps key
;;;; classification, history navigation, and the public
;;;; MINIBUFFER-HANDLE-KEY entrypoint separate from completion in
;;;; src/application/minibuffer-completion.lisp and from the minibuffer's
;;;; core state/activation protocol in src/application/minibuffer.lisp.
(in-package #:loom)

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

(defun %minibuffer-key-kind (key-event type code)
  "Classify KEY-EVENT -- whose CL-TTY-KIT:KEY-EVENT-TYPE and -CODE the caller
has already read out as TYPE and CODE -- as one of the nine things
MINIBUFFER-HANDLE-KEY does with a keystroke: :CANCEL, :BACKSPACE,
:HISTORY-PREVIOUS, :HISTORY-NEXT, :COMPLETE, :CONFIRM, :CHARACTER, or
:IGNORE for anything else. Pure: the classification is separated from the
mutation so MINIBUFFER-HANDLE-KEY dispatches on one value rather than
re-testing TYPE and CODE at every branch."
  (cond
    ((%control-g-key-p key-event) :cancel)
    ((and (eq type :special) (eq code :backspace)) :backspace)
    ((and (eq type :special) (eq code :up)) :history-previous)
    ((and (eq type :special) (eq code :down)) :history-next)
    ((and (eq type :special) (eq code :tab)) :complete)
    ((and (eq type :special) (eq code :enter)) :confirm)
    ((eq type :character) :character)
    (t :ignore)))

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
      (setf (%minibuffer-input minibuffer) recalled))))

(defun %minibuffer-consume-key (minibuffer key-event)
  "Offer KEY-EVENT to MINIBUFFER's ON-KEY hook and return true when it took it."
  (let ((on-key (%minibuffer-on-key minibuffer)))
    (and on-key (funcall on-key key-event) t)))

(defun %minibuffer-notify-change (minibuffer)
  "Tell MINIBUFFER's ON-CHANGE hook that the input text just changed.

Only the branches that actually edit the input call this; confirm and cancel do
not, because by then the session they would notify is already over."
  (let ((on-change (%minibuffer-on-change minibuffer)))
    (when on-change
      (funcall on-change (%minibuffer-input minibuffer)))))

(defmacro %with-minibuffer-change ((minibuffer) &body body)
  "Apply an input mutation and notify the prompt's change hook once."
  `(progn
     ,@body
     (%minibuffer-notify-change ,minibuffer)))

(defun %minibuffer-cancel (minibuffer)
  (when (%minibuffer-on-cancel minibuffer)
    (funcall (%minibuffer-on-cancel minibuffer)))
  (%minibuffer-deactivate minibuffer))

(defun %minibuffer-delete-backward (minibuffer)
  (let ((input (%minibuffer-input minibuffer)))
    (when (string/= input "")
      (setf (%minibuffer-input minibuffer)
            (subseq input 0 (1- (length input)))))))

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
  (setf (%minibuffer-input minibuffer)
        (concatenate 'string (%minibuffer-input minibuffer)
                     (string code))))

(defun %minibuffer-dispatch-key (minibuffer kind code)
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
    (:complete
     (%with-minibuffer-change (minibuffer)
       (minibuffer-complete minibuffer)))
    (:confirm (%minibuffer-confirm minibuffer))
    (:character
     (%with-minibuffer-change (minibuffer)
       (%minibuffer-insert-character minibuffer code)))
    (t nil)))

(defun minibuffer-handle-key (minibuffer key-event)
  "Feed one KEY-EVENT (as returned by CL-TTY-KIT:DECODE-INPUT-CHUNK) to an
active MINIBUFFER: ordinary character events are appended to the input,
Backspace/Delete edit it, Up/Down recall history (when MINIBUFFER was created
with one, via CL-HISTORY-KIT:HISTORY-PREVIOUS/HISTORY-NEXT), RET invokes the
ON-CONFIRM callback passed to MINIBUFFER-ACTIVATE after deactivating the
current prompt (so the callback may activate a next prompt),
Tab invokes MINIBUFFER-COMPLETE,
and C-g invokes ON-CANCEL and deactivates MINIBUFFER. Has no effect if
MINIBUFFER is not active. Returns MINIBUFFER."
  (when (and (%minibuffer-active-p minibuffer)
               (not (%minibuffer-consume-key minibuffer key-event)))
      (let* ((type (cl-tty-kit:key-event-type key-event))
             (code (cl-tty-kit:key-event-code key-event))
             (kind (%minibuffer-key-kind key-event type code)))
        (%minibuffer-dispatch-key minibuffer kind code)))
  minibuffer)
