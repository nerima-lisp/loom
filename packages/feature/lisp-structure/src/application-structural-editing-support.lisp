(in-package #:loom)

(defun %structural-list-close (text classes open)
  (let ((end (%sexp-forward-list-end text classes open)))
    (when end
      (1- end))))
(defun %structural-prefix-p ()
  "Whether a structural command has a prefix different from the replay default."
  (let ((argument (%structural-prefix-count)))
    (and argument (/= argument 1))))
(defun %structural-prefix-count ()
  (or loom/core/command:*current-prefix-argument*
      (when loom/core/editor-session:*editor-state*
        (loom/core/command:prefix-argument-value-for-editor))
      1))

(defun %structural-list-bounds (text classes offset)
  "Return (VALUES OPEN CLOSE) for the list enclosing OFFSET.

  CLOSE is the index of the closing character, not one past it. Returns NIL
when point is not inside a list, or when the list it is inside never closes."
  (let ((open (%backward-up-list-offset text offset classes)))
    (when open
      (let ((close (%structural-list-close text classes open)))
        (when close
          (values open close))))))

(defmacro %with-structural-list-bounds ((open close) (text classes offset)
                                         &body body)
  "Evaluate BODY only when OFFSET is inside a complete list."
  `(multiple-value-bind (,open ,close)
       (%structural-list-bounds ,text ,classes ,offset)
     (when ,close
       ,@body)))

(defun %structural-separator-needed-p (text offset)
  "True when inserting a delimiter at OFFSET would abut a token."
  (and (< offset (length text))
       (let ((character (char text offset)))
         (not (or (%sexp-whitespace-p character)
                  (member character +sexp-close-characters+ :test #'char=))))))

(defun %forward-barf-delimiter (text target delimiter)
  "Return DELIMITER for insertion at TARGET before the last expression.
Append a space when the character at TARGET requires separation."
  (if (%structural-separator-needed-p text target)
      (concatenate 'string delimiter " ")
      delimiter))

(defun %backward-barf-delimiter (text target delimiter)
  "Return DELIMITER positioned before the expression at TARGET."
  (if (and (plusp target)
           (not (%sexp-whitespace-p (char text (1- target)))))
      (concatenate 'string " " delimiter)
      delimiter))

(defun %consume-structural-prefix ()
  (let ((state loom/core/editor-session:*editor-state*))
    (when (and state
               (loom/core/command:prefix-argument-active-p
                (loom/core/command:prefix-argument-for-editor)))
      (loom/core/command:consume-prefix-argument-for-editor)
      (loom/core/command:minibuffer-message
       (loom/core/editor-session:editor-state-minibuffer state)
       nil))))
