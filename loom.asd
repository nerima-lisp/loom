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
for filesystem access, and cl-history-kit for minibuffer input recall. Its
source is laid out package-by-feature under src/domain, src/infrastructure,
src/application, and src/presentation (mirroring nshell's DDD layering):
buffer editing, rendering, keymap dispatch, minibuffer, window management, and
a file-tree sidebar are all implemented against that layering."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/loom"
  :bug-tracker "https://github.com/nerima-lisp/loom/issues"
  :source-control (:git "https://github.com/nerima-lisp/loom.git")
  :depends-on ("cl-tty-kit" "cl-host-kit" "cl-history-kit" "cl-prolog" "cl-cli"
               "cl-regex-kit" "cl-boundary-kit")
  :pathname "src"
  :serial t
  :components
  ;; File order, :serial t: package first; then domain (pure state/logic,
  ;; no dependency on cl-tty-kit/cl-host-kit/cl-history-kit, so nothing
  ;; below can forward-reference it); then infrastructure (adapters to
  ;; those sibling libraries); then application (orchestrates domain +
  ;; infrastructure via *editor-state*); then presentation (composes
  ;; domain/application/infrastructure output for the screen); main last,
  ;; since it is the entry point everything else exists to be called from.
  ;; Path-prefixed :file names, not nested :module blocks, per nshell.asd's
  ;; precedent.
  ((:file "package")
   (:file "domain/buffer")
   (:file "domain/window")
   (:file "domain/keymap")
   (:file "domain/file-tree")
   (:file "infrastructure/terminal-renderer")
   (:file "infrastructure/filesystem")
   (:file "application/editor-state")
   (:file "application/minibuffer")
   (:file "application/commands-internal")
   (:file "application/commands-movement")
   (:file "application/commands-editing")
   (:file "application/commands-search")
   (:file "application/commands-file")
   (:file "application/commands-window")
   (:file "application/commands-misc")
   (:file "application/commands-keybindings")
   (:file "presentation/layout")
   (:file "main"))
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
  :depends-on ("loom" "cl-weave")
  :pathname "t"
  :serial t
  :components
  ((:file "package")
   (:file "protocol-test")
   (:file "buffer-test")
   (:file "terminal-renderer-test")
   (:file "filesystem-test")
   (:file "window-test")
   (:file "keymap-test")
   (:file "file-tree-test")
   (:file "minibuffer-test")
   (:file "commands-test")
   (:file "layout-test")
   (:file "main-test"))
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
