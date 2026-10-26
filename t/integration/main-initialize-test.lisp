(in-package #:loom/test)

(describe "%initialize-editor-state"
          (it
           "loads an existing file into the initial buffer and names it after the file"
           (host-kit:with-temporary-directory (dir)
                                              (let ((path
                                                     (merge-pathnames "note.txt"
                                                                      dir))
                                                    (*editor-state* nil))
                                                (host-kit:write-file-string
                                                 "hello"
                                                 path)
                                                (loom::%initialize-editor-state
                                                 (namestring path))
                                                (expect
                                                 (buffer-name
                                                  (%selected-test-buffer))
                                                 :to-equal
                                                 "note.txt")
                                                (expect
                                                 (buffer-text
                                                  (%selected-test-buffer))
                                                 :to-equal
                                                 "hello"))))
          (it "registers all startup files and leaves the first one selected"
              (host-kit:with-temporary-directory (dir)
                                                 (let ((first-path
                                                        (merge-pathnames
                                                         "first.txt"
                                                         dir))
                                                       (second-path
                                                        (merge-pathnames
                                                         "second.txt"
                                                         dir))
                                                       (*editor-state* nil))
                                                   (host-kit:write-file-string
                                                    "first"
                                                    first-path)
                                                   (host-kit:write-file-string
                                                    "second"
                                                    second-path)
                                                   (loom::%initialize-editor-state
                                                    (namestring first-path)
                                                    (list
                                                     (namestring second-path)
                                                     (namestring second-path)))
                                                   (let* ((session
                                                           (editor-state-session
                                                            *editor-state*))
                                                          (buffers
                                                           (loom/feature/buffers:registered-buffers
                                                            session))
                                                          (second-buffer
                                                           (find "second.txt"
                                                                 buffers
                                                                 :key
                                                                 #'buffer-name
                                                                 :test
                                                                 #'string=)))
                                                     (expect (length buffers)
                                                             :to-equal
                                                             2)
                                                     (expect
                                                      (buffer-name
                                                       (%selected-test-buffer))
                                                      :to-equal
                                                      "first.txt")
                                                     (expect
                                                      (buffer-text
                                                       (%selected-test-buffer))
                                                      :to-equal
                                                      "first")
                                                     (expect second-buffer
                                                             :to-be-truthy)
                                                     (expect
                                                      (buffer-text
                                                       second-buffer)
                                                      :to-equal
                                                      "second")
                                                     (expect
                                                      (buffer-path
                                                       second-buffer)
                                                      :to-equal
                                                      (probe-file second-path))))))
          (it "opens an empty *scratch* buffer when given no path argument"
              (let ((*editor-state* nil))
                (loom::%initialize-editor-state nil)
                (expect (buffer-name (%selected-test-buffer))
                        :to-equal
                        "*scratch*"))))

(describe "loom-version"
          (it "returns the loom ASDF system's version string"
              (expect (loom:loom-version)
                      :to-equal
                      (asdf:component-version (asdf:find-system "loom"))))
          (it "uses an explicit fallback when the ASDF system is unavailable"
              (with-replaced-function
               (asdf:find-system
                (lambda (name &optional error-p)
                  (declare (ignore name error-p))
                  nil))
               (expect (loom:loom-version) :to-equal "unknown"))))

(describe "session save hooks"
          (it
           "runs before-save before the write and after-save after mark-saved"
           (host-kit:with-temporary-directory (directory)
                                              (let* ((path
                                                      (merge-pathnames
                                                       "notes.txt"
                                                       directory))
                                                     (buffer
                                                      (make-buffer :name
                                                                   "notes.txt"
                                                                   :path
                                                                   path
                                                                   :initial-content
                                                                   "draft"))
                                                     (session
                                                      (%make-test-editor-session
                                                       (list buffer)))
                                                     (loom/core/editor-session::*session-hooks*
                                                      (make-hash-table :test
                                                                       #'eq))
                                                     (loom/core/editor-session:*editor-session*
                                                      session)
                                                     (events nil))
                                                (loom/feature/files::%remember-file-snapshot buffer nil)
                                                (buffer-mark-modified buffer)
                                                (loom/core/editor-session:register-session-hook
                                                 :before-save
                                                 :feature/format
                                                 (lambda
                                                     (received-session
                                                      received-buffer)
                                                   (expect received-session
                                                           :to-be
                                                           session)
                                                   (expect received-buffer
                                                           :to-be
                                                           buffer)
                                                   (expect
                                                    (buffer-modified-p buffer)
                                                    :to-be-truthy)
                                                   (expect
                                                    (host-kit:path-exists-p
                                                     path)
                                                    :to-be
                                                    nil)
                                                   (push :before events)))
                                                (loom/core/editor-session:register-session-hook
                                                 :after-save
                                                 :feature/auto-save
                                                 (lambda
                                                     (received-session
                                                      received-buffer)
                                                   (expect received-session
                                                           :to-be
                                                           session)
                                                   (expect received-buffer
                                                           :to-be
                                                           buffer)
                                                   (expect
                                                    (host-kit:path-exists-p
                                                     path)
                                                    :to-be-truthy)
                                                   (expect
                                                    (buffer-modified-p buffer)
                                                    :to-be-falsy)
                                                   (push :after events)))
                                                (expect (buffer-save buffer)
                                                        :to-be
                                                        buffer)
                                                (expect (reverse events)
                                                        :to-equal
                                                        '(:before :after))
                                                (expect
                                                 (host-kit:read-file-string
                                                  path)
                                                 :to-equal
                                                 "draft"))))
          (it "does not write when a before-save hook fails"
              (host-kit:with-temporary-directory (directory)
                                                 (let* ((path
                                                         (merge-pathnames
                                                          "notes.txt"
                                                          directory))
                                                        (buffer
                                                         (make-buffer :name
                                                                      "notes.txt"
                                                                      :path
                                                                      path
                                                                      :initial-content
                                                                      "draft"))
                                                        (session
                                                         (%make-test-editor-session
                                                          (list buffer)))
                                                        (loom/core/editor-session::*session-hooks*
                                                         (make-hash-table :test
                                                                          #'eq))
                                                        (loom/core/editor-session:*editor-session*
                                                         session))
                                                   (buffer-mark-modified buffer)
                                                   (loom/core/editor-session:register-session-hook
                                                    :before-save
                                                    :feature/format
                                                    (lambda
                                                        (received-session
                                                         received-buffer)
                                                      (declare (ignore
                                                                received-session
                                                                received-buffer))
                                                      (error
                                                       "before-save failed")))
                                                   (signals error
                                                            (buffer-save buffer))
                                                   (expect
                                                    (host-kit:path-exists-p
                                                     path)
                                                    :to-be
                                                    nil)
                                                   (expect
                                                    (buffer-modified-p buffer)
                                                    :to-be-truthy))))
          (it "keeps a completed write when an after-save hook fails"
              (host-kit:with-temporary-directory (directory)
                                                 (let* ((path
                                                         (merge-pathnames
                                                          "notes.txt"
                                                          directory))
                                                        (buffer
                                                         (make-buffer :name
                                                                      "notes.txt"
                                                                      :path
                                                                      path
                                                                      :initial-content
                                                                      "draft"))
                                                        (session
                                                         (%make-test-editor-session
                                                          (list buffer)))
                                                        (loom/core/editor-session::*session-hooks*
                                                         (make-hash-table :test
                                                                          #'eq))
                                                        (loom/core/editor-session:*editor-session*
                                                         session))
                                                   (loom/feature/files::%remember-file-snapshot buffer nil)
                                                   (buffer-mark-modified buffer)
                                                   (loom/core/editor-session:register-session-hook
                                                    :after-save
                                                    :feature/auto-save
                                                    (lambda
                                                        (received-session
                                                         received-buffer)
                                                      (declare (ignore
                                                                received-session
                                                                received-buffer))
                                                      (error
                                                       "after-save failed")))
                                                   (signals error
                                                            (buffer-save buffer))
                                                   (expect
                                                    (host-kit:path-exists-p
                                                     path)
                                                    :to-be-truthy)
                                                   (expect
                                                    (host-kit:read-file-string
                                                     path)
                                                    :to-equal
                                                    "draft")
                                                   (expect
                                                    (buffer-modified-p buffer)
                                                    :to-be-falsy)))))
