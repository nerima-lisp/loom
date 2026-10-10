(in-package #:loom/test)

(describe
  "session-store envelope validation"
  (it
    "accepts only the canonical v5 envelope and rejects invalid plist shapes"
    (host-kit:with-temporary-directory (directory)
      (let* ((valid-buffer-form
               "(:name \"*x*\" :path nil :text \"\" :point-line 0 :point-column 0 :mark-line nil :mark-column nil :modified-p nil)")
             (valid-workspace-form
               "(:name \"main\" :layout (:leaf 0 0) :selected-window-index 0)")
             (valid-form
               (format nil
                       "(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                       valid-buffer-form
                       valid-workspace-form)))
        (flet ((reject (name contents)
                 (let ((path (merge-pathnames name directory)))
                   (host-kit:write-file-string contents path)
                   (signals error (session-store-read path)))))
          (reject "empty.sexp" "")
          (dolist (version '(1 2 3 4 6))
            (reject (format nil "unsupported-version-~D.sexp" version)
                    (format nil
                            "(:loom-session ~D :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                            version
                            valid-buffer-form
                            valid-workspace-form)))
          (reject "bad-command-history.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history (42) :workspaces (~A) :current-workspace-index 0)"
                          valid-buffer-form
                          valid-workspace-form))
          (reject "trailing.sexp"
                  (format nil "~A~%~A" valid-form valid-form))
          (reject "duplicate-field.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0 :current-workspace-index 0)"
                          valid-buffer-form
                          valid-workspace-form))
          (reject "missing-field.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A)"
                          valid-buffer-form
                          valid-workspace-form))
          (reject "extra-field.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0 :unexpected t)"
                          valid-buffer-form
                          valid-workspace-form))
          (reject "bad-buffers.sexp"
                  (format nil
                          "(:loom-session 5 :buffers \"not a list\" :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-workspace-form))
          (reject "bad-buffer-value.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (42) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-workspace-form))
          (reject "odd-buffer-plist.sexp"
                  (format nil
                          "(:loom-session 5 :buffers ((:name)) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-workspace-form))
          (reject "non-keyword-buffer-plist.sexp"
                  (format nil
                          "(:loom-session 5 :buffers ((name \"*x*\")) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-workspace-form))
          (reject "bad-buffer-fields.sexp"
                  (format nil
                          "(:loom-session 5 :buffers ((:name \"*x*\" :path nil :text \"\" :point-line 0 :point-column 0 :mark-line nil :mark-column nil :modified-p nil :modified-p nil)) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-buffer-form))
          (reject "bad-workspace-value.sexp"
                  "(:loom-session 5 :buffers ((:name \"*x*\" :path nil :text \"\" :point-line 0 :point-column 0 :mark-line nil :mark-column nil :modified-p nil)) :recent-files () :bookmarks () :command-history () :workspaces (42) :current-workspace-index 0)")
          (reject "empty-buffers.sexp"
                  (format nil
                          "(:loom-session 5 :buffers () :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-workspace-form))
          (reject "cyclic-recent-files.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (~A) :recent-files #1=(\"recent\" . #1#) :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-buffer-form
                          valid-workspace-form))
          (reject "cyclic-top-level.sexp"
                  (format nil
                          "#1=(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0 . #1#)"
                          valid-buffer-form
                          valid-workspace-form))
          (reject "cyclic-version.sexp"
                  (format nil
                          "(:loom-session #1=(5 . #1#) :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces (~A) :current-workspace-index 0)"
                          valid-buffer-form
                          valid-workspace-form))
          (reject "cyclic-layout.sexp"
                  (format nil
                          "(:loom-session 5 :buffers (~A) :recent-files () :bookmarks () :command-history () :workspaces ((:name \"main\" :layout #1=(:split :horizontal (:leaf 0 0) #1#) :selected-window-index 0)) :current-workspace-index 0)"
                          valid-buffer-form))))))

  (it
    "keeps cyclic input diagnostics printable after the reader unwinds"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "cyclic.sexp" directory)))
        (host-kit:write-file-string "#1=(:loom-session 5 . #1#)" path)
        (let ((condition (handler-case
                             (progn (session-store-read path) nil)
                           (error (condition) condition))))
          (expect (typep condition 'error) :to-be-truthy)
          (let* ((*print-circle* nil)
                 (message (princ-to-string condition)))
            (expect message :to-contain "session-store-read: cannot read")
            (expect message :to-contain "expected a keyword plist")
            (expect message :to-contain "#1#")
            (expect (< (length message) 4096) :to-be-truthy)))))))
