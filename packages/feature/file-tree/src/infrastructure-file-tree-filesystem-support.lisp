
(in-package #:loom/feature/file-tree)

(defmacro %dispatch-native-path-operation ((&rest paths)
                                           native-form
                                           boundary-form)
  `(if (%native-path-operation-p ,@paths)
       ,native-form
       ,boundary-form))
