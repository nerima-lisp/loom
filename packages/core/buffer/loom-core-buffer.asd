(asdf:defsystem "loom-core-buffer"
  :depends-on ()
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "domain-buffer-storage")
     (:file "domain-buffer-storage-support")
     (:file "domain-buffer-piece-table-position")
     (:file "domain-buffer-piece-table-coalescing")
     (:file "domain-buffer-piece-table-splicing")
     (:file "domain-buffer-piece-table-support")
     (:file "domain-buffer-piece-table")
     (:file "domain-buffer-piece-table-undo")
     (:file "domain-buffer")
     (:file "domain-buffer-accessors")
     (:file "domain-buffer-editing")
     (:file "domain-buffer-deletion")
     (:file "domain-buffer-history")
     (:file "domain-buffer-narrowing-support")
     (:file "domain-buffer-narrowing")
     (:file "domain-buffer-positions")))))

(asdf:defsystem "loom-core-buffer/test"
  :depends-on ("loom-core-buffer" "loom/test-support" "cl-host-kit")
  :serial t
  :components
  ((:module "t"
    :serial t
    :components
    ((:module "unit"
      :serial t
      :components
      ((:file "buffer-test-support")
       (:file "buffer-basic-test")
       (:file "buffer-insert-test")
       (:file "buffer-delete-char-test")
       (:file "buffer-region-test")
       (:file "buffer-undo-test")
       (:file "buffer-redo-test")
       (:file "buffer-read-only-test")
       (:file "buffer-storage-test")
       (:file "buffer-view-test")))
     (:module "integration"
      :serial t
      :components
      ((:file "piece-table-model-test")))))))
