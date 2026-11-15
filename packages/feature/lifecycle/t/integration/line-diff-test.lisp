(in-package #:loom/test)

(describe "cl-vcs-kit recovery line diffs"
  (it "renders a recovery candidate without changing the visiting buffer"
    (let* ((original (format nil "first~%saved~%last~%"))
           (buffer (make-buffer :initial-content original))
           (candidate (format nil "first~%recovered~%last~%"))
           (result (vcs-kit:compute-line-diff
                    (buffer-text buffer) candidate
                    :old-path "document.lisp" :new-path "recovery.lisp"))
           (hunk (first (vcs-kit:line-diff-result-hunks result))))
      (expect (vcs-kit:line-diff-result-status result) :to-be :ok)
      (expect (vcs-kit:line-diff-result-edit-distance result) :to-equal 2)
      (expect (length (vcs-kit:line-diff-result-hunks result)) :to-equal 1)
      (expect (vcs-kit:line-diff-hunk-old-start hunk) :to-equal 1)
      (expect (vcs-kit:line-diff-hunk-new-start hunk) :to-equal 1)
      (expect (vcs-kit:line-diff-hunk-old-count hunk) :to-equal 3)
      (expect (vcs-kit:line-diff-hunk-new-count hunk) :to-equal 3)
      (expect (vcs-kit:format-unified-diff result)
              :to-equal
              (format nil "--- document.lisp~%+++ recovery.lisp~%@@ -1,3 +1,3 @@~% first~%-saved~%+recovered~% last~%"))
      (expect (buffer-text buffer) :to-equal original)))

  (it "preserves the recovery candidate's missing final newline"
    (let* ((result (vcs-kit:compute-line-diff
                    (format nil "saved~%") "recovered"
                    :old-path "saved" :new-path "recovery"))
           (lines (vcs-kit:line-diff-hunk-lines
                   (first (vcs-kit:line-diff-result-hunks result)))))
      (expect (vcs-kit:line-diff-result-status result) :to-be :ok)
      (expect (mapcar #'vcs-kit:line-diff-line-kind lines)
              :to-equal '(:delete :insert))
      (expect (mapcar #'vcs-kit:line-diff-line-text lines)
              :to-equal '("saved" "recovered"))
      (expect (mapcar #'vcs-kit:line-diff-line-newline-p lines)
              :to-equal '(t nil))
      (expect (vcs-kit:format-unified-diff result)
              :to-equal
              (format nil "--- saved~%+++ recovery~%@@ -1 +1 @@~%-saved~%+recovered~%\\ No newline at end of file~%"))))

  (it "reports an oversized recovery diff without a partial preview"
    (let ((result (vcs-kit:compute-line-diff
                   "saved" "recovered" :max-edit-distance 1)))
      (expect (vcs-kit:line-diff-result-status result) :to-be :too-large)
      (expect (vcs-kit:line-diff-result-hunks result) :to-be nil)
      (expect (vcs-kit:line-diff-result-edit-distance result) :to-be nil)
      (signals error (vcs-kit:format-unified-diff result)))))
