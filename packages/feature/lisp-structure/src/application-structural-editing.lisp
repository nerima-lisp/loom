(in-package #:loom)

(defun %forward-slurp-target (text classes close)
  (let ((target (%forward-sexp-offset text (1+ close) classes)))
    (when target
      (if (and (%structural-prefix-p)
               (< target (length text))
               (char= (char text target) #\Newline))
          (values (1+ target) target)
          (values target nil)))))

(defun %forward-slurp-edits-at (text close target reindent-offset)
  (values (list (list :delete close 1)
                (list :insert (1- target) (string (char text close))))
          :as-listed
          reindent-offset))

(defun %forward-slurp-edits (text classes offset)
  "Move the enclosing list close past the next expression."
  (%with-structural-list-bounds (open close) (text classes offset)
    (multiple-value-bind (target reindent-offset)
        (%forward-slurp-target text classes close)
      (when (and open target)
        (%forward-slurp-edits-at text close target reindent-offset)))))

(defun %forward-barf-target-position (text classes open close)
  (let ((last-start (%backward-sexp-offset text close classes)))
    (when (and last-start (> last-start open))
      (%sexp-skip-backward-filler text classes last-start))))

(defun %forward-barf-target (text classes open close)
  (let ((target (%forward-barf-target-position text classes open close)))
    (when target
      (let ((delimiter (string (char text close))))
        (values target
                (%forward-barf-delimiter text target delimiter))))))

(defun %forward-barf-edits (text classes offset)
  "Move the enclosing list close past the last prefix-count expressions."
  (%with-structural-list-bounds (open close) (text classes offset)
    (if (%structural-prefix-p)
        (let ((target
                (loop with position = close
                      with target = nil
                      repeat (max 0 (%structural-prefix-count))
                      for start = (%backward-sexp-offset text position classes)
                      while (and start
                                 (> start open)
                                 (< start position))
                      do (setf target start
                               position start)
                      finally
                        (return
                          (and target
                               (%sexp-skip-backward-filler
                                text classes target))))))
          (when target
            (values (list (list :delete close 1)
                          (list :insert
                                target
                                (if (= target (1+ open))
                                    (string (char text close))
                                    (%forward-barf-delimiter
                                     text target
                                     (string (char text close))))))
                    :as-listed
                    nil
                    offset)))
        (multiple-value-bind (target moved-delimiter)
            (%forward-barf-target text classes open close)
          (when target
            (list (list :delete close 1)
                  (list :insert target moved-delimiter)))))))

(defun %backward-slurp-target (text classes open)
  (%backward-sexp-offset text open classes))

(defun %backward-slurp-edits-at (text open target)
  (list (list :delete open 1)
        (list :insert target (string (char text open)))))

(defun %backward-slurp-edits (text classes offset)
  "Move the enclosing list's opening delimiter back past the expression before it."
  (%with-structural-list-bounds (open close) (text classes offset)
    (let ((target (%backward-slurp-target text classes open)))
      (when target
        (%backward-slurp-edits-at text open target)))))

(defun %backward-barf-target-position (text classes open close)
  (let ((first-end (%forward-sexp-offset text (1+ open) classes)))
    (when (and first-end (<= first-end close))
      (%sexp-skip-forward-filler text classes first-end))))

(defun %backward-barf-target (text classes open close)
  (let ((target (%backward-barf-target-position text classes open close)))
    (when target
      (let ((delimiter (string (char text open))))
        (values target
                (%backward-barf-delimiter text target delimiter))))))

(defun %backward-barf-edits (text classes offset)
  "Move the enclosing list open past prefix-count expressions before point."
  (%with-structural-list-bounds (open close) (text classes offset)
    (multiple-value-bind (target moved-delimiter)
        (if (%structural-prefix-p)
            (let ((target
                    (loop with position = (1+ open)
                          with target = nil
                          repeat (max 0 (%structural-prefix-count))
                          for end = (%forward-sexp-offset text position classes)
                          while (and end
                                     (<= end offset)
                                     (<= end close))
                          do (setf target (%sexp-skip-forward-filler
                                           text classes end)
                                   position target)
                          finally (return target))))
              (when target
                (values target
                        (%backward-barf-delimiter
                         text target (string (char text open))))))
            (%backward-barf-target text classes open close))
      (when target
        (values (list (list :delete open 1)
                      (list :insert (1- target) moved-delimiter))
                :as-listed)))))

(defun %wrap-round-edits (text classes offset)
  "Wrap the prefix-count expressions after OFFSET in parentheses."
  (let* ((start (%sexp-skip-forward-filler text classes offset))
         (end
           (if (%structural-prefix-p)
               (loop with position = offset
                     with target = nil
                     repeat (max 0 (%structural-prefix-count))
                     for next = (%forward-sexp-offset text position classes)
                     while next
                     do (setf target next
                              position next)
                     finally (return target))
               (%forward-sexp-offset text offset classes))))
    (if end
        (values (list (list :insert start "(")
                      (list :insert (1+ end) ")"))
                :as-listed)
        (values (list (list :insert start "(")
                      (list :insert (1+ start) ")"))
                :as-listed))))

(defun %splice-edits (text classes offset)
  "Remove the enclosing list's delimiters, keeping its contents in place."
  (%with-structural-list-bounds (open close) (text classes offset)
    (list (list :delete close 1)
          (list :delete open 1))))

(defun %raiseable-range-p (open close start end)
  (and end
       (> start open)
       (<= end close)))

(defun %raise-range-edits (open close start end)
  (list (list :delete end (- (1+ close) end))
        (list :delete open (- start open))))

(defun %raiseable-range (text classes offset open close)
  (let ((start (%sexp-skip-forward-filler text classes offset))
        (end (%forward-sexp-offset text offset classes)))
    (when (%raiseable-range-p open close start end)
      (values start end))))

(defun %raise-edits (text classes offset)
  "Replace the enclosing list with the prefix-count expressions at OFFSET."
  (%with-structural-list-bounds (open close) (text classes offset)
    (let ((end
            (if (%structural-prefix-p)
                (loop with position = offset
                      with target = nil
                      repeat (max 0 (%structural-prefix-count))
                      for next = (%forward-sexp-offset
                                  text position classes)
                      while (and next (> next position) (<= next close))
                      do (setf target next
                               position next)
                      finally (return target))
                (%forward-sexp-offset text offset classes))))
      (when end
        (let ((start (%sexp-skip-forward-filler text classes offset)))
          (when (%raiseable-range-p open close start end)
            (%raise-range-edits open close start end)))))))
