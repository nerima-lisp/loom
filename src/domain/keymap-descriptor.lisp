(in-package #:loom)

(defun normalize-key-descriptor (descriptor)
  "Normalize DESCRIPTOR -- either a (MODIFIERS . CODE) cons or a bare
character/keyword CODE -- into the canonical (SORTED-MODIFIERS . CODE) cons
used as this keymap implementation's trie key. See the file header for the
accepted descriptor shapes."
  (if (and (consp descriptor) (listp (car descriptor)))
      (cons (sort (copy-list (car descriptor)) #'string< :key #'symbol-name)
            (cdr descriptor))
      (cons nil descriptor)))
