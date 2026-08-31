(in-package #:loom/test)

(describe
  "auto-save sidecars"
  (it "wraps the complete file name in hash characters"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "notes.txt" directory)))
        (expect (file-namestring (auto-save-path path))
                :to-equal
                "#notes.txt#"))))

  (it "accepts string content and creates parent directories"
    (host-kit:with-temporary-directory (directory)
      (let ((path (merge-pathnames "nested/#notes.txt#" directory)))
        (expect (write-auto-save-file path "draft") :to-equal path)
        (expect (host-kit:read-file-string path) :to-equal "draft"))))

  (it "rejects non-string auto-save content"
    (signals type-error
      (write-auto-save-file "/tmp/loom-invalid-auto-save" 42)))

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

  (it "treats missing or pathless sidecars as harmless"
    (let ((buffer (make-buffer :initial-content "draft")))
      (expect (delete-auto-save-file buffer) :to-be nil)))

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
  (it "toggles global mode when no explicit value is supplied"
    (%with-minibuffer-state (minibuffer "text")
      (let ((state *editor-state*))
        (expect (editor-state-auto-save-mode-p state) :to-be-falsy)
        (expect (auto-save-mode) :to-be-truthy)
        (expect (editor-state-auto-save-mode-p state) :to-be-truthy)
        (expect (auto-save-mode) :to-be-falsy)
        (expect (editor-state-auto-save-mode-p state) :to-be-falsy))))

(describe
  "automatic save command boundaries"
  (it "reports a selected-buffer auto-save and skips an ineligible buffer"
    (host-kit:with-temporary-directory (directory)
      (let* ((path (merge-pathnames "notes.txt" directory))
             (buffer (make-buffer :name "notes.txt"
                                  :path path
                                  :initial-content "draft")))
        (%with-minibuffer-state (minibuffer "text")
          (let ((state *editor-state*))
            (setf (editor-state-buffers state) (list buffer))
            (window-set-buffer (%selected-window) buffer)
            (expect (auto-save-current-buffer) :to-be nil)
            (expect (minibuffer-message-string minibuffer)
                    :to-equal "Auto-save skipped")
            (buffer-mark-modified buffer)
            (auto-save-mode t)
            (expect (auto-save-current-buffer) :to-equal (auto-save-path path))
            (expect (minibuffer-message-string minibuffer)
                    :to-equal "Auto-saved notes.txt"))))))
  (it "handles auto-save without an active editor state"
    (let ((*editor-state* nil))
      (signals error (auto-save-mode t))
      (expect (maybe-auto-save :force t) :to-be nil))))

(describe
  "automatic save selection boundaries"
  (it "rejects toggling a buffer when no selected buffer is active"
    (%with-minibuffer-state (minibuffer "text")
      (window-set-buffer (%selected-window) nil)
      (signals error (toggle-auto-save)))))

(describe
  "automatic save error boundaries"
  (it "reports an error from the selected-buffer auto-save"
    (%with-minibuffer-state (minibuffer "text")
      (with-replaced-function
          (loom/feature/auto-save::auto-save-buffer
           (lambda (&rest arguments)
             (declare (ignore arguments))
             (error "sidecar unavailable")))
        (expect (auto-save-current-buffer) :to-be nil)
        (expect (minibuffer-message-string minibuffer)
                :to-contain "Auto-save error: sidecar unavailable"))))
  (it "continues a pass when one enabled buffer cannot be saved"
    (%with-minibuffer-state (minibuffer "text")
      (let* ((state *editor-state*)
             (selected (%selected-test-buffer))
             (other (make-buffer :name "other" :initial-content "draft")))
        (setf (editor-state-buffers state) (list selected other))
        (auto-save-mode t)
        (with-replaced-function
            (loom/feature/auto-save::auto-save-buffer
             (lambda (buffer)
               (if (eq buffer selected)
                   (error "selected sidecar unavailable")
                   "other.sidecar")))
          (expect (maybe-auto-save :force t :now 100)
                  :to-equal (list "other.sidecar"))
          (expect (minibuffer-message-string minibuffer)
                  :to-contain "Auto-save error for"))))))
