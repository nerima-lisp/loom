;;;; src/domain/keymap-descriptor.lisp
;;;;
;;;; Domain layer: canonical key descriptor normalization for keymap protocols.
;;;; The keymap trie itself lives in src/domain/keymap.lisp; incremental dispatch
;;;; state lives in src/domain/keymap-state.lisp.
;;;;
;;;; Key descriptor representation: since this layer has no dependency on
;;;; cl-tty-kit, it does not know that library's KEY-EVENT class's slots. It
;;;; instead defines its own canonical, lighter descriptor and normalizes
;;;; anything handed to KEYMAP-DEFINE-KEY / KEYMAP-STATE-DISPATCH into that
;;;; shape:
;;;;
;;;;   a cons whose CAR is MODIFIERS and whose CDR is CODE
;;;;
;;;; where MODIFIERS is a list of keyword symbols such as :CONTROL, :META,
;;;; :SHIFT (order-independent -- NORMALIZE-KEY-DESCRIPTOR sorts it), and CODE
;;;; is either a character (for printable keys, e.g. #\x) or a keyword naming
;;;; a special key (e.g. :UP, :TAB, :ENTER, :ESCAPE). A bare character or
;;;; keyword is also accepted directly, as shorthand for (NIL . CODE), i.e. an
;;;; unmodified key. Infrastructure code that decodes real CL-TTY-KIT
;;;; key-event objects is responsible for converting them into one of these
;;;; two accepted shapes before calling into this protocol.
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
