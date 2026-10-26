(in-package #:loom/test)

;; Reference claims follow GNU Emacs manual sections: Undo,
;; Moving Point, Scrolling, Erasing, Recentering, Case,
;; Transpose, Fill Commands, Multi-line Indent, List Buffers,
;; Save Commands, Bookmarks, Lisp Eval, and Exiting.
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Undo.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Moving-Point.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Scrolling.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Erasing.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Recentering.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Case.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Transpose.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Fill-Commands.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Multi_002dline-Indent.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/List-Buffers.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Save-Commands.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Bookmarks.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Lisp-Eval.html
;; https://www.gnu.org/software/emacs/manual/html_node/emacs/Exiting.html
;; C-x C-u is upcase-region and is normally disabled in Emacs. The manual
;; lookup did not establish a default binding for C-x C-y or C-M-_;
;; the latter remains a Loom requirement, not a cited Emacs baseline.
(defparameter *emacs-keymap-reference*
  '((:id "undo-control-slash"
     :keys (((:control) . #\/)) :emacs "undo" :target "undo"
     :target-map :global :effective "undo" :owner :w3-1 :status :implemented)
    (:id "undo-control-underscore"
     :keys (((:control) . #\_)) :emacs "undo" :target "undo"
     :target-map :global :effective "undo" :owner :w3-1 :status :implemented)
    (:id "undo-control-x-u"
     :keys (((:control) . #\x) #\u) :emacs "undo" :target "undo"
     :target-map :global :effective "undo" :owner :w3-1 :status :implemented)
    (:id "redo-control-meta-underscore"
     :keys (((:alt :control) . #\_)) :emacs :not-established :target "redo"
     :target-map :global :effective "redo" :owner :w3-1 :status :implemented)
    (:id "backward-char-left"
     :keys (:left) :emacs "backward-char" :target "backward-char"
     :target-map :global :effective "backward-char" :owner :w3-1 :status :implemented)
    (:id "forward-char-right"
     :keys (:right) :emacs "forward-char" :target "forward-char"
     :target-map :global :effective "forward-char" :owner :w3-1 :status :implemented)
    (:id "previous-line-up"
     :keys (:up) :emacs "previous-line" :target "previous-line"
     :target-map :global :effective "previous-line" :owner :w3-1 :status :implemented)
    (:id "next-line-down"
     :keys (:down) :emacs "next-line" :target "next-line"
     :target-map :global :effective "next-line" :owner :w3-1 :status :implemented)
    (:id "beginning-of-line-home"
     :keys (:home) :emacs "move-beginning-of-line" :target "move-beginning-of-line"
     :target-map :global :effective "move-beginning-of-line" :owner :w3-1 :status :implemented)
    (:id "end-of-line-end"
     :keys (:end) :emacs "move-end-of-line" :target "move-end-of-line"
     :target-map :global :effective "move-end-of-line" :owner :w3-1 :status :implemented)
    (:id "scroll-down-page-up"
     :keys (:page-up) :emacs "scroll-down-command" :target "scroll-down-command"
     :target-map :global :effective "scroll-down-command" :owner :w3-1 :status :implemented)
    (:id "scroll-up-page-down"
     :keys (:page-down) :emacs "scroll-up-command" :target "scroll-up-command"
     :target-map :global :effective "scroll-up-command" :owner :w3-1 :status :implemented)
    (:id "delete-char-delete"
     :keys (:delete) :emacs "delete-char" :target "delete-char"
     :target-map :global :effective "delete-char" :owner :w3-1 :status :implemented)
    (:id "undo-legacy-control-x-control-u"
     :keys (((:control) . #\x) ((:control) . #\u))
     :emacs "upcase-region (normally disabled)" :target :unbound
     :target-map :global :effective nil :owner :w3-1 :status :removed)
    (:id "redo-legacy-control-x-control-y"
     :keys (((:control) . #\x) ((:control) . #\y)) :emacs :not-established
     :target :unbound :target-map :global :effective nil
     :owner :w3-1 :status :removed)
    (:id "recenter-control-l"
     :keys (((:control) . #\l)) :emacs "recenter-top-bottom"
     :target "recenter-top-bottom" :target-map :global
     :effective "recenter-top-bottom" :owner :w3-1 :status :implemented)
    (:id "transpose-control-t"
     :keys (((:control) . #\t)) :emacs "transpose-chars"
     :target "transpose-chars" :target-map :global
     :effective "transpose-chars" :owner :w3-1 :status :implemented)
    (:id "upcase-word-meta-u"
     :keys (((:alt) . #\u)) :emacs "upcase-word" :target "upcase-word"
     :target-map :global :effective "upcase-word" :owner :w3-1 :status :implemented)
    (:id "downcase-word-meta-l"
     :keys (((:alt) . #\l)) :emacs "downcase-word" :target "downcase-word"
     :target-map :global :effective "downcase-word" :owner :w3-1 :status :implemented)
    (:id "capitalize-word-meta-c"
     :keys (((:alt) . #\c)) :emacs "capitalize-word" :target "capitalize-word"
     :target-map :global :effective "capitalize-word" :owner :w3-1 :status :implemented)
    (:id "fill-paragraph-meta-q"
     :keys (((:alt) . #\q)) :emacs "fill-paragraph" :target "fill-paragraph"
     :target-map :global :effective "fill-paragraph" :owner :w3-1 :status :implemented)
    (:id "indent-region-control-meta-backslash"
     :keys (((:alt :control) . #\\)) :emacs "indent-region" :target "indent-for-tab-command"
     :target-map :mode-provider :effective "indent-for-tab-command" :owner :w3-7a :status :implemented)
    (:id "delete-indentation-meta-caret"
     :keys (((:alt) . #\^)) :emacs "delete-indentation" :target "delete-indentation"
     :target-map :global :effective "delete-indentation" :owner :w3-1 :status :implemented)
    (:id "goto-line-meta-g-meta-g"
     :keys (((:alt) . #\g) ((:alt) . #\g)) :emacs :not-established
     :target "goto-line" :target-map :global :effective "goto-line"
     :owner :w3-1 :status :implemented)
    (:id "goto-line-meta-g-plain-g"
     :keys (((:alt) . #\g) #\g) :emacs "goto-line" :target "goto-line"
     :target-map :global :effective "goto-line" :owner :w3-1
     :status :implemented)
    (:id "list-buffers-control-x-control-b"
     :keys (((:control) . #\x) ((:control) . #\b)) :emacs "list-buffers"
     :target "list-buffers" :target-map :global
     :effective :not-asserted :owner :w3-3 :status :pending)
    (:id "save-some-buffers-control-x-s"
     :keys (((:control) . #\x) #\s) :emacs "save-some-buffers"
     :target "save-some-buffers" :target-map :global
     :effective :not-asserted :owner :w3-3 :status :pending)
    (:id "eval-last-sexp-control-x-control-e"
     :keys (((:control) . #\x) ((:control) . #\e)) :emacs "eval-last-sexp"
     :target "eval-last-sexp" :target-map :global
     :effective "eval-last-sexp" :owner :w3-7b :status :implemented)
    (:id "eval-buffer-m-x"
     :keys nil :emacs "eval-buffer via M-x" :target "eval-buffer"
     :target-map :extended-command :effective "eval-buffer"
     :owner :w3-7b :status :implemented)
    (:id "file-tree-legacy-control-x-control-t"
     :keys (((:control) . #\x) ((:control) . #\t)) :emacs "transpose-lines"
     :target :unbound :target-map :global :effective nil
     :owner :w3-10 :status :removed)
    (:id "file-tree-control-x-d"
     :keys (((:control) . #\x) #\d) :emacs "dired"
     :target "toggle-file-tree" :target-map :global :effective "toggle-file-tree"
     :owner :w3-10 :status :implemented)
    (:id "list-bookmarks-control-x-r-l"
     :keys (((:control) . #\x) #\r #\l) :emacs "list-bookmarks"
     :target "list-bookmarks" :target-map :global :effective "list-bookmarks"
     :owner :w3-10 :status :implemented)
    (:id "load-session-m-x"
     :keys nil :emacs :no-default-command :target "load-session"
     :target-map :extended-command :effective "load-session"
     :owner :w3-10 :status :implemented)
    (:id "file-tree-next-local"
     :keys (((:control) . #\c) #\n) :emacs :not-established
     :target "file-tree-select-next" :target-map :file-tree-local
     :effective "file-tree-select-next" :owner :w3-10 :status :implemented)
    (:id "file-tree-previous-local"
     :keys (((:control) . #\c) #\p) :emacs :not-established
     :target "file-tree-select-previous" :target-map :file-tree-local
     :effective "file-tree-select-previous" :owner :w3-10 :status :implemented)
    (:id "file-tree-open-local"
     :keys (((:control) . #\c) #\o) :emacs :not-established
     :target "file-tree-open-selected" :target-map :file-tree-local
     :effective "file-tree-open-selected" :owner :w3-10 :status :implemented)
    (:id "file-tree-create-file-local"
     :keys (((:control) . #\c) #\c) :emacs :not-established
     :target "file-tree-create-file" :target-map :file-tree-local
     :effective "file-tree-create-file" :owner :w3-10 :status :implemented)
    (:id "file-tree-create-directory-local"
     :keys (((:control) . #\c) #\d) :emacs :not-established
     :target "file-tree-create-directory" :target-map :file-tree-local
     :effective "file-tree-create-directory" :owner :w3-10 :status :implemented)
    (:id "paredit-forward-slurp-local"
     :keys (((:control) . :right)) :emacs "forward-word"
     :target "forward-slurp-sexp" :target-map :lisp-mode-local
     :effective "forward-slurp-sexp" :owner :w3-7b :status :implemented)
    (:id "paredit-forward-barf-local"
     :keys (((:control) . :left)) :emacs "backward-word"
     :target "forward-barf-sexp" :target-map :lisp-mode-local
     :effective "forward-barf-sexp" :owner :w3-7b :status :implemented)
    (:id "paredit-backward-slurp-local"
     :keys (((:alt :control) . :left)) :emacs "backward-sexp"
     :target "backward-slurp-sexp" :target-map :lisp-mode-local
     :effective "backward-slurp-sexp" :owner :w3-7b :status :implemented)
    (:id "paredit-backward-barf-local"
     :keys (((:alt :control) . :right)) :emacs "forward-sexp"
     :target "backward-barf-sexp" :target-map :lisp-mode-local
     :effective "backward-barf-sexp" :owner :w3-7b :status :implemented)
    (:id "paredit-wrap-meta-open"
     :keys (((:alt) . #\()) :emacs "insert-parentheses"
     :target "wrap-round" :target-map :lisp-mode-local
     :effective "wrap-round" :owner :w3-7b :status :implemented)
    (:id "paredit-splice-meta-s"
     :keys (((:alt) . #\s)) :emacs :prefix :target "splice-sexp"
     :target-map :lisp-mode-local :effective "splice-sexp"
     :owner :w3-7b :status :implemented)
    (:id "paredit-raise-meta-r"
     :keys (((:alt) . #\r)) :emacs "move-to-window-line"
     :target "raise-sexp" :target-map :lisp-mode-local
     :effective "raise-sexp" :owner :w3-7b :status :implemented)
    (:id "suspend-frame-control-z"
     :keys (((:control) . #\z)) :emacs "suspend-frame on text terminal"
     :target "suspend-frame" :target-map :global
     :effective "suspend-frame" :owner :w3-2 :status :implemented)))
