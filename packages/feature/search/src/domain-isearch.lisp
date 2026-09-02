;;;; packages/feature/search/src/domain-isearch.lisp
;;;;
;;;; Domain layer: the incremental-search session and its pure transitions.
;;;; Everything here works on a buffer plus offsets and returns a new session
;;;; state; moving point, prompting, and drawing belong to the application and
;;;; presentation layers.
(in-package #:loom/feature/search)

(defstruct (isearch-session (:constructor %make-isearch-session)
                            (:conc-name %isearch-))
  ;; The buffer the session was started in. A session never follows point into
  ;; another buffer: the origin it can return to would mean nothing there.
  (buffer nil)
  ;; Where point was when the search began, so C-g can put it back exactly.
  (origin-offset 0)
  ;; Where the next search starts. A new character searches from here again so
  ;; the match grows in place; a repeat moves it past the current match first.
  (search-offset 0)
  (direction :forward)
  (pattern "")
  ;; The match point currently sits on, and every match in the buffer. The
  ;; renderer distinguishes the first from the rest.
  (match nil)
  (matches nil)
  (failed-p nil))

(defun make-isearch-session (buffer origin-offset &key (direction :forward))
  "Start a session in BUFFER with point at ORIGIN-OFFSET."
  (check-type direction (member :forward :backward))
  (%make-isearch-session :buffer buffer
                         :origin-offset origin-offset
                         :search-offset origin-offset
                         :direction direction))

(defun isearch-session-buffer (session)
  "Return the buffer SESSION searches."
  (%isearch-buffer session))

(defun isearch-session-origin-offset (session)
  "Return the offset point occupied when SESSION began."
  (%isearch-origin-offset session))

(defun isearch-session-direction (session)
  "Return :FORWARD or :BACKWARD."
  (%isearch-direction session))

(defun isearch-session-pattern (session)
  "Return the pattern typed into SESSION so far."
  (%isearch-pattern session))

(defun isearch-session-match (session)
  "Return the BUFFER-SPAN point currently sits on, or NIL."
  (%isearch-match session))

(defun isearch-session-matches (session)
  "Return every BUFFER-SPAN the current pattern matches, in buffer order."
  (copy-list (%isearch-matches session)))

(defun isearch-session-failed-p (session)
  "Return true when the current pattern has no match anywhere in range."
  (%isearch-failed-p session))

(defun %isearch-all-matches (buffer pattern)
  "Return every match for PATTERN in buffer order, restricted to the visible
region: BUFFER-SEARCH-SPANS starting at the narrow start wraps over nothing, so
the result needs no rotation back into order."
  (and (string/= pattern "")
       (buffer-search-spans buffer pattern
                            (buffer-narrow-start-offset buffer))))

(defun %isearch-forward-match (matches offset)
  (or (find-if (lambda (span) (>= (buffer-span-start span) offset)) matches)
      (first matches)))

(defun %isearch-backward-match (matches offset)
  (or (car (last (remove-if-not
                  (lambda (span) (<= (buffer-span-start span) offset))
                  matches)))
      (car (last matches))))

(defun %isearch-select-match (matches offset direction)
  "Return the match at or past OFFSET in DIRECTION, wrapping once."
  (when matches
    (ecase direction
      (:forward (%isearch-forward-match matches offset))
      (:backward (%isearch-backward-match matches offset)))))

(defun isearch-apply-pattern (session pattern)
  "Return SESSION searching for PATTERN from its current search offset.

An empty pattern is not a failure -- it is the state the prompt opens in -- so
it clears the match without reporting one."
  (let* ((buffer (%isearch-buffer session))
         (matches (%isearch-all-matches buffer pattern))
         (match (and matches
                     (%isearch-select-match matches
                                            (%isearch-search-offset session)
                                            (%isearch-direction session)))))
    (setf (%isearch-pattern session) pattern
          (%isearch-matches session) (or matches '())
          (%isearch-match session) match
          (%isearch-failed-p session) (and (string/= pattern "")
                                           (null match)))
    session))

(defun isearch-repeat (session direction)
  "Return SESSION advanced to the next match in DIRECTION.

Repeating with no pattern yet is what re-runs the previous search in Emacs;
here it simply leaves the session alone rather than inventing one. A repeat
that finds nothing new leaves the current match in place, so point stops moving
once the pattern has failed."
  (check-type direction (member :forward :backward))
  (setf (%isearch-direction session) direction)
  (let ((match (%isearch-match session)))
    (when match
      (setf (%isearch-search-offset session)
            (ecase direction
              (:forward (1+ (buffer-span-start match)))
              (:backward (1- (buffer-span-start match)))))))
  (isearch-apply-pattern session (%isearch-pattern session)))
