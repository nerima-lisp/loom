;;;; t/unit/lsp-request-decode-test.lisp
;;;;
;;;; Decoding of the completion and definition responses, including the shapes
;;;; the protocol allows a server to choose between.
(in-package #:loom/test)

(defun %decode-completion (json)
  (loom/feature/lsp::%lsp-parse-completion-result (%parse-lsp-json json)))

(defun %decode-definition (json)
  (loom/feature/lsp::%lsp-parse-definition-result (%parse-lsp-json json)))

(describe
  "completion response decoding"
  (it
    "accepts a bare array of items"
    (let ((items (%decode-completion
                  "[{\"label\":\"alpha\"},{\"label\":\"beta\"}]")))
      (expect (mapcar #'lsp-completion-item-label items)
              :to-equal '("alpha" "beta"))))

  (it
    "accepts a CompletionList object and reads its items"
    (let ((items (%decode-completion
                  "{\"isIncomplete\":false,\"items\":[{\"label\":\"alpha\"}]}")))
      (expect (mapcar #'lsp-completion-item-label items) :to-equal '("alpha"))))

  (it
    "treats null and an empty list alike"
    (expect (%decode-completion "null") :to-equal nil)
    (expect (%decode-completion "[]") :to-equal nil)
    (expect (%decode-completion "{\"items\":[]}") :to-equal nil))

  (it
    "inserts insertText when it differs from the label"
    (let ((item (first (%decode-completion
                        "[{\"label\":\"foo(...)\",\"insertText\":\"foo\"}]"))))
      (expect (lsp-completion-item-label item) :to-equal "foo(...)")
      (expect (lsp-completion-item-text item) :to-equal "foo")))

  (it
    "falls back to the label when there is no insertText"
    (let ((item (first (%decode-completion "[{\"label\":\"foo\"}]"))))
      (expect (lsp-completion-item-text item) :to-equal "foo")))

  (it
    "keeps detail and kind when present and ignores the wrong types"
    (let ((item (first (%decode-completion
                        "[{\"label\":\"a\",\"detail\":\"fn\",\"kind\":3}]")))
          (loose (first (%decode-completion
                         "[{\"label\":\"a\",\"detail\":7,\"kind\":\"x\"}]"))))
      (expect (lsp-completion-item-detail item) :to-equal "fn")
      (expect (lsp-completion-item-kind item) :to-equal 3)
      (expect (lsp-completion-item-detail loose) :to-be nil)
      (expect (lsp-completion-item-kind loose) :to-be nil)))

  (it
    "drops one malformed item instead of losing the whole response"
    (let ((items (%decode-completion
                  "[{\"label\":\"alpha\"},{\"nolabel\":1},{\"label\":\"beta\"}]")))
      (expect (mapcar #'lsp-completion-item-label items)
              :to-equal '("alpha" "beta"))))

  (it
    "drops a non-object completion item"
    (expect (mapcar #'lsp-completion-item-label
                    (%decode-completion "[1,{\"label\":\"alpha\"}]"))
            :to-equal '("alpha")))

  (it
    "treats a non-array CompletionList items value as empty"
    (expect (%decode-completion "{\"items\":1}") :to-equal nil))

  (it
    "treats an unsupported completion result shape as empty"
    (expect (%decode-completion "42") :to-equal nil))

  (it
    "rejects completion items that are not objects or have no label"
    (signals error
      (loom/feature/lsp::%lsp-parse-completion-item 42))
    (signals error
      (loom/feature/lsp::%lsp-parse-completion-item
       (let ((object (make-hash-table :test #'equal)))
         (setf (gethash "label" object) 42)
         object)))))

(describe
  "definition response decoding"
  (it
    "accepts a single Location"
    (let ((locations (%decode-definition
                      "{\"uri\":\"file:///tmp/a.lisp\",\"range\":{\"start\":{\"line\":2,\"character\":4},\"end\":{\"line\":2,\"character\":9}}}")))
      (expect (length locations) :to-equal 1)
      (expect (lsp-location-uri (first locations))
              :to-equal "file:///tmp/a.lisp")
      (expect (lsp-position-line
               (lsp-range-start (lsp-location-range (first locations))))
              :to-equal 2)))

  (it
    "accepts an array of Locations"
    (expect (length (%decode-definition
                     "[{\"uri\":\"file:///a\",\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":1}}},{\"uri\":\"file:///b\",\"range\":{\"start\":{\"line\":1,\"character\":0},\"end\":{\"line\":1,\"character\":1}}}]"))
            :to-equal 2))

  (it
    "accepts a LocationLink, whose fields are named differently"
    (let ((locations (%decode-definition
                      "[{\"targetUri\":\"file:///tmp/b.lisp\",\"targetSelectionRange\":{\"start\":{\"line\":5,\"character\":1},\"end\":{\"line\":5,\"character\":3}}}]")))
      (expect (lsp-location-uri (first locations))
              :to-equal "file:///tmp/b.lisp")
      (expect (lsp-position-line
               (lsp-range-start (lsp-location-range (first locations))))
              :to-equal 5)))

  (it
    "accepts the optional targetRange LocationLink field"
    (let ((locations (%decode-definition
                      "[{\"targetUri\":\"file:///tmp/c.lisp\",\"targetRange\":{\"start\":{\"line\":7,\"character\":0},\"end\":{\"line\":7,\"character\":2}}}]")))
      (expect (lsp-location-uri (first locations))
              :to-equal "file:///tmp/c.lisp")
      (expect (lsp-position-line
               (lsp-range-start (lsp-location-range (first locations))))
              :to-equal 7)))

  (it
    "drops malformed definitions while keeping valid locations"
    (let ((locations (%decode-definition
                      "[1,{\"uri\":\"file:///tmp/a\",\"range\":{\"start\":{\"line\":0,\"character\":0},\"end\":{\"line\":0,\"character\":1}}},{\"range\":{}}]")))
      (expect (length locations) :to-equal 1)
      (expect (lsp-location-uri (first locations))
              :to-equal "file:///tmp/a")))

  (it
    "treats a malformed single Location as no definition"
    (expect (%decode-definition "{\"range\":{}}") :to-equal nil))

  (it
    "treats an unsupported definition result shape as empty"
    (expect (%decode-definition "42") :to-equal nil))

  (it
    "treats null as no definition"
    (expect (%decode-definition "null") :to-equal nil)
    (expect (%decode-definition "[]") :to-equal nil))

  (it
    "rejects locations that are not objects or lack a valid URI and range"
    (signals error
      (loom/feature/lsp::%lsp-parse-location 42))
    (signals error
      (loom/feature/lsp::%lsp-parse-location
       (let ((object (make-hash-table :test #'equal)))
         (setf (gethash "uri" object) "file:///tmp/a.lisp")
         object)))))

(describe
  "lsp-uri-path"
  (it-each
      (("/tmp/main.lisp")
       ("/tmp/dir with spaces/a.lisp")
       ("/tmp/日本語.lisp"))
      "round-trips ~S through a file URI"
      (path)
    (expect (lsp-uri-path (lsp-path-uri path)) :to-equal path))

  (it
    "returns nil for a uri that does not name a local file"
    (expect (lsp-uri-path "http://example.com/a.lisp") :to-be nil)
    (expect (lsp-uri-path "untitled:Untitled-1") :to-be nil)
    (expect (lsp-uri-path 42) :to-be nil)))

(describe
  "lsp-session-capability"
  (it
    "reads an advertised capability and rejects absent, null, and false"
    (%with-started-fake-lsp-session ((transport session))
      (%fake-push-initialize-response
       transport
       "{\"capabilities\":{\"completionProvider\":{\"triggerCharacters\":[\".\"]},\"definitionProvider\":true,\"hoverProvider\":false,\"renameProvider\":null}}")
      (lsp-session-drain session)
      (expect (lsp-session-capability session "completionProvider")
              :to-be-truthy)
      (expect (lsp-session-capability session "definitionProvider")
              :to-be-truthy)
      (expect (lsp-session-capability session "hoverProvider") :to-be nil)
      (expect (lsp-session-capability session "renameProvider") :to-be nil)
      (expect (lsp-session-capability session "referencesProvider")
              :to-be nil))))
