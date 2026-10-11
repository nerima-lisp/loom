(in-package #:loom/feature/file-tree)


(defun file-tree-create-file (tree path)
  "Create an empty regular file at PATH through native or configured filesystem dispatch.
Signals an error if PATH already exists. Returns PATH."
  (%file-tree-assert-native-path-within-root tree path)
  (%dispatch-native-path-operation
      (path)
      (%native-create-file path)
      (cl-boundary-kit:filesystem-store-file *loom-filesystem* path ""
                                             :if-exists :error))
  path)

(defun file-tree-create-directory (tree path)
  "Create an empty directory at PATH through native or configured filesystem dispatch. Signals
an error if PATH already exists. Returns PATH."
  (%file-tree-assert-native-path-within-root tree path)
  (%dispatch-native-path-operation
      (path)
      (progn
        (when (%native-path-exists-p path)
          (error "file-tree-create-directory: ~A already exists" path))
        (%native-make-directory path))
      (progn
        (when (cl-boundary-kit:filesystem-directory-exists-p
                *loom-filesystem* path)
          (error "file-tree-create-directory: ~A already exists" path))
        (cl-boundary-kit:filesystem-make-directory *loom-filesystem* path)))
  path)

(defun file-tree-rename (tree old-path new-path)
  "Move the file or directory at OLD-PATH to NEW-PATH through filesystem dispatch.
Signals an error if OLD-PATH does not exist or
NEW-PATH already does. Returns NEW-PATH."
  (%file-tree-assert-native-path-within-root tree old-path)
  (%file-tree-assert-native-path-within-root tree new-path)
  (%dispatch-native-path-operation
        (old-path new-path)
        (progn
          (unless (%native-path-exists-p old-path)
            (error "file-tree-rename: ~A does not exist" old-path))
          (when (%native-path-exists-p new-path)
            (error "file-tree-rename: ~A already exists" new-path))
          (%native-rename old-path new-path))
        (progn
          (unless (cl-boundary-kit:filesystem-path-exists-p
                    *loom-filesystem* old-path)
            (error "file-tree-rename: ~A does not exist" old-path))
          (when (cl-boundary-kit:filesystem-path-exists-p
                  *loom-filesystem* new-path)
            (error "file-tree-rename: ~A already exists" new-path))
          (cl-boundary-kit:filesystem-rename-file
           *loom-filesystem* old-path new-path)))
  new-path)

(defun file-tree-delete (tree path)
  "Delete the file or directory at PATH through native or host filesystem dispatch.
Signals an error if PATH does not exist. Returns TREE."
  (%file-tree-assert-native-path-within-root tree path)
  (%dispatch-native-path-operation
        (path)
        (%native-delete-path path)
        (host-kit:delete-path path :recursive t :if-does-not-exist :error))
  tree)
