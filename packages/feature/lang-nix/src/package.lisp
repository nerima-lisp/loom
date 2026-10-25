(defpackage #:loom/feature/lang-nix
  (:use #:cl))

(progn
  (loom/feature/mode:register-major-mode
   :nix
   :name "Nix"
   :extensions '("nix")
   :comment-prefix "#" :comment-start "#" :comment-end nil
   :skip-closing-delimiter t
   :indentation-width 2 :tab-width 8
   :truncate-lines t :language-id "nix"
   :keywords '("abort" "assert" "baseNameOf" "builtins" "derivation"
               "dirOf" "else" "false" "fetchTarball" "fetchurl" "if"
               "import" "in" "inherit" "isNull" "let" "map" "null" "or"
               "rec" "removeAttrs" "then" "throw" "toString" "true" "with")))
