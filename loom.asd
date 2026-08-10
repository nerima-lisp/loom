;;;; loom.asd

;;; This form comes FIRST, before any defsystem. ASDF binds *package* to
;;; ASDF-USER only for a file it loads itself; read any other way -- a REPL
;;; `load`, an editor evaluating the buffer, flake.nix parsing :version -- the
;;; file is read in whatever package happens to be current, and an unqualified
;;; `defsystem` then fails to read at all. Saying it makes the file
;;; self-contained. See PACKAGE_STANDARD.md "asd の書き方".
(in-package #:asdf-user)

;;; Metadata keys follow the org's canonical order:
;;;   :description :long-description :author :maintainer :license :version
;;;   :homepage :bug-tracker :source-control :depends-on :pathname :serial
;;;   :components :in-order-to
;;; so a diff between two sibling repositories shows what actually differs and
;;; a missing key is visible by position.
(asdf:defsystem "loom"
  :description "Terminal text editor with Emacs-like keybindings"
  :long-description "loom is a terminal text editor for SBCL with Emacs-style
keybindings, built on cl-tty-kit for terminal I/O and rendering, cl-host-kit
for filesystem access, and cl-history-kit for minibuffer input recall. The
composition root follows src/<DDD>, while reusable editing code lives in
packages/core/editor and complete user-facing slices live in
packages/feature/<feature>/src. Those package files retain explicit domain,
application, infrastructure, and presentation boundaries without making the
root source tree responsible for every feature."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/loom"
  :bug-tracker "https://github.com/nerima-lisp/loom/issues"
  :source-control (:git "https://github.com/nerima-lisp/loom.git")
  :depends-on ("cl-tty-kit" "cl-host-kit" "cl-history-kit" "cl-prolog" "cl-cli"
               "cl-regex-kit" "cl-boundary-kit" "cl-concurrent-kit" "cl-json-kit")
  :pathname "."
  :serial t
  :components
  ;; File order, :serial t: package declarations first; then domain (pure state/logic,
  ;; no dependency on cl-tty-kit/cl-host-kit/cl-history-kit, so nothing
  ;; below can forward-reference it); then infrastructure (direct integration
  ;; with those sibling libraries); then application (orchestrates domain +
  ;; infrastructure via *editor-state*); then presentation (composes
  ;; domain/application/infrastructure output for the screen); main last,
  ;; since it is the entry point everything else exists to be called from.
  ;; Path-prefixed :file names, not nested :module blocks, per nshell.asd's
  ;; precedent. Package-local filenames preserve the DDD layer in their
  ;; basename (for example, domain-buffer and application-commands-search),
  ;; and each feature owns its package declaration next to its source. This
  ;; root list remains the composition root and load-order contract.
  ((:file "src/package")
   (:file "packages/feature/mode/src/package")
   (:file "packages/feature/syntax-highlighting/src/package")
   (:file "packages/feature/project/src/package")
   (:file "packages/feature/search/src/package")
   (:file "packages/feature/window/src/package")
   (:file "packages/feature/workspace/src/package")
   (:file "packages/feature/file-tree/src/package")
   (:file "packages/feature/evaluation/src/package")
   (:file "packages/feature/shell/src/package")
   (:file "packages/feature/format/src/package")
   (:file "packages/feature/auto-save/src/package")
   (:file "packages/feature/terminal/src/package")
   (:file "packages/feature/git/src/package")
   (:file "packages/feature/keyboard-macro/src/package")
   (:file "packages/feature/register/src/package")
   (:file "packages/feature/session/src/package")
   (:file "packages/feature/user-init/src/package")
   (:file "packages/feature/lsp/src/package")
   (:file "packages/feature/multiple-cursors/src/package")
   (:file "src/package-user")
   (:file "packages/feature/mode/src/domain-major-mode")
   (:file "packages/feature/syntax-highlighting/src/domain-syntax-highlighting")
   (:file "packages/feature/project/src/domain-project")
   (:file "packages/core/editor/src/domain-buffer-storage")
   (:file "packages/core/editor/src/domain-buffer")
   (:file "packages/feature/multiple-cursors/src/domain-multiple-cursor")
   (:file "packages/core/editor/src/domain-prefix-argument")
   (:file "packages/feature/search/src/domain-buffer-search")
   (:file "packages/feature/window/src/domain-window")
   (:file "packages/feature/window/src/domain-window-operations")
   (:file "packages/feature/workspace/src/domain-workspace")
   (:file "packages/feature/session/src/domain-session")
   (:file "packages/feature/evaluation/src/domain-evaluation")
   (:file "packages/feature/auto-save/src/domain-auto-save")
   (:file "packages/feature/terminal/src/domain-terminal")
   (:file "packages/feature/terminal/src/domain-terminal-session")
   (:file "packages/feature/shell/src/domain-shell")
   (:file "packages/feature/git/src/domain-git")
   (:file "packages/feature/lsp/src/domain-lsp")
   (:file "src/domain/keymap")
   (:file "packages/feature/file-tree/src/domain-file-tree")
   (:file "src/infrastructure/terminal-renderer")
   (:file "packages/feature/file-tree/src/infrastructure-filesystem-native")
   (:file "packages/feature/file-tree/src/infrastructure-filesystem")
   (:file "packages/feature/auto-save/src/infrastructure-auto-save")
   (:file "packages/feature/terminal/src/infrastructure-terminal")
   (:file "packages/feature/project/src/infrastructure-project-filesystem")
   (:file "packages/feature/session/src/infrastructure-session-store")
   (:file "packages/feature/user-init/src/infrastructure-user-init")
   (:file "packages/feature/evaluation/src/infrastructure-lisp-evaluator")
   (:file "packages/feature/shell/src/infrastructure-shell")
   (:file "packages/feature/git/src/infrastructure-git")
   (:file "packages/feature/lsp/src/infrastructure-lsp-framing")
   (:file "packages/feature/lsp/src/infrastructure-lsp-process")
   (:file "packages/feature/file-tree/src/infrastructure-concurrent-runtime")
   (:file "packages/feature/register/src/domain-register")
   (:file "packages/feature/keyboard-macro/src/domain-keyboard-macro")
   (:file "src/application/editor-state")
   (:file "src/application/minibuffer")
   (:file "src/application/commands-internal")
   (:file "packages/feature/multiple-cursors/src/application-commands-multiple-cursor")
   (:file "src/application/command-registry")
   (:file "packages/feature/mode/src/application-major-mode")
   (:file "packages/feature/project/src/application-commands-project")
   (:file "packages/core/editor/src/application-commands-prefix-argument")
   (:file "packages/core/editor/src/application-commands-movement")
   (:file "packages/core/editor/src/application-commands-editing")
   (:file "packages/feature/register/src/application-commands-register")
   (:file "packages/feature/keyboard-macro/src/application-commands-keyboard-macro")
   (:file "packages/feature/search/src/application-commands-search")
   (:file "packages/feature/file-tree/src/application-commands-file")
   (:file "packages/feature/window/src/application-commands-window")
   (:file "packages/feature/workspace/src/application-commands-workspace")
   (:file "packages/feature/file-tree/src/application-commands-file-tree")
   (:file "packages/feature/session/src/application-commands-session")
   (:file "packages/feature/evaluation/src/application-commands-evaluation")
   (:file "packages/feature/shell/src/application-commands-shell")
   (:file "packages/feature/format/src/application-commands-format")
   (:file "packages/feature/auto-save/src/application-commands-auto-save")
   (:file "packages/feature/terminal/src/application-commands-terminal")
   (:file "packages/feature/git/src/application-commands-git")
   (:file "packages/feature/lsp/src/application-lsp-service")
   (:file "packages/feature/lsp/src/application-commands-lsp")
   (:file "src/application/commands-misc")
   (:file "src/application/command-definitions")
   (:file "src/application/commands-keybindings")
   (:file "packages/feature/user-init/src/application-user-configuration")
   (:file "packages/feature/syntax-highlighting/src/presentation-syntax-highlighting")
   (:file "src/presentation/layout")
   (:file "src/application/input-dispatch")
   (:file "src/application/event-loop")
   (:file "src/application/startup")
   (:file "src/main"))
  ;; The three build keys and the :perform below are exempt from the metadata
  ;; order above -- PACKAGE_STANDARD.md names cl-weave's identical trio and
  ;; cl-tty-kit's :perform as "はどこに書いても構いません" -- and they sit here,
  ;; together, because they are one statement: how this system becomes a
  ;; binary. They are also the ONLY statement of it, so `nix build` and a plain
  ;; `(asdf:operate 'asdf:program-op "loom")` in a REPL produce the same
  ;; executable; flake.nix no longer repeats the entry point in a hand-written
  ;; save-lisp-and-die of its own.
  :build-operation "program-op"
  :build-pathname "loom"
  :entry-point "loom:main"
  ;; Why this method exists at all: ASDF's own `perform ((o image-op) (c
  ;; system))` calls `uiop:dump-image` and never passes :compression, and SBCL
  ;; offers no global that would add it, so a system that wants a compressed
  ;; core must dump it itself. Performing the dump here is what lets flake.nix
  ;; delegate to cl-nix-forge's mkExecutable, which drives program-op and
  ;; documents :compression as the one thing it cannot express.
  ;;
  ;; ASDF:OUTPUT-FILE rather than a literal "loom": it resolves
  ;; :build-pathname through whatever output translations are configured, so
  ;; the image lands exactly where the default method would have put it --
  ;; which is the path mkExecutable then goes looking for.
  ;;
  ;; The toplevel function is read back out of :entry-point above instead of
  ;; being named a second time, so the two cannot drift apart -- the same
  ;; idiom nshell.asd and cl-nix-forge's own Darwin delivery path use. UIOP
  ;; and ASDF/SYSTEM are safe to name at read time here: ASDF ships both, so
  ;; they are already in the image by the time this file is read. `#'loom:main`
  ;; would NOT be -- it is a read-time error, which is why the entry point is
  ;; a string.
  :perform (asdf:program-op (o c)
             (sb-ext:save-lisp-and-die
              (asdf:output-file o c)
              :executable t
              :compression t
              ;; Stop the SBCL C runtime from intercepting --version/--help
              ;; and other runtime flags before loom:main runs.
              :save-runtime-options t
              :toplevel (uiop:ensure-function
                         (asdf/system:component-entry-point c))))
  :in-order-to ((asdf:test-op (asdf:test-op "loom/test"))))

(asdf:defsystem "loom/test"
  :description "Test system for loom"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/loom"
  :bug-tracker "https://github.com/nerima-lisp/loom/issues"
  :source-control (:git "https://github.com/nerima-lisp/loom.git")
  :depends-on ("loom" "cl-weave" "cl-date-kit")
  :pathname "."
  :serial t
  :components
  ((:file "t/package")
   (:file "t/test-helpers")
   (:file "t/unit/protocol-test")
   (:file "t/unit/buffer-test")
   (:file "t/unit/syntax-highlighting-test")
   (:file "t/unit/major-mode-test")
   (:file "t/unit/project-test")
   (:file "t/unit/terminal-renderer-test")
   (:file "t/unit/filesystem-test")
   (:file "t/unit/window-test")
   (:file "t/unit/workspace-test")
   (:file "t/unit/keymap-test")
   (:file "t/unit/register-test")
   (:file "t/unit/keyboard-macro-test")
   (:file "t/unit/prefix-argument-test")
   (:file "t/unit/file-tree-test")
   (:file "t/unit/minibuffer-test")
   (:file "t/unit/multiple-cursor-test")
   (:file "t/unit/evaluation-test")
   (:file "t/unit/shell-test")
   (:file "t/unit/format-test")
   (:file "t/unit/auto-save-test")
   (:file "t/unit/terminal-test")
   (:file "t/unit/git-test")
   (:file "t/unit/lsp-framing-test")
   (:file "t/unit/cli-test")
   (:file "t/integration/commands-test")
   (:file "t/integration/workspace-test")
   (:file "t/integration/lsp-test")
   (:file "t/integration/commands-movement-test")
   (:file "t/integration/commands-editing-test")
   (:file "t/integration/major-mode-test")
   (:file "t/integration/project-test")
   (:file "t/integration/commands-misc-test")
   (:file "t/integration/commands-keybindings-test")
   (:file "t/integration/register-test")
   (:file "t/integration/keyboard-macro-test")
   (:file "t/integration/prefix-argument-test")
   (:file "t/integration/user-init-test")
   (:file "t/integration/layout-test")
   (:file "t/integration/session-test")
   (:file "t/integration/main-test")
   (:file "t/integration/concurrent-runtime-test")
   (:file "t/integration/advanced-test")
   (:file "t/integration/editor-flow-test"))
  ;; Not HOST-KIT:SYMBOL-CALL or UIOP:SYMBOL-CALL: a .asd is read by the plain
  ;; CL reader before :depends-on is ever consulted, so any PKG:SYMBOL token
  ;; here must resolve against a package already in the image. FIND-SYMBOL /
  ;; FIND-PACKAGE / FUNCALL are CL, always present, and are what SYMBOL-CALL
  ;; boils down to anyway. See nshell.asd and cl-host-kit.asd for the same
  ;; precedent.
  :perform (asdf:test-op (o s)
             (declare (ignore o s))
             (unless (funcall (find-symbol "RUN-TESTS" (find-package "LOOM/TEST")))
               (error "cl-weave tests failed"))))
