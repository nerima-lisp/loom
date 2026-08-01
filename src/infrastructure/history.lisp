;;;; src/infrastructure/history.lisp
;;;;
;;;; Infrastructure layer: placeholder for a CL-HISTORY-KIT adapter.
;;;;
;;;; Decision (checked against the actual minibuffer protocol group in the
;;;; original src/protocol.lisp before splitting it): MAKE-MINIBUFFER and
;;;; MINIBUFFER-HANDLE-KEY already name CL-HISTORY-KIT:MAKE-HISTORY and
;;;; CL-HISTORY-KIT:HISTORY-PREVIOUS/HISTORY-NEXT directly in their contracts
;;;; -- there is no separate "history" sub-protocol to split out. Minibuffer
;;;; history is therefore accessed directly via cl-history-kit inside
;;;; application/minibuffer.lisp (the minibuffer protocol's HISTORY keyword
;;;; argument is, and will remain, a CL-HISTORY-KIT history object), and no
;;;; new generics are declared here. This file exists only so the
;;;; infrastructure/ directory's intended scope -- adapters to sibling
;;;; libraries -- is visible to future contributors before any such adapter
;;;; is actually needed.
(in-package #:loom)
