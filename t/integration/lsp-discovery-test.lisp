(in-package #:loom/test)

(describe
  "LSP project discovery"
  (it "uses the nearest .loom-lsp command and skips comments and blank lines"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (nested (merge-pathnames "nested/" directory))
             (source (merge-pathnames "nested/main.lisp" directory))
             (root-config (merge-pathnames ".loom-lsp" directory))
             (nested-config (merge-pathnames ".loom-lsp" nested)))
        (ensure-directories-exist source)
        (host-kit:write-file-string
         (format nil "# root command~%~%  root-server --stdio  ~%")
         root-config)
        (host-kit:write-file-string
         (format nil " # nested comment~%~% nested-server --stdio ~%")
         nested-config)
        (multiple-value-bind (command root configuration)
            (lsp-discover-command source)
          (expect command :to-equal "nested-server --stdio")
          (expect (namestring root)
                  :to-equal
                  (namestring (truename nested)))
          (expect (namestring configuration)
                  :to-equal
                  (namestring (truename nested-config)))))))

  (it "returns no discovery for missing or commandless configuration"
    (host-kit:with-temporary-directory (directory)
      (let* ((directory (truename directory))
             (source (merge-pathnames "main.lisp" directory))
             (configuration (merge-pathnames ".loom-lsp" directory)))
        (host-kit:write-file-string "source" source)
        (multiple-value-bind (command root config)
            (lsp-discover-command source)
          (expect command :to-be nil)
          (expect root :to-be nil)
          (expect config :to-be nil))
        (host-kit:write-file-string
         (format nil "# comment~%~%  ~%")
         configuration)
        (multiple-value-bind (command root config)
            (lsp-discover-command source)
          (expect command :to-be nil)
          (expect root :to-be nil)
          (expect config :to-be nil)))))

  (it "ignores non-string configuration contents"
    (expect (loom/feature/lsp::%lsp-config-command nil)
            :to-be nil)))
