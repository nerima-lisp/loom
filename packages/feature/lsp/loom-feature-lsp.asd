(asdf:defsystem "loom-feature-lsp"
  :depends-on ("cl-json-kit" "cl-host-kit"
                             "cl-concurrent-kit"
                             "cl-date-kit"
                             "loom-core-buffer"
                             "loom-core-editor-session"
                             "loom-core-minibuffer"
                             "loom-core-window-tree"
                             "loom-core-command"
                             "loom-feature-buffers"
                             "loom-feature-file-tree"
                             "loom-feature-project" "loom-feature-mode"
                             "loom-feature-search")
  :serial t
  :components ((:module "src"
                        :serial
                        t
                        :components
                        ((:file "package") (:file "domain-lsp")
                         (:file "infrastructure-lsp-framing-support")
                         (:file "infrastructure-lsp-headers")
                         (:file "infrastructure-lsp-framing")
                         (:file "infrastructure-lsp-discovery")
                         (:file "infrastructure-lsp-transport-support")
                         (:file "infrastructure-lsp-transport")
                         (:file "application-lsp-protocol-send")
                         (:file "application-lsp-protocol-initialize")
                         (:file "application-lsp-protocol-helpers")
                         (:file "application-lsp-diagnostic-decode")
                         (:file "application-lsp-request-decode")
                         (:file "application-lsp-protocol-responses")
                         (:file "application-lsp-requests")
                         (:file "application-lsp-protocol-routing")
                         (:file "application-lsp-protocol-receive")
                         (:file "application-lsp-session-state") (:file "application-lsp-session-uri")
                         (:file "application-lsp-session-registry")
                         (:file "application-lsp-session-sync")
                         (:file "application-lsp-session-lifecycle")
                         (:file "application-lsp-diagnostics-view")
                         (:file "application-commands-lsp-support")
                         (:file "application-commands-lsp-context")
                         (:file "application-commands-lsp")
                         (:file "application-commands-lsp-completion")
                         (:file "application-commands-lsp-navigation")
                         (:file "command-specs-lsp")
                         (:file "command-specs-lsp-navigation")
                         (:file "command-specs-lsp-completion")))))

(asdf:defsystem "loom-feature-lsp/test"
  :depends-on ("loom-feature-lsp" "loom/test-support" "cl-host-kit" "cl-weave")
  :serial t
  :components ((:module "t"
                        :serial
                        t
                        :components
                        ((:module "unit"
                                  :serial
                                  t
                                  :components
                                  ((:file "lsp-framing-test-support")
                                   (:file "lsp-framing-test")
                                   (:file "lsp-domain-values-test")
                                   (:file "lsp-request-decode-test")))
                         (:module "integration"
                                  :serial
                                  t
                                  :components
                                  ((:file "lsp-session-lifecycle-error-test")
                                   (:file
                                    "lsp-session-lifecycle-initialize-test")
                                   (:file "lsp-session-lifecycle-stop-test")
                                   (:file
                                    "lsp-session-lifecycle-transport-test")
                                   (:file
                                    "lsp-session-lifecycle-transport-readers-test")
                                   (:file
                                    "lsp-session-lifecycle-transport-state-test")
                                   (:file
                                    "lsp-session-lifecycle-transport-process-test")
                                   (:file "lsp-session-diagnostics-test")
                                   (:file "lsp-session-paths-test")
                                   (:file "lsp-discovery-test")
                                   (:file "lsp-command-diagnostics-render-test")
                                   (:file "lsp-command-diagnostics-state-test")
                                   (:file
                                    "commands-lsp-navigation-test-support")
                                   (:file "commands-lsp-navigation-test")
                                   (:file "lsp-completion-data-test")
                                   (:file "commands-lsp-definition-test")
                                   (:file "lsp-command-diagnostics-format-test")
                                   (:file "lsp-command-start-test")
                                   (:file "lsp-command-start-discovery-test")))))))
