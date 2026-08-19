(in-package #:loom/feature/terminal)

(defstruct (terminal-screen
            (:constructor %make-terminal-screen
                (width height rows cursor-row cursor-column parser-state
                 csi-parameters csi-private saved-row saved-column
                 main-rows main-cursor-row main-cursor-column alternate-p
                 wrap-pending)))
  "The small, stateful screen model used to render a PTY transcript.

It deliberately models the cursor and the common CSI editing operations used
by interactive terminal programs.  It is not intended to be a complete VT
parser, but keeping state here means cursor-addressed output is rendered in
the same order it was received instead of being reduced to a styled string."
  width
  height
  rows
  cursor-row
  cursor-column
  parser-state
  csi-parameters
  csi-private
  saved-row
  saved-column
  main-rows
  main-cursor-row
  main-cursor-column
  alternate-p
  wrap-pending)

(defun make-terminal-screen (&key (width 80) (height 24))
  "Create a blank terminal screen with WIDTH columns and HEIGHT rows."
  (%terminal-ensure-dimension width "width")
  (%terminal-ensure-dimension height "height")
  (%make-terminal-screen width
                         height
                         (%terminal-blank-rows width height)
                         0
                         0
                         :ground
                         ""
                         nil
                         0
                         0
                         nil
                         0
                         0
                         nil
                         nil))

(defun terminal-screen-text (screen)
  "Return the visible screen as newline-separated, trimmed terminal rows."
  (let ((last-row
          (loop for row downfrom (1- (terminal-screen-height screen)) downto 0
                when (%terminal-screen-row-content-p
                      (aref (terminal-screen-rows screen) row))
                  return row)))
    (if (null last-row)
        ""
        (with-output-to-string (output)
          (loop for row below (1+ last-row)
                do (when (plusp row)
                     (write-char #\Newline output))
                   (write-string
                    (string-right-trim " "
                                       (aref (terminal-screen-rows screen)
                                             row))
                    output))))))

(defun terminal-screen-resize (screen width height)
  "Resize SCREEN while retaining the top-left visible content."
  (%terminal-ensure-dimension width "width")
  (%terminal-ensure-dimension height "height")
  (let ((rows (%terminal-copy-rows (terminal-screen-rows screen)
                                   width
                                   height))
        (main-rows (and (terminal-screen-main-rows screen)
                        (%terminal-copy-rows
                         (terminal-screen-main-rows screen)
                         width
                         height))))
    (setf (terminal-screen-width screen) width
          (terminal-screen-height screen) height
          (terminal-screen-rows screen) rows
          (terminal-screen-main-rows screen) main-rows)
    (%terminal-screen-clamp-cursor screen))
  screen)
