(defpackage #:loom/feature/lang-markup
  (:use #:cl))

(progn
  (defun loom/feature/lang-markup::org-comment-dwim ()
    (let* ((buffer
             (loom/core/window-tree:window-buffer
              (loom/core/window-tree:window-tree-selected-window
               (loom/core/editor-session:editor-state-window-tree
                loom/core/editor-session:*editor-state*))))
           (span
             (and buffer
                  (loom/core/buffer:buffer-active-region-span buffer))))
      (if (and span
               (> (loom/core/buffer:buffer-span-end span)
                  (loom/core/buffer:buffer-span-start span)))
          (loom/feature/mode:comment-dwim)
          (loom/feature/mode:comment-line))))
  (eval-when (:load-toplevel :execute)
    (loom/core/command::register-internal-command
     :feature/lang-markup
     "lang-markup/org-comment-dwim"
     #'loom/feature/lang-markup::org-comment-dwim
     :mutates t :prompts nil :needs-region nil :external nil
     :modes (list :org)))
  (loom/feature/mode:register-major-mode
   :markdown
   :name "Markdown"
   :extensions '("md" "markdown")
   :comment-prefix nil
   :comment-start "<!-- " :comment-end " -->"
   :skip-closing-delimiter nil
   :indentation-width 2 :tab-width 8
   :truncate-lines nil :language-id "markdown"
   :keywords nil
   :keybindings '(((:alt #\;) . loom/feature/mode:comment-dwim)))
  (loom/feature/mode:register-major-mode
   :org
   :name "Org"
   :extensions '("org")
   :comment-prefix "#"
   :comment-start "#" :comment-end nil
   :skip-closing-delimiter nil
   :indentation-width 2 :tab-width 8
   :truncate-lines nil :language-id "org"
   :keywords '("CANCELLED" "CLOSED" "DEADLINE" "DONE" "NEXT"
               "SCHEDULED" "TODO" "WAITING")
   :keybindings '(((:alt #\;) . loom/feature/lang-markup::org-comment-dwim))))
