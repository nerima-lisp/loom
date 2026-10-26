(in-package #:loom/feature/session)

(defstruct session-buffer-snapshot
  "Serializable state for one registered editor buffer."
  name
  path
  text
  point-line
  point-column
  mark-line
  mark-column
  modified-p)

(defstruct session-bookmark-snapshot
  "Serializable state for one named bookmark."
  name
  path
  buffer-name
  line
  column)

(defstruct session-workspace-snapshot
  "Serializable state for one named workspace.

LAYOUT uses the indexes of SESSION-SNAPSHOT-BUFFERS."
  name
  layout
  selected-window-index)
(defstruct session-file-tree-snapshot
  "Serializable file-tree state independent of the startup root."
  root-path
  visible-p
  expanded-paths
  selected-path)

(defstruct session-snapshot
  "Validated serializable state for one Loom editing session.

WORKSPACES contains named views whose layouts refer to buffer indexes in
SESSION-SNAPSHOT-BUFFERS. Selected-window indexes refer to each layout leaf
order."
  buffers
  recent-files
  bookmarks
  command-history
  workspaces
  current-workspace-index
  file-tree)
