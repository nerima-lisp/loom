(defpackage #:loom/feature/lang-markup
  (:use #:cl))

(progn
  (loom/feature/mode:register-major-mode
   :markdown
   :name "Markdown"
   :extensions '("md" "markdown")
   :comment-prefix "#" :comment-start "<!--" :comment-end "-->"
   :skip-closing-delimiter nil
   :indentation-width 2 :tab-width 8
   :truncate-lines nil :language-id "markdown"
   :keywords nil)
  (loom/feature/mode:register-major-mode
   :org
   :name "Org"
   :extensions '("org")
   :comment-prefix "#" :comment-start "#" :comment-end nil
   :skip-closing-delimiter nil
   :indentation-width 2 :tab-width 8
   :truncate-lines nil :language-id "org"
   :keywords '("CANCELLED" "CLOSED" "DEADLINE" "DONE" "NEXT"
               "SCHEDULED" "TODO" "WAITING")))
