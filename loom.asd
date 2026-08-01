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
for filesystem access, and cl-history-kit for minibuffer input recall. This
system currently ships only the cross-module protocol (defgeneric stubs),
laid out package-by-feature under src/domain, src/infrastructure,
src/application, and src/presentation (mirroring nshell's DDD layering) that
buffer editing, rendering, keymap dispatch, minibuffer, window management, and
file-tree features are implemented against."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/loom"
  :bug-tracker "https://github.com/nerima-lisp/loom/issues"
  :source-control (:git "https://github.com/nerima-lisp/loom.git")
  :depends-on ("cl-tty-kit"
               "cl-host-kit"
               "cl-history-kit")
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
   (:file "infrastructure/history")
   (:file "application/editor-state")
   (:file "application/minibuffer")
   (:file "application/commands")
   (:file "presentation/layout")
   (:file "main"))
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
   (:file "layout-test"))
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
