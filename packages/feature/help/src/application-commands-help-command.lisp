(in-package #:loom)

(progn
  (defun %help-selected-buffer ()
    (loom/core/window-tree:window-buffer
     (loom/core/window-tree:window-tree-selected-window
      (loom/core/editor-session:editor-state-window-tree
       loom/core/editor-session:*editor-state*))))

  (defun %show-help (text)
    (let* ((state loom/core/editor-session:*editor-state*)
           (session (loom/core/editor-session:editor-state-session state))
           (buffer
             (loom/feature/buffers:ensure-result-buffer session "*Help*"))
           (window
             (loom/core/window-tree:window-tree-selected-window
              (loom/core/editor-session:editor-state-window-tree state))))
      (loom/core/buffer:buffer-widen buffer)
      (let ((old-text (loom/core/buffer:buffer-text buffer)))
        (unless (zerop (length old-text))
          (let ((end (loom/core/buffer:buffer-offset-position
                      buffer (length old-text))))
            (loom/core/buffer:buffer-delete-region
             buffer 0 0
             (loom/core/buffer:buffer-position-line end)
             (loom/core/buffer:buffer-position-column end)))))
      (unless (zerop (length text))
        (loom/core/buffer:buffer-insert-string buffer text))
      (loom/core/buffer:buffer-set-point buffer 0 0)
      (loom/core/window-tree:window-set-buffer window buffer)
      (progn
        (loom/core/buffer:buffer-mark-saved buffer)
        buffer)))

  (defun %help-catalog ()
    (json-kit:parse
     (loom/core/command:command-catalog-json)
     :array-type :list
     :object-type :hash-table))

  (defun %help-catalog-entry (id)
    (find id (%help-catalog)
          :key (lambda (entry) (gethash "id" entry))
          :test #'string=))

  (progn
  (defun %help-format-json-key (descriptor)
    (format nil "~{~A~}~A"
            (mapcar (lambda (modifier)
                      (cond
                        ((string-equal modifier "control") "C-")
                        ((string-equal modifier "alt") "M-")
                        (t (format nil "~A-" (string-upcase modifier)))))
                    (gethash "modifiers" descriptor))
            (let ((key (gethash "key" descriptor)))
              (cond
                ((member key '("enter" "return") :test #'string-equal)
                 "RET")
                ((string-equal key "tab") "TAB")
                ((member key '("backspace" "delete") :test #'string-equal)
                 "DEL")
                ((= (length key) 1) key)
                (t (string-upcase key))))))

  (defun %help-format-json-sequence (sequence)
    (format nil "~{~A~^ ~}"
            (mapcar #'%help-format-json-key sequence)))

  (defun %help-entry-bindings (entry)
    (format nil "~{~A~^, ~}"
            (mapcar
             (lambda (binding)
               (format nil "~A (~A)"
                       (%help-format-json-sequence
                        (gethash "sequence" binding))
                       (string-upcase (gethash "keymap" binding))))
             (gethash "keys" entry))))

  (defun %help-entry-text (entry)
    (format nil "~A (~A)~%Group: ~A~%Keys: ~A"
            (gethash "name" entry)
            (gethash "id" entry)
            (gethash "group" entry)
            (%help-entry-bindings entry))))

  (defun %help-key-tokens (input)
    (loop with start = 0
          for end = (or (position #\Space input :start start) (length input))
          for token = (subseq input start end)
          unless (string= token "")
            collect token
          while (< end (length input))
            do (setf start (1+ end))))

  (defun %help-parse-key-chord (token)
    (let ((modifiers nil)
          (key token))
      (loop for modifier =
              (when (and (> (length key) 1)
                         (char= (char key 1) #\-))
                (case (char-upcase (char key 0))
                  (#\C :control)
                  (#\M :alt)
                  (#\S :shift)))
            while modifier
            do (when (member modifier modifiers)
                 (return-from %help-parse-key-chord nil))
               (push modifier modifiers)
               (setf key (subseq key 2)))
      (let* ((key-name (string-upcase key))
             (code
               (or (and (= (length key) 1)
                        (char key 0))
                   (cdr
                    (assoc
                     key-name
                     '(("RET" . :enter)
                       ("RETURN" . :enter)
                       ("ENTER" . :enter)
                       ("TAB" . :tab)
                       ("BACKTAB" . :backtab)
                       ("DEL" . :backspace)
                       ("BACKSPACE" . :backspace)
                       ("BS" . :backspace)
                       ("DELETE" . :delete)
                       ("ESC" . :escape)
                       ("ESCAPE" . :escape)
                       ("SPC" . #\Space)
                       ("SPACE" . #\Space)
                       ("UP" . :up)
                       ("ARROW-UP" . :up)
                       ("DOWN" . :down)
                       ("ARROW-DOWN" . :down)
                       ("LEFT" . :left)
                       ("ARROW-LEFT" . :left)
                       ("RIGHT" . :right)
                       ("ARROW-RIGHT" . :right)
                       ("HOME" . :home)
                       ("END" . :end)
                       ("INSERT" . :insert)
                       ("PAGE-UP" . :page-up)
                       ("PAGEUP" . :page-up)
                       ("PGUP" . :page-up)
                       ("PAGE-DOWN" . :page-down)
                       ("PAGEDOWN" . :page-down)
                       ("PGDN" . :page-down)
                       ("F1" . :f1)
                       ("F2" . :f2)
                       ("F3" . :f3)
                       ("F4" . :f4)
                       ("F5" . :f5)
                       ("F6" . :f6)
                       ("F7" . :f7)
                       ("F8" . :f8)
                       ("F9" . :f9)
                       ("F10" . :f10)
                       ("F11" . :f11)
                       ("F12" . :f12)
                       ("F13" . :f13)
                       ("F14" . :f14)
                       ("F15" . :f15)
                       ("F16" . :f16)
                       ("F17" . :f17)
                       ("F18" . :f18)
                       ("F19" . :f19)
                       ("F20" . :f20)
                       ("F21" . :f21)
                       ("F22" . :f22)
                       ("F23" . :f23)
                       ("F24" . :f24)
                       ("F25" . :f25)
                       ("F26" . :f26)
                       ("F27" . :f27)
                       ("F28" . :f28)
                       ("F29" . :f29)
                       ("F30" . :f30)
                       ("F31" . :f31)
                       ("F32" . :f32)
                       ("F33" . :f33)
                       ("F34" . :f34)
                       ("F35" . :f35)
                       ("CAPS-LOCK" . :caps-lock)
                       ("SCROLL-LOCK" . :scroll-lock)
                       ("NUM-LOCK" . :num-lock)
                       ("PRINT-SCREEN" . :print-screen)
                       ("PAUSE" . :pause)
                       ("MENU" . :menu)
                       ("KP-0" . :kp-0)
                       ("KP-1" . :kp-1)
                       ("KP-2" . :kp-2)
                       ("KP-3" . :kp-3)
                       ("KP-4" . :kp-4)
                       ("KP-5" . :kp-5)
                       ("KP-6" . :kp-6)
                       ("KP-7" . :kp-7)
                       ("KP-8" . :kp-8)
                       ("KP-9" . :kp-9)
                       ("KP-DECIMAL" . :kp-decimal)
                       ("KP-DIVIDE" . :kp-divide)
                       ("KP-MULTIPLY" . :kp-multiply)
                       ("KP-SUBTRACT" . :kp-subtract)
                       ("KP-ADD" . :kp-add)
                       ("KP-ENTER" . :kp-enter)
                       ("KP-EQUAL" . :kp-equal)
                       ("KP-SEPARATOR" . :kp-separator)
                       ("KP-LEFT" . :kp-left)
                       ("KP-RIGHT" . :kp-right)
                       ("KP-UP" . :kp-up)
                       ("KP-DOWN" . :kp-down)
                       ("KP-PAGE-UP" . :kp-page-up)
                       ("KP-PAGE-DOWN" . :kp-page-down)
                       ("KP-HOME" . :kp-home)
                       ("KP-END" . :kp-end)
                       ("KP-INSERT" . :kp-insert)
                       ("KP-DELETE" . :kp-delete)
                       ("KP-BEGIN" . :kp-begin)
                       ("FOCUS-IN" . :focus-in)
                       ("FOCUS-OUT" . :focus-out)
                       ("MEDIA-PLAY" . :media-play)
                       ("MEDIA-PAUSE" . :media-pause)
                       ("MEDIA-PLAY-PAUSE" . :media-play-pause)
                       ("MEDIA-REVERSE" . :media-reverse)
                       ("MEDIA-STOP" . :media-stop)
                       ("MEDIA-FAST-FORWARD" . :media-fast-forward)
                       ("MEDIA-REWIND" . :media-rewind)
                       ("MEDIA-TRACK-NEXT" . :media-track-next)
                       ("MEDIA-TRACK-PREVIOUS" . :media-track-previous)
                       ("MEDIA-RECORD" . :media-record)
                       ("LOWER-VOLUME" . :lower-volume)
                       ("RAISE-VOLUME" . :raise-volume)
                       ("MUTE-VOLUME" . :mute-volume)
                       ("LEFT-SHIFT" . :left-shift)
                       ("LEFT-CONTROL" . :left-control)
                       ("LEFT-ALT" . :left-alt)
                       ("LEFT-SUPER" . :left-super)
                       ("LEFT-HYPER" . :left-hyper)
                       ("LEFT-META" . :left-meta)
                       ("RIGHT-SHIFT" . :right-shift)
                       ("RIGHT-CONTROL" . :right-control)
                       ("RIGHT-ALT" . :right-alt)
                       ("RIGHT-SUPER" . :right-super)
                       ("RIGHT-HYPER" . :right-hyper)
                       ("RIGHT-META" . :right-meta))
                     :test #'string=)))))
        (and code
             (cond
               (modifiers (cons (nreverse modifiers) code))
               ((characterp code) code)
               (t (cons nil code)))))))

  (defun %help-parse-key-sequence (input)
    (let ((tokens (%help-key-tokens input)))
      (when tokens
        (let ((sequence (mapcar #'%help-parse-key-chord tokens)))
          (and (every #'identity sequence) sequence)))))

  (defun %help-global-bindings-text ()
  (with-output-to-string (output)
    (dolist (entry (%help-catalog))
      (dolist (binding (gethash "keys" entry))
        (when (string-equal (gethash "keymap" binding) "global")
          (format output "~A  ~A (~A)~%"
                  (%help-format-json-sequence
                   (gethash "sequence" binding))
                  (gethash "name" entry)
                  (gethash "id" entry)))))))

  (progn
  (defun %help-format-runtime-key (descriptor)
    (format nil "~{~A-~}~A"
            (mapcar (lambda (modifier)
                      (if (eq modifier :control) "C-" "M-"))
                    (car descriptor))
            (let ((code (cdr descriptor)))
              (if (characterp code)
                  (string code)
                  (string-upcase (symbol-name code))))))

  (defun %help-format-runtime-sequence (sequence)
    (format nil "~{~A~^ ~}"
            (mapcar #'%help-format-runtime-key sequence)))

  (defun %help-local-command-label (command)
    (let* ((id (handler-case
                   (loom/core/command:command-id-for-function command)
                 (error () nil)))
           (entry (and id (%help-catalog-entry id))))
      (or (and entry (gethash "name" entry))
          id
          (princ-to-string command))))

  (defun %help-local-bindings-text (mode)
    (let ((bindings (getf mode :keybindings)))
      (if bindings
          (with-output-to-string (output)
            (dolist (binding bindings)
              (format output "  ~A  ~A~%"
                      (%help-format-runtime-sequence
                       (loom/core/command:defkeys-key-sequence
                        (car binding)))
                      (%help-local-command-label (cdr binding)))))
          "  none"))))

  (defun help-command ()
    "Show the primary command reference in the *Help* buffer."
    (%show-help (loom/core/command:help-summary-message)))

  (defun describe-key ()
    "Describe the command bound to a key sequence."
    (with-prompts
        (minibuffer (editor-state-minibuffer *editor-state*)
                    :on-cancel (minibuffer-message minibuffer "Quit"))
        ((input "Describe key: "))
      (let* ((buffer (%help-selected-buffer))
             (sequence (%help-parse-key-sequence input)))
        (if sequence
            (let* ((keymap
                     (loom/core/command:keymap-for-buffer
                      (editor-state-session *editor-state*)
                      buffer
                      (editor-state-keymap *editor-state*)))
                   (binding (loom/core/command:keymap-lookup keymap sequence))
                   (entry (and (stringp binding)
                               (%help-catalog-entry binding))))
              (%show-help
               (cond
                 ((eq binding :prefix)
                  (format nil "~A is a prefix key." input))
                 (entry
                  (format nil "Key: ~A~%~A"
                          input (%help-entry-text entry)))
                 (t (format nil "~A is not bound." input)))))
            (%show-help
             (format nil "Could not parse key sequence: ~A" input))))))

  (defun describe-command ()
    "Describe a named command."
    (with-prompts
        (minibuffer (editor-state-minibuffer *editor-state*)
                    :on-cancel (minibuffer-message minibuffer "Quit"))
        ((input "Describe command: "
                :completion-function
                (lambda (prefix)
                  (loom/core/command:command-completion-names prefix))))
      (let* ((spec (loom/core/command:find-extended-command-spec input))
             (id (and spec (loom/core/command:command-spec-id spec)))
             (entry (and id (%help-catalog-entry id))))
        (%show-help
         (if entry
             (%help-entry-text entry)
             (format nil "No command named ~A." input))))))

  (defun describe-bindings ()
    "Show global and current mode bindings."
    (let* ((mode
             (loom/feature/mode:mode-description-for-buffer
              (%help-selected-buffer))))
      (%show-help
       (format nil "Global bindings~%~A~%~%~A bindings~%~A"
               (%help-global-bindings-text)
               (getf mode :name)
               (%help-local-bindings-text mode)))))

  (defun describe-mode ()
    "Describe the selected buffer's major mode."
    (let* ((mode
             (loom/feature/mode:mode-description-for-buffer
              (%help-selected-buffer))))
      (%show-help
       (format nil "Mode: ~A (~A)~%~A~%~%Local bindings~%~A"
               (or (getf mode :name) "Unknown")
               (getf mode :mode)
               (or (getf mode :description) "No mode description.")
               (%help-local-bindings-text mode))))))
