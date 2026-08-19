;;;; src/application/commands-prompts.lisp
;;;;
;;;; Application layer: prompt orchestration macros shared by command entry
;;;; points. The editor-state/session helper functions remain in
;;;; commands-internal.lisp; this file exists so continuation-style prompt
;;;; composition has its own compile/load boundary.
(in-package #:loom/application)

(defmacro with-prompts ((minibuffer-var minibuffer-form &key on-cancel) bindings &body body)
  "Prompt for each (VAR PROMPT-STRING &KEY COMPLETION-FUNCTION) pair in
BINDINGS in turn, binding VAR to the typed input, then run BODY with every VAR
bound and MINIBUFFER-VAR bound to MINIBUFFER-FORM's value (evaluated once).
ON-CANCEL, when supplied, is a form -- evaluated with MINIBUFFER-VAR in scope
-- run if the user cancels (C-g) at any prompt in the chain, not only the
first; it is threaded into every generated MINIBUFFER-ACTIVATE's :ON-CANCEL,
and the keyword is omitted entirely when ON-CANCEL is absent.

MINIBUFFER-ACTIVATE returns immediately; the typed answer only arrives later,
asynchronously, through its :ON-CONFIRM callback. A second, dependent prompt
therefore cannot be issued until the first one's callback runs -- the
continuation-passing chain REPLACE-STRING needs (prompt for the text to
replace, THEN prompt for its replacement) is unavoidable by construction.
WITH-PROMPTS is that chain written once, as a macro that expands BINDINGS
into nested MINIBUFFER-ACTIVATE/:ON-CONFIRM continuations, so a multi-prompt
command reads top-to-bottom like ordinary sequential code instead of as a
hand-nested pyramid of lambdas."
  (labels ((expand-bindings (bindings)
             (if bindings
                 (destructuring-bind (var prompt &key completion-function)
                     (first bindings)
                   `(loom:minibuffer-activate ,minibuffer-var ,prompt
                                              :on-confirm (lambda (,var)
                                                            ,(expand-bindings (rest bindings)))
                                              ,@(when completion-function
                                                  `(:completion-function
                                                    ,completion-function))
                                              ,@(when on-cancel
                                                  `(:on-cancel (lambda () ,on-cancel)))))
                 `(progn ,@body))))
    `(let ((,minibuffer-var ,minibuffer-form))
       ,(expand-bindings bindings))))
