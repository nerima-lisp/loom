(in-package #:loom/core/minibuffer)

(defun %minibuffer-prefix-match-p (prefix candidate)
  "Return true when CANDIDATE begins with PREFIX, ignoring case."
  (and (<= (length prefix) (length candidate))
       (string-equal prefix candidate :end2 (length prefix))))
(defun %minibuffer-refresh-completion-candidates (minibuffer)
  "Refresh the active minibuffer's filtered candidates."
  (let ((completion-function (%minibuffer-completion-function minibuffer)))
    (setf (%minibuffer-completion-candidates minibuffer)
          (if (and (%minibuffer-active-p minibuffer) completion-function)
              (%minibuffer-matching-candidates
               (%minibuffer-input minibuffer)
               (%minibuffer-valid-completion-candidates
                completion-function
                (%minibuffer-input minibuffer)))
              nil)))
  minibuffer)
(defun %minibuffer-flex-match-p (input candidate)
  "Match INPUT as an ordered, case-insensitive subsequence of CANDIDATE."
  (loop with next-index = 0
        for character across input
        for found = (position character candidate
                              :start next-index
                              :test #'char-equal)
        do (unless found
             (return-from %minibuffer-flex-match-p nil))
           (setf next-index (1+ found))
        finally (return t)))
(defun %minibuffer-partial-match-p (input candidate)
  "Match ordered input parts at the start of candidate parts."
  (let ((input-parts (%minibuffer-completion-parts input))
        (candidate-parts (%minibuffer-completion-parts candidate)))
    (let ((remaining candidate-parts))
      (every (lambda (part)
               (let ((position
                       (position-if
                        (lambda (candidate-part)
                          (%minibuffer-prefix-match-p part candidate-part))
                        remaining)))
                 (when position
                   (setf remaining (nthcdr (1+ position) remaining)))
                 position))
             input-parts))))
(defun %minibuffer-completion-parts (text)
  "Split TEXT at path and word separators for partial completion."
  (let ((parts nil)
        (start 0))
    (loop for index from 0 to (length text)
          for separator-p =
            (or (= index (length text))
                (find (char text index)
                      '(#\/ #\- #\_ #\. #\Space #\Tab)))
          when separator-p
            do (when (< start index)
                 (push (subseq text start index) parts))
               (setf start (1+ index)))
    (nreverse parts)))

(defun %minibuffer-common-character-p (first candidates index)
  "Return true when CANDIDATES share FIRST's character at INDEX."
  (every (lambda (candidate)
           (char-equal (char first index)
                       (char candidate index)))
         candidates))

(defun %minibuffer-longest-common-prefix (candidates)
  "Return the case-preserving longest common prefix of CANDIDATES.
CANDIDATES must be a non-empty list of strings."
  (let* ((first (first candidates))
         (limit (loop for candidate in candidates
                      minimize (length candidate)))
         (common-length
           (loop for index below limit
                 while (%minibuffer-common-character-p
                        first (rest candidates) index)
                 finally (return index))))
    (subseq first 0 common-length)))

(defun %minibuffer-valid-completion-candidates (completion-function input)
  "Call COMPLETION-FUNCTION and validate its list of string candidates."
  (let ((candidates (funcall completion-function input)))
    (unless (listp candidates)
      (error "Completion function must return a list: ~S" candidates))
    (dolist (candidate candidates)
      (unless (stringp candidate)
        (error "Completion candidates must be strings: ~S" candidate)))
    candidates))

(defun %minibuffer-matching-candidates (input candidates)
  "Return prefix, partial, and flex matches for INPUT."
  (remove-if-not
   (lambda (candidate)
     (or (%minibuffer-prefix-match-p input candidate)
         (%minibuffer-partial-match-p input candidate)
         (%minibuffer-flex-match-p input candidate)))
   candidates))

(defun minibuffer-complete (minibuffer)
  "Complete MINIBUFFER's current input using its activation's completion
function. Tab replaces a unique match or extends the common prefix when every
match shares it. Matching candidates remain available for vertical display.
With no completion function or no matching candidates, the input is unchanged.
Returns MINIBUFFER."
  (when (and (%minibuffer-active-p minibuffer)
             (%minibuffer-completion-function minibuffer))
    (%minibuffer-refresh-completion-candidates minibuffer)
    (let ((matches (%minibuffer-completion-candidates minibuffer))
          (input (%minibuffer-input minibuffer)))
      (cond
        ((null matches) nil)
        ((null (rest matches))
         (setf (%minibuffer-input minibuffer) (first matches)
               (%minibuffer-point minibuffer) (length (first matches))))
        (t
         (let ((common (%minibuffer-longest-common-prefix matches)))
           (when (%minibuffer-prefix-match-p input common)
             (setf (%minibuffer-input minibuffer) common
                   (%minibuffer-point minibuffer) (length common))))))))
  minibuffer)
