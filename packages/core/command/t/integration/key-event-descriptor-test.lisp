(in-package #:loom/test)

(describe
  "structural motion keybindings"
  (it
    "keeps an ESC-prefixed Ctrl-letter distinct from the bare chord"
    (expect (loom/core/command:key-event->descriptor (cl-tty-kit:make-key-event :type :special :code :control-f))
            :to-equal '((:control) . #\f))
    (expect (loom/core/command:key-event->descriptor (cl-tty-kit:make-key-event :type :special
                                        :code :control-f
                                        :modifiers '(:alt)))
            :to-equal '((:control :alt) . #\f))))
