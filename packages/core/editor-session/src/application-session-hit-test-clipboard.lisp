(in-package #:loom/core/editor-session)

(defstruct (%hit-test-provider
            (:constructor %make-hit-test-provider
                          (owner priority function order))
            (:copier nil)
            (:conc-name %hit-test-provider-))
  owner
  priority
  function
  order)

(defstruct (hit-test-result
            (:constructor %make-hit-test-result
                          (owner kind window buffer position target))
            (:copier nil)
            (:conc-name %hit-test-result-))
  owner
  kind
  window
  buffer
  position
  target)

(defvar *hit-test-providers* nil)
(defvar *next-hit-test-provider-order* 0)
(defvar *terminal-clipboard-requests* (make-hash-table :test #'eq))

(defun %validate-hit-test-result-payload (kind window buffer position target)
  (case kind
    (:buffer-text
     (unless (and window buffer position (null target))
       (error
        ":BUFFER-TEXT hit-test results require WINDOW, BUFFER, and POSITION only.")))
    ((:window-blank :mode-line)
     (unless (and window (null buffer) (null position) (null target))
       (error "~A hit-test results require WINDOW only." kind)))
    (:feature-item
     (unless (and target (null window) (null buffer) (null position))
       (error ":FEATURE-ITEM hit-test results require TARGET only.")))
    (otherwise
     (error "Unknown hit-test result kind: ~S" kind)))
  t)

(defun make-hit-test-result (owner kind &key window buffer position target)
  (unless (keywordp owner)
    (error "Hit-test result owner must be a keyword: ~S" owner))
  (%validate-hit-test-result-payload kind window buffer position target)
  (%make-hit-test-result owner kind window buffer position target))

(defun hit-test-result-owner (result)
  (check-type result hit-test-result)
  (%hit-test-result-owner result))

(defun hit-test-result-kind (result)
  (check-type result hit-test-result)
  (%hit-test-result-kind result))

(defun hit-test-result-window (result)
  (check-type result hit-test-result)
  (%hit-test-result-window result))

(defun hit-test-result-buffer (result)
  (check-type result hit-test-result)
  (%hit-test-result-buffer result))

(defun hit-test-result-position (result)
  (check-type result hit-test-result)
  (%hit-test-result-position result))

(defun hit-test-result-target (result)
  (check-type result hit-test-result)
  (%hit-test-result-target result))

(defun register-hit-test-provider (owner priority function)
  (unless (keywordp owner)
    (error "Hit-test provider owner must be a keyword: ~S" owner))
  (unless (integerp priority)
    (error "Hit-test provider priority must be an integer: ~S" priority))
  (check-type function function)
  (%with-session-extension-lock
   (unless
       (find-if
        (lambda (provider)
          (and (eq owner (%hit-test-provider-owner provider))
               (= priority (%hit-test-provider-priority provider))
               (eq function (%hit-test-provider-function provider))))
        *hit-test-providers*)
     (setf *hit-test-providers*
           (append *hit-test-providers*
                   (list (%make-hit-test-provider
                          owner priority function
                          *next-hit-test-provider-order*))))
     (incf *next-hit-test-provider-order*)))
  function)

(defun %ordered-hit-test-providers ()
  (stable-sort
   (%with-session-extension-lock (copy-list *hit-test-providers*))
   (lambda (left right)
     (> (%hit-test-provider-priority left)
        (%hit-test-provider-priority right)))))

(defun %validate-hit-test-provider-result (provider result)
  (unless (hit-test-result-p result)
    (error "Hit-test provider ~S returned neither NIL nor a hit-test result: ~S"
           (%hit-test-provider-owner provider)
           result))
  (unless (eq (%hit-test-provider-owner provider)
              (%hit-test-result-owner result))
    (error "Hit-test provider ~S returned a result owned by ~S."
           (%hit-test-provider-owner provider)
           (%hit-test-result-owner result)))
  (%validate-hit-test-result-payload (%hit-test-result-kind result)
                                     (%hit-test-result-window result)
                                     (%hit-test-result-buffer result)
                                     (%hit-test-result-position result)
                                     (%hit-test-result-target result))
  result)

(defun hit-test-coordinate (session screen-x screen-y)
  (check-type session editor-session)
  (unless (and (integerp screen-x) (integerp screen-y))
    (error "Hit-test coordinates must be integers: ~S, ~S" screen-x screen-y))
  (let* ((window-tree (editor-session-slice session :core/window-tree))
         (frame-width (loom/core/window-tree:window-tree-width window-tree))
         (frame-height (loom/core/window-tree:window-tree-height window-tree)))
    (when (and (<= 0 screen-x) (< screen-x frame-width)
               (<= 0 screen-y) (< screen-y frame-height))
      (dolist (provider (%ordered-hit-test-providers))
        (let ((result
                (funcall (%hit-test-provider-function provider)
                         session screen-x screen-y)))
          (when result
            (return-from hit-test-coordinate
              (%validate-hit-test-provider-result provider result)))))))
  nil)

(defun hit-test-buffer-position (session screen-x screen-y)
  (let ((result (hit-test-coordinate session screen-x screen-y)))
    (when (and result (eq (%hit-test-result-kind result) :buffer-text))
      (return-from hit-test-buffer-position
        (values (%hit-test-result-window result)
                (%hit-test-result-buffer result)
                (%hit-test-result-position result)))))
  nil)

(defun request-terminal-clipboard-write (session text)
  (check-type session editor-session)
  (check-type text string)
  (%with-session-extension-lock
   (push (copy-seq text)
         (gethash session *terminal-clipboard-requests*)))
  :queued)

(defun drain-terminal-clipboard-requests (session)
  (check-type session editor-session)
  (%with-session-extension-lock
   (let ((requests (gethash session *terminal-clipboard-requests*)))
     (remhash session *terminal-clipboard-requests*)
     (mapcar #'copy-seq (nreverse requests)))))
