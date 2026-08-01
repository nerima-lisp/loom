;;;; src/main.lisp
;;;;
;;;; The :TOPLEVEL entry point saved into the loom executable by
;;;; SB-EXT:SAVE-LISP-AND-DIE (see flake.nix). Wires the real domain/
;;;; infrastructure/application objects into *EDITOR-STATE*, then runs a
;;;; CL-TTY-KIT:WITH-TERMINAL-SESSION event loop: read raw bytes from stdin,
;;;; decode them into key events, route each event to the minibuffer, plain
;;;; character self-insertion, or the global keymap, poll for terminal
;;;; resizes, and redraw via presentation/layout.lisp's COMPOSE-FRAME plus
;;;; LOOM-RENDERER-PRESENT -- until the user quits (C-x C-c, see
;;;; application/commands.lisp's SAVE-BUFFERS-KILL-TERMINAL/LOOM-QUIT) or
;;;; standard input reaches EOF.
(in-package #:loom)

;;; ---------------------------------------------------------------------
;;; Raw input reading
;;;
;;; CL-TTY-KIT:DECODE-INPUT-CHUNK accepts either a string or an octet vector
;;; (see infrastructure/terminal-renderer.lisp's sibling library,
;;; input-decode.lisp, for that contract), so this reads octets directly off
;;; *STANDARD-INPUT* via READ-BYTE rather than going through a character
;;; decode first -- SBCL's stdin fd-stream is bivalent (READ-BYTE and
;;; READ-CHAR both work on it), and reading octets sidesteps ever needing to
;;; worry about *STANDARD-INPUT*'s external-format matching what the terminal
;;; actually sent.
;;; ---------------------------------------------------------------------

(defun %read-input-octets (buffer)
  "Block until at least one octet is available on *STANDARD-INPUT*, then
drain any additional octets already buffered (checked via LISTEN, so this
never blocks a second time) into BUFFER, up to (LENGTH BUFFER) octets total.
Returns the number of octets actually placed in BUFFER, or NIL at
end-of-file (no octet was read at all)."
  (let ((first (read-byte *standard-input* nil nil)))
    (when first
      (setf (aref buffer 0) first)
      (let ((count 1))
        (loop while (and (< count (length buffer)) (listen *standard-input*))
              do (let ((byte (read-byte *standard-input* nil nil)))
                   (if byte
                       (progn (setf (aref buffer count) byte) (incf count))
                       (loop-finish))))
        count))))

;;; ---------------------------------------------------------------------
;;; Key-event routing
;;; ---------------------------------------------------------------------

(defun %key-event->descriptor (event)
  "Convert a CL-TTY-KIT:KEY-EVENT into the (MODIFIERS . CODE) descriptor
shape domain/keymap.lisp's protocol expects -- see that file's header
comment: it has no CL-TTY-KIT dependency and documents that infrastructure
code decoding real key-event objects is responsible for this conversion
before calling KEYMAP-STATE-DISPATCH.

Two different terminal encodings of the same physical Ctrl+letter combo are
unified into one shape here, the same problem application/minibuffer.lisp's
%CONTROL-G-KEY-P already had to solve for C-g specifically: a plain-terminal
C0 byte decodes as a :SPECIAL event whose CODE is a :CONTROL-<letter> keyword
with no separate modifier, while the kitty CSI-u protocol decodes the same
combo as a :CHARACTER event carrying the letter itself plus an explicit
:CONTROL modifier. INSTALL-DEFAULT-KEYBINDINGS only ever binds the latter
(character + :CONTROL) shape (its CTRL helper), so a :SPECIAL
:CONTROL-<letter> event is rewritten into it here; every other event (plain
characters, arrows, Enter, Backspace, ...) passes through with its own
TYPE/CODE/MODIFIERS verbatim, wrapped as (MODIFIERS . CODE)."
  (let ((type (cl-tty-kit:key-event-type event))
        (code (cl-tty-kit:key-event-code event))
        (modifiers (cl-tty-kit:key-event-modifiers event)))
    (if (and (eq type :special)
             (keywordp code)
             (let ((name (symbol-name code)))
               (and (= (length name) 9) (string= "CONTROL-" name :end2 8))))
        (cons '(:control) (char-downcase (char (symbol-name code) 8)))
        (cons modifiers code))))

(defun %record-undo-boundary-for-command (self-insert-p)
  "Call BUFFER-RECORD-UNDO-BOUNDARY on the selected window's buffer when the
command about to run (SELF-INSERT-P: true for SELF-INSERT-COMMAND, false for
anything dispatched via the keymap) differs in kind from the previously
dispatched command, per *EDITOR-STATE*'s LAST-COMMAND-SELF-INSERT-P \(see
application/editor-state.lisp\). This is what makes consecutive
SELF-INSERT-COMMAND invocations -- ordinary typing -- group into one undo
step while switching to any other command starts a new undo group; without
this call site, BUFFER-RECORD-UNDO-BOUNDARY (domain/buffer.lisp) is never
invoked outside of its own unit test, so a single UNDO-COMMAND call would
walk BUFFER-UNDO-LIST all the way back to its start in one shot instead of
stopping at a group boundary. Updates LAST-COMMAND-SELF-INSERT-P for the next
call. Not applied on the minibuffer-input path: the minibuffer has its own
input buffer, not a BUFFER-* undo history, and MINIBUFFER-HANDLE-KEY never
touches the selected window's buffer."
  (unless (eq self-insert-p (editor-state-last-command-self-insert-p *editor-state*))
    (buffer-record-undo-boundary (%selected-buffer)))
  (setf (editor-state-last-command-self-insert-p *editor-state*) self-insert-p))

(defun %dispatch-key-event (event keymap-state)
  "Route one decoded KEY-EVENT: to MINIBUFFER-HANDLE-KEY while the minibuffer
is soliciting input; to SELF-INSERT-COMMAND for a plain, unmodified printable
:CHARACTER event when KEYMAP-STATE has no prefix key already accumulated
\(KEYMAP-STATE-SEQUENCE null); otherwise to KEYMAP-STATE-DISPATCH via
%KEY-EVENT->DESCRIPTOR. Also records undo-group boundaries on the
buffer-editing paths (see %RECORD-UNDO-BOUNDARY-FOR-COMMAND).

The invoked command (or, on the minibuffer path, its ON-CONFIRM callback via
MINIBUFFER-HANDLE-KEY) runs inside a HANDLER-CASE on ERROR: an ordinary,
expected error -- FIND-FILE on a nonexistent path, SAVE-BUFFER to an
unwritable path, a file-tree create/rename against an existing/missing path,
and so on -- is reported in the minibuffer instead of propagating out of the
event loop to MAIN's own top-level HANDLER-CASE, which would otherwise exit
the whole process and discard every unsaved buffer. LOOM-QUIT
\(application/commands.lisp\) is signalled via CL:SIGNAL, not CL:ERROR, and
does not inherit from CL:ERROR, so it passes straight through this
HANDLER-CASE untouched and still reaches %RUN-EVENT-LOOP's own
\(LOOM-QUIT () ...\) clause for a clean exit."
  (let ((minibuffer (editor-state-minibuffer *editor-state*)))
    (handler-case
        (cond
          ((minibuffer-active-p minibuffer)
           (minibuffer-handle-key minibuffer event))
          ((and (eq (cl-tty-kit:key-event-type event) :character)
                (not (intersection '(:control :alt) (cl-tty-kit:key-event-modifiers event)))
                (null (keymap-state-sequence keymap-state)))
           (%record-undo-boundary-for-command t)
           (self-insert-command (cl-tty-kit:key-event-code event)))
          (t
           (%record-undo-boundary-for-command nil)
           (keymap-state-dispatch keymap-state (%key-event->descriptor event))))
      (error (condition)
        (minibuffer-message minibuffer (format nil "~A" condition))))))

;;; ---------------------------------------------------------------------
;;; Event loop
;;; ---------------------------------------------------------------------

(defun %initial-terminal-size ()
  "Return (VALUES WIDTH HEIGHT) for the controlling terminal via
CL-TTY-KIT:TERMINAL-SIZE, falling back to 80x24 when the size is unavailable
(e.g. *STANDARD-INPUT* is not a real terminal)."
  (multiple-value-bind (columns rows) (cl-tty-kit:terminal-size)
    (values (or columns 80) (or rows 24))))

(defun %run-event-loop (stream)
  "Run loom's main input/render loop, writing frames to STREAM. Returns
normally -- so the caller's CL-TTY-KIT:WITH-TERMINAL-SESSION can unwind and
restore the terminal -- once the user quits via SAVE-BUFFERS-KILL-TERMINAL
(C-x C-c, which signals LOOM-QUIT) or *STANDARD-INPUT* reaches end-of-file.

Each iteration: read a chunk of raw octets (blocking for at least one),
decode it into key events and dispatch each one, then poll
CL-TTY-KIT:TERMINAL-SIZE and, on a change, resize the renderer via
LOOM-RENDERER-RESIZE (the window tree's own resize is COMPOSE-FRAME's job --
see its docstring -- since it alone knows the file-tree sidebar's current
width and must recompute the layout every frame regardless of why it
changed), then COMPOSE-FRAME and LOOM-RENDERER-PRESENT to draw."
  (let ((decoder (cl-tty-kit:make-input-decoder))
        (buf (make-array 4096 :element-type '(unsigned-byte 8)))
        (keymap-state (make-keymap-state (editor-state-keymap *editor-state*))))
    (multiple-value-bind (last-width last-height) (cl-tty-kit:terminal-size)
      (setf last-width (or last-width 80)
            last-height (or last-height 24))
      (handler-case
          (loop
            (let ((count (%read-input-octets buf)))
              (unless count
                (return-from %run-event-loop))
              (let* ((chunk (if (= count (length buf)) buf (subseq buf 0 count)))
                     (events (cl-tty-kit:decode-input-chunk decoder chunk)))
                (dolist (event events)
                  (%dispatch-key-event event keymap-state))))
            (multiple-value-bind (width height) (cl-tty-kit:terminal-size)
              (when (and width height
                         (or (/= width last-width) (/= height last-height)))
                (setf last-width width
                      last-height height)
                (loom-renderer-resize (editor-state-renderer *editor-state*) width height)))
            (compose-frame *editor-state*)
            (loom-renderer-present (editor-state-renderer *editor-state*) :stream stream))
        (loom-quit () nil)))))

;;; ---------------------------------------------------------------------
;;; Entry point
;;; ---------------------------------------------------------------------

(defun %initialize-editor-state ()
  "Build a fresh *EDITOR-STATE* around a *scratch* buffer and the real
domain/infrastructure/application objects that back it: a window tree sized
to the current terminal, the default keybindings, a minibuffer backed by a
real CL-HISTORY-KIT history, a file tree rooted at the second POSIX argument
(defaulting to the current directory) with its CHILD-LISTER seam wired to the
real disk-backed LOOM-FS-LIST-DIRECTORY (see infrastructure/filesystem.lisp's
header comment for why that seam exists), and a renderer sized to match."
  (multiple-value-bind (width height) (%initial-terminal-size)
    (let* ((scratch (make-buffer :name "*scratch*"))
           (window-tree (make-window-tree scratch width (max 1 (1- height))))
           (keymap (install-default-keybindings (make-keymap)))
           (minibuffer (make-minibuffer :history (history-kit:make-history)))
           (file-tree (make-file-tree (or (second sb-ext:*posix-argv*) ".")))
           (renderer (make-loom-renderer width height)))
      (setf (file-tree-child-lister file-tree) #'loom-fs-list-directory)
      (setf *editor-state*
            (make-editor-state :window-tree window-tree
                                :minibuffer minibuffer
                                :keymap keymap
                                :file-tree file-tree
                                :renderer renderer
                                :kill-ring nil)))))

(defun main ()
  "Entry point for the loom binary. Initializes *EDITOR-STATE* (see
%INITIALIZE-EDITOR-STATE) then runs the terminal session and event loop (see
%RUN-EVENT-LOOP) until the user quits or stdin hits EOF.

CL-TTY-KIT:WITH-TERMINAL-SESSION already wraps its body in an UNWIND-PROTECT
(nested inside WITH-RAW-MODE's own UNWIND-PROTECT) that restores raw mode and
exits the alternate screen on any non-local exit, so an unhandled error
inside the loop still leaves the terminal in a clean state before this
function's own HANDLER-CASE gets a chance to report it -- the terminal is
never left in raw/alternate-screen mode, whether the error is caught here or
not."
  (%initialize-editor-state)
  (handler-case
      (cl-tty-kit:with-terminal-session (stream :raw-mode t
                                         :alternate-screen t
                                         :hide-cursor nil)
        (%run-event-loop stream))
    (error (condition)
      (format *error-output* "~&loom: ~A~%" condition)))
  (sb-ext:exit :code 0))
