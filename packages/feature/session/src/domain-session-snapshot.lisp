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

(defstruct session-snapshot
  "Validated, serializable state for one Loom editing session.

WORKSPACES contains the named workspace views. Each workspace's LAYOUT is a
nested (:LEAF BUFFER-INDEX SCROLL-LINE) / (:SPLIT DIRECTION CHILD-1 CHILD-2)
description. Buffer indexes refer to the order of SESSION-SNAPSHOT-BUFFERS,
and each workspace's SELECTED-WINDOW-INDEX refers to the depth-first order of
leaves in its LAYOUT."
  buffers
  recent-files
  bookmarks
  command-history
  workspaces
  current-workspace-index)
