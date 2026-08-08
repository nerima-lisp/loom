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
;;;; application/commands-misc.lisp's SAVE-BUFFERS-KILL-TERMINAL/LOOM-QUIT) or
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

(defun %drain-buffered-octets (buffer start-count)
  "Read the octets already waiting on *STANDARD-INPUT* into BUFFER, filling it
from index START-COUNT onwards and stopping at (LENGTH BUFFER) octets or as
soon as LISTEN reports nothing more is buffered -- so this never blocks.
Returns the resulting octet count."
  (loop with count = start-count
        while (and (< count (length buffer)) (listen *standard-input*))
        do (let ((byte (read-byte *standard-input* nil nil)))
             (unless byte (loop-finish))
             (setf (aref buffer count) byte)
             (incf count))
        finally (return count)))

(defun %read-input-octets (buffer)
  "Block until at least one octet is available on *STANDARD-INPUT*, then
drain any additional octets already buffered (checked via LISTEN, so this
never blocks a second time) into BUFFER, up to (LENGTH BUFFER) octets total.
Returns the number of octets actually placed in BUFFER, or NIL at
end-of-file (no octet was read at all)."
  (let ((first (read-byte *standard-input* nil nil)))
    (when first
      (setf (aref buffer 0) first)
      (%drain-buffered-octets buffer 1))))

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
\(application/commands-misc.lisp\) is signalled via CL:SIGNAL, not CL:ERROR, and
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
(defun %dispatch-input-chunk (decoder buffer count keymap-state)
  "Decode the first COUNT octets of BUFFER through DECODER and route every key
event they yield to %DISPATCH-KEY-EVENT with KEYMAP-STATE. A completely full
BUFFER is handed to CL-TTY-KIT:DECODE-INPUT-CHUNK as-is, so the common case of
a full read does not copy."
  (let ((chunk (if (= count (length buffer)) buffer (subseq buffer 0 count))))
    (dolist (event (cl-tty-kit:decode-input-chunk decoder chunk))
      (%dispatch-key-event event keymap-state))))

;;; ---------------------------------------------------------------------
;;; Event loop
;;; ---------------------------------------------------------------------

(defun %initial-terminal-size ()
  "Return (VALUES WIDTH HEIGHT) for the controlling terminal via
CL-TTY-KIT:TERMINAL-SIZE, falling back to 80x24 when the size is unavailable
(e.g. *STANDARD-INPUT* is not a real terminal)."
  (multiple-value-bind (columns rows) (cl-tty-kit:terminal-size)
    (values (or columns 80) (or rows 24))))

(defun %poll-terminal-resize (renderer last-width last-height)
  "Check CL-TTY-KIT:TERMINAL-SIZE against LAST-WIDTH/LAST-HEIGHT and, on a
change, resize RENDERER via LOOM-RENDERER-RESIZE. Returns the (VALUES WIDTH
HEIGHT) to track as the last-seen size from now on -- LAST-WIDTH/LAST-HEIGHT
unchanged when the terminal size could not be read or has not changed."
  (multiple-value-bind (width height) (cl-tty-kit:terminal-size)
    (if (and width height (or (/= width last-width) (/= height last-height)))
        (progn
          (loom-renderer-resize renderer width height)
          (values width height))
        (values last-width last-height))))

(defun %file-tree-prefetch-paths (tree)
  "Return TREE's root and currently expanded directories for prefetching."
  (cons (file-tree-root-path tree)
        (loop for path being the hash-keys of (file-tree-expanded tree)
              collect path)))

(defun %run-event-loop (stream)
  "Run the main input and render loop, writing frames to STREAM.\n\nThe initial frame is rendered before waiting for input. Each subsequent\niteration reads raw octets, dispatches decoded key events, reacts to terminal\nresizes, then redraws the frame."
  (let ((decoder (cl-tty-kit:make-input-decoder))
        (buf (make-array 4096 :element-type '(unsigned-byte 8)))
        (keymap-state (make-keymap-state (editor-state-keymap *editor-state*))))
    (multiple-value-bind (last-width last-height) (%initial-terminal-size)
      (labels ((render-frame ()
                 (let ((runtime (editor-state-concurrent-runtime *editor-state*)))
                   (when runtime
                     (loom-concurrent-runtime-drain runtime)
                     (loom-concurrent-runtime-prefetch
                      runtime
                      (%file-tree-prefetch-paths
                       (editor-state-file-tree *editor-state*)))))
                 (compose-frame *editor-state*)
                 (loom-renderer-present (editor-state-renderer *editor-state*)
                                        :stream stream
                                        :cursor (editor-cursor *editor-state*)))
               (read-and-dispatch ()
                 ;; NIL once *STANDARD-INPUT* hits EOF, which is what ends the
                 ;; LOOP below; LOOM-QUIT ends it by unwinding instead.
                 (let ((count (%read-input-octets buf)))
                   (when count
                     (%dispatch-input-chunk decoder buf count keymap-state)
                     t))))
        (render-frame)
        (handler-case
            (loop while (read-and-dispatch)
                  do (multiple-value-setq (last-width last-height)
                       (%poll-terminal-resize (editor-state-renderer *editor-state*)
                                              last-width last-height))
                     (render-frame))
          (loom-quit () nil))))))

;;; ---------------------------------------------------------------------
;;; Entry point
;;; ---------------------------------------------------------------------

(defun %startup-file-and-root (argument)
  "Return the existing startup file, if ARGUMENT names one, and the file-tree root.\n\nAn existing regular file opens in the selected window while its containing\ndirectory becomes the file-tree root. A directory (or no argument) retains\nthe scratch buffer and is itself the root."
  (let* ((root (or argument "."))
         (resolved (probe-file root)))
    (cond
      ((and argument (null resolved))
       (error 'cl-cli:cli-invalid-positional-value
              :message (format nil "PATH does not exist: ~A" argument)
              :name "PATH"
              :value argument
              :cause nil))
      ((and resolved (not (host-kit:directory-pathname-p resolved)))
       (values resolved (make-pathname :name nil :type nil :defaults resolved)))
      (t
       (values nil root)))))

(defun %initialize-editor-state (path-argument)
  "Build a fresh *EDITOR-STATE* around the startup buffer and supporting
objects. PATH-ARGUMENT is the file or directory CL-CLI:POSITIONAL-VALUE
parsed from argv, or NIL when none was given."
  (multiple-value-bind (width height) (%initial-terminal-size)
    (multiple-value-bind (startup-file file-tree-root)
        (%startup-file-and-root path-argument)
      (let* ((initial-buffer (if startup-file
                                 (buffer-load startup-file)
                                 (make-buffer :name "*scratch*")))
             (window-tree (make-window-tree initial-buffer width (max 1 (1- height))))
             (keymap (install-default-keybindings (make-keymap)))
             (minibuffer (make-minibuffer :history (history-kit:make-history)))
             (file-tree (make-file-tree file-tree-root))
             (renderer (make-loom-renderer width height)))
        (setf (file-tree-child-lister file-tree) (function loom-fs-list-directory))
        (setf *editor-state*
              (make-editor-state :window-tree window-tree
                                 :minibuffer minibuffer
                                 :keymap keymap
                                 :file-tree file-tree
                                 :renderer renderer
                                 :buffers (list initial-buffer)
                                 :kill-ring nil))))))

(defun %enable-concurrent-file-tree (state)
  "Replace STATE's synchronous file-tree lister with a cached runtime."
  (let* ((tree (editor-state-file-tree state))
         (lister (file-tree-child-lister tree))
         (root (file-tree-root-path tree))
         (initial-entries (funcall lister root))
         (runtime (make-loom-concurrent-runtime
                   :directory-lister lister)))
    (loom-concurrent-runtime-prime-directory runtime root initial-entries)
    (setf (file-tree-child-lister tree)
          (lambda (path)
            (multiple-value-bind (entries present-p)
                (loom-concurrent-runtime-directory-entries runtime path)
              (if present-p entries nil))))
    (setf (editor-state-concurrent-runtime state) runtime)
    runtime))

(defun %loom-version ()
  "Return LOOM's version string from its own ASDF system definition -- the
single source of truth loom.asd's header comment and flake.nix's ASDVERSIONOF
both already rely on -- so CL-CLI's generated --version output cannot drift
from it."
  (let ((system (asdf:find-system "loom" nil)))
    (or (and system (asdf:component-version system)) "unknown")))

(defun %run-loom (invocation &key (fd 0))
  "CL-CLI handler for *LOOM-APP*: initialize *EDITOR-STATE* around the :PATH
positional, then run the terminal session event loop (see %RUN-EVENT-LOOP)
until the user quits or stdin hits EOF. FD names the controlling terminal's
file descriptor (0, i.e. stdin, in production; overridable so a test can
pass a real CL-TTY-KIT:MAKE-PTY descriptor instead).

CL-TTY-KIT:WITH-TERMINAL-SESSION already wraps its body in an UNWIND-PROTECT
(nested inside WITH-RAW-MODE's own UNWIND-PROTECT) that restores raw mode and
exits the alternate screen on any non-local exit, so an unhandled error
inside the loop still leaves the terminal in a clean state before this
function's own HANDLER-CASE gets a chance to report it -- the terminal is
never left in raw/alternate-screen mode, whether the error is caught here or
not."
  (%initialize-editor-state (cl-cli:positional-value invocation :path))
  (%enable-concurrent-file-tree *editor-state*)
  (unwind-protect
       (handler-case
           (progn
             (cl-tty-kit:with-terminal-session (stream :fd fd
                                                :raw-mode t
                                                :alternate-screen t
                                                :hide-cursor nil)
               (%run-event-loop stream))
             0)
         (error (condition)
           (format *error-output* "~&loom: ~A~%" condition)
           1))
    (let ((runtime (editor-state-concurrent-runtime *editor-state*)))
      (when runtime
        (loom-concurrent-runtime-shutdown runtime)))))

(defparameter *loom-app*
  (cl-cli:make-app
   :name "loom"
   :version (%loom-version)
   :summary "Terminal text editor with Emacs-like keybindings"
   :positionals (list (cl-cli:make-positional
                       :key :path
                       :required-p nil
                       :description "A file to open, or a directory to browse (defaults to \".\")"))
   :handler (function %run-loom))
  "CL-CLI application spec for the loom binary: a single positional path
argument and no subcommands (the \"root positional\" shape CL-CLI's own
getting-started guide documents for script-style tools), which gets
--help/--version/-h/-V for free instead of main.lisp hand-parsing argv.")

(defun main ()
  "Entry point for the loom binary: dispatches SB-EXT:*POSIX-ARGV* through
*LOOM-APP* (see %RUN-LOOM) and exits with the resulting CL-CLI exit code."
  (sb-ext:exit :code (cl-cli:run-app *loom-app* :argv sb-ext:*posix-argv*)))
