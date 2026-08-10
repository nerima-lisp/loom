(in-package #:loom/test)

(describe
  "auto-save sidecars"
  (it "wraps the complete file name in hash characters"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "notes.txt" directory)))
        (expect (file-namestring (auto-save-path path))
                :to-equal
                "#notes.txt#"))))

  (it "writes modified file buffers without clearing their modified state"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "notes.txt" directory))
             (buffer (make-buffer :name "notes.txt"
                                  :path path
                                  :initial-content "draft"))
             (sidecar (progn
                        (buffer-mark-modified buffer)
                        (auto-save-buffer-to-file buffer))))
        (expect (host-kit:path-exists-p sidecar) :to-be-truthy)
        (expect (host-kit:read-file-string sidecar) :to-equal "draft")
        (expect (buffer-modified-p buffer) :to-be-truthy))))

  (it "skips unmodified and read-only buffers"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "notes.txt" directory))
             (buffer (make-buffer :path path :initial-content "draft")))
        (expect (auto-save-eligible-p buffer) :to-be-falsy)
        (buffer-mark-modified buffer)
        (buffer-set-read-only buffer t)
        (expect (auto-save-eligible-p buffer) :to-be-falsy)
        (expect (auto-save-buffer-to-file buffer) :to-be nil)))))

  (it "removes the sidecar and runs hooks after an ordinary save"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "notes.txt" directory))
             (buffer (make-buffer :name "notes.txt"
                                  :path path
                                  :initial-content "draft"))
             (tree (make-window-tree buffer 80 24))
             (state (make-editor-state
                     :window-tree tree
                     :workspaces (make-workspace-manager tree :name "main")
                     :minibuffer (make-minibuffer)
                     :keymap (make-keymap)
                     :file-tree nil
                     :renderer nil
                     :buffers (list buffer)
                     :kill-ring nil))
             (hook-buffer nil))
        (buffer-mark-modified buffer)
        (let ((sidecar (auto-save-buffer-to-file buffer)))
          (let ((*editor-state* state))
            (add-after-save-hook #'delete-auto-save-file)
            (add-after-save-hook (lambda (saved-buffer)
                                   (setf hook-buffer saved-buffer)))
            (expect (buffer-save buffer) :to-be buffer))
          (expect (host-kit:path-exists-p sidecar) :to-be nil)
          (expect (buffer-modified-p buffer) :to-be-falsy)
          (expect hook-buffer :to-be buffer)
          (expect (host-kit:read-file-string path) :to-equal "draft")))))

(describe
  "automatic save modes"
  (it "supports global mode, per-buffer mode, and the interval gate"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "notes.txt" directory))
             (buffer (make-buffer :name "notes.txt"
                                  :path path
                                  :initial-content "draft"))
             (tree (make-window-tree buffer 80 24))
             (state (make-editor-state
                     :window-tree tree
                     :workspaces (make-workspace-manager tree :name "main")
                     :minibuffer (make-minibuffer)
                     :keymap (make-keymap)
                     :file-tree nil
                     :renderer nil
                     :buffers (list buffer)
                     :kill-ring nil)))
        (buffer-mark-modified buffer)
        (let ((*editor-state* state))
          (expect (auto-save-mode t) :to-be-truthy)
          (expect (auto-save-enabled-p buffer) :to-be-truthy)
          (let ((paths (maybe-auto-save :force t :now 100)))
            (expect (length paths) :to-equal 1)
            (expect (host-kit:read-file-string (first paths))
                    :to-equal
                    "draft"))
          (expect (maybe-auto-save :now 101) :to-be nil)
          (auto-save-mode nil)
          (expect (auto-save-enabled-p buffer) :to-be-falsy)
          (expect (toggle-auto-save) :to-be-truthy)
          (expect (auto-save-enabled-p buffer) :to-be-truthy)
          (expect (toggle-auto-save) :to-be nil)
          (expect (auto-save-enabled-p buffer) :to-be-falsy))))))
