
(in-package #:asdf-user)

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
  :depends-on ("cl-tty-kit" "cl-host-kit" "cl-history-kit" "cl-prolog-kit" "cl-cli" "cl-regex-kit" "cl-boundary-kit" "cl-concurrent-kit" "cl-date-kit" "cl-json-kit" "cl-log-kit" "cl-process-kit" "cl-vcs-kit" "cl-resilience-kit" "loom-core-buffer" "loom-core-window-tree" "loom-core-editor-session" "loom-core-minibuffer" "loom-core-command" "loom-feature-mode" "loom-feature-clipboard" "loom-feature-mouse" "loom-feature-window" "loom-feature-kill-ring" "loom-feature-search" "loom-feature-completion" "loom-feature-help" "loom-feature-workspace" "loom-feature-lisp-structure" "loom-feature-register" "loom-feature-keyboard-macro" "loom-feature-user-init" "loom-feature-syntax-highlighting" "loom-feature-lang-lisp" "loom-feature-lang-nix" "loom-feature-lang-web" "loom-feature-lang-markup" "loom-feature-minibuffer-ui" "loom-feature-buffers" "loom-feature-files" "loom-feature-file-tree" "loom-feature-bookmark" "loom-feature-project" "loom-feature-lsp" "loom-feature-terminal" "loom-feature-lifecycle" "loom-feature-evaluation" "loom-feature-session" "loom-feature-shell")
  :pathname "."
  :serial t
  :components
  (
   (:module "feature-project-package"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-search-package"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-shell-package"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-format-package"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/format/src/package")
    ))
   (:module "feature-auto-save-package"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/auto-save/src/package")
    ))
   (:module "feature-git-package"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/git/src/package")
    ))
   (:module "bootstrap-2"
    :pathname "."
    :serial t
    :components
    (
     (:file "src/package-user")
    ))
   (:module "feature-project-domain"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-search-domain"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-auto-save-domain"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/auto-save/src/domain-auto-save")
    ))
   (:module "feature-shell-domain"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-git-domain"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/git/src/domain-git")
    ))
   (:module "root-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     (:file "src/infrastructure/terminal-renderer")
     (:file "src/infrastructure/terminal-renderer-cursor")
     (:file "src/infrastructure/terminal-renderer-text")
     (:file "src/infrastructure/terminal-renderer-text-wrapping")
    ))
   (:module "feature-project-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-shell-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-git-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/git/src/infrastructure-git")
    ))
   (:module "root-application"
  :pathname "."
  :serial t
  :components
  ((:file "src/application/commands-internal")))
   (:module "feature-auto-save-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/auto-save/src/infrastructure-auto-save")
    ))
   (:module "feature-project-application"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-search-application"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-shell-application"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-format-application"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/format/src/application-format-buffer")
     (:file "packages/feature/format/src/application-commands-format")
    ))
   (:module "feature-auto-save-application"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/auto-save/src/application-auto-save-support")
     (:file "packages/feature/auto-save/src/application-commands-auto-save")
    ))
   (:module "feature-git-application"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/git/src/application-commands-git-support")
     (:file "packages/feature/git/src/application-commands-git")
    ))
   (:module "root-application-2"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/git/src/command-specs-git")
     (:file "packages/feature/format/src/command-specs-format")
     (:file "packages/feature/auto-save/src/command-specs-auto-save")
     ))
   (:module "root-presentation"
    :pathname "."
    :serial t
    :components
    (
     (:file "src/presentation/layout")
     (:file "src/presentation/layout-wrapping")
     (:file "src/presentation/layout-windows")
     (:file "src/presentation/layout-isearch")
     (:file "src/presentation/layout-minibuffer")
     (:file "src/presentation/layout-completion")
     (:file "src/presentation/layout-file-tree")
     (:file "src/presentation/frame-layout-cursor")
     (:file "src/presentation/frame-layout-viewport")
     (:file "src/presentation/frame-layout")
    ))
   (:module "root-application-3"
    :pathname "."
    :serial t
    :components
    (
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
    ))
   (:module "root-entrypoint"
    :pathname "."
    :serial t
    :components
    (
     (:file "src/main")
    ))
  )
  :build-operation "program-op"
  :build-pathname "loom"
  :entry-point "loom:main"
  :perform (asdf:program-op (o c)
             (sb-ext:save-lisp-and-die
              (asdf:output-file o c)
              :executable t
              :compression t
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
  :depends-on ("loom" "cl-weave" "cl-date-kit" "cl-codec-kit"
               "cl-parser-kit" "cl-regex-kit" "cl-boundary-kit"
               "cl-concurrent-kit" "cl-vcs-kit" "cl-process-kit")
  :pathname "."
  :serial t
  :components
  ((:file "t/unit/protocol-test")
   (:file "t/unit/terminal-renderer-test")
   (:file "t/unit/terminal-renderer-cursor-test")
   (:file "t/unit/format-test")
  (:file "t/unit/auto-save-test")
  (:file "t/unit/git-test")
  (:file "t/unit/git-file-operations-test")
  (:file "t/unit/cli-test")
  (:file "t/unit/dependency-contract-test")
   (:file "t/unit/boundary-architecture-test")
   (:file "t/integration/commands-test")
   (:file "t/integration/commands-lsp-completion-popup-test")
   (:file "t/integration/commands-movement-char-test")
   (:file "t/integration/commands-movement-line-test")
   (:file "t/integration/commands-movement-word-test")
   (:file "t/integration/commands-movement-scroll-edit-test")
   (:file "t/integration/commands-editing-buffer-mutation-test")
   (:file "t/integration/commands-editing-buffer-mark-test")
   (:file "t/integration/commands-editing-buffer-narrowing-test")
   (:file "t/integration/commands-editing-buffer-history-test")
   (:file "t/integration/commands-editing-buffer-read-only-test")
   (:file "t/integration/commands-editing-file-root-test")
   (:file "t/integration/commands-editing-minibuffer-keybinding-test")
   (:file "t/integration/commands-prompt-cancellation-test")
   (:file "t/integration/prefix-argument-macro-test")
   (:file "t/integration/frame-layout-test-support")
   (:file "t/integration/layout-test")
   (:file "t/integration/layout-isearch-test")
   (:file "t/integration/layout-secondary-test")
   (:file "t/integration/frame-layout-test")
   (:file "t/integration/frame-layout-cursor-test")
  (:file "t/integration/frame-layout-wrapping-test")
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
   (:file "t/integration/advanced-test")
   (:file "t/integration/editor-flow-test"))
  :perform
  (asdf:test-op (o s)
             (declare (ignore o s))
             (unless (funcall (find-symbol "RUN-TESTS" (find-package "LOOM/TEST")))
               (error "cl-weave tests failed"))) :in-order-to ((asdf:prepare-op (asdf:load-op "loom/test-support" "loom-core-buffer/test" "loom-core-window-tree/test" "loom-core-editor-session/test" "loom-core-minibuffer/test" "loom-core-command/test" "loom-core-package-bootstrap/test" "loom-feature-mode/test" "loom-feature-clipboard/test" "loom-feature-mouse/test" "loom-feature-window/test" "loom-feature-kill-ring/test" "loom-feature-search/test" "loom-feature-completion/test" "loom-feature-help/test" "loom-feature-workspace/test" "loom-feature-lisp-structure/test" "loom-feature-register/test" "loom-feature-keyboard-macro/test" "loom-feature-user-init/test" "loom-feature-syntax-highlighting/test" "loom-feature-lang-lisp/test" "loom-feature-lang-nix/test" "loom-feature-lang-web/test" "loom-feature-lang-markup/test" "loom-feature-minibuffer-ui/test" "loom-feature-buffers/test" "loom-feature-file-tree/test" "loom-feature-files/test" "loom-feature-bookmark/test" "loom-feature-project/test" "loom-feature-lifecycle/test" "loom-feature-evaluation/test" "loom-feature-session/test" "loom-feature-lsp/test" "loom-feature-terminal/test" "loom-feature-shell/test"))))

(asdf:defsystem "loom/test-support"
  :description "Shared test package and fixtures for loom slice tests"
  :depends-on ("loom")
  :pathname "."
  :serial t
  :in-order-to ((asdf:prepare-op (asdf:load-op "cl-weave")))
  :components
  ((:file "t/package") (:file "t/test-support/buffer-test-support") (:file "t/test-helpers-core") (:file "t/test-helpers-prompts") (:file "t/integration/commands-editing-test-support") (:file "t/test-helpers-lsp")))
