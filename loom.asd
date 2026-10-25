
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
  :depends-on ("cl-tty-kit" "cl-host-kit" "cl-history-kit" "cl-prolog-kit" "cl-cli" "cl-regex-kit" "cl-boundary-kit" "cl-concurrent-kit" "cl-date-kit" "cl-json-kit" "cl-log-kit" "cl-process-kit" "cl-vcs-kit" "cl-resilience-kit" "loom-core-buffer" "loom-core-window-tree" "loom-core-editor-session" "loom-core-minibuffer" "loom-core-command" "loom-feature-mode" "loom-feature-clipboard" "loom-feature-mouse" "loom-feature-window" "loom-feature-kill-ring" "loom-feature-search" "loom-feature-completion" "loom-feature-help" "loom-feature-workspace" "loom-feature-lisp-structure" "loom-feature-register" "loom-feature-keyboard-macro" "loom-feature-user-init" "loom-feature-syntax-highlighting" "loom-feature-lang-lisp" "loom-feature-lang-nix" "loom-feature-lang-web" "loom-feature-lang-markup" "loom-feature-minibuffer-ui" "loom-feature-buffers" "loom-feature-files")
  :pathname "."
  :serial t
  :components
  (
   (:module "feature-project-package"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/project/src/package")
    ))
   (:module "feature-search-package"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-file-tree-package"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/file-tree/src/package")
    ))
   (:module "feature-evaluation-package"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/evaluation/src/package")
    ))
   (:module "feature-shell-package"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/shell/src/package")
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
   (:module "feature-terminal-package"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/terminal/src/package")
    ))
   (:module "feature-git-package"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/git/src/package")
    ))
   (:module "feature-session-package"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/session/src/package")
    ))
   (:module "feature-lsp-package"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/lsp/src/package")
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
     (:file "packages/feature/project/src/domain-project")
    ))
   (:module "feature-search-domain"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-session-domain"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/session/src/domain-session-snapshot")
     (:file "packages/feature/session/src/domain-session-predicates")
     (:file "packages/feature/session/src/domain-session-validation-metadata")
     (:file "packages/feature/session/src/domain-session-validation-layout")
     (:file "packages/feature/session/src/domain-session-validation")
    ))
   (:module "feature-session-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/session/src/infrastructure-session-codec-plist")
     (:file "packages/feature/session/src/infrastructure-session-codec")
    ))
   (:module "feature-evaluation-domain"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/evaluation/src/domain-evaluation")
    ))
   (:module "feature-auto-save-domain"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/auto-save/src/domain-auto-save")
    ))
   (:module "feature-terminal-domain"
    :pathname "."
    :serial t
    :components
    (
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
    ))
   (:module "feature-shell-domain"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/shell/src/domain-shell")
    ))
   (:module "feature-git-domain"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/git/src/domain-git")
    ))
   (:module "feature-lsp-domain"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/lsp/src/domain-lsp")
    ))
   (:module "feature-file-tree-domain"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/file-tree/src/domain-file-tree")
     (:file "packages/feature/file-tree/src/domain-file-tree-navigation")
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
   (:module "feature-file-tree-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/file-tree/src/infrastructure-filesystem-native-mutations")
     (:file "packages/feature/file-tree/src/infrastructure-filesystem-native-delete")
     (:file "packages/feature/file-tree/src/infrastructure-file-tree-directory-listing")
     (:file "packages/feature/file-tree/src/infrastructure-file-tree-filesystem-support")
     (:file "packages/feature/file-tree/src/infrastructure-file-tree-filesystem")
     ))
   (:module "feature-terminal-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/terminal/src/infrastructure-terminal")
     (:file "packages/feature/terminal/src/infrastructure-terminal-session-runtime")
    ))
   (:module "feature-project-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/project/src/infrastructure-project-filesystem")
    ))
   (:module "feature-session-infrastructure-2"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/session/src/infrastructure-session-store")
    ))
   (:module "feature-evaluation-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/evaluation/src/infrastructure-lisp-evaluator")
    ))
   (:module "feature-shell-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/shell/src/infrastructure-shell")
    ))
   (:module "feature-git-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/git/src/infrastructure-git")
    ))
   (:module "feature-lsp-infrastructure"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/lsp/src/infrastructure-lsp-framing-support")
     (:file "packages/feature/lsp/src/infrastructure-lsp-headers")
     (:file "packages/feature/lsp/src/infrastructure-lsp-framing")
     (:file "packages/feature/lsp/src/infrastructure-lsp-discovery")
     (:file "packages/feature/lsp/src/infrastructure-lsp-transport-support")
     (:file "packages/feature/lsp/src/infrastructure-lsp-transport")
    ))
   (:module "feature-file-tree-infrastructure-2"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/file-tree/src/infrastructure-concurrent-runtime-state")
     (:file "packages/feature/file-tree/src/infrastructure-concurrent-runtime-prefetch")
     (:file "packages/feature/file-tree/src/infrastructure-concurrent-runtime-results")
    ))
   (:module "root-application"
  :pathname "."
  :serial t
  :components
  ((:file "packages/feature/bookmark/src/domain-editor-bookmark")
   (:file "src/application/commands-internal")))
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
     (:file "packages/feature/project/src/application-commands-project")
    ))
   (:module "feature-search-application"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-file-tree-application"
    :pathname "."
    :serial t
    :components
    (
     ))
   (:module "feature-file-tree-application-2"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/file-tree/src/application-commands-file-tree")
    ))
   (:module "feature-session-application"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/session/src/application-session-bookmarks")
     (:file "packages/feature/session/src/application-session-workspaces")
     (:file "packages/feature/session/src/application-session-snapshot")
     (:file "packages/feature/session/src/application-session-restore")
     (:file "packages/feature/session/src/application-commands-session")
    ))
   (:module "feature-evaluation-application"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/evaluation/src/application-commands-evaluation")
    ))
   (:module "feature-shell-application"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/shell/src/application-commands-shell")
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
   (:module "feature-terminal-application"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/terminal/src/application-terminal-input-support")
     (:file "packages/feature/terminal/src/application-terminal-input")
     (:file "packages/feature/terminal/src/application-commands-terminal")
    ))
   (:module "feature-git-application"
    :pathname "."
    :serial t
    :components
    (
     (:file "packages/feature/git/src/application-commands-git-support")
     (:file "packages/feature/git/src/application-commands-git")
    ))
   (:module "feature-lsp-application"
    :pathname "."
    :serial t
    :components
    (
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
     (:file "packages/feature/lsp/src/application-lsp-session-uri")
     (:file "packages/feature/lsp/src/application-lsp-session-sync")
     (:file "packages/feature/lsp/src/application-lsp-session-lifecycle")
     (:file "packages/feature/lsp/src/application-lsp-diagnostics-view")
     (:file "packages/feature/lsp/src/application-commands-lsp-support")
     (:file "packages/feature/lsp/src/application-commands-lsp-context")
     (:file "packages/feature/lsp/src/application-commands-lsp")
     (:file "packages/feature/lsp/src/application-commands-lsp-completion")
     (:file "packages/feature/lsp/src/application-commands-lsp-navigation")
    ))
   (:module "root-application-2"
    :pathname "."
    :serial t
    :components
    (
     (:file "src/application/commands-bookmark-support")
     (:file "src/application/commands-bookmark")
     (:file "src/application/commands-quit")
     (:file "packages/feature/terminal/src/command-specs-terminal")
     (:file "packages/feature/shell/src/command-specs-shell")
     (:file "packages/feature/session/src/command-specs-session")
     (:file "packages/feature/project/src/command-specs-project")
     (:file "packages/feature/lsp/src/command-specs-lsp")
     (:file "packages/feature/lsp/src/command-specs-lsp-navigation")
     (:file "packages/feature/lsp/src/command-specs-lsp-completion")
     (:file "packages/feature/lifecycle/src/command-specs-quit")
     (:file "packages/feature/git/src/command-specs-git")
     (:file "packages/feature/format/src/command-specs-format")
     (:file "packages/feature/file-tree/src/command-specs-file-tree")
     (:file "packages/feature/evaluation/src/command-specs-evaluation")
     (:file "packages/feature/bookmark/src/command-specs-bookmark")
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
   (:file "t/unit/project-test")
   (:file "t/unit/terminal-renderer-test")
   (:file "t/unit/terminal-renderer-cursor-test")
   (:file "t/unit/filesystem-test-support")
   (:file "t/unit/filesystem-create-test")
   (:file "t/unit/filesystem-directory-test")
   (:file "t/unit/filesystem-rename-boundary-test")
   (:file "t/unit/filesystem-delete-test")
   (:file "t/unit/filesystem-listing-test")
   (:file "t/unit/file-tree-test")
   (:file "t/unit/file-tree-selection-test")
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
  (:file "t/unit/terminal-session-lifecycle-test")
  (:file "t/unit/git-test")
  (:file "t/unit/git-file-operations-test")
  (:file "t/unit/lsp-framing-test-support")
  (:file "t/unit/lsp-framing-test")
  (:file "t/unit/lsp-domain-values-test")
   (:file "t/unit/lsp-request-decode-test")
   (:file "t/unit/cli-test")
  (:file "t/unit/dependency-contract-test")
   (:file "t/unit/boundary-architecture-test")
   (:file "t/integration/commands-test")
   (:file "t/integration/lsp-session-lifecycle-error-test")
   (:file "t/integration/lsp-session-lifecycle-initialize-test")
   (:file "t/integration/lsp-session-lifecycle-stop-test")
   (:file "t/integration/lsp-session-lifecycle-transport-test")
   (:file "t/integration/lsp-session-lifecycle-transport-readers-test")
   (:file "t/integration/lsp-session-lifecycle-transport-state-test")
   (:file "t/integration/lsp-session-lifecycle-transport-process-test")
   (:file "t/integration/lsp-session-diagnostics-test")
   (:file "t/integration/lsp-session-paths-test")
   (:file "t/integration/lsp-discovery-test")
  (:file "t/integration/lsp-command-diagnostics-render-test")
  (:file "t/integration/lsp-command-diagnostics-state-test")
   (:file "t/integration/commands-lsp-navigation-test-support")
   (:file "t/integration/commands-lsp-navigation-test")
   (:file "t/integration/commands-lsp-completion-popup-test")
   (:file "t/integration/lsp-completion-data-test")
   (:file "t/integration/commands-lsp-definition-test")
  (:file "t/integration/lsp-command-diagnostics-format-test")
               (:file "t/integration/lsp-command-start-test")
               (:file "t/integration/lsp-command-start-discovery-test")
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
   (:file "t/integration/commands-editing-quit-test")
   (:file "t/integration/project-test")
   (:file "t/integration/project-missing-root-test")
   (:file "t/integration/commands-misc-test")
   (:file "t/integration/commands-file-tree-navigation-test")
   (:file "t/integration/commands-file-tree-mutation-test")
   (:file "t/integration/commands-bookmark-test")
   (:file "t/integration/commands-prompt-cancellation-test")
   (:file "t/integration/prefix-argument-macro-test")
   (:file "t/integration/frame-layout-test-support")
   (:file "t/integration/layout-test")
   (:file "t/integration/layout-isearch-test")
   (:file "t/integration/layout-secondary-test")
   (:file "t/integration/frame-layout-test")
   (:file "t/integration/frame-layout-cursor-test")
  (:file "t/integration/frame-layout-wrapping-test")
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
  :perform
  (asdf:test-op (o s)
             (declare (ignore o s))
             (unless (funcall (find-symbol "RUN-TESTS" (find-package "LOOM/TEST")))
               (error "cl-weave tests failed"))) :in-order-to ((asdf:prepare-op (asdf:load-op "loom/test-support" "loom-core-buffer/test" "loom-core-window-tree/test" "loom-core-editor-session/test" "loom-core-minibuffer/test" "loom-core-command/test" "loom-core-package-bootstrap/test" "loom-feature-mode/test" "loom-feature-clipboard/test" "loom-feature-mouse/test" "loom-feature-window/test" "loom-feature-kill-ring/test" "loom-feature-search/test" "loom-feature-completion/test" "loom-feature-help/test" "loom-feature-workspace/test" "loom-feature-lisp-structure/test" "loom-feature-register/test" "loom-feature-keyboard-macro/test" "loom-feature-user-init/test" "loom-feature-syntax-highlighting/test" "loom-feature-lang-lisp/test" "loom-feature-lang-nix/test" "loom-feature-lang-web/test" "loom-feature-lang-markup/test" "loom-feature-minibuffer-ui/test" "loom-feature-buffers/test" "loom-feature-files/test"))))

(asdf:defsystem "loom/test-support"
  :description "Shared test package and fixtures for loom slice tests"
  :depends-on ("loom")
  :pathname "."
  :serial t
  :in-order-to ((asdf:prepare-op (asdf:load-op "cl-weave")))
  :components
  ((:file "t/package") (:file "t/test-support/buffer-test-support") (:file "t/test-helpers-core") (:file "t/test-helpers-prompts") (:file "t/integration/commands-editing-test-support") (:file "t/test-helpers-lsp")))
