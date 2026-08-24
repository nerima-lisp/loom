;;;; packages/feature/lsp/src/application-lsp-session-state.lisp
;;;;
;;;; Application-layer session state and URI/language helpers for one
;;;; language-server session. JSON values and process I/O stay behind the
;;;; infrastructure protocols; this file owns the persistent state visible to
;;;; commands and the main event loop.
(in-package #:loom/feature/lsp)

(defparameter *lsp-shutdown-timeout-seconds* 0.25
  "Maximum time LSP shutdown waits for a response before sending EXIT.")

(defstruct (lsp-session
            (:constructor %make-lsp-session))
  "The application state for one running Language Server Protocol session."
  transport
  command
  root-uri
  (next-id 0 :type integer)
  pending-initialize-id
  (initialized-p nil)
  server-capabilities
  server-info
  (documents (make-hash-table :test #'equal))
  (diagnostic-table (make-hash-table :test #'equal))
  ;; Response handlers for requests the user drove, keyed by JSON-RPC id.
  ;; Initialize and shutdown keep their own dedicated slots because their
  ;; responses change the session's lifecycle rather than returning a value.
  (pending-requests (make-hash-table :test #'eql))
  pending-shutdown-id
  (exit-sent-p nil)
  last-error
  (closed-p nil))

(defun %lsp-uri-path-character-p (character)
  (or (char= character #\/)
      (or (and (char>= character #\0)
               (char<= character #\9))
          (and (char>= character #\A)
               (char<= character #\Z))
          (and (char>= character #\a)
               (char<= character #\z)))
      (find character "-._~:@!$&'()*+,;=" :test #'char=)))

(defun %lsp-uri-escape-path (path)
  (with-output-to-string (output)
    (loop for character across path
          do (if (%lsp-uri-path-character-p character)
                 (write-char character output)
                 (loop for octet across (%lsp-utf8-encode (string character))
                       do (format output "%~2,'0X" octet))))))

(defun lsp-path-uri (path)
  "Return the file URI used for PATH by Loom's minimal LSP client.

PATH is normally an absolute pathname supplied by a file-backed buffer. The
path component is percent-encoded as UTF-8 while URI path separators and
unreserved characters remain readable."
  (format nil "file://~A"
          (%lsp-uri-escape-path (namestring (pathname path)))))

(defun %lsp-uri-hex-digit (character)
  (digit-char-p character 16))

(defun lsp-uri-path (uri)
  "Return the filesystem path a `file://' URI names, or NIL for anything else.

The inverse of LSP-PATH-URI: percent escapes are decoded back to their bytes
and the bytes read as UTF-8, so a server that echoes back the URI loom sent it
yields the path loom started from."
  (when (and (stringp uri) (uiop:string-prefix-p "file://" uri))
    (let ((octets (make-array 0 :element-type '(unsigned-byte 8)
                                :adjustable t :fill-pointer 0))
          (index 7)
          (length (length uri)))
      (loop while (< index length)
            do (let ((character (char uri index)))
                 (if (and (char= character #\%)
                          (< (+ index 2) length)
                          (%lsp-uri-hex-digit (char uri (+ index 1)))
                          (%lsp-uri-hex-digit (char uri (+ index 2))))
                     (progn
                       (vector-push-extend
                        (parse-integer uri :start (1+ index) :end (+ index 3)
                                           :radix 16)
                        octets)
                       (incf index 3))
                     (progn
                       (vector-push-extend (char-code character) octets)
                       (incf index)))))
      (%lsp-utf8-decode
       (coerce octets '(simple-array (unsigned-byte 8) (*)))))))

(defun %lsp-language-id (path)
  (let ((type (string-downcase (or (pathname-type (pathname path)) ""))))
    (if (member type '("lisp" "cl" "asd") :test #'string=)
        "common-lisp"
        (if (plusp (length type)) type "plaintext"))))

(defun make-lsp-session (&key transport command directory root-uri)
  "Create an LSP session over TRANSPORT or a child process COMMAND.

Supplying TRANSPORT is the seam used by tests and future non-process
frontends. COMMAND is intentionally a shell command, so launching it has
the same trust boundary as user initialization and Lisp evaluation."
  (let ((actual-transport
          (or transport
              (progn
                (unless command
                  (error "MAKE-LSP-SESSION needs TRANSPORT or COMMAND"))
                (make-lsp-process command :directory directory)))))
    (%make-lsp-session :transport actual-transport
                       :command command
                       :root-uri root-uri)))
