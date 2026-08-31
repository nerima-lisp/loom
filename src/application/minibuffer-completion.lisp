;;;; src/application/minibuffer-completion.lisp
;;;;
;;;; Application layer: minibuffer completion. This file keeps candidate
;;;; matching and the public MINIBUFFER-COMPLETE entrypoint separate from
;;;; keystroke classification/history navigation in
;;;; src/application/minibuffer-input.lisp and from the core minibuffer
;;;; state/activation protocol in src/application/minibuffer.lisp.
(in-package #:loom)

(defun %minibuffer-prefix-match-p (prefix candidate)
  "Return true when CANDIDATE begins with PREFIX, ignoring case."
  (and (<= (length prefix) (length candidate))
       (string-equal prefix candidate :end2 (length prefix))))

(defun %minibuffer-longest-common-prefix (candidates)
  "Return the case-preserving longest common prefix of CANDIDATES.
CANDIDATES must be a non-empty list of strings."
  (let* ((first (first candidates))
         (limit (loop for candidate in candidates
                      minimize (length candidate)))
         (common-length
           (loop for index below limit
                 while (every (lambda (candidate)
                                (char-equal (char first index)
                                            (char candidate index)))
                              (rest candidates))
                 finally (return index))))
    (subseq first 0 common-length)))

(defun minibuffer-complete (minibuffer)
  "Complete MINIBUFFER's current input using its activation's completion
function. The function receives the current input and must return a list of
candidate strings. Candidates are matched case-insensitively; a Tab key
replaces the input with their longest common prefix. With no completion
function or no matching candidates, the input is unchanged. Returns
MINIBUFFER."
  (let ((completion-function (%minibuffer-completion-function minibuffer)))
    (when (and (%minibuffer-active-p minibuffer) completion-function)
      (let ((candidates (funcall completion-function
                                 (%minibuffer-input minibuffer))))
        (unless (listp candidates)
          (error "Completion function must return a list: ~S" candidates))
        (dolist (candidate candidates)
          (unless (stringp candidate)
            (error "Completion candidates must be strings: ~S" candidate)))
        (let ((matches
                (remove-if-not
                 (lambda (candidate)
                   (%minibuffer-prefix-match-p
                    (%minibuffer-input minibuffer)
                    candidate))
                 candidates)))
          (when matches
            (setf (%minibuffer-input minibuffer)
                  (%minibuffer-longest-common-prefix matches)))))))
  minibuffer)
