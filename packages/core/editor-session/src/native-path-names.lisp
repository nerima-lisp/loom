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

(defun literal-file-path (path)
  "Return a path designator that names the file the user or a kit gave as PATH.
A string holding * ? [ or \\ is the operating system's name for the file, so it
is parsed natively, with a leading ~/ read as the home directory. Any other
string is returned as is for callers that parse it with PATHNAME. A pathname is
returned as is, except that a wild one is read through the text of its
namestring."
  (cond
    ((not (stringp path))
     (let ((pathname (pathname path)))
       (if (wild-pathname-p pathname)
           (sb-ext:parse-native-namestring (namestring pathname))
           pathname)))
    ((not (find-if (lambda (character) (find character "*?[\\")) path))
     path)
    ((and (>= (length path) 2) (string= "~/" path :end2 2))
     (sb-ext:parse-native-namestring
      (concatenate 'string
                   (sb-ext:native-namestring (user-homedir-pathname))
                   (subseq path 2))))
    (t (sb-ext:parse-native-namestring path))))
