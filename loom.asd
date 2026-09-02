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
  :depends-on ("cl-tty-kit" "cl-host-kit" "cl-history-kit" "cl-prolog-kit" "cl-cli"
               "cl-regex-kit" "cl-boundary-kit" "cl-concurrent-kit" "cl-json-kit"
               "cl-log-kit" "cl-process-kit" "cl-vcs-kit")
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
  ((:file "src/package-exports")
   (:file "src/package-application")
   (:file "src/package")
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
   (:file "src/package-user")
   (:file "packages/feature/mode/src/domain-major-mode-definitions")
   (:file "packages/feature/mode/src/domain-major-mode-registry-support")
   (:file "packages/feature/mode/src/domain-major-mode")
   (:file "packages/feature/mode/src/domain-major-mode-registry")
   (:file "packages/feature/mode/src/domain-major-mode-path")
   (:file "packages/feature/syntax-highlighting/src/domain-syntax-highlighting")
   (:file "packages/feature/syntax-highlighting/src/domain-syntax-highlighting-common-lisp")
   (:file "packages/feature/syntax-highlighting/src/domain-syntax-highlighting-generic")
   (:file "packages/feature/project/src/domain-project")
   (:file "packages/core/editor/src/domain-buffer-storage")
   (:file "packages/core/editor/src/domain-buffer-storage-support")
  (:file "packages/core/editor/src/domain-buffer-piece-table-position")
  (:file "packages/core/editor/src/domain-buffer-piece-table-coalescing")
  (:file "packages/core/editor/src/domain-buffer-piece-table-splicing")
  (:file "packages/core/editor/src/domain-buffer-piece-table-support")
  (:file "packages/core/editor/src/domain-buffer-piece-table")
  (:file "packages/core/editor/src/domain-buffer-piece-table-undo")
   (:file "packages/core/editor/src/domain-buffer")
  (:file "packages/core/editor/src/domain-buffer-accessors")
  (:file "packages/core/editor/src/domain-buffer-editing")
  (:file "packages/core/editor/src/domain-buffer-deletion")
  (:file "packages/core/editor/src/domain-buffer-history")
   (:file "packages/core/editor/src/domain-buffer-narrowing-support")
   (:file "packages/core/editor/src/domain-buffer-narrowing")
   (:file "packages/core/editor/src/domain-buffer-positions")
   (:file "packages/core/editor/src/domain-prefix-argument")
   (:file "packages/feature/search/src/domain-buffer-search")
   (:file "packages/feature/search/src/domain-isearch")
   (:file "packages/feature/window/src/domain-window")
   (:file "packages/feature/window/src/domain-window-support")
   (:file "packages/feature/window/src/domain-window-layout")
   (:file "packages/feature/window/src/domain-window-operations")
   (:file "packages/feature/window/src/domain-window-accessors")
   (:file "packages/feature/window/src/domain-window-deletion")
   (:file "packages/feature/workspace/src/domain-workspace-support")
   (:file "packages/feature/workspace/src/domain-workspace")
   (:file "packages/feature/workspace/src/domain-workspace-navigation")
   (:file "packages/feature/session/src/domain-session-snapshot")
   (:file "packages/feature/session/src/domain-session-predicates")
   (:file "packages/feature/session/src/domain-session-validation-metadata")
   (:file "packages/feature/session/src/domain-session-validation-layout")
   (:file "packages/feature/session/src/domain-session-validation")
   (:file "packages/feature/session/src/infrastructure-session-codec-plist")
   (:file "packages/feature/session/src/infrastructure-session-codec")
   (:file "packages/feature/evaluation/src/domain-evaluation")
   (:file "packages/feature/auto-save/src/domain-auto-save")
               (:file "packages/feature/terminal/src/domain-terminal-support")
               (:file "packages/feature/terminal/src/domain-terminal")
               (:file "packages/feature/terminal/src/domain-terminal-screen-operations")
               (:file "packages/feature/terminal/src/domain-terminal-screen-state")
               (:file "packages/feature/terminal/src/domain-terminal-csi-screen-operations")
               (:file "packages/feature/terminal/src/domain-terminal-csi-cursor")
               (:file "packages/feature/terminal/src/domain-terminal-csi-edit")
               (:file "packages/feature/terminal/src/domain-terminal-parser-csi")
               (:file "packages/feature/terminal/src/domain-terminal-parser")
               (:file "packages/feature/terminal/src/domain-terminal-session")
   (:file "packages/feature/shell/src/domain-shell")
   (:file "packages/feature/git/src/domain-git")
   (:file "packages/feature/lsp/src/domain-lsp")
   (:file "src/domain/keymap-descriptor")
   (:file "src/domain/keymap")
   (:file "src/domain/keymap-state")
   (:file "packages/feature/file-tree/src/domain-file-tree")
   (:file "packages/feature/file-tree/src/domain-file-tree-navigation")
   (:file "src/infrastructure/terminal-renderer")
   (:file "src/infrastructure/terminal-renderer-cursor")
   (:file "src/infrastructure/terminal-renderer-text")
   (:file "packages/feature/file-tree/src/infrastructure-filesystem-native-paths")
   (:file "packages/feature/file-tree/src/infrastructure-filesystem-native-mutations")
   (:file "packages/feature/file-tree/src/infrastructure-filesystem-native-io")
   (:file "packages/feature/file-tree/src/infrastructure-filesystem-native-delete")
   (:file "packages/feature/file-tree/src/infrastructure-file-tree-directory-listing")
   (:file "packages/feature/file-tree/src/infrastructure-file-tree-filesystem-support")
   (:file "packages/feature/file-tree/src/infrastructure-file-tree-filesystem")
   (:file "packages/feature/file-tree/src/infrastructure-buffer-filesystem")
   (:file "packages/feature/auto-save/src/infrastructure-auto-save")
   (:file "packages/feature/terminal/src/infrastructure-terminal")
   (:file "packages/feature/terminal/src/infrastructure-terminal-session-runtime")
   (:file "packages/feature/project/src/infrastructure-project-filesystem")
   (:file "packages/feature/session/src/infrastructure-session-store")
   (:file "packages/feature/user-init/src/infrastructure-user-init")
   (:file "packages/feature/evaluation/src/infrastructure-lisp-evaluator")
   (:file "packages/feature/shell/src/infrastructure-shell")
   (:file "packages/feature/git/src/infrastructure-git")
   (:file "packages/feature/lsp/src/infrastructure-lsp-framing-support")
   (:file "packages/feature/lsp/src/infrastructure-lsp-headers")
   (:file "packages/feature/lsp/src/infrastructure-lsp-framing")
   (:file "packages/feature/lsp/src/infrastructure-lsp-discovery")
   (:file "packages/feature/lsp/src/infrastructure-lsp-transport-support")
   (:file "packages/feature/lsp/src/infrastructure-lsp-transport")
   (:file "packages/feature/file-tree/src/infrastructure-concurrent-runtime-state")
   (:file "packages/feature/file-tree/src/infrastructure-concurrent-runtime-prefetch")
   (:file "packages/feature/file-tree/src/infrastructure-concurrent-runtime-results")
   (:file "packages/feature/register/src/domain-register")
   (:file "packages/feature/keyboard-macro/src/domain-keyboard-macro")
   (:file "src/application/editor-state-bookmarks")
   (:file "src/application/editor-state-support")
   (:file "src/application/editor-state-types")
   (:file "src/application/editor-state")
   (:file "src/application/editor-state-save-hooks")
   (:file "src/application/editor-state-recent-files")
   (:file "src/application/editor-state-operations")
   (:file "src/application/input-routing-descriptor")
   (:file "src/application/minibuffer")
   (:file "src/application/minibuffer-activation")
   (:file "src/application/minibuffer-history")
   (:file "src/application/minibuffer-completion")
   (:file "src/application/completion-popup")
   (:file "src/application/completion-popup-input")
   (:file "src/application/minibuffer-input")
   (:file "src/application/commands-prompts")
   (:file "src/application/commands-internal")
   (:file "src/application/command-registry-forms")
    (:file "src/application/command-registry-build")
    (:file "src/application/command-registry")
    (:file "packages/feature/mode/src/application-major-mode-support")
    (:file "packages/feature/mode/src/application-major-mode")
    (:file "packages/feature/mode/src/application-major-mode-editing")
   (:file "packages/feature/project/src/application-commands-project")
   (:file "packages/core/editor/src/application-commands-prefix-argument-support")
  (:file "packages/core/editor/src/application-commands-prefix-argument")
   (:file "packages/core/editor/src/application-word-motion")
   (:file "packages/core/editor/src/application-sexp-syntax")
   (:file "packages/core/editor/src/application-sexp-motion-support")
   (:file "packages/core/editor/src/application-sexp-motion")
   (:file "packages/core/editor/src/application-structural-editing-support")
   (:file "packages/core/editor/src/application-structural-editing")
   (:file "packages/core/editor/src/application-structural-editing-offsets")
   (:file "packages/core/editor/src/application-structural-editing-application")
   (:file "packages/core/editor/src/application-commands-movement-support")
   (:file "packages/core/editor/src/application-commands-movement-view-support")
   (:file "packages/core/editor/src/application-commands-movement-visual-lines")
   (:file "packages/core/editor/src/application-commands-movement")
  (:file "packages/core/editor/src/application-commands-editing-support")
  (:file "packages/core/editor/src/application-commands-editing")
  (:file "packages/core/editor/src/application-commands-yank-support")
  (:file "packages/core/editor/src/application-commands-yank-pop-support")
  (:file "packages/core/editor/src/application-commands-region-support")
   (:file "packages/core/editor/src/application-commands-region")
   (:file "packages/core/editor/src/application-commands-kill-support")
   (:file "packages/core/editor/src/application-commands-kill-region-support")
   (:file "packages/core/editor/src/application-commands-kill-word-support")
   (:file "packages/core/editor/src/application-commands-kill")
   (:file "packages/core/editor/src/application-commands-sexp")
   (:file "packages/core/editor/src/application-commands-structural-editing")
   (:file "packages/core/editor/src/application-commands-yank")
   (:file "packages/feature/register/src/application-commands-register")
   (:file "packages/feature/keyboard-macro/src/application-commands-keyboard-macro")
   (:file "packages/feature/search/src/application-commands-search")
   (:file "packages/feature/search/src/application-commands-isearch")
   (:file "packages/feature/file-tree/src/application-commands-file")
   (:file "packages/feature/file-tree/src/application-commands-file-save")
   (:file "packages/feature/window/src/application-window-buffer-support")
   (:file "packages/feature/window/src/application-commands-window")
   (:file "packages/feature/workspace/src/application-workspace-switch-support")
   (:file "packages/feature/workspace/src/application-workspace-transition-support")
   (:file "packages/feature/workspace/src/application-commands-workspace")
   (:file "packages/feature/file-tree/src/application-commands-file-tree")
   (:file "packages/feature/session/src/application-session-bookmarks")
   (:file "packages/feature/session/src/application-session-workspaces")
   (:file "packages/feature/session/src/application-session-snapshot")
   (:file "packages/feature/session/src/application-session-restore")
   (:file "packages/feature/session/src/application-commands-session")
   (:file "packages/feature/evaluation/src/application-commands-evaluation")
   (:file "packages/feature/shell/src/application-commands-shell")
   (:file "packages/feature/format/src/application-format-buffer")
   (:file "packages/feature/format/src/application-commands-format")
   (:file "packages/feature/auto-save/src/application-auto-save-support")
   (:file "packages/feature/auto-save/src/application-commands-auto-save")
   (:file "packages/feature/terminal/src/application-terminal-input-support")
   (:file "packages/feature/terminal/src/application-terminal-input")
   (:file "packages/feature/terminal/src/application-commands-terminal")
   (:file "packages/feature/git/src/application-commands-git-support")
   (:file "packages/feature/git/src/application-commands-git")
   (:file "packages/feature/lsp/src/application-lsp-protocol-send")
   (:file "packages/feature/lsp/src/application-lsp-protocol-initialize")
   (:file "packages/feature/lsp/src/application-lsp-protocol-helpers")
   (:file "packages/feature/lsp/src/application-lsp-diagnostic-decode")
   (:file "packages/feature/lsp/src/application-lsp-request-decode")
   (:file "packages/feature/lsp/src/application-lsp-protocol-responses")
   (:file "packages/feature/lsp/src/application-lsp-requests")
   (:file "packages/feature/lsp/src/application-lsp-protocol-routing")
   (:file "packages/feature/lsp/src/application-lsp-protocol-receive")
   (:file "packages/feature/lsp/src/application-lsp-session-state")
   (:file "packages/feature/lsp/src/application-lsp-session-sync")
   (:file "packages/feature/lsp/src/application-lsp-session-lifecycle")
   (:file "packages/feature/lsp/src/application-lsp-diagnostics-view")
   (:file "packages/feature/lsp/src/application-commands-lsp-support")
   (:file "packages/feature/lsp/src/application-commands-lsp-context")
   (:file "packages/feature/lsp/src/application-commands-lsp")
   (:file "packages/feature/lsp/src/application-commands-lsp-completion")
   (:file "packages/feature/lsp/src/application-commands-lsp-navigation")
   (:file "src/application/commands-misc")
   (:file "src/application/commands-bookmark-support")
   (:file "src/application/commands-bookmark")
   (:file "src/application/commands-quit")
   (:file "src/application/command-definitions-movement")
   (:file "src/application/command-definitions-editing")
   (:file "src/application/command-definitions-files")
   (:file "src/application/command-definitions-windows")
   (:file "src/application/command-definitions-session")
   (:file "src/application/command-definitions-macros")
   (:file "src/application/command-definitions-tooling")
   (:file "src/application/command-definitions-file-tree")
   (:file "src/application/command-definitions-ui")
   (:file "src/application/command-definitions")
   (:file "src/application/commands-keybinding-spec")
   (:file "src/application/commands-keybindings")
   (:file "packages/feature/user-init/src/application-user-configuration")
   (:file "packages/feature/syntax-highlighting/src/presentation-syntax-highlighting")
   (:file "src/presentation/layout")
   (:file "src/presentation/layout-windows")
   (:file "src/presentation/layout-isearch")
   (:file "src/presentation/layout-minibuffer")
   (:file "src/presentation/layout-file-tree")
   (:file "src/presentation/frame-layout-cursor")
   (:file "src/presentation/frame-layout-viewport")
   (:file "src/presentation/frame-layout")
   (:file "src/application/input-routing-command-state")
   (:file "src/application/input-routing-decision")
   (:file "src/application/input-routing-effects")
   (:file "src/application/input-routing-dispatch")
   (:file "src/application/input-dispatch")
    (:file "src/application/event-loop-rendering")
    (:file "src/application/event-loop-control")
    (:file "src/application/event-loop")
   (:file "src/application/startup-state")
   (:file "src/application/startup-services")
   (:file "src/application/startup")
   (:file "src/application/startup-cli")
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
  ;; Test sources use these systems directly. Keep those edges explicit so
  ;; the test system remains loadable if loom's implementation dependencies
  ;; are reduced or rearranged.
  :depends-on ("loom" "cl-weave" "cl-date-kit" "cl-codec-kit"
               "cl-parser-kit" "cl-regex-kit" "cl-boundary-kit"
               "cl-concurrent-kit" "cl-vcs-kit" "cl-process-kit")
  :pathname "."
  :serial t
  :components
  ((:file "t/package")
   (:file "t/test-helpers-core")
   (:file "t/test-helpers-prompts")
   (:file "t/test-helpers-lsp")
   (:file "t/unit/protocol-test")
   (:file "t/unit/buffer-test-support")
   (:file "t/unit/buffer-basic-test")
   (:file "t/unit/buffer-insert-test")
   (:file "t/unit/buffer-delete-char-test")
   (:file "t/unit/buffer-region-test")
   (:file "t/unit/buffer-undo-test")
   (:file "t/unit/buffer-redo-test")
   (:file "t/unit/buffer-read-only-test")
   (:file "t/unit/buffer-storage-test")
   (:file "t/unit/buffer-view-test")
   (:file "t/unit/sexp-motion-test")
   (:file "t/unit/structural-editing-test")
   (:file "t/unit/syntax-highlighting-test")
   (:file "t/unit/major-mode-test")
   (:file "t/unit/major-mode-extension-test")
   (:file "t/unit/major-mode-syntax-highlighting-test")
   (:file "t/unit/project-test")
   (:file "t/unit/terminal-renderer-test")
   (:file "t/unit/terminal-renderer-cursor-test")
   (:file "t/unit/filesystem-test-support")
   (:file "t/unit/filesystem-create-test")
   (:file "t/unit/filesystem-directory-test")
   (:file "t/unit/filesystem-rename-boundary-test")
   (:file "t/unit/filesystem-delete-test")
   (:file "t/unit/filesystem-listing-test")
   (:file "t/unit/window-basic-test")
   (:file "t/unit/window-delete-behavior-test")
   (:file "t/unit/window-delete-node-test")
   (:file "t/unit/window-delete-other-windows-test")
   (:file "t/unit/window-layout-test")
   (:file "t/unit/workspace-test")
   (:file "t/unit/workspace-navigation-test")
   (:file "t/unit/editor-state-test")
   (:file "t/unit/editor-state-recent-files-test")
   (:file "t/unit/keymap-test-support")
   (:file "t/unit/isearch-test")
   (:file "t/unit/keymap-lookup-test")
   (:file "t/unit/keymap-state-test")
   (:file "t/unit/register-test")
   (:file "t/unit/keyboard-macro-test")
   (:file "t/unit/prefix-argument-test")
   (:file "t/unit/file-tree-test")
   (:file "t/unit/file-tree-selection-test")
   (:file "t/unit/minibuffer-test")
   (:file "t/unit/minibuffer-input-test-support")
   (:file "t/unit/minibuffer-input-activation-test")
   (:file "t/unit/minibuffer-input-history-test")
   (:file "t/unit/minibuffer-input-completion-test")
   (:file "t/unit/minibuffer-input-classification-test")
   (:file "t/unit/evaluation-test")
   (:file "t/unit/evaluation-result-test")
   (:file "t/unit/shell-test")
  (:file "t/unit/format-test")
  (:file "t/unit/auto-save-test")
  (:file "t/unit/terminal-screen-basic-test")
  (:file "t/unit/terminal-screen-cursor-test")
  (:file "t/unit/terminal-screen-control-test")
  (:file "t/unit/terminal-screen-validation-test")
  (:file "t/unit/terminal-event-test")
  (:file "t/unit/terminal-session-test")
  (:file "t/unit/git-test")
  (:file "t/unit/git-file-operations-test")
  (:file "t/unit/lsp-framing-test-support")
  (:file "t/unit/lsp-framing-test")
  (:file "t/unit/lsp-domain-values-test")
   (:file "t/unit/lsp-request-decode-test")
   (:file "t/unit/completion-popup-test")
  (:file "t/unit/cli-test")
   (:file "t/unit/dependency-contract-test")
   (:file "t/integration/commands-sexp-test")
   (:file "t/integration/commands-structural-editing-test")
   (:file "t/integration/commands-test")
   (:file "t/integration/workspace-test")
   (:file "t/integration/lsp-session-lifecycle-error-test")
   (:file "t/integration/lsp-session-lifecycle-initialize-test")
   (:file "t/integration/lsp-session-lifecycle-stop-test")
   (:file "t/integration/lsp-session-lifecycle-transport-test")
   (:file "t/integration/lsp-session-diagnostics-test")
   (:file "t/integration/lsp-session-paths-test")
   (:file "t/integration/lsp-discovery-test")
  (:file "t/integration/lsp-command-diagnostics-render-test")
  (:file "t/integration/lsp-command-diagnostics-state-test")
   (:file "t/integration/commands-lsp-navigation-test")
   (:file "t/integration/commands-lsp-definition-test")
  (:file "t/integration/lsp-command-diagnostics-format-test")
               (:file "t/integration/lsp-command-start-test")
               (:file "t/integration/lsp-command-start-discovery-test")
   (:file "t/integration/commands-movement-char-test")
   (:file "t/integration/commands-movement-line-test")
   (:file "t/integration/commands-movement-word-test")
   (:file "t/integration/commands-movement-scroll-edit-test")
   (:file "t/integration/commands-window-test")
   (:file "t/integration/commands-buffer-lifecycle-test")
   (:file "t/integration/commands-editing-test-support")
   (:file "t/integration/commands-editing-buffer-mutation-test")
   (:file "t/integration/commands-editing-buffer-mark-test")
   (:file "t/integration/commands-editing-buffer-narrowing-test")
   (:file "t/integration/commands-editing-buffer-history-test")
   (:file "t/integration/commands-editing-buffer-read-only-test")
   (:file "t/integration/commands-editing-file-test")
   (:file "t/integration/commands-editing-isearch-test")
   (:file "t/integration/commands-editing-search-navigation-test")
   (:file "t/integration/commands-editing-search-replace-test")
   (:file "t/integration/commands-editing-minibuffer-keybinding-test")
   (:file "t/integration/commands-editing-quit-test")
   (:file "t/integration/kill-yank-test-support")
   (:file "t/integration/kill-yank-test")
   (:file "t/integration/kill-yank-region-test")
   (:file "t/integration/kill-yank-yank-test")
   (:file "t/integration/major-mode-test")
   (:file "t/integration/major-mode-comment-line-test")
   (:file "t/integration/major-mode-keymap-dispatch-test")
   (:file "t/integration/project-test")
   (:file "t/integration/project-missing-root-test")
   (:file "t/integration/commands-misc-test")
   (:file "t/integration/command-registry-definition-test")
   (:file "t/integration/command-spec-validation-test")
   (:file "t/integration/commands-help-test")
   (:file "t/integration/command-registration-test")
   (:file "t/integration/command-keybinding-consistency-test")
   (:file "t/integration/commands-file-tree-navigation-test")
   (:file "t/integration/commands-file-tree-mutation-test")
   (:file "t/integration/commands-bookmark-test")
   (:file "t/integration/commands-keybindings-test")
   (:file "t/integration/commands-prompt-cancellation-test")
   (:file "t/integration/register-test")
   (:file "t/integration/keyboard-macro-test")
   (:file "t/integration/prefix-argument-dispatch-test")
   (:file "t/integration/prefix-argument-macro-test")
   (:file "t/integration/prefix-argument-action-test")
   (:file "t/integration/user-init-test")
   (:file "t/integration/layout-test")
   (:file "t/integration/frame-layout-test-support")
   (:file "t/integration/frame-layout-test")
   (:file "t/integration/frame-layout-cursor-test")
  (:file "t/integration/session-test-support")
  (:file "t/integration/session-store-roundtrip-test")
  (:file "t/integration/session-store-buffer-validation-test")
  (:file "t/integration/session-store-layout-validation-test")
  (:file "t/integration/session-store-envelope-test")
  (:file "t/integration/session-application-test")
  (:file "t/integration/session-workspace-application-test")
  (:file "t/integration/session-command-test")
   (:file "t/integration/input-routing-test")
   (:file "t/integration/input-routing-minibuffer-test")
   (:file "t/integration/input-routing-keymap-test")
   (:file "t/integration/main-test-support")
   (:file "t/integration/main-input-test")
   (:file "t/integration/main-terminal-size-test")
   (:file "t/integration/main-event-loop-input-test")
   (:file "t/integration/main-run-loom-test")
   (:file "t/integration/main-cli-test")
   (:file "t/integration/main-startup-test")
   (:file "t/integration/main-initialize-test")
   (:file "t/integration/concurrent-runtime-test-support")
   (:file "t/integration/concurrent-runtime-prefetch-test")
   (:file "t/integration/concurrent-runtime-invalidation-test")
   (:file "t/integration/concurrent-runtime-stale-prime-test")
   (:file "t/integration/concurrent-runtime-stale-invalidation-test")
   (:file "t/integration/concurrent-runtime-shutdown-test")
   (:file "t/integration/concurrent-runtime-submission-test")
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
