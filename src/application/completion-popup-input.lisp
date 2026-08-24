;;;; src/application/completion-popup-input.lisp
;;;;
;;;; Keystroke handling for an active completion popup, and the edit that
;;;; accepting a candidate performs.
;;;;
;;;; The popup gets first refusal on a key and then gets out of the way: a key
;;;; it does not recognize dismisses it and is *not* consumed, so the key still
;;;; reaches its ordinary binding. Swallowing it would mean a stray popup
;;;; silently eating the next character the user typed.
(in-package #:loom)

(defparameter +completion-popup-next-keys+
  '(((:control) . #\n) (nil . :down))
  "Descriptors that move the selection down.")

(defparameter +completion-popup-previous-keys+
  '(((:control) . #\p) (nil . :up))
  "Descriptors that move the selection up.")

(defparameter +completion-popup-accept-keys+
  '((nil . :enter) (nil . :tab))
  "Descriptors that insert the selected candidate.")

(defparameter +completion-popup-dismiss-keys+
  '(((:control) . #\g) (nil . :escape))
  "Descriptors that close the popup without inserting anything.")

(defun %completion-popup ()
  (and *editor-state* (editor-state-completion *editor-state*)))

(defun %completion-popup-active-p ()
  (not (null (%completion-popup))))

(defun %completion-popup-dismiss ()
  "Close the popup and return NIL."
  (when *editor-state*
    (setf (editor-state-completion *editor-state*) nil))
  nil)

(defun %completion-popup-key-member-p (descriptor descriptors)
  (let ((normalized (normalize-key-descriptor descriptor)))
    (loop for candidate in descriptors
          thereis (equal normalized (normalize-key-descriptor candidate)))))

(defun %completion-popup-accept ()
  "Replace the completed prefix with the selected candidate. Returns true.

The replacement only runs while point is still on the anchored line at or past
the anchored column. Point can have moved since the request was sent -- the
answer arrives frames later -- and inserting into wherever it happens to be now
would corrupt unrelated text."
  (let* ((completion (%completion-popup))
         (item (and completion (editor-completion-selected completion))))
    (when item
      (let* ((buffer (editor-completion-buffer completion))
             (line (editor-completion-line completion))
             (column (editor-completion-column completion)))
        (when (and (eq buffer (%selected-buffer))
                   (= line (buffer-point-line buffer))
                   (<= column (buffer-point-column buffer)))
          (buffer-delete-region buffer line column
                                line (buffer-point-column buffer))
          (buffer-set-point buffer line column)
          (buffer-insert-string buffer (editor-completion-item-text item)))))
    (%completion-popup-dismiss)
    t))

(defun %completion-popup-handle-key (event)
  "Offer EVENT to the active popup and return true when the popup consumed it."
  (let ((completion (%completion-popup)))
    (when completion
      (let ((descriptor (%key-event->descriptor event)))
        (cond
          ((%completion-popup-key-member-p descriptor
                                           +completion-popup-next-keys+)
           (editor-completion-move completion 1)
           t)
          ((%completion-popup-key-member-p descriptor
                                           +completion-popup-previous-keys+)
           (editor-completion-move completion -1)
           t)
          ((%completion-popup-key-member-p descriptor
                                           +completion-popup-accept-keys+)
           (%completion-popup-accept))
          ((%completion-popup-key-member-p descriptor
                                           +completion-popup-dismiss-keys+)
           (%completion-popup-dismiss)
           t)
          (t
           (%completion-popup-dismiss)
           nil))))))
