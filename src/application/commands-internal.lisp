(in-package #:loom/application)

(defun %order-region (point-line point-column mark-line mark-column)
  "Return the region bounds in buffer order.

Positions are compared by line and then by column.  Keeping this pure
ordering operation in the shared application package lets register commands
reuse it without depending on the editor command implementation."
  (if (or (< point-line mark-line)
          (and (= point-line mark-line) (<= point-column mark-column)))
      (values point-line point-column mark-line mark-column)
      (values mark-line mark-column point-line point-column)))
(defun find-extended-command (input)
  "Return the registered command function named by INPUT, or NIL."
  (getf (find-extended-command-spec input) :command))
