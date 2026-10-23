(in-package #:loom)

(define-command-spec-groups *movement-command-spec-groups*
  (command-spec-group "movement"
      (command-spec "universal-argument" universal-argument
                    :keys ((:control #\u))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "forward-char" forward-char :keys ((:control #\f))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "backward-char" backward-char :keys ((:control #\b))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "next-line" next-line :keys ((:control #\n))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "previous-line" previous-line :keys ((:control #\p))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "forward-sexp" forward-sexp
                    :keys ((:control :alt #\f))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "backward-sexp" backward-sexp
                    :keys ((:control :alt #\b))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "backward-up-list" backward-up-list
                    :keys ((:control :alt #\u))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "down-list" down-list
                    :keys ((:control :alt #\d))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "kill-sexp" kill-sexp
                    :keys ((:control :alt #\k))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "forward-slurp-sexp" forward-slurp-sexp
                    :keys ((:control :right))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "forward-barf-sexp" forward-barf-sexp
                    :keys ((:control :left))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "backward-slurp-sexp" backward-slurp-sexp
                    :keys ((:control :alt :left))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "backward-barf-sexp" backward-barf-sexp
                    :keys ((:control :alt :right))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "wrap-round" wrap-round
                    :keys ((:alt #\())
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "splice-sexp" splice-sexp
                    :keys ((:alt #\s))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "raise-sexp" raise-sexp
                    :keys ((:alt #\r))
                    :mutates T
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "forward-word" forward-word :keys ((:alt #\f))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "backward-word" backward-word :keys ((:alt #\b))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "move-beginning-of-line" move-beginning-of-line
                    :keys ((:control #\a))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "move-end-of-line" move-end-of-line :keys ((:control #\e))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "beginning-of-buffer" beginning-of-buffer :keys ((:alt #\<))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "end-of-buffer" end-of-buffer :keys ((:alt #\>))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "scroll-up-command" scroll-up-command :keys ((:control #\v))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "scroll-down-command" scroll-down-command :keys ((:alt #\v))
                    :mutates NIL
                    :prompts NIL
                    :needs-region NIL
                    :external NIL
                    :modes (:all))
      (command-spec "goto-line" goto-line :keys (((:alt #\g) #\g))
                    :mutates NIL
                    :prompts (:numeric)
                    :needs-region NIL
                    :external NIL
                    :modes (:all))))
