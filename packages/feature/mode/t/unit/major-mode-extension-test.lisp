(in-package #:loom/test)

(progn
  (asdf:load-system "loom-feature-lang-lisp")
  (asdf:load-system "loom-feature-lang-nix")
  (asdf:load-system "loom-feature-lang-web")
  (asdf:load-system "loom-feature-lang-markup"))

(describe
  "extension-defined major modes"
  (it
    "registers aliases, metadata, path rules, and parent modes"
    (%with-registered-major-modes (:loom-test-mode)
           (expect
            (register-major-mode
             :loom-test-mode
             :name "Loom Test"
             :aliases '("lt")
             :parent :python
             :extensions '(".loomtest")
             :filenames '("SpecialLoomFile")
             :comment-prefix "!"
             :indentation-width 3
             :language-id "loom-test"
             :keywords '("widget")
             :keybindings
             (list (cons '(:control #\x)
                         #'%loom-test-extension-command)))
            :to-be
            :loom-test-mode)
           (expect (major-mode-from-name "lt") :to-be :loom-test-mode)
           (expect (major-mode-from-name "Loom Test") :to-be :loom-test-mode)
           (expect (major-mode-parent :loom-test-mode) :to-be :python)
           (expect (major-mode-for-path "src/main.loomtest")
                   :to-be
                   :loom-test-mode)
           (expect (major-mode-for-path "/tmp/SpecialLoomFile")
                   :to-be
                   :loom-test-mode)
           (expect (major-mode-comment-prefix :loom-test-mode)
                   :to-equal
                   "!")
           (expect (major-mode-indentation-width :loom-test-mode)
                   :to-equal
                   3)
           (expect (major-mode-language-id :loom-test-mode)
                   :to-equal
                   "loom-test")
           (expect (major-mode-keywords :loom-test-mode)
                   :to-equal
                   '("widget"))
           (expect (major-mode-keybindings :loom-test-mode)
                   :to-equal
                   (list (cons '(:control #\x)
                               #'%loom-test-extension-command)))
           (let ((keywords (major-mode-keywords :loom-test-mode))
                 (keybindings (major-mode-keybindings :loom-test-mode))
                 (definition (major-mode-definition :loom-test-mode)))
             (setf (car keywords) "changed"
                   (cdr (first keybindings)) nil
                   (getf definition :name) "Changed")
             (expect (major-mode-keywords :loom-test-mode)
                     :to-equal
                     '("widget"))
             (expect (major-mode-keybindings :loom-test-mode)
                     :to-equal
                     (list (cons '(:control #\x)
                                 #'%loom-test-extension-command)))
             (expect (major-mode-name :loom-test-mode)
                     :to-equal
                     "Loom Test"))
           (expect (major-mode-names) :to-contain "Loom Test")
           (expect (unregister-major-mode :loom-test-mode)
                   :to-be
                   :loom-test-mode)
           (expect (major-mode-known-p :loom-test-mode) :to-be-falsy))
      ))

  (it
    "handles unknown and built-in removal requests explicitly"
    (expect (unregister-major-mode :loom-unknown-mode) :to-be nil)
    (expect
     (signals error
       (unregister-major-mode :python))
     :to-be-truthy))

  (it
    "normalizes optional registration metadata and rejects collisions"
    (%with-registered-major-modes (:loom-default-mode :loom-alias-collision)
           (expect
            (register-major-mode
             :loom-default-mode
             :aliases '("LmD")
             :extensions '(".loom" "Loom")
             :truncate-lines nil)
            :to-be
            :loom-default-mode)
           (expect (major-mode-parent :loom-default-mode)
                   :to-be
                   :fundamental)
           (expect (major-mode-language-id :loom-default-mode)
                   :to-equal
                   "loom-default-mode")
           (expect (major-mode-truncate-lines-p :loom-default-mode)
                   :to-be
                   nil)
           (expect (major-mode-for-path "README.loom")
                   :to-be
                   :loom-default-mode)
           (expect
            (signals error
              (register-major-mode :loom-default-mode))
            :to-be-truthy)
           (expect
            (signals error
              (register-major-mode :loom-alias-collision :aliases '("LmD")))
            :to-be-truthy)))

  (it
    "rejects malformed extension metadata before registration"
    (expect
     (signals error
       (register-major-mode 42))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-name :name 42))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-alias-list :aliases 42))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-alias-item :aliases '(42)))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-keyword-list :keywords 42))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-keywords :keywords '(42)))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-keybinding-list :keybindings 42))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-keybinding :keybindings '((nil . nil))))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-aliases :aliases '("dup" "DUP")))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-empty-name :name "   "))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-empty-extension :extensions '(".")))
     :to-be-truthy)
    (expect
     (signals error
       (register-major-mode :loom-invalid-indentation :indentation-width 0))
     :to-be-truthy))
  (it
  "registers built-in modes from their owning language slices"
  (let* ((mode-package (find-package "LOOM/FEATURE/MODE"))
         (registered-modes
           (symbol-value (find-symbol "*REGISTERED-MAJOR-MODES*" mode-package)))
         (modes
           '(:common-lisp :emacs-lisp :nix :typescript :typescript-react
             :markdown :org :json)))
    (expect (every (lambda (mode) (gethash mode registered-modes)) modes)
            :to-be-truthy)
    (expect
     (mapcar #'major-mode-for-path
             '("src/main.lisp" "src/main.lsp" "src/main.cl" "src/main.el"
               "default.nix" "src/main.ts" "src/main.mts" "src/main.cts"
               "src/main.tsx" "README.md" "README.markdown" "todo.org"
               "config.json"))
     :to-equal
     '(:common-lisp :common-lisp :common-lisp :emacs-lisp :nix :typescript
       :typescript :typescript :typescript-react :markdown :markdown :org
       :json))
    (expect (major-mode-from-name "common lisp") :to-be :common-lisp)
    (expect (major-mode-from-name "elisp") :to-be :emacs-lisp)
    (expect (major-mode-from-name "ts") :to-be :typescript)
    (expect (major-mode-from-name "tsx") :to-be :typescript-react)
    (expect
     (every (lambda (mode)
              (and (= (major-mode-indentation-width mode) 2)
                   (= (major-mode-tab-width mode) 8)))
            modes)
     :to-be-truthy)
    (expect (member "defun" (major-mode-keywords :common-lisp) :test #'string=)
            :to-be-truthy)
    (expect (member "defun" (major-mode-keywords :emacs-lisp) :test #'string=)
            :to-be-truthy)
    (expect (member "derivation" (major-mode-keywords :nix) :test #'string=)
            :to-be-truthy)
    (expect (member "interface" (major-mode-keywords :typescript) :test #'string=)
            :to-be-truthy)
    (expect
     (equal (major-mode-keywords :typescript)
            (major-mode-keywords :typescript-react))
     :to-be-truthy)
    (expect (major-mode-keywords :markdown) :to-equal nil)
    (expect (member "TODO" (major-mode-keywords :org) :test #'string=)
            :to-be-truthy)
    (expect (major-mode-keywords :json) :to-equal nil)
    (expect
     (mapcar #'major-mode-comment-prefix modes)
     :to-equal
     '(";" ";" "#" "//" "//" nil "#" nil))
    (expect
     (mapcar #'major-mode-comment-start modes)
     :to-equal
     '(";" ";" "# " "//" "//" "<!-- " "#" nil))
    (expect
     (mapcar #'major-mode-comment-end modes)
     :to-equal
     '(nil nil nil nil nil " -->" nil nil))
    (expect
     (mapcar #'major-mode-skip-closing-delimiter-p modes)
     :to-equal
     '(t t t t t nil nil t))
    (expect
     (mapcar #'major-mode-truncate-lines-p modes)
     :to-equal
     '(t t t t t nil nil t))
    (let ((mode (register-major-mode :loom-mode-metadata-defaults
                                    :comment-prefix "#")))
      (unwind-protect
           (progn
             (expect (major-mode-comment-start mode) :to-equal "#")
             (expect (major-mode-comment-end mode) :to-be nil)
             (expect (major-mode-skip-closing-delimiter-p mode) :to-be nil))
        (unregister-major-mode mode)))))
  (it
    "returns mode details and copied local keybindings"
    (%with-registered-major-modes (:loom-test-description)
      (register-major-mode
       :loom-test-description
       :name "Loom Test Description"
       :description "A test editing mode."
       :keybindings
       (list (cons '(:control #\x)
                   #'%loom-test-extension-command)))
      (let ((buffer (make-buffer :name "mode-description")))
        (buffer-set-major-mode buffer :loom-test-description)
        (let ((description (mode-description-for-buffer buffer)))
          (expect (getf description :mode) :to-be :loom-test-description)
          (expect (getf description :name)
                  :to-equal
                  "Loom Test Description")
          (expect (getf description :description)
                  :to-equal
                  "A test editing mode.")
          (expect (getf description :keybindings)
                  :to-equal
                  (major-mode-keybindings :loom-test-description))
          (setf (char (getf description :name) 0) #\X
                (char (getf description :description) 0) #\X
                (cdr (first (getf description :keybindings))) nil)
          (expect (mode-description-for-buffer buffer)
                  :to-equal
                  (list :mode :loom-test-description
                        :name "Loom Test Description"
                        :description "A test editing mode."
                        :keybindings
                        (list (cons '(:control #\x)
                                    #'%loom-test-extension-command)))))
        (expect (mode-description-for-buffer (make-buffer))
                :to-equal
                '(:mode :fundamental
                  :name "Fundamental"
                  :description nil
                  :keybindings nil)))))
