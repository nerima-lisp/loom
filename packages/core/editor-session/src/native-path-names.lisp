(in-package #:loom/core/editor-session)

;; Features receive native pathnames (SB-EXT:PARSE-NATIVE-NAMESTRING), whose
;; components hold the literal on-disk name, and legacy pathnames parsed by
;; PATHNAME, where * ? and [ are wildcards. NAMESTRING and FILE-NAMESTRING
;; escape those characters in a native pathname, so neither yields the name
;; the operating system uses.

(defun native-path-namestring (path)
  "Return PATH as the operating system names it.
A string is returned as is. A wild pathname is read through the text of its
namestring, which is how loom named such paths before it used native
pathnames."
  (if (stringp path)
      path
      (let ((pathname (pathname path)))
        (sb-ext:native-namestring
         (if (wild-pathname-p pathname)
             (sb-ext:parse-native-namestring (namestring pathname))
             pathname)))))

(defun native-path-basename (path)
  "Return the last component of PATH as the operating system names it: the
file name, or the last directory name of a directory pathname.
A string is parsed with PATHNAME first."
  (let ((native (string-right-trim
                 "/" (native-path-namestring (pathname path)))))
    (subseq native (1+ (or (position #\/ native :from-end t) -1)))))
