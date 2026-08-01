;;;; src/application/commands.lisp
;;;;
;;;; Application layer: commands are the use-case entry points a keymap
;;;; binding invokes.
;;;;
;;;; Commands are NOT declared as generic functions: each editable command is
;;;; a plain, ordinary function of zero arguments that reads and mutates
;;;; *EDITOR-STATE* (see application/editor-state.lisp) and the protocol
;;;; operations declared in domain/, infrastructure/, and application/ when
;;;; invoked, e.g.:
;;;;
;;;;   (defun forward-char ()
;;;;     "Move point forward one character in the selected window's buffer."
;;;;     (let ((window (window-tree-selected-window
;;;;                    (editor-state-window-tree *editor-state*))))
;;;;       (buffer-set-point (window-buffer window) ...)))
;;;;
;;;; A keymap binds a key sequence directly to such a function (see
;;;; KEYMAP-DEFINE-KEY), so command names are the vocabulary keymap bindings
;;;; are written against. This file names commands after their Emacs
;;;; equivalents where one exists (FORWARD-CHAR, KILL-LINE, SAVE-BUFFER, ...)
;;;; so the mapping from a keybinding to its behavior stays obvious from
;;;; domain/keymap.lisp alone.
;;;;
;;;; None of the commands below are exported from the LOOM package (see
;;;; src/package.lisp's header comment describing its export list as "the
;;;; fixed contract, only the file layout moved" -- adding a whole new export
;;;; section here is out of scope for this file); INSTALL-DEFAULT-KEYBINDINGS
;;;; and MAIN (same package) refer to them unqualified, and tests reach them
;;;; via LOOM:: qualification, the same precedent t/file-tree-test.lisp
;;;; already set for LOOM::FILE-TREE-CHILD-LISTER.
(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Internal helpers
;;; ---------------------------------------------------------------------

(defun %selected-window ()
  "Return *EDITOR-STATE*'s currently selected window."
  (window-tree-selected-window (editor-state-window-tree *editor-state*)))

(defun %selected-buffer ()
  "Return the buffer displayed in *EDITOR-STATE*'s currently selected window."
  (window-buffer (%selected-window)))

;;; ---------------------------------------------------------------------
;;; Movement
;;; ---------------------------------------------------------------------

(defun forward-char ()
  "Move point forward one character, wrapping onto the next line at EOL."
  (let* ((buffer (%selected-buffer))
         (line (buffer-point-line buffer))
         (column (buffer-point-column buffer))
         (line-len (length (buffer-line buffer line))))
    (cond
      ((< column line-len)
       (buffer-set-point buffer line (1+ column)))
      ((< line (1- (buffer-line-count buffer)))
       (buffer-set-point buffer (1+ line) 0))
      (t
       (buffer-set-point buffer line column)))))

(defun backward-char ()
  "Move point backward one character, wrapping onto the previous line at BOL."
  (let* ((buffer (%selected-buffer))
         (line (buffer-point-line buffer))
         (column (buffer-point-column buffer)))
    (cond
      ((> column 0)
       (buffer-set-point buffer line (1- column)))
      ((> line 0)
       (buffer-set-point buffer (1- line) (length (buffer-line buffer (1- line)))))
      (t
       (buffer-set-point buffer line column)))))

(defun next-line ()
  "Move point down one line, clamping column to the new line's length."
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (1+ (buffer-point-line buffer)) (buffer-point-column buffer))))

(defun previous-line ()
  "Move point up one line, clamping column to the new line's length."
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (1- (buffer-point-line buffer)) (buffer-point-column buffer))))

(defun move-beginning-of-line ()
  "Move point to the beginning of the current line."
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (buffer-point-line buffer) 0)))

(defun move-end-of-line ()
  "Move point to the end of the current line."
  (let ((buffer (%selected-buffer)))
    (buffer-set-point buffer (buffer-point-line buffer)
                       (length (buffer-line buffer (buffer-point-line buffer))))))

;;; ---------------------------------------------------------------------
;;; Editing
;;; ---------------------------------------------------------------------

;; SELF-INSERT-COMMAND is the one deliberate exception to the zero-argument
;; command convention: ordinary commands are bound once, ahead of time, via
;; KEYMAP-DEFINE-KEY, so a command function never needs to know which key
;; invoked it. Printable-character input does not go through that lookup at
;; all -- the main input loop's :CHARACTER key-events are handed directly to
;; whatever inserts text, since binding all of Unicode into the keymap trie
;; one codepoint at a time would be pointless -- so SELF-INSERT-COMMAND takes
;; the typed character as an explicit argument instead of reading it back out
;; of some special variable.
(defun self-insert-command (char)
  "Insert CHAR at point in the selected window's buffer."
  (buffer-insert-string (%selected-buffer) (string char)))

(defun delete-char ()
  "Delete the character at/after point (forward delete, C-d)."
  (buffer-delete-char (%selected-buffer)))

(defun delete-backward-char ()
  "Delete the character before point (backspace)."
  (buffer-delete-char (%selected-buffer) :backward t))

;; Unlike Emacs's KILL-RING-MAX (~120 by default), nothing previously capped
;; how many entries EDITOR-STATE-KILL-RING could accumulate: repeated
;; kill-line/kill-region calls in a long session would grow it without bound,
;; holding onto arbitrarily large amounts of killed text indefinitely (a
;; low-severity memory/security concern as well as wasted work walking a
;; needlessly long list). +KILL-RING-MAX+ mirrors Emacs's default; %KILL-
;; RING-PUSH is the single place both KILL-LINE and KILL-REGION funnel
;; through so the cap is enforced consistently.
(defconstant +kill-ring-max+ 120
  "Maximum number of entries kept in EDITOR-STATE-KILL-RING. Oldest entries
(the tail of the list, since new kills are pushed onto the front) are
dropped once a push would exceed this.")

(defun %kill-ring-push (text)
  "Push TEXT onto *EDITOR-STATE*'s kill ring, then trim the ring down to
+KILL-RING-MAX+ entries by dropping the oldest (tail) entries."
  (let ((kill-ring (cons text (editor-state-kill-ring *editor-state*))))
    (when (> (length kill-ring) +kill-ring-max+)
      (setf kill-ring (subseq kill-ring 0 +kill-ring-max+)))
    (setf (editor-state-kill-ring *editor-state*) kill-ring)))

(defun kill-line ()
  "Kill from point to the end of the line, pushing the text onto the kill ring."
  (let* ((buffer (%selected-buffer))
         (line (buffer-point-line buffer))
         (column (buffer-point-column buffer))
         (line-len (length (buffer-line buffer line))))
    (multiple-value-bind (end-line end-column)
        (cond
          ((< column line-len) (values line line-len))
          ((< line (1- (buffer-line-count buffer))) (values (1+ line) 0))
          (t (values line column)))
      (unless (and (= end-line line) (= end-column column))
        (%kill-ring-push (buffer-delete-region buffer line column end-line end-column))))))

(defun kill-region ()
  "Kill the region between point and mark, or report no region set."
  (let ((buffer (%selected-buffer)))
    (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
      (if (null mark-line)
          (minibuffer-message (editor-state-minibuffer *editor-state*)
                               "The mark is not set now, so no region is active")
          (let ((point-line (buffer-point-line buffer))
                (point-column (buffer-point-column buffer)))
            (multiple-value-bind (start-line start-column end-line end-column)
                (if (or (< point-line mark-line)
                        (and (= point-line mark-line) (<= point-column mark-column)))
                    (values point-line point-column mark-line mark-column)
                    (values mark-line mark-column point-line point-column))
              (%kill-ring-push (buffer-delete-region buffer start-line start-column end-line end-column))))))))

(defun yank ()
  "Insert the most recently killed text at point."
  (let ((text (first (editor-state-kill-ring *editor-state*))))
    (when text
      (buffer-insert-string (%selected-buffer) text))))

(defun set-mark-command ()
  "Set mark to point's current position."
  (let ((buffer (%selected-buffer)))
    (buffer-set-mark buffer (buffer-point-line buffer) (buffer-point-column buffer))))

;;; ---------------------------------------------------------------------
;;; Undo
;;; ---------------------------------------------------------------------

(defun undo-command ()
  "Undo the most recent change group in the selected buffer."
  (buffer-undo (%selected-buffer)))

;;; ---------------------------------------------------------------------
;;; File
;;; ---------------------------------------------------------------------

(defun find-file ()
  "Prompt for a path and load it into a buffer shown in the selected window."
  (minibuffer-activate
   (editor-state-minibuffer *editor-state*)
   "Find file: "
   :on-confirm (lambda (path)
                 (window-set-buffer (%selected-window) (buffer-load path)))))

(defun save-buffer ()
  "Save the selected buffer, prompting for a path first if it has none."
  (let ((window (%selected-window)))
    (let ((buffer (window-buffer window)))
      (if (buffer-path buffer)
          (buffer-save buffer)
          ;; The buffer protocol exposes no operation to attach a path to an
          ;; existing buffer after the fact (BUFFER-PATH has no SETF method);
          ;; instead of reaching into domain/buffer.lisp's internal
          ;; %BUFFER-PATH slot, build a fresh buffer carrying the same text
          ;; and the new path via the public MAKE-BUFFER/BUFFER-TEXT
          ;; operations, save that, and swap it into the window.
          (minibuffer-activate
           (editor-state-minibuffer *editor-state*)
           "Save file: "
           :on-confirm
           (lambda (path)
             (let ((new-buffer (make-buffer :name (buffer-name buffer)
                                             :path path
                                             :initial-content (buffer-text buffer)))
                   (old-line (buffer-point-line buffer))
                   (old-column (buffer-point-column buffer)))
               ;; MAKE-BUFFER always starts point/mark at (0,0); without this,
               ;; a path-less first save silently relocates the user's cursor
               ;; to the top of the buffer. Carry point (and mark, when set)
               ;; over onto NEW-BUFFER before it replaces BUFFER in WINDOW.
               ;; Undo history has no public transfer mechanism anywhere in
               ;; the buffer protocol (MAKE-BUFFER/BUFFER-TEXT do not expose
               ;; one), so that part of the old buffer's state is a known,
               ;; documented loss on a path-less first save.
               (buffer-set-point new-buffer old-line old-column)
               (multiple-value-bind (mark-line mark-column) (buffer-mark buffer)
                 (when (and mark-line mark-column)
                   (buffer-set-mark new-buffer mark-line mark-column)))
               (window-set-buffer window new-buffer)
               ;; Unlike the already-has-a-path fast path above, a path typed
               ;; here may already name an existing, unrelated file; BUFFER-
               ;; SAVE's real method (infrastructure/filesystem.lisp) writes
               ;; via HOST-KIT:WRITE-FILE-STRING with default :IF-EXISTS
               ;; :SUPERSEDE semantics, which would silently clobber it.
               ;; HOST-KIT:FILE-EXISTS-P (exported by cl-host-kit) is the
               ;; existence check; on a hit, warn instead of writing rather
               ;; than building a general confirmation-dialog subsystem --
               ;; NEW-BUFFER is already installed in WINDOW with PATH
               ;; attached, so the user's very next C-x C-s goes through the
               ;; ordinary already-has-a-path fast path above and writes for
               ;; real, which serves as the required second, explicit
               ;; confirmation.
               (if (host-kit:file-exists-p path)
                   (minibuffer-message
                    (editor-state-minibuffer *editor-state*)
                    (format nil "File exists: ~A (press C-x C-s again to overwrite)" path))
                   (buffer-save new-buffer)))))))))

;;; ---------------------------------------------------------------------
;;; Window
;;; ---------------------------------------------------------------------

(defun split-window-below ()
  "Split the selected window horizontally, stacking top/bottom (C-x 2)."
  (let ((tree (editor-state-window-tree *editor-state*)))
    (window-split tree (window-tree-selected-window tree) :horizontal)))

(defun split-window-right ()
  "Split the selected window vertically, placing panes side by side (C-x 3)."
  (let ((tree (editor-state-window-tree *editor-state*)))
    (window-split tree (window-tree-selected-window tree) :vertical)))

(defun other-window ()
  "Select the next window, cycling back to the first (C-x o)."
  (window-select-next (editor-state-window-tree *editor-state*)))

;; SWITCH-TO-BUFFER is a simplified stand-in: loom has no global buffer-list
;; registry anywhere in the domain/application layers yet (EDITOR-STATE has
;; no such slot -- see application/editor-state.lisp), so rather than
;; building one just for this command, this looks the typed name up among
;; the buffers currently displayed in some window of the window tree, which
;; is the only buffer collection that exists today.
(defun switch-to-buffer ()
  "Prompt for a buffer name and display it in the selected window."
  (minibuffer-activate
   (editor-state-minibuffer *editor-state*)
   "Switch to buffer: "
   :on-confirm
   (lambda (name)
     (let* ((tree (editor-state-window-tree *editor-state*))
            (match (find name (window-tree-windows tree)
                         :key (lambda (window) (buffer-name (window-buffer window)))
                         :test #'string=)))
       (if match
           (window-set-buffer (window-tree-selected-window tree) (window-buffer match))
           (minibuffer-message (editor-state-minibuffer *editor-state*)
                                (format nil "No such buffer: ~A" name)))))))

;;; ---------------------------------------------------------------------
;;; File tree
;;; ---------------------------------------------------------------------

(defun toggle-file-tree ()
  "Toggle whether the file-tree sidebar is shown."
  (file-tree-toggle (editor-state-file-tree *editor-state*)))

(defun file-tree-select-next ()
  "Move the file-tree selection to the next visible entry."
  (file-tree-move-selection (editor-state-file-tree *editor-state*) :down))

(defun file-tree-select-previous ()
  "Move the file-tree selection to the previous visible entry."
  (file-tree-move-selection (editor-state-file-tree *editor-state*) :up))

(defun file-tree-open-selected ()
  "Open the selected entry as a buffer, or toggle it if it is a directory."
  (let* ((tree (editor-state-file-tree *editor-state*))
         (path (file-tree-selected-path tree)))
    (when path
      ;; domain/file-tree.lisp exposes no public "what kind of entry is
      ;; this" query (only the internal %FILE-TREE-FIND-KIND helper does,
      ;; and reaching into a %-prefixed domain helper from the application
      ;; layer would cross the same layering line FILE-TREE-TOGGLE-EXPAND
      ;; itself is written to respect). FILE-TREE-TOGGLE-EXPAND's own
      ;; documented contract signals an error for a non-directory PATH, so
      ;; that error is used here as the directory/file discriminator.
      (handler-case (file-tree-toggle-expand tree path)
        (error ()
          (window-set-buffer (%selected-window) (buffer-load path)))))))

(defun file-tree-create-file-command ()
  "Prompt for a path and create a new empty file there."
  (let ((tree (editor-state-file-tree *editor-state*)))
    (minibuffer-activate
     (editor-state-minibuffer *editor-state*)
     "Create file: "
     :on-confirm (lambda (path) (file-tree-create-file tree path)))))

(defun file-tree-create-directory-command ()
  "Prompt for a path and create a new empty directory there."
  (let ((tree (editor-state-file-tree *editor-state*)))
    (minibuffer-activate
     (editor-state-minibuffer *editor-state*)
     "Create directory: "
     :on-confirm (lambda (path) (file-tree-create-directory tree path)))))

(defun file-tree-rename-command ()
  "Prompt for a new path and rename the selected entry to it."
  (let* ((tree (editor-state-file-tree *editor-state*))
         (old-path (file-tree-selected-path tree)))
    (when old-path
      (minibuffer-activate
       (editor-state-minibuffer *editor-state*)
       (format nil "Rename ~A to: " old-path)
       :on-confirm (lambda (new-path) (file-tree-rename tree old-path new-path))))))

;; No confirmation prompt: unlike create/rename, delete needs no typed input,
;; only a yes/no confirmation, and the minibuffer protocol as it stands
;; (application/minibuffer.lisp) only offers a free-text ON-CONFIRM/ON-CANCEL
;; prompt, not a dedicated y-or-n-p; a free-text "type anything to confirm"
;; prompt would not actually reduce accidental deletes over just deleting
;; directly, so this deletes the selection immediately.
(defun file-tree-delete-command ()
  "Delete the selected file-tree entry from disk."
  (let* ((tree (editor-state-file-tree *editor-state*))
         (path (file-tree-selected-path tree)))
    (when path
      (file-tree-delete tree path))))

;;; ---------------------------------------------------------------------
;;; Misc
;;; ---------------------------------------------------------------------

;; KEYBOARD-QUIT's own cancel path is narrower than it looks: a literal C-g
;; typed while the minibuffer has focus is already handled entirely inside
;; MINIBUFFER-HANDLE-KEY (see its contract in application/minibuffer.lisp --
;; it calls ON-CANCEL and deactivates the minibuffer itself for a C-g
;; KEY-EVENT), so that path never reaches this top-level command at all.
;; MINIBUFFER-HANDLE-KEY's KEY-EVENT is documented as an opaque CL-TTY-KIT
;; object this layer has no business fabricating, and no other public
;; minibuffer operation cancels a prompt programmatically, so this command's
;; only well-defined job is the global-keymap fallback: report "Quit", same
;; as Emacs's top-level C-g when there is nothing else to cancel.
(defun keyboard-quit ()
  "Report a Quit message (C-g)."
  (minibuffer-message (editor-state-minibuffer *editor-state*) "Quit"))

;; LOOM-QUIT carries no data: it exists only so src/main.lisp's event loop
;; can HANDLER-CASE on a type it, not a plain return value, to tell a real
;; quit apart from every other command's return value. SIGNAL rather than
;; ERROR is deliberate -- an unhandled LOOM-QUIT (e.g. this command called
;; outside the real event loop, such as from a test) is a harmless no-op
;; instead of an unwanted error.
(define-condition loom-quit () ()
  (:documentation
   "Signaled by SAVE-BUFFERS-KILL-TERMINAL to ask the main event loop in
src/main.lisp to exit cleanly."))

(defun save-buffers-kill-terminal ()
  "Exit loom (C-x C-c). There is no buffer-list registry yet (see SWITCH-TO-
BUFFER's comment above) to check for unsaved buffers against, so this does
not prompt to save first -- it unconditionally asks the event loop to quit."
  (signal 'loom-quit))

;;; ---------------------------------------------------------------------
;;; Default keybindings
;;; ---------------------------------------------------------------------

(defun install-default-keybindings (keymap)
  "Bind the default Emacs-style key sequences to their commands in KEYMAP."
  (flet ((ctrl (char) (cons '(:control) char))
         (plain (char) (cons nil char)))
    (keymap-define-key keymap (list (ctrl #\f)) 'forward-char)
    (keymap-define-key keymap (list (ctrl #\b)) 'backward-char)
    (keymap-define-key keymap (list (ctrl #\n)) 'next-line)
    (keymap-define-key keymap (list (ctrl #\p)) 'previous-line)
    (keymap-define-key keymap (list (ctrl #\a)) 'move-beginning-of-line)
    (keymap-define-key keymap (list (ctrl #\e)) 'move-end-of-line)
    (keymap-define-key keymap (list (ctrl #\d)) 'delete-char)
    ;; DEL and Backspace decode to the same terminal byte in practice, so a
    ;; single :BACKSPACE special-key binding covers both.
    (keymap-define-key keymap (list (plain :backspace)) 'delete-backward-char)
    (keymap-define-key keymap (list (ctrl #\k)) 'kill-line)
    (keymap-define-key keymap (list (ctrl #\w)) 'kill-region)
    (keymap-define-key keymap (list (ctrl #\y)) 'yank)
    (keymap-define-key keymap (list (ctrl #\Space)) 'set-mark-command)
    ;; Undo: bound to C-x u rather than C-/ or C-_, which depend on a
    ;; terminal's control-character encoding of shifted punctuation that
    ;; this codebase has no other reason to rely on.
    (keymap-define-key keymap (list (ctrl #\x) (plain #\u)) 'undo-command)
    (keymap-define-key keymap (list (ctrl #\x) (ctrl #\f)) 'find-file)
    (keymap-define-key keymap (list (ctrl #\x) (ctrl #\s)) 'save-buffer)
    (keymap-define-key keymap (list (ctrl #\x) (plain #\2)) 'split-window-below)
    (keymap-define-key keymap (list (ctrl #\x) (plain #\3)) 'split-window-right)
    (keymap-define-key keymap (list (ctrl #\x) (plain #\o)) 'other-window)
    (keymap-define-key keymap (list (ctrl #\x) (plain #\b)) 'switch-to-buffer)
    ;; File-tree toggle: C-x C-t, an otherwise-unused C-x sequence, chosen to
    ;; mirror the existing C-x C-f / C-x C-s prefix-key pattern.
    (keymap-define-key keymap (list (ctrl #\x) (ctrl #\t)) 'toggle-file-tree)
    ;; File-tree navigation/CRUD: these commands were fully implemented but
    ;; had no default keyboard path to reach them once the sidebar is open.
    ;; Nesting them under C-x C-t (the toggle) would be awkward -- that
    ;; sequence is already a complete, non-prefix binding -- so C-c, otherwise
    ;; entirely unused in this keymap, is claimed as a second prefix
    ;; (mirroring Emacs's convention of reserving C-c for such
    ;; not-quite-global command groups) with mnemonic single-letter suffixes.
    (keymap-define-key keymap (list (ctrl #\c) (plain #\n)) 'file-tree-select-next)
    (keymap-define-key keymap (list (ctrl #\c) (plain #\p)) 'file-tree-select-previous)
    (keymap-define-key keymap (list (ctrl #\c) (plain #\o)) 'file-tree-open-selected)
    (keymap-define-key keymap (list (ctrl #\c) (plain #\c)) 'file-tree-create-file-command)
    (keymap-define-key keymap (list (ctrl #\c) (plain #\d)) 'file-tree-create-directory-command)
    (keymap-define-key keymap (list (ctrl #\c) (plain #\r)) 'file-tree-rename-command)
    ;; "k" for delete, echoing Dired's kill-line-style delete-entry binding
    ;; rather than "d", which is already taken by create-directory above.
    (keymap-define-key keymap (list (ctrl #\c) (plain #\k)) 'file-tree-delete-command)
    (keymap-define-key keymap (list (ctrl #\g)) 'keyboard-quit)
    ;; Quit: C-x C-c, the conventional Emacs binding.
    (keymap-define-key keymap (list (ctrl #\x) (ctrl #\c)) 'save-buffers-kill-terminal))
  keymap)
