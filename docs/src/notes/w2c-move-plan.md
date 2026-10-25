# W2c 移設計画

## 目的と前提

本書は`docs/src/notes/requirements-modern-editor.md`の4.2節と11章、および`docs/src/notes/design-core-and-slices.md`の4〜6章を根拠にW2cのslice移設順、並列単位、W3開始条件を定める。W2a〜W2dは設計5章の移設phase、FR-A05は要件4.2のsource移設要件、W3-1〜W3-11は要件11.6の実装laneを指す。ここでいう移設には物理pathの変更とASDF上の所有権切替を含む。

調査はリポジトリ内の静的な読み取りと検索に限る。実際の移設、ビルド、テストは行わない。表の現行pathは`origin/main`の`555c2dda3ee0ba883774898e628cc4f7024a5a96`を基準とする。移設先は各sourceまたはtest assertionのownerを示し、ASDF componentの切替は表の移設と同じcommitで行う。

## 1. 移設表

### 1.1 `src/`と`t/`の全Lispファイル

以下は確認済みの`origin/main`にある`src/`と`t/`配下のLisp fileを一度ずつ割り当てた表である。LOCは物理行数である。production行の`root`はcomposition rootに残す。test行の`root`で始まるowner名はrootの`loom/test`集約に残す分類であり、末尾の語は残す理由を示す。`root command integration`などは分類名で、ASDF system名ではない。`root test-support`は共有fixture用system `loom/test-support`の所有を表す。`split`行では対象の関数またはassertionと移設先を対応させる。同じ最終pathへ別sourceを結合せず、分割片にはsourceごとに異なるpathを割り当てる。

`core/buffer`のcommand ownerはsource directory名から推定せず、現行W2a specと責務定義で確認した。editing、movement、regionのspecは対象commandを`:core/buffer` ownerで登録し（`packages/core/buffer/src/command-specs-editing.lisp:4-47`、`packages/core/buffer/src/command-specs-movement.lisp:4-122`、`packages/core/buffer/src/command-specs-region.lisp:4-91`）、requirementはcore/bufferにbuffer編集、位置、narrowing、read-onlyを割り当てる（`docs/src/notes/requirements-modern-editor.md:145`）。特に`application-commands-movement-view-support.lisp`は現行treeではgoto-lineの入力・検証だけを含み（`packages/core/editor/src/application-commands-movement-view-support.lisp:3-36`）、W2a specもgoto-lineを`:core/buffer` ownerで登録する（`packages/core/buffer/src/command-specs-movement.lisp:114-122`）。設計表の`:3-66`とscroll helperの記述は現行sourceと一致しないため、この計画では現行W2a ownerを維持する。

ここで確定するのはW2a command catalogの論理ownerであり、ASDF componentの所属ではない。1.2表の`移設先`は物理pathを示し、ASDF ownerは別に決める。`packages/core/buffer`を移設先とするapplication command sourceはcommand macro（`packages/core/editor/src/application-commands-editing.lisp:3-19`）、editor stateとwindow tree（`packages/core/editor/src/application-commands-movement-support.lisp:17-30`）、minibuffer（`packages/core/editor/src/application-commands-movement-view-support.lisp:28-36`）を参照する。batch 0ではこれらのfileを表のpathへ物理移動してもroot `loom` componentが所有し、依存0件の`loom-core-buffer`には登録しない。package bootstrapの移設後、batch 2でcomponent ownerを`loom-core-command`へ切り替える。例外のword-motion helperとcaller 2 fileはbatch 0では現在の`core/editor` pathとroot component ownerに保ち、batch 2で3 fileを一緒に`core/command`へ移す。3 fileはいずれも`LOOM` packageに属するためhelperをexportしない。各batchの開始前にW2cの進行役がintegration ownerを1人指名し、そのownerが共有root manifestを適用する。

| owner | 現在のpath | LOC | W2c移設先 / 扱い |
|---|---|---:|---|
| bookmark | `src/application/commands-bookmark-support.lisp` | 77 | `packages/feature/bookmark/src/commands-bookmark-support.lisp` |
| bookmark | `src/application/commands-bookmark.lisp` | 57 | `packages/feature/bookmark/src/commands-bookmark.lisp` |
| root | `src/application/commands-internal.lisp` | 12 | `src/application/commands-internal.lisp` をrootに保持 |
| split: core/minibuffer + core/command + help | `src/application/commands-misc.lisp` | 26 | `keyboard-quit` (`:3-6`) → `packages/core/minibuffer/src/application-commands-minibuffer.lisp`、`execute-extended-command` (`:8-20`) → `packages/core/command/src/application-commands-extended-command.lisp`、`help-command` (`:22-26`) → `packages/feature/help/src/application-commands-help-command.lisp` |
| split: lifecycle + buffers | `src/application/commands-quit.lisp` | 78 | `loom-quit`、quit prompt/action、`save-buffers-kill-terminal` (`:3-8`, `:20-78`) → `packages/feature/lifecycle/src/application-commands-quit.lisp`、`%quit-buffer-list` (`:9-18`) → `packages/feature/buffers/src/application-commands-quit-buffer-list.lisp` |
| completion | `src/application/completion-popup-input.lisp` | 94 | `packages/feature/completion/src/completion-popup-input.lisp` |
| completion | `src/application/completion-popup.lisp` | 54 | `packages/feature/completion/src/completion-popup.lisp` |
| bookmark | `src/application/editor-state-bookmarks.lisp` | 11 | `packages/feature/bookmark/src/editor-state-bookmarks.lisp` |
| kill-ring | `src/application/editor-state-operations.lisp` | 4 | `packages/feature/kill-ring/src/editor-state-operations.lisp` |
| files | `src/application/editor-state-recent-files.lisp` | 31 | `packages/feature/files/src/editor-state-recent-files.lisp` |
| root | `src/application/event-loop-control.lisp` | 55 | `src/application/event-loop-control.lisp` をrootに保持 |
| root | `src/application/event-loop-rendering.lisp` | 20 | `src/application/event-loop-rendering.lisp` をrootに保持 |
| root | `src/application/event-loop.lisp` | 52 | `src/application/event-loop.lisp` をrootに保持 |
| root | `src/application/input-dispatch.lisp` | 35 | `src/application/input-dispatch.lisp` をrootに保持 |
| root | `src/application/input-routing-command-state.lisp` | 38 | `src/application/input-routing-command-state.lisp` をrootに保持 |
| root | `src/application/input-routing-decision.lisp` | 113 | `src/application/input-routing-decision.lisp` をrootに保持 |
| root | `src/application/input-routing-dispatch.lisp` | 79 | `src/application/input-routing-dispatch.lisp` をrootに保持 |
| root | `src/application/input-routing-effects.lisp` | 57 | `src/application/input-routing-effects.lisp` をrootに保持 |
| root | `src/application/startup-cli.lisp` | 19 | `src/application/startup-cli.lisp` をrootに保持 |
| root | `src/application/startup-services.lisp` | 51 | `src/application/startup-services.lisp` をrootに保持 |
| root | `src/application/startup-state.lisp` | 113 | `src/application/startup-state.lisp` をrootに保持 |
| root | `src/application/startup.lisp` | 41 | `src/application/startup.lisp` をrootに保持 |
| root | `src/infrastructure/terminal-renderer-cursor.lisp` | 8 | `src/infrastructure/terminal-renderer-cursor.lisp` をrootに保持 |
| root | `src/infrastructure/terminal-renderer-text-wrapping.lisp` | 54 | `src/infrastructure/terminal-renderer-text-wrapping.lisp` をrootに保持 |
| root | `src/infrastructure/terminal-renderer-text.lisp` | 54 | `src/infrastructure/terminal-renderer-text.lisp` をrootに保持 |
| root | `src/infrastructure/terminal-renderer.lisp` | 84 | `src/infrastructure/terminal-renderer.lisp` をrootに保持 |
| root | `src/main.lisp` | 13 | `src/main.lisp` をrootに保持 |
| root | `src/package-application.lisp` | 1 | `src/package-application.lisp` をrootに保持 |
| root | `src/package-exports.lisp` | 81 | `src/package-exports.lisp` をrootに保持 |
| root | `src/package-user.lisp` | 4 | `src/package-user.lisp` をrootに保持 |
| root | `src/package.lisp` | 10 | `src/package.lisp` をrootに保持 |
| root | `src/presentation/frame-layout-cursor.lisp` | 106 | `src/presentation/frame-layout-cursor.lisp` をrootに保持 |
| root | `src/presentation/frame-layout-viewport.lisp` | 89 | `src/presentation/frame-layout-viewport.lisp` をrootに保持 |
| root | `src/presentation/frame-layout.lisp` | 67 | `src/presentation/frame-layout.lisp` をrootに保持 |
| root | `src/presentation/layout-completion.lisp` | 107 | `src/presentation/layout-completion.lisp` をrootに保持 |
| root | `src/presentation/layout-file-tree.lisp` | 36 | `src/presentation/layout-file-tree.lisp` をrootに保持 |
| root | `src/presentation/layout-isearch.lisp` | 164 | `src/presentation/layout-isearch.lisp` をrootに保持 |
| root | `src/presentation/layout-minibuffer.lisp` | 20 | `src/presentation/layout-minibuffer.lisp` をrootに保持 |
| root | `src/presentation/layout-windows.lisp` | 297 | `src/presentation/layout-windows.lisp` をrootに保持 |
| root | `src/presentation/layout-wrapping.lisp` | 87 | `src/presentation/layout-wrapping.lisp` をrootに保持 |
| root | `src/presentation/layout.lisp` | 38 | `src/presentation/layout.lisp` をrootに保持 |
| root integration | `t/integration/advanced-test.lisp` | 89 | `t/integration/advanced-test.lisp` をrootに保持 |
| core/command | `t/integration/command-keybinding-consistency-test.lisp` | 50 | `packages/core/command/t/integration/command-keybinding-consistency-test.lisp` |
| core/command | `t/integration/command-registration-test.lisp` | 298 | `packages/core/command/t/integration/command-registration-test.lisp` |
| core/command | `t/integration/command-registry-definition-test.lisp` | 127 | `packages/core/command/t/integration/command-registry-definition-test.lisp` |
| core/command | `t/integration/command-spec-validation-test.lisp` | 122 | `packages/core/command/t/integration/command-spec-validation-test.lisp` |
| bookmark | `t/integration/commands-bookmark-test.lisp` | 186 | `packages/feature/bookmark/t/integration/commands-bookmark-test.lisp` |
| buffers | `t/integration/commands-buffer-lifecycle-test.lisp` | 102 | `packages/feature/buffers/t/integration/commands-buffer-lifecycle-test.lisp` |
| root command integration | `t/integration/commands-editing-buffer-history-test.lisp` | 23 | `t/integration/commands-editing-buffer-history-test.lisp` をrootに保持 |
| root command integration | `t/integration/commands-editing-buffer-mark-test.lisp` | 35 | `t/integration/commands-editing-buffer-mark-test.lisp` をrootに保持 |
| root command integration | `t/integration/commands-editing-buffer-mutation-test.lisp` | 33 | `t/integration/commands-editing-buffer-mutation-test.lisp` をrootに保持 |
| root command integration | `t/integration/commands-editing-buffer-narrowing-test.lisp` | 72 | `t/integration/commands-editing-buffer-narrowing-test.lisp` をrootに保持 |
| root command integration | `t/integration/commands-editing-buffer-read-only-test.lisp` | 18 | `t/integration/commands-editing-buffer-read-only-test.lisp` をrootに保持 |
| split: root + file-tree + files | `t/integration/commands-editing-file-test.lisp` | 112 | keybinding installation and uncreated-path open/save integration assertions (`:3-44`) → `t/integration/commands-editing-file-root-test.lisp`、existing-file load assertions (`:46-56`) → `packages/feature/file-tree/t/integration/commands-editing-find-file-test.lisp`、write/new-path/save assertions (`:58-112`) → `packages/feature/files/t/integration/commands-editing-save-file-test.lisp` |
| search | `t/integration/commands-editing-isearch-test.lisp` | 143 | `packages/feature/search/t/integration/commands-editing-isearch-test.lisp` |
| root cross-slice | `t/integration/commands-editing-minibuffer-keybinding-test.lisp` | 58 | `t/integration/commands-editing-minibuffer-keybinding-test.lisp` をrootに保持 |
| lifecycle | `t/integration/commands-editing-quit-test.lisp` | 99 | `packages/feature/lifecycle/t/integration/commands-editing-quit-test.lisp` |
| search | `t/integration/commands-editing-search-navigation-test.lisp` | 145 | `packages/feature/search/t/integration/commands-editing-search-navigation-test.lisp` |
| search | `t/integration/commands-editing-search-replace-test.lisp` | 72 | `packages/feature/search/t/integration/commands-editing-search-replace-test.lisp` |
| root test-support | `t/integration/commands-editing-test-support.lisp` | 16 | `t/integration/commands-editing-test-support.lisp` をrootに保持 |
| file-tree | `t/integration/commands-file-tree-mutation-test.lisp` | 74 | `packages/feature/file-tree/t/integration/commands-file-tree-mutation-test.lisp` |
| file-tree | `t/integration/commands-file-tree-navigation-test.lisp` | 129 | `packages/feature/file-tree/t/integration/commands-file-tree-navigation-test.lisp` |
| split: core/command + help | `t/integration/commands-help-test.lisp` | 98 | command completion, registry ordering, and help-summary assertions (`:3-82`) → `packages/core/command/t/integration/command-help-registry-test.lisp`、help command interaction and keybindings (`:83-98`) → `packages/feature/help/t/integration/commands-help-test.lisp` |
| core/command | `t/integration/commands-keybindings-test.lisp` | 85 | `packages/core/command/t/integration/commands-keybindings-test.lisp` |
| root cross-slice | `t/integration/commands-lsp-completion-popup-test.lisp` | 176 | `t/integration/commands-lsp-completion-popup-test.lisp` をrootに保持 |
| lsp | `t/integration/commands-lsp-definition-test.lisp` | 197 | `packages/feature/lsp/t/integration/commands-lsp-definition-test.lisp` |
| lsp | `t/integration/commands-lsp-navigation-test-support.lisp` | 51 | `packages/feature/lsp/t/integration/commands-lsp-navigation-test-support.lisp` |
| lsp | `t/integration/commands-lsp-navigation-test.lisp` | 127 | `packages/feature/lsp/t/integration/commands-lsp-navigation-test.lisp` |
| split: lifecycle + core/minibuffer | `t/integration/commands-misc-test.lisp` | 32 | quit-answer assertions (`:3-16`) → `packages/feature/lifecycle/t/integration/commands-quit-test.lisp`、keyboard-quit and minibuffer assertions (`:18-32`) → `packages/core/minibuffer/t/integration/commands-minibuffer-test.lisp` |
| root command integration | `t/integration/commands-movement-char-test.lisp` | 60 | `t/integration/commands-movement-char-test.lisp` をrootに保持 |
| root command integration | `t/integration/commands-movement-line-test.lisp` | 28 | `t/integration/commands-movement-line-test.lisp` をrootに保持 |
| root command integration | `t/integration/commands-movement-scroll-edit-test.lisp` | 53 | `t/integration/commands-movement-scroll-edit-test.lisp` をrootに保持 |
| root command integration | `t/integration/commands-movement-word-test.lisp` | 38 | `t/integration/commands-movement-word-test.lisp` をrootに保持 |
| root cross-slice | `t/integration/commands-prompt-cancellation-test.lisp` | 96 | `t/integration/commands-prompt-cancellation-test.lisp` をrootに保持 |
| split: lisp-structure + core/command | `t/integration/commands-sexp-test.lisp` | 126 | sexp motion/editing, including `kill-sexp`, assertions (`:3-117`) → `packages/feature/lisp-structure/t/integration/commands-sexp-test.lisp`、`key-event->descriptor` assertions (`:119-126`) → `packages/core/command/t/integration/key-event-descriptor-test.lisp` |
| lisp-structure | `t/integration/commands-structural-editing-test.lisp` | 164 | `packages/feature/lisp-structure/t/integration/commands-structural-editing-test.lisp` |
| root command integration | `t/integration/commands-test.lisp` | 1 | `t/integration/commands-test.lisp` をrootに保持 |
| split: window + buffers | `t/integration/commands-window-test.lisp` | 84 | window operation assertions (`:2-54`) → `packages/feature/window/t/integration/commands-window-test.lisp`、`switch-to-buffer` assertions (`:56-84`) → `packages/feature/buffers/t/integration/commands-switch-buffer-test.lisp` |
| file-tree | `t/integration/concurrent-runtime-invalidation-test.lisp` | 146 | `packages/feature/file-tree/t/integration/concurrent-runtime-invalidation-test.lisp` |
| file-tree | `t/integration/concurrent-runtime-prefetch-test.lisp` | 98 | `packages/feature/file-tree/t/integration/concurrent-runtime-prefetch-test.lisp` |
| file-tree | `t/integration/concurrent-runtime-shutdown-test.lisp` | 101 | `packages/feature/file-tree/t/integration/concurrent-runtime-shutdown-test.lisp` |
| file-tree | `t/integration/concurrent-runtime-stale-invalidation-test.lisp` | 72 | `packages/feature/file-tree/t/integration/concurrent-runtime-stale-invalidation-test.lisp` |
| file-tree | `t/integration/concurrent-runtime-stale-prime-test.lisp` | 50 | `packages/feature/file-tree/t/integration/concurrent-runtime-stale-prime-test.lisp` |
| file-tree | `t/integration/concurrent-runtime-submission-test.lisp` | 50 | `packages/feature/file-tree/t/integration/concurrent-runtime-submission-test.lisp` |
| file-tree | `t/integration/concurrent-runtime-test-support.lisp` | 49 | `packages/feature/file-tree/t/integration/concurrent-runtime-test-support.lisp` |
| root integration | `t/integration/editor-flow-test.lisp` | 35 | `t/integration/editor-flow-test.lisp` をrootに保持 |
| root presentation | `t/integration/frame-layout-cursor-test.lisp` | 241 | `t/integration/frame-layout-cursor-test.lisp` をrootに保持 |
| root presentation | `t/integration/frame-layout-test-support.lisp` | 28 | `t/integration/frame-layout-test-support.lisp` をrootに保持 |
| root presentation | `t/integration/frame-layout-test.lisp` | 109 | `t/integration/frame-layout-test.lisp` をrootに保持 |
| root presentation | `t/integration/frame-layout-wrapping-test.lisp` | 153 | `t/integration/frame-layout-wrapping-test.lisp` をrootに保持 |
| root integration | `t/integration/input-routing-keymap-test.lisp` | 102 | `t/integration/input-routing-keymap-test.lisp` をrootに保持 |
| root integration | `t/integration/input-routing-minibuffer-test.lisp` | 44 | `t/integration/input-routing-minibuffer-test.lisp` をrootに保持 |
| root integration | `t/integration/input-routing-test.lisp` | 167 | `t/integration/input-routing-test.lisp` をrootに保持 |
| keyboard-macro | `t/integration/keyboard-macro-test.lisp` | 181 | `packages/feature/keyboard-macro/t/integration/keyboard-macro-test.lisp` |
| kill-ring | `t/integration/kill-yank-region-test.lisp` | 63 | `packages/feature/kill-ring/t/integration/kill-yank-region-test.lisp` |
| kill-ring | `t/integration/kill-yank-test-support.lisp` | 14 | `packages/feature/kill-ring/t/integration/kill-yank-test-support.lisp` |
| kill-ring | `t/integration/kill-yank-test.lisp` | 120 | `packages/feature/kill-ring/t/integration/kill-yank-test.lisp` |
| kill-ring | `t/integration/kill-yank-yank-test.lisp` | 164 | `packages/feature/kill-ring/t/integration/kill-yank-yank-test.lisp` |
| root presentation | `t/integration/layout-isearch-test.lisp` | 220 | `t/integration/layout-isearch-test.lisp` をrootに保持 |
| root presentation | `t/integration/layout-secondary-test.lisp` | 355 | `t/integration/layout-secondary-test.lisp` をrootに保持 |
| root presentation | `t/integration/layout-test.lisp` | 350 | `t/integration/layout-test.lisp` をrootに保持 |
| lsp | `t/integration/lsp-command-diagnostics-format-test.lisp` | 46 | `packages/feature/lsp/t/integration/lsp-command-diagnostics-format-test.lisp` |
| lsp | `t/integration/lsp-command-diagnostics-render-test.lisp` | 56 | `packages/feature/lsp/t/integration/lsp-command-diagnostics-render-test.lisp` |
| lsp | `t/integration/lsp-command-diagnostics-state-test.lisp` | 28 | `packages/feature/lsp/t/integration/lsp-command-diagnostics-state-test.lisp` |
| lsp | `t/integration/lsp-command-start-discovery-test.lisp` | 272 | `packages/feature/lsp/t/integration/lsp-command-start-discovery-test.lisp` |
| lsp | `t/integration/lsp-command-start-test.lisp` | 170 | `packages/feature/lsp/t/integration/lsp-command-start-test.lisp` |
| lsp | `t/integration/lsp-completion-data-test.lisp` | 34 | `packages/feature/lsp/t/integration/lsp-completion-data-test.lisp` |
| lsp | `t/integration/lsp-discovery-test.lisp` | 88 | `packages/feature/lsp/t/integration/lsp-discovery-test.lisp` |
| lsp | `t/integration/lsp-session-diagnostics-test.lisp` | 117 | `packages/feature/lsp/t/integration/lsp-session-diagnostics-test.lisp` |
| lsp | `t/integration/lsp-session-lifecycle-error-test.lisp` | 96 | `packages/feature/lsp/t/integration/lsp-session-lifecycle-error-test.lisp` |
| lsp | `t/integration/lsp-session-lifecycle-initialize-test.lisp` | 50 | `packages/feature/lsp/t/integration/lsp-session-lifecycle-initialize-test.lisp` |
| lsp | `t/integration/lsp-session-lifecycle-stop-test.lisp` | 55 | `packages/feature/lsp/t/integration/lsp-session-lifecycle-stop-test.lisp` |
| lsp | `t/integration/lsp-session-lifecycle-transport-process-test.lisp` | 51 | `packages/feature/lsp/t/integration/lsp-session-lifecycle-transport-process-test.lisp` |
| lsp | `t/integration/lsp-session-lifecycle-transport-readers-test.lisp` | 73 | `packages/feature/lsp/t/integration/lsp-session-lifecycle-transport-readers-test.lisp` |
| lsp | `t/integration/lsp-session-lifecycle-transport-state-test.lisp` | 113 | `packages/feature/lsp/t/integration/lsp-session-lifecycle-transport-state-test.lisp` |
| lsp | `t/integration/lsp-session-lifecycle-transport-test.lisp` | 39 | `packages/feature/lsp/t/integration/lsp-session-lifecycle-transport-test.lisp` |
| lsp | `t/integration/lsp-session-paths-test.lisp` | 47 | `packages/feature/lsp/t/integration/lsp-session-paths-test.lisp` |
| root integration | `t/integration/main-cli-test.lisp` | 76 | `t/integration/main-cli-test.lisp` をrootに保持 |
| root integration | `t/integration/main-event-loop-input-test.lisp` | 206 | `t/integration/main-event-loop-input-test.lisp` をrootに保持 |
| root integration | `t/integration/main-initialize-test.lisp` | 70 | `t/integration/main-initialize-test.lisp` をrootに保持 |
| root integration | `t/integration/main-input-test.lisp` | 74 | `t/integration/main-input-test.lisp` をrootに保持 |
| root integration | `t/integration/main-run-loom-test.lisp` | 68 | `t/integration/main-run-loom-test.lisp` をrootに保持 |
| root integration | `t/integration/main-startup-test.lisp` | 173 | `t/integration/main-startup-test.lisp` をrootに保持 |
| root integration | `t/integration/main-terminal-size-test.lisp` | 96 | `t/integration/main-terminal-size-test.lisp` をrootに保持 |
| root test-support | `t/integration/main-test-support.lisp` | 26 | `t/integration/main-test-support.lisp` をrootに保持 |
| mode | `t/integration/major-mode-comment-line-test.lisp` | 103 | `packages/feature/mode/t/integration/major-mode-comment-line-test.lisp` |
| mode | `t/integration/major-mode-keymap-dispatch-test.lisp` | 88 | `packages/feature/mode/t/integration/major-mode-keymap-dispatch-test.lisp` |
| mode | `t/integration/major-mode-test.lisp` | 99 | `packages/feature/mode/t/integration/major-mode-test.lisp` |
| core/buffer | `t/integration/piece-table-model-test.lisp` | 88 | `packages/core/buffer/t/integration/piece-table-model-test.lisp` |
| core/command | `t/integration/prefix-argument-action-test.lisp` | 17 | `packages/core/command/t/integration/prefix-argument-action-test.lisp` |
| core/command | `t/integration/prefix-argument-dispatch-test.lisp` | 99 | `packages/core/command/t/integration/prefix-argument-dispatch-test.lisp` |
| split: core/command + keyboard-macro | `t/integration/prefix-argument-macro-test.lisp` | 58 | prefix-argument macro definition assertions (`:3-27`) → `packages/core/command/t/integration/prefix-argument-macro-test.lisp`、macro recording/replay assertions (`:29-58`) → `packages/feature/keyboard-macro/t/integration/prefix-argument-macro-test.lisp` |
| project | `t/integration/project-missing-root-test.lisp` | 40 | `packages/feature/project/t/integration/project-missing-root-test.lisp` |
| project | `t/integration/project-test.lisp` | 115 | `packages/feature/project/t/integration/project-test.lisp` |
| register | `t/integration/register-test.lisp` | 80 | `packages/feature/register/t/integration/register-test.lisp` |
| session | `t/integration/session-application-test.lisp` | 197 | `packages/feature/session/t/integration/session-application-test.lisp` |
| session | `t/integration/session-command-test.lisp` | 73 | `packages/feature/session/t/integration/session-command-test.lisp` |
| session | `t/integration/session-store-buffer-validation-test.lisp` | 148 | `packages/feature/session/t/integration/session-store-buffer-validation-test.lisp` |
| session | `t/integration/session-store-envelope-test.lisp` | 111 | `packages/feature/session/t/integration/session-store-envelope-test.lisp` |
| session | `t/integration/session-store-layout-validation-test.lisp` | 222 | `packages/feature/session/t/integration/session-store-layout-validation-test.lisp` |
| session | `t/integration/session-store-roundtrip-test.lisp` | 145 | `packages/feature/session/t/integration/session-store-roundtrip-test.lisp` |
| session | `t/integration/session-test-support.lisp` | 34 | `packages/feature/session/t/integration/session-test-support.lisp` |
| session | `t/integration/session-workspace-application-test.lisp` | 70 | `packages/feature/session/t/integration/session-workspace-application-test.lisp` |
| user-init | `t/integration/user-init-test.lisp` | 160 | `packages/feature/user-init/t/integration/user-init-test.lisp` |
| workspace | `t/integration/workspace-test.lisp` | 128 | `packages/feature/workspace/t/integration/workspace-test.lisp` |
| root test-support | `t/package.lisp` | 44 | `t/package.lisp` をrootに保持 |
| root test-support | `t/test-helpers-core.lisp` | 145 | `t/test-helpers-core.lisp` をrootに保持 |
| root test-support | `t/test-helpers-lsp.lisp` | 103 | `t/test-helpers-lsp.lisp` をrootに保持 |
| root test-support | `t/test-helpers-prompts.lisp` | 70 | `t/test-helpers-prompts.lisp` をrootに保持 |
| auto-save | `t/unit/auto-save-test.lisp` | 209 | `packages/feature/auto-save/t/unit/auto-save-test.lisp` |
| root gate | `t/unit/boundary-architecture-test.lisp` | 1490 | `t/unit/boundary-architecture-test.lisp` をrootに保持 |
| core/buffer | `t/unit/buffer-basic-test.lisp` | 84 | `packages/core/buffer/t/unit/buffer-basic-test.lisp` |
| core/buffer | `t/unit/buffer-delete-char-test.lisp` | 71 | `packages/core/buffer/t/unit/buffer-delete-char-test.lisp` |
| core/buffer | `t/unit/buffer-insert-test.lisp` | 42 | `packages/core/buffer/t/unit/buffer-insert-test.lisp` |
| core/buffer | `t/unit/buffer-read-only-test.lisp` | 26 | `packages/core/buffer/t/unit/buffer-read-only-test.lisp` |
| core/buffer | `t/unit/buffer-redo-test.lisp` | 35 | `packages/core/buffer/t/unit/buffer-redo-test.lisp` |
| core/buffer | `t/unit/buffer-region-test.lisp` | 83 | `packages/core/buffer/t/unit/buffer-region-test.lisp` |
| split: buffers + core/editor-session | `t/unit/buffer-registry-test.lisp` | 61 | registry behavior (`:3-31`) → `packages/feature/buffers/t/unit/buffer-registry-test.lisp`、stable-symbol slice re-registration (`:32-61`) → `packages/core/editor-session/t/unit/slice-state-registration-test.lisp` |
| core/buffer | `t/unit/buffer-storage-test.lisp` | 218 | `packages/core/buffer/t/unit/buffer-storage-test.lisp` |
| core/buffer | `t/unit/buffer-test-support.lisp` | 7 | `packages/core/buffer/t/unit/buffer-test-support.lisp` |
| core/buffer | `t/unit/buffer-undo-test.lisp` | 60 | `packages/core/buffer/t/unit/buffer-undo-test.lisp` |
| core/buffer | `t/unit/buffer-view-test.lisp` | 157 | `packages/core/buffer/t/unit/buffer-view-test.lisp` |
| root gate | `t/unit/cli-test.lisp` | 73 | `t/unit/cli-test.lisp` をrootに保持 |
| completion | `t/unit/completion-popup-test.lisp` | 52 | `packages/feature/completion/t/unit/completion-popup-test.lisp` |
| root gate | `t/unit/dependency-contract-test.lisp` | 149 | `t/unit/dependency-contract-test.lisp` をrootに保持 |
| split: bookmark + file-tree + files + kill-ring | `t/unit/editor-state-recent-files-test.lisp` | 95 | bookmark assertions (`:3-17`) → `packages/feature/bookmark/t/unit/editor-state-bookmarks-test.lisp`、recent-file completion adapter assertion (`:20-28`) → `packages/feature/file-tree/t/unit/editor-state-recent-file-completion-test.lisp`、recent-file state assertions (`:30-76`) → `packages/feature/files/t/unit/editor-state-recent-files-test.lisp`、yank tracking reset (`:78-95`) → `packages/feature/kill-ring/t/unit/editor-state-yank-reset-test.lisp` |
| split: core/editor-session + workspace + keyboard-macro | `t/unit/editor-state-test.lisp` | 50 | editor-state accessors and session/window invariant (`:3-47`, `:50`) → `packages/core/editor-session/t/unit/editor-state-test.lisp`; workspace defaults and supplied manager (`:49-50`) plus keyboard-macro default (`:49`) remain in the root test until batch 3, then move to `packages/feature/workspace/t/unit/editor-state-workspace-test.lisp` and `packages/feature/keyboard-macro/t/unit/editor-state-keyboard-macro-state-test.lisp` |
| core/editor-session | `t/unit/editor-session-api-test.lisp` | 286 | `packages/core/editor-session/t/unit/editor-session-api-test.lisp` |
| core/editor-session | `t/unit/frame-snapshot-test.lisp` | 170 | `packages/core/editor-session/t/unit/frame-snapshot-test.lisp` |
| core/editor-session | `t/unit/session-hook-test.lisp` | 1065 | `packages/core/editor-session/t/unit/session-hook-test.lisp` |
| evaluation | `t/unit/evaluation-result-test.lisp` | 29 | `packages/feature/evaluation/t/unit/evaluation-result-test.lisp` |
| evaluation | `t/unit/evaluation-test.lisp` | 110 | `packages/feature/evaluation/t/unit/evaluation-test.lisp` |
| file-tree | `t/unit/file-tree-selection-test.lisp` | 91 | `packages/feature/file-tree/t/unit/file-tree-selection-test.lisp` |
| file-tree | `t/unit/file-tree-test.lisp` | 153 | `packages/feature/file-tree/t/unit/file-tree-test.lisp` |
| file-tree | `t/unit/filesystem-create-test.lisp` | 120 | `packages/feature/file-tree/t/unit/filesystem-create-test.lisp` |
| file-tree | `t/unit/filesystem-delete-test.lisp` | 64 | `packages/feature/file-tree/t/unit/filesystem-delete-test.lisp` |
| file-tree | `t/unit/filesystem-directory-test.lisp` | 92 | `packages/feature/file-tree/t/unit/filesystem-directory-test.lisp` |
| file-tree | `t/unit/filesystem-listing-test.lisp` | 116 | `packages/feature/file-tree/t/unit/filesystem-listing-test.lisp` |
| file-tree | `t/unit/filesystem-rename-boundary-test.lisp` | 156 | `packages/feature/file-tree/t/unit/filesystem-rename-boundary-test.lisp` |
| file-tree | `t/unit/filesystem-test-support.lisp` | 47 | `packages/feature/file-tree/t/unit/filesystem-test-support.lisp` |
| format | `t/unit/format-test.lisp` | 261 | `packages/feature/format/t/unit/format-test.lisp` |
| git | `t/unit/git-file-operations-test.lisp` | 204 | `packages/feature/git/t/unit/git-file-operations-test.lisp` |
| git | `t/unit/git-test.lisp` | 211 | `packages/feature/git/t/unit/git-test.lisp` |
| search | `t/unit/isearch-test.lisp` | 105 | `packages/feature/search/t/unit/isearch-test.lisp` |
| keyboard-macro | `t/unit/keyboard-macro-test.lisp` | 75 | `packages/feature/keyboard-macro/t/unit/keyboard-macro-test.lisp` |
| core/command | `t/unit/keymap-lookup-test.lisp` | 81 | `packages/core/command/t/unit/keymap-lookup-test.lisp` |
| core/command | `t/unit/keymap-state-test.lisp` | 41 | `packages/core/command/t/unit/keymap-state-test.lisp` |
| core/command | `t/unit/keymap-test-support.lisp` | 4 | `packages/core/command/t/unit/keymap-test-support.lisp` |
| lsp | `t/unit/lsp-domain-values-test.lisp` | 113 | `packages/feature/lsp/t/unit/lsp-domain-values-test.lisp` |
| lsp | `t/unit/lsp-framing-test-support.lisp` | 25 | `packages/feature/lsp/t/unit/lsp-framing-test-support.lisp` |
| lsp | `t/unit/lsp-framing-test.lisp` | 175 | `packages/feature/lsp/t/unit/lsp-framing-test.lisp` |
| lsp | `t/unit/lsp-request-decode-test.lisp` | 186 | `packages/feature/lsp/t/unit/lsp-request-decode-test.lisp` |
| mode | `t/unit/major-mode-extension-test.lisp` | 162 | `packages/feature/mode/t/unit/major-mode-extension-test.lisp` |
| syntax-highlighting | `t/unit/major-mode-syntax-highlighting-test.lisp` | 87 | `packages/feature/syntax-highlighting/t/unit/major-mode-syntax-highlighting-test.lisp` |
| mode | `t/unit/major-mode-test.lisp` | 198 | `packages/feature/mode/t/unit/major-mode-test.lisp` |
| core/minibuffer | `t/unit/minibuffer-input-activation-test.lisp` | 152 | `packages/core/minibuffer/t/unit/minibuffer-input-activation-test.lisp` |
| core/minibuffer | `t/unit/minibuffer-input-classification-test.lisp` | 18 | `packages/core/minibuffer/t/unit/minibuffer-input-classification-test.lisp` |
| core/minibuffer | `t/unit/minibuffer-input-completion-test.lisp` | 112 | `packages/core/minibuffer/t/unit/minibuffer-input-completion-test.lisp` |
| core/minibuffer | `t/unit/minibuffer-input-history-test.lisp` | 39 | `packages/core/minibuffer/t/unit/minibuffer-input-history-test.lisp` |
| core/minibuffer | `t/unit/minibuffer-input-test-support.lisp` | 11 | `packages/core/minibuffer/t/unit/minibuffer-input-test-support.lisp` |
| core/minibuffer | `t/unit/minibuffer-test.lisp` | 73 | `packages/core/minibuffer/t/unit/minibuffer-test.lisp` |
| core/command | `t/unit/prefix-argument-test.lisp` | 94 | `packages/core/command/t/unit/prefix-argument-test.lisp` |
| project | `t/unit/project-test.lisp` | 104 | `packages/feature/project/t/unit/project-test.lisp` |
| root gate | `t/unit/protocol-test.lisp` | 7 | `t/unit/protocol-test.lisp` をrootに保持 |
| register | `t/unit/register-test.lisp` | 49 | `packages/feature/register/t/unit/register-test.lisp` |
| lisp-structure | `t/unit/sexp-motion-test.lisp` | 174 | `packages/feature/lisp-structure/t/unit/sexp-motion-test.lisp` |
| shell | `t/unit/shell-test.lisp` | 195 | `packages/feature/shell/t/unit/shell-test.lisp` |
| lisp-structure | `t/unit/structural-editing-test.lisp` | 124 | `packages/feature/lisp-structure/t/unit/structural-editing-test.lisp` |
| syntax-highlighting | `t/unit/syntax-highlighting-test.lisp` | 104 | `packages/feature/syntax-highlighting/t/unit/syntax-highlighting-test.lisp` |
| terminal | `t/unit/terminal-event-test.lisp` | 159 | `packages/feature/terminal/t/unit/terminal-event-test.lisp` |
| root presentation | `t/unit/terminal-renderer-cursor-test.lisp` | 47 | `t/unit/terminal-renderer-cursor-test.lisp` をrootに保持 |
| root presentation | `t/unit/terminal-renderer-test.lisp` | 302 | `t/unit/terminal-renderer-test.lisp` をrootに保持 |
| terminal | `t/unit/terminal-screen-basic-test.lisp` | 26 | `packages/feature/terminal/t/unit/terminal-screen-basic-test.lisp` |
| terminal | `t/unit/terminal-screen-control-test.lisp` | 228 | `packages/feature/terminal/t/unit/terminal-screen-control-test.lisp` |
| terminal | `t/unit/terminal-screen-cursor-test.lisp` | 67 | `packages/feature/terminal/t/unit/terminal-screen-cursor-test.lisp` |
| terminal | `t/unit/terminal-screen-validation-test.lisp` | 12 | `packages/feature/terminal/t/unit/terminal-screen-validation-test.lisp` |
| terminal | `t/unit/terminal-session-lifecycle-test.lisp` | 276 | `packages/feature/terminal/t/unit/terminal-session-lifecycle-test.lisp` |
| terminal | `t/unit/terminal-session-test.lisp` | 155 | `packages/feature/terminal/t/unit/terminal-session-test.lisp` |
| core/window-tree | `t/unit/window-basic-test.lisp` | 125 | `packages/core/window-tree/t/unit/window-basic-test.lisp` |
| core/window-tree | `t/unit/window-delete-behavior-test.lisp` | 51 | `packages/core/window-tree/t/unit/window-delete-behavior-test.lisp` |
| core/window-tree | `t/unit/window-delete-node-test.lisp` | 61 | `packages/core/window-tree/t/unit/window-delete-node-test.lisp` |
| core/window-tree | `t/unit/window-delete-other-windows-test.lisp` | 17 | `packages/core/window-tree/t/unit/window-delete-other-windows-test.lisp` |
| core/window-tree | `t/unit/window-layout-test.lisp` | 51 | `packages/core/window-tree/t/unit/window-layout-test.lisp` |
| workspace | `t/unit/workspace-navigation-test.lisp` | 65 | `packages/feature/workspace/t/unit/workspace-navigation-test.lisp` |
| workspace | `t/unit/workspace-test.lisp` | 155 | `packages/feature/workspace/t/unit/workspace-test.lisp` |

### 1.2 `packages/` 配下にすでにあるproduction source

以下のsourceは物理的に各slice directoryにあるものが大半であり、W2cではroot aggregateから各slice `.asd`へ唯一のASDF所有先を切り替える。例外は旧 `core/editor`、`feature/window`、`feature/file-tree` にあるsourceであり、移設先または分割先を個別に示す。LOCは現行root treeの物理行数である。

| owner | 現在のpath | LOC | W2c移設先 / 扱い |
|---|---|---:|---|
| core/buffer | `packages/core/buffer/src/domain-buffer-accessors.lisp` | 88 | `packages/core/buffer/src/domain-buffer-accessors.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-deletion.lisp` | 91 | `packages/core/buffer/src/domain-buffer-deletion.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-editing.lisp` | 15 | `packages/core/buffer/src/domain-buffer-editing.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-history.lisp` | 68 | `packages/core/buffer/src/domain-buffer-history.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-narrowing-support.lisp` | 81 | `packages/core/buffer/src/domain-buffer-narrowing-support.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-narrowing.lisp` | 77 | `packages/core/buffer/src/domain-buffer-narrowing.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-piece-table-coalescing.lisp` | 28 | `packages/core/buffer/src/domain-buffer-piece-table-coalescing.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-piece-table-position.lisp` | 72 | `packages/core/buffer/src/domain-buffer-piece-table-position.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-piece-table-splicing.lisp` | 66 | `packages/core/buffer/src/domain-buffer-piece-table-splicing.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-piece-table-support.lisp` | 58 | `packages/core/buffer/src/domain-buffer-piece-table-support.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-piece-table-undo.lisp` | 28 | `packages/core/buffer/src/domain-buffer-piece-table-undo.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-piece-table.lisp` | 63 | `packages/core/buffer/src/domain-buffer-piece-table.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-positions.lisp` | 51 | `packages/core/buffer/src/domain-buffer-positions.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-storage-support.lisp` | 17 | `packages/core/buffer/src/domain-buffer-storage-support.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer-storage.lisp` | 88 | `packages/core/buffer/src/domain-buffer-storage.lisp` |
| core/buffer | `packages/core/buffer/src/domain-buffer.lisp` | 97 | `packages/core/buffer/src/domain-buffer.lisp` |
| core/buffer | `packages/core/buffer/src/package.lisp` | 60 | `packages/core/buffer/src/package.lisp` |
| core/command | `packages/core/command/src/command-invocation.lisp` | 167 | `packages/core/command/src/command-invocation.lisp` |
| core/command | `packages/core/command/src/command-registry-build.lisp` | 111 | `packages/core/command/src/command-registry-build.lisp` |
| core/command | `packages/core/command/src/command-registry-forms.lisp` | 84 | `packages/core/command/src/command-registry-forms.lisp` |
| core/command | `packages/core/command/src/command-registry.lisp` | 144 | `packages/core/command/src/command-registry.lisp` |
| core/command | `packages/core/command/src/command-repeat.lisp` | 10 | `packages/core/command/src/command-repeat.lisp` |
| core/command | `packages/core/command/src/commands-keybinding-spec.lisp` | 47 | `packages/core/command/src/commands-keybinding-spec.lisp` |
| core/command | `packages/core/command/src/commands-keybindings.lisp` | 7 | `packages/core/command/src/commands-keybindings.lisp` |
| core/command | `packages/core/command/src/domain-key-event-descriptor.lisp` | 43 | `packages/core/command/src/domain-key-event-descriptor.lisp` |
| core/command | `packages/core/command/src/domain-keymap-descriptor.lisp` | 10 | `packages/core/command/src/domain-keymap-descriptor.lisp` |
| core/command | `packages/core/command/src/domain-keymap-state.lisp` | 74 | `packages/core/command/src/domain-keymap-state.lisp` |
| core/command | `packages/core/command/src/domain-keymap.lisp` | 97 | `packages/core/command/src/domain-keymap.lisp` |
| core/command | `packages/core/command/src/domain-prefix-argument.lisp` | 66 | `packages/core/command/src/domain-prefix-argument.lisp` |
| core/command | `packages/core/command/src/package.lisp` | 72 | `packages/core/command/src/package.lisp` |
| core/editor-session | `packages/core/editor-session/src/application-commands-movement-visual-lines.lisp` | 158 | `packages/core/editor-session/src/application-commands-movement-visual-lines.lisp` |
| core/editor-session | `packages/core/editor-session/src/application-session-hooks.lisp` | 368 | `packages/core/editor-session/src/application-session-hooks.lisp` |
| core/editor-session | `packages/core/editor-session/src/application-session-extension-points.lisp` | 335 | `packages/core/editor-session/src/application-session-extension-points.lisp` |
| core/editor-session | `packages/core/editor-session/src/application-session-hit-test-clipboard.lisp` | 161 | `packages/core/editor-session/src/application-session-hit-test-clipboard.lisp` |
| core/editor-session | `packages/core/editor-session/src/application-editor-state-support.lisp` | 40 | `packages/core/editor-session/src/application-editor-state-support.lisp` |
| core/editor-session | `packages/core/editor-session/src/application-editor-state-types.lisp` | 73 | `packages/core/editor-session/src/application-editor-state-types.lisp` |
| core/editor-session | `packages/core/editor-session/src/application-editor-state.lisp` | 25 | `packages/core/editor-session/src/application-editor-state.lisp` |
| core/editor-session | `packages/core/editor-session/src/domain-editor-session-slices.lisp` | 85 | `packages/core/editor-session/src/domain-editor-session-slices.lisp` |
| core/editor-session | `packages/core/editor-session/src/package.lisp` | 118 | `packages/core/editor-session/src/package.lisp` |
| core/buffer | `packages/core/editor/src/application-commands-editing-support.lisp` | 21 | `packages/core/buffer/src/application-commands-editing-support.lisp` |
| core/buffer | `packages/core/editor/src/application-commands-editing.lisp` | 19 | `packages/core/buffer/src/application-commands-editing.lisp` |
| kill-ring | `packages/core/editor/src/application-commands-kill-region-support.lisp` | 50 | `packages/feature/kill-ring/src/application-commands-kill-region-support.lisp` |
| kill-ring | `packages/core/editor/src/application-commands-kill-support.lisp` | 91 | `packages/feature/kill-ring/src/application-commands-kill-support.lisp` |
| kill-ring | `packages/core/editor/src/application-commands-kill-word-support.lisp` | 60 | `packages/feature/kill-ring/src/application-commands-kill-word-support.lisp` |
| core/command | `packages/core/editor/src/application-commands-kill.lisp` | 24 | `packages/core/command/src/application-commands-kill.lisp`（batch 2でword-motion helperと一緒に移す） |
| core/command | `packages/core/editor/src/application-commands-movement-support.lisp` | 72 | `packages/core/command/src/application-commands-movement-support.lisp`（batch 2でword-motion helperと一緒に移す） |
| core/buffer | `packages/core/editor/src/application-commands-movement-view-support.lisp` | 36 | `packages/core/buffer/src/application-commands-movement-view-support.lisp` |
| core/buffer | `packages/core/editor/src/application-commands-movement.lisp` | 52 | `packages/core/buffer/src/application-commands-movement.lisp` |
| core/command | `packages/core/editor/src/application-commands-prefix-argument-support.lisp` | 22 | `packages/core/command/src/application-commands-prefix-argument-support.lisp` |
| core/command | `packages/core/editor/src/application-commands-prefix-argument.lisp` | 8 | `packages/core/command/src/application-commands-prefix-argument.lisp` |
| core/buffer | `packages/core/editor/src/application-commands-region-support.lisp` | 79 | `packages/core/buffer/src/application-commands-region-support.lisp` |
| core/buffer | `packages/core/editor/src/application-commands-region.lisp` | 33 | `packages/core/buffer/src/application-commands-region.lisp`（`set-mark-command`、`exchange-point-and-mark`、`mark-whole-buffer`、`narrow-to-region`、`widen`、`toggle-read-only`、`undo-command`、`redo-command`; source `:3-33`） |
| lisp-structure | `packages/core/editor/src/application-commands-sexp.lisp` | 69 | `packages/feature/lisp-structure/src/application-commands-sexp.lisp` |
| lisp-structure | `packages/core/editor/src/application-commands-structural-editing.lisp` | 73 | `packages/feature/lisp-structure/src/application-commands-structural-editing.lisp` |
| kill-ring | `packages/core/editor/src/application-commands-yank-pop-support.lisp` | 97 | `packages/feature/kill-ring/src/application-commands-yank-pop-support.lisp` |
| kill-ring | `packages/core/editor/src/application-commands-yank-support.lisp` | 26 | `packages/feature/kill-ring/src/application-commands-yank-support.lisp` |
| kill-ring | `packages/core/editor/src/application-commands-yank.lisp` | 25 | `packages/feature/kill-ring/src/application-commands-yank.lisp` |
| lisp-structure | `packages/core/editor/src/application-sexp-motion-support.lisp` | 91 | `packages/feature/lisp-structure/src/application-sexp-motion-support.lisp` |
| lisp-structure | `packages/core/editor/src/application-sexp-motion-tokens.lisp` | 46 | `packages/feature/lisp-structure/src/application-sexp-motion-tokens.lisp` |
| lisp-structure | `packages/core/editor/src/application-sexp-motion.lisp` | 87 | `packages/feature/lisp-structure/src/application-sexp-motion.lisp` |
| lisp-structure | `packages/core/editor/src/application-sexp-syntax.lisp` | 107 | `packages/feature/lisp-structure/src/application-sexp-syntax.lisp` |
| lisp-structure | `packages/core/editor/src/application-structural-editing-application.lisp` | 33 | `packages/feature/lisp-structure/src/application-structural-editing-application.lisp` |
| lisp-structure | `packages/core/editor/src/application-structural-editing-offsets.lisp` | 24 | `packages/feature/lisp-structure/src/application-structural-editing-offsets.lisp` |
| lisp-structure | `packages/core/editor/src/application-structural-editing-support.lisp` | 46 | `packages/feature/lisp-structure/src/application-structural-editing-support.lisp` |
| lisp-structure | `packages/core/editor/src/application-structural-editing.lisp` | 116 | `packages/feature/lisp-structure/src/application-structural-editing.lisp` |
| core/command | `packages/core/editor/src/application-word-motion.lisp` | 25 | `packages/core/command/src/application-word-motion.lisp`（callerと一緒にbatch 2で移す） |
| core/minibuffer | `packages/core/minibuffer/src/commands-prompts.lisp` | 35 | `packages/core/minibuffer/src/commands-prompts.lisp` |
| core/minibuffer | `packages/core/minibuffer/src/minibuffer-activation.lisp` | 72 | `packages/core/minibuffer/src/minibuffer-activation.lisp` |
| core/minibuffer | `packages/core/minibuffer/src/minibuffer-completion.lisp` | 60 | `packages/core/minibuffer/src/minibuffer-completion.lisp` |
| core/minibuffer | `packages/core/minibuffer/src/minibuffer-history.lisp` | 27 | `packages/core/minibuffer/src/minibuffer-history.lisp` |
| core/minibuffer | `packages/core/minibuffer/src/minibuffer-input.lisp` | 137 | `packages/core/minibuffer/src/minibuffer-input.lisp` |
| core/minibuffer | `packages/core/minibuffer/src/minibuffer.lisp` | 41 | `packages/core/minibuffer/src/minibuffer.lisp` |
| core/minibuffer | `packages/core/minibuffer/src/package.lisp` | 18 | `packages/core/minibuffer/src/package.lisp` |
| core/window-tree | `packages/core/window-tree/src/domain-window-accessors.lisp` | 19 | `packages/core/window-tree/src/domain-window-accessors.lisp` |
| core/window-tree | `packages/core/window-tree/src/domain-window-deletion.lisp` | 73 | `packages/core/window-tree/src/domain-window-deletion.lisp` |
| core/window-tree | `packages/core/window-tree/src/domain-window-layout.lisp` | 85 | `packages/core/window-tree/src/domain-window-layout.lisp` |
| core/window-tree | `packages/core/window-tree/src/domain-window-operations.lisp` | 106 | `packages/core/window-tree/src/domain-window-operations.lisp` |
| core/window-tree | `packages/core/window-tree/src/domain-window-support.lisp` | 44 | `packages/core/window-tree/src/domain-window-support.lisp` |
| core/window-tree | `packages/core/window-tree/src/domain-window.lisp` | 45 | `packages/core/window-tree/src/domain-window.lisp` |
| core/window-tree | `packages/core/window-tree/src/package.lisp` | 27 | `packages/core/window-tree/src/package.lisp` |
| auto-save | `packages/feature/auto-save/src/application-auto-save-support.lisp` | 77 | `packages/feature/auto-save/src/application-auto-save-support.lisp` |
| auto-save | `packages/feature/auto-save/src/application-commands-auto-save.lisp` | 45 | `packages/feature/auto-save/src/application-commands-auto-save.lisp` |
| auto-save | `packages/feature/auto-save/src/domain-auto-save.lisp` | 24 | `packages/feature/auto-save/src/domain-auto-save.lisp` |
| auto-save | `packages/feature/auto-save/src/infrastructure-auto-save.lisp` | 37 | `packages/feature/auto-save/src/infrastructure-auto-save.lisp` |
| auto-save | `packages/feature/auto-save/src/package.lisp` | 35 | `packages/feature/auto-save/src/package.lisp` |
| bookmark | `packages/feature/bookmark/src/domain-editor-bookmark.lisp` | 11 | `packages/feature/bookmark/src/domain-editor-bookmark.lisp` |
| bookmark | `packages/feature/bookmark/src/package.lisp` | 11 | `packages/feature/bookmark/src/package.lisp` |
| buffers | `packages/feature/buffers/src/application-commands-buffer.lisp` | 46 | `packages/feature/buffers/src/application-commands-buffer.lisp` |
| buffers | `packages/feature/buffers/src/application-window-buffer-support.lisp` | 58 | `packages/feature/buffers/src/application-window-buffer-support.lisp` |
| buffers | `packages/feature/buffers/src/domain-buffer-registry.lisp` | 36 | `packages/feature/buffers/src/domain-buffer-registry.lisp` |
| buffers | `packages/feature/buffers/src/package.lisp` | 29 | `packages/feature/buffers/src/package.lisp` |
| clipboard | `packages/feature/clipboard/src/package.lisp` | 2 | `packages/feature/clipboard/src/package.lisp` |
| completion | `packages/feature/completion/src/package.lisp` | 2 | `packages/feature/completion/src/package.lisp` |
| evaluation | `packages/feature/evaluation/src/application-commands-evaluation.lisp` | 81 | `packages/feature/evaluation/src/application-commands-evaluation.lisp` |
| evaluation | `packages/feature/evaluation/src/domain-evaluation.lisp` | 53 | `packages/feature/evaluation/src/domain-evaluation.lisp` |
| evaluation | `packages/feature/evaluation/src/infrastructure-lisp-evaluator.lisp` | 90 | `packages/feature/evaluation/src/infrastructure-lisp-evaluator.lisp` |
| evaluation | `packages/feature/evaluation/src/package.lisp` | 36 | `packages/feature/evaluation/src/package.lisp` |
| files | `packages/feature/file-tree/src/application-commands-file-save.lisp` | 88 | `packages/feature/files/src/application-commands-file-save.lisp` |
| file-tree | `packages/feature/file-tree/src/application-commands-file-tree.lisp` | 95 | `packages/feature/file-tree/src/application-commands-file-tree.lisp` |
| files | `packages/feature/file-tree/src/application-commands-file.lisp` | 99 | `packages/feature/files/src/application-commands-file.lisp` |
| file-tree | `packages/feature/file-tree/src/domain-file-tree-navigation.lisp` | 122 | `packages/feature/file-tree/src/domain-file-tree-navigation.lisp` |
| file-tree | `packages/feature/file-tree/src/domain-file-tree.lisp` | 45 | `packages/feature/file-tree/src/domain-file-tree.lisp` |
| files | `packages/feature/file-tree/src/infrastructure-buffer-filesystem.lisp` | 34 | `packages/feature/files/src/infrastructure-buffer-filesystem.lisp` |
| file-tree | `packages/feature/file-tree/src/infrastructure-concurrent-runtime-prefetch.lisp` | 86 | `packages/feature/file-tree/src/infrastructure-concurrent-runtime-prefetch.lisp` |
| file-tree | `packages/feature/file-tree/src/infrastructure-concurrent-runtime-results.lisp` | 62 | `packages/feature/file-tree/src/infrastructure-concurrent-runtime-results.lisp` |
| file-tree | `packages/feature/file-tree/src/infrastructure-concurrent-runtime-state.lisp` | 89 | `packages/feature/file-tree/src/infrastructure-concurrent-runtime-state.lisp` |
| file-tree | `packages/feature/file-tree/src/infrastructure-file-tree-directory-listing.lisp` | 35 | `packages/feature/file-tree/src/infrastructure-file-tree-directory-listing.lisp` |
| file-tree | `packages/feature/file-tree/src/infrastructure-file-tree-filesystem-support.lisp` | 39 | `packages/feature/file-tree/src/infrastructure-file-tree-filesystem-support.lisp` |
| file-tree | `packages/feature/file-tree/src/infrastructure-file-tree-filesystem.lisp` | 65 | `packages/feature/file-tree/src/infrastructure-file-tree-filesystem.lisp` |
| file-tree | `packages/feature/file-tree/src/infrastructure-filesystem-native-delete.lisp` | 40 | `packages/feature/file-tree/src/infrastructure-filesystem-native-delete.lisp` |
| files | `packages/feature/file-tree/src/infrastructure-filesystem-native-io.lisp` | 44 | `packages/feature/files/src/infrastructure-filesystem-native-io.lisp` |
| file-tree | `packages/feature/file-tree/src/infrastructure-filesystem-native-mutations.lisp` | 41 | `packages/feature/file-tree/src/infrastructure-filesystem-native-mutations.lisp` |
| files | `packages/feature/file-tree/src/infrastructure-filesystem-native-paths.lisp` | 58 | `packages/feature/files/src/infrastructure-filesystem-native-paths.lisp` |
| file-tree | `packages/feature/file-tree/src/package.lisp` | 72 | `packages/feature/file-tree/src/package.lisp` |
| files | `packages/feature/files/src/package.lisp` | 2 | `packages/feature/files/src/package.lisp` |
| format | `packages/feature/format/src/application-commands-format.lisp` | 109 | `packages/feature/format/src/application-commands-format.lisp` |
| format | `packages/feature/format/src/application-format-buffer.lisp` | 73 | `packages/feature/format/src/application-format-buffer.lisp` |
| format | `packages/feature/format/src/package.lisp` | 38 | `packages/feature/format/src/package.lisp` |
| git | `packages/feature/git/src/application-commands-git-support.lisp` | 127 | `packages/feature/git/src/application-commands-git-support.lisp` |
| git | `packages/feature/git/src/application-commands-git.lisp` | 45 | `packages/feature/git/src/application-commands-git.lisp` |
| git | `packages/feature/git/src/domain-git.lisp` | 9 | `packages/feature/git/src/domain-git.lisp` |
| git | `packages/feature/git/src/infrastructure-git.lisp` | 41 | `packages/feature/git/src/infrastructure-git.lisp` |
| git | `packages/feature/git/src/package.lisp` | 41 | `packages/feature/git/src/package.lisp` |
| help | `packages/feature/help/src/package.lisp` | 2 | `packages/feature/help/src/package.lisp` |
| keyboard-macro | `packages/feature/keyboard-macro/src/application-commands-keyboard-macro.lisp` | 113 | `packages/feature/keyboard-macro/src/application-commands-keyboard-macro.lisp` |
| keyboard-macro | `packages/feature/keyboard-macro/src/domain-keyboard-macro.lisp` | 90 | `packages/feature/keyboard-macro/src/domain-keyboard-macro.lisp` |
| keyboard-macro | `packages/feature/keyboard-macro/src/package.lisp` | 48 | `packages/feature/keyboard-macro/src/package.lisp` |
| kill-ring | `packages/feature/kill-ring/src/package.lisp` | 2 | `packages/feature/kill-ring/src/package.lisp` |
| lang-lisp | `packages/feature/lang-lisp/src/package.lisp` | 2 | `packages/feature/lang-lisp/src/package.lisp` |
| lang-markup | `packages/feature/lang-markup/src/package.lisp` | 2 | `packages/feature/lang-markup/src/package.lisp` |
| lang-nix | `packages/feature/lang-nix/src/package.lisp` | 2 | `packages/feature/lang-nix/src/package.lisp` |
| lang-web | `packages/feature/lang-web/src/package.lisp` | 2 | `packages/feature/lang-web/src/package.lisp` |
| lifecycle | `packages/feature/lifecycle/src/package.lisp` | 2 | `packages/feature/lifecycle/src/package.lisp` |
| lisp-structure | `packages/feature/lisp-structure/src/package.lisp` | 2 | `packages/feature/lisp-structure/src/package.lisp` |
| lsp | `packages/feature/lsp/src/application-commands-lsp-completion.lisp` | 85 | `packages/feature/lsp/src/application-commands-lsp-completion.lisp` |
| lsp | `packages/feature/lsp/src/application-commands-lsp-context.lisp` | 33 | `packages/feature/lsp/src/application-commands-lsp-context.lisp` |
| lsp | `packages/feature/lsp/src/application-commands-lsp-navigation.lisp` | 82 | `packages/feature/lsp/src/application-commands-lsp-navigation.lisp` |
| lsp | `packages/feature/lsp/src/application-commands-lsp-support.lisp` | 102 | `packages/feature/lsp/src/application-commands-lsp-support.lisp` |
| lsp | `packages/feature/lsp/src/application-commands-lsp.lisp` | 84 | `packages/feature/lsp/src/application-commands-lsp.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-diagnostic-decode.lisp` | 65 | `packages/feature/lsp/src/application-lsp-diagnostic-decode.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-diagnostics-view.lisp` | 53 | `packages/feature/lsp/src/application-lsp-diagnostics-view.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-protocol-helpers.lisp` | 29 | `packages/feature/lsp/src/application-lsp-protocol-helpers.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-protocol-initialize.lisp` | 41 | `packages/feature/lsp/src/application-lsp-protocol-initialize.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-protocol-receive.lisp` | 36 | `packages/feature/lsp/src/application-lsp-protocol-receive.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-protocol-responses.lisp` | 81 | `packages/feature/lsp/src/application-lsp-protocol-responses.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-protocol-routing.lisp` | 38 | `packages/feature/lsp/src/application-lsp-protocol-routing.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-protocol-send.lisp` | 22 | `packages/feature/lsp/src/application-lsp-protocol-send.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-request-decode.lisp` | 87 | `packages/feature/lsp/src/application-lsp-request-decode.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-requests.lisp` | 87 | `packages/feature/lsp/src/application-lsp-requests.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-session-lifecycle.lisp` | 84 | `packages/feature/lsp/src/application-lsp-session-lifecycle.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-session-state.lisp` | 58 | `packages/feature/lsp/src/application-lsp-session-state.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-session-sync.lisp` | 70 | `packages/feature/lsp/src/application-lsp-session-sync.lisp` |
| lsp | `packages/feature/lsp/src/application-lsp-session-uri.lisp` | 69 | `packages/feature/lsp/src/application-lsp-session-uri.lisp` |
| lsp | `packages/feature/lsp/src/domain-lsp.lisp` | 82 | `packages/feature/lsp/src/domain-lsp.lisp` |
| lsp | `packages/feature/lsp/src/infrastructure-lsp-discovery.lisp` | 56 | `packages/feature/lsp/src/infrastructure-lsp-discovery.lisp` |
| lsp | `packages/feature/lsp/src/infrastructure-lsp-framing-support.lisp` | 90 | `packages/feature/lsp/src/infrastructure-lsp-framing-support.lisp` |
| lsp | `packages/feature/lsp/src/infrastructure-lsp-framing.lisp` | 51 | `packages/feature/lsp/src/infrastructure-lsp-framing.lisp` |
| lsp | `packages/feature/lsp/src/infrastructure-lsp-headers.lisp` | 83 | `packages/feature/lsp/src/infrastructure-lsp-headers.lisp` |
| lsp | `packages/feature/lsp/src/infrastructure-lsp-transport-support.lisp` | 49 | `packages/feature/lsp/src/infrastructure-lsp-transport-support.lisp` |
| lsp | `packages/feature/lsp/src/infrastructure-lsp-transport.lisp` | 124 | `packages/feature/lsp/src/infrastructure-lsp-transport.lisp` |
| lsp | `packages/feature/lsp/src/package.lisp` | 104 | `packages/feature/lsp/src/package.lisp` |
| minibuffer-ui | `packages/feature/minibuffer-ui/src/package.lisp` | 2 | `packages/feature/minibuffer-ui/src/package.lisp` |
| mode | `packages/feature/mode/src/application-major-mode-editing.lisp` | 99 | `packages/feature/mode/src/application-major-mode-editing.lisp` |
| mode | `packages/feature/mode/src/application-major-mode-support.lisp` | 53 | `packages/feature/mode/src/application-major-mode-support.lisp` |
| mode | `packages/feature/mode/src/application-major-mode.lisp` | 49 | `packages/feature/mode/src/application-major-mode.lisp` |
| mode | `packages/feature/mode/src/domain-major-mode-definitions.lisp` | 134 | `packages/feature/mode/src/domain-major-mode-definitions.lisp` |
| mode | `packages/feature/mode/src/domain-major-mode-keywords.lisp` | 13 | `packages/feature/mode/src/domain-major-mode-keywords.lisp` |
| mode | `packages/feature/mode/src/domain-major-mode-path.lisp` | 69 | `packages/feature/mode/src/domain-major-mode-path.lisp` |
| mode | `packages/feature/mode/src/domain-major-mode-registry-support.lisp` | 66 | `packages/feature/mode/src/domain-major-mode-registry-support.lisp` |
| mode | `packages/feature/mode/src/domain-major-mode-registry.lisp` | 99 | `packages/feature/mode/src/domain-major-mode-registry.lisp` |
| mode | `packages/feature/mode/src/domain-major-mode.lisp` | 92 | `packages/feature/mode/src/domain-major-mode.lisp` |
| mode | `packages/feature/mode/src/package.lisp` | 53 | `packages/feature/mode/src/package.lisp` |
| mouse | `packages/feature/mouse/src/package.lisp` | 2 | `packages/feature/mouse/src/package.lisp` |
| project | `packages/feature/project/src/application-commands-project.lisp` | 96 | `packages/feature/project/src/application-commands-project.lisp` |
| project | `packages/feature/project/src/domain-project.lisp` | 77 | `packages/feature/project/src/domain-project.lisp` |
| project | `packages/feature/project/src/infrastructure-project-filesystem.lisp` | 69 | `packages/feature/project/src/infrastructure-project-filesystem.lisp` |
| project | `packages/feature/project/src/package.lisp` | 32 | `packages/feature/project/src/package.lisp` |
| register | `packages/feature/register/src/application-commands-register.lisp` | 96 | `packages/feature/register/src/application-commands-register.lisp` |
| register | `packages/feature/register/src/domain-register.lisp` | 62 | `packages/feature/register/src/domain-register.lisp` |
| register | `packages/feature/register/src/package.lisp` | 36 | `packages/feature/register/src/package.lisp` |
| search | `packages/feature/search/src/application-commands-isearch.lisp` | 139 | `packages/feature/search/src/application-commands-isearch.lisp` |
| search | `packages/feature/search/src/application-commands-search.lisp` | 78 | `packages/feature/search/src/application-commands-search.lisp` |
| search | `packages/feature/search/src/domain-buffer-search.lisp` | 90 | `packages/feature/search/src/domain-buffer-search.lisp` |
| search | `packages/feature/search/src/domain-isearch.lisp` | 106 | `packages/feature/search/src/domain-isearch.lisp` |
| search | `packages/feature/search/src/package.lisp` | 42 | `packages/feature/search/src/package.lisp` |
| session | `packages/feature/session/src/application-commands-session.lisp` | 42 | `packages/feature/session/src/application-commands-session.lisp` |
| session | `packages/feature/session/src/application-session-bookmarks.lisp` | 74 | `packages/feature/session/src/application-session-bookmarks.lisp` |
| session | `packages/feature/session/src/application-session-restore.lisp` | 68 | `packages/feature/session/src/application-session-restore.lisp` |
| session | `packages/feature/session/src/application-session-snapshot.lisp` | 62 | `packages/feature/session/src/application-session-snapshot.lisp` |
| session | `packages/feature/session/src/application-session-workspaces.lisp` | 76 | `packages/feature/session/src/application-session-workspaces.lisp` |
| session | `packages/feature/session/src/domain-session-predicates.lisp` | 17 | `packages/feature/session/src/domain-session-predicates.lisp` |
| session | `packages/feature/session/src/domain-session-snapshot.lisp` | 43 | `packages/feature/session/src/domain-session-snapshot.lisp` |
| session | `packages/feature/session/src/domain-session-validation-layout.lisp` | 74 | `packages/feature/session/src/domain-session-validation-layout.lisp` |
| session | `packages/feature/session/src/domain-session-validation-metadata.lisp` | 89 | `packages/feature/session/src/domain-session-validation-metadata.lisp` |
| session | `packages/feature/session/src/domain-session-validation.lisp` | 18 | `packages/feature/session/src/domain-session-validation.lisp` |
| session | `packages/feature/session/src/infrastructure-session-codec-plist.lisp` | 105 | `packages/feature/session/src/infrastructure-session-codec-plist.lisp` |
| session | `packages/feature/session/src/infrastructure-session-codec.lisp` | 59 | `packages/feature/session/src/infrastructure-session-codec.lisp` |
| session | `packages/feature/session/src/infrastructure-session-store.lisp` | 72 | `packages/feature/session/src/infrastructure-session-store.lisp` |
| session | `packages/feature/session/src/package.lisp` | 75 | `packages/feature/session/src/package.lisp` |
| shell | `packages/feature/shell/src/application-commands-shell.lisp` | 85 | `packages/feature/shell/src/application-commands-shell.lisp` |
| shell | `packages/feature/shell/src/domain-shell.lisp` | 42 | `packages/feature/shell/src/domain-shell.lisp` |
| shell | `packages/feature/shell/src/infrastructure-shell.lisp` | 74 | `packages/feature/shell/src/infrastructure-shell.lisp` |
| shell | `packages/feature/shell/src/package.lisp` | 37 | `packages/feature/shell/src/package.lisp` |
| syntax-highlighting | `packages/feature/syntax-highlighting/src/domain-syntax-highlighting-common-lisp.lisp` | 93 | `packages/feature/syntax-highlighting/src/domain-syntax-highlighting-common-lisp.lisp` |
| syntax-highlighting | `packages/feature/syntax-highlighting/src/domain-syntax-highlighting-generic.lisp` | 93 | `packages/feature/syntax-highlighting/src/domain-syntax-highlighting-generic.lisp` |
| syntax-highlighting | `packages/feature/syntax-highlighting/src/domain-syntax-highlighting.lisp` | 70 | `packages/feature/syntax-highlighting/src/domain-syntax-highlighting.lisp` |
| syntax-highlighting | `packages/feature/syntax-highlighting/src/package.lisp` | 21 | `packages/feature/syntax-highlighting/src/package.lisp` |
| syntax-highlighting | `packages/feature/syntax-highlighting/src/presentation-syntax-highlighting.lisp` | 129 | `packages/feature/syntax-highlighting/src/presentation-syntax-highlighting.lisp` |
| terminal | `packages/feature/terminal/src/application-commands-terminal.lisp` | 45 | `packages/feature/terminal/src/application-commands-terminal.lisp` |
| terminal | `packages/feature/terminal/src/application-terminal-input-support.lisp` | 98 | `packages/feature/terminal/src/application-terminal-input-support.lisp` |
| terminal | `packages/feature/terminal/src/application-terminal-input.lisp` | 32 | `packages/feature/terminal/src/application-terminal-input.lisp` |
| terminal | `packages/feature/terminal/src/domain-terminal-csi-cursor.lisp` | 79 | `packages/feature/terminal/src/domain-terminal-csi-cursor.lisp` |
| terminal | `packages/feature/terminal/src/domain-terminal-csi-edit.lisp` | 40 | `packages/feature/terminal/src/domain-terminal-csi-edit.lisp` |
| terminal | `packages/feature/terminal/src/domain-terminal-csi-screen-operations.lisp` | 73 | `packages/feature/terminal/src/domain-terminal-csi-screen-operations.lisp` |
| terminal | `packages/feature/terminal/src/domain-terminal-parser-csi.lisp` | 53 | `packages/feature/terminal/src/domain-terminal-parser-csi.lisp` |
| terminal | `packages/feature/terminal/src/domain-terminal-parser.lisp` | 156 | `packages/feature/terminal/src/domain-terminal-parser.lisp` |
| terminal | `packages/feature/terminal/src/domain-terminal-screen-operations.lisp` | 72 | `packages/feature/terminal/src/domain-terminal-screen-operations.lisp` |
| terminal | `packages/feature/terminal/src/domain-terminal-screen-state.lisp` | 104 | `packages/feature/terminal/src/domain-terminal-screen-state.lisp` |
| terminal | `packages/feature/terminal/src/domain-terminal-session.lisp` | 28 | `packages/feature/terminal/src/domain-terminal-session.lisp` |
| terminal | `packages/feature/terminal/src/domain-terminal-support.lisp` | 27 | `packages/feature/terminal/src/domain-terminal-support.lisp` |
| terminal | `packages/feature/terminal/src/domain-terminal.lisp` | 91 | `packages/feature/terminal/src/domain-terminal.lisp` |
| terminal | `packages/feature/terminal/src/infrastructure-terminal-session-runtime.lisp` | 94 | `packages/feature/terminal/src/infrastructure-terminal-session-runtime.lisp` |
| terminal | `packages/feature/terminal/src/infrastructure-terminal.lisp` | 88 | `packages/feature/terminal/src/infrastructure-terminal.lisp` |
| terminal | `packages/feature/terminal/src/package.lisp` | 66 | `packages/feature/terminal/src/package.lisp` |
| user-init | `packages/feature/user-init/src/application-user-configuration.lisp` | 124 | `packages/feature/user-init/src/application-user-configuration.lisp` |
| user-init | `packages/feature/user-init/src/infrastructure-user-init.lisp` | 44 | `packages/feature/user-init/src/infrastructure-user-init.lisp` |
| user-init | `packages/feature/user-init/src/package.lisp` | 18 | `packages/feature/user-init/src/package.lisp` |
| window | `packages/feature/window/src/application-commands-window-scroll.lisp` | 38 | `packages/feature/window/src/application-commands-window-scroll.lisp` |
| window | `packages/feature/window/src/application-commands-window.lisp` | 32 | `packages/feature/window/src/application-commands-window.lisp`（`split-window-below`、`split-window-right`、`other-window`、`delete-window`、`delete-other-windows`; source `:3-32`） |
| window | `packages/feature/window/src/package.lisp` | 40 | `packages/feature/window/src/package.lisp` |
| workspace | `packages/feature/workspace/src/application-commands-workspace.lisp` | 39 | `packages/feature/workspace/src/application-commands-workspace.lisp` |
| workspace | `packages/feature/workspace/src/application-workspace-switch-support.lisp` | 37 | `packages/feature/workspace/src/application-workspace-switch-support.lisp` |
| workspace | `packages/feature/workspace/src/application-workspace-transition-support.lisp` | 43 | `packages/feature/workspace/src/application-workspace-transition-support.lisp` |
| workspace | `packages/feature/workspace/src/domain-workspace-navigation.lisp` | 44 | `packages/feature/workspace/src/domain-workspace-navigation.lisp` |
| workspace | `packages/feature/workspace/src/domain-workspace-support.lisp` | 54 | `packages/feature/workspace/src/domain-workspace-support.lisp` |
| workspace | `packages/feature/workspace/src/domain-workspace.lisp` | 81 | `packages/feature/workspace/src/domain-workspace.lisp` |
| workspace | `packages/feature/workspace/src/package.lisp` | 42 | `packages/feature/workspace/src/package.lisp` |
| core/command | `packages/core/buffer/src/command-specs-editing.lisp` | 48 | `packages/core/command/src/command-specs-editing.lisp`（W2a source。`in-package #:loom/core/command`、`register-command-spec`呼出し） |
| core/command | `packages/core/buffer/src/command-specs-movement.lisp` | 125 | `packages/core/command/src/command-specs-movement.lisp`（W2a source。`in-package #:loom/core/command`、`register-command-spec`呼出し） |
| core/command | `packages/core/buffer/src/command-specs-region.lisp` | 92 | `packages/core/command/src/command-specs-region.lisp`（W2a source。`in-package #:loom/core/command`、`register-command-spec`呼出し） |
| core/command | `packages/core/command/src/command-registry-registration.lisp` | 302 | `packages/core/command/src/command-registry-registration.lisp` |
| core/command | `packages/core/command/src/command-specs-extended-command.lisp` | 5 | `packages/core/command/src/command-specs-extended-command.lisp` |
| core/command | `packages/core/command/src/command-specs-input.lisp` | 5 | `packages/core/command/src/command-specs-input.lisp` |
| core/command | `packages/core/command/src/command-specs-prefix-argument.lisp` | 15 | `packages/core/command/src/command-specs-prefix-argument.lisp` |
| auto-save | `packages/feature/auto-save/src/command-specs-auto-save.lisp` | 10 | `packages/feature/auto-save/src/command-specs-auto-save.lisp` |
| bookmark | `packages/feature/bookmark/src/command-specs-bookmark.lisp` | 13 | `packages/feature/bookmark/src/command-specs-bookmark.lisp` |
| buffers | `packages/feature/buffers/src/command-specs-buffers.lisp` | 7 | `packages/feature/buffers/src/command-specs-buffers.lisp` |
| evaluation | `packages/feature/evaluation/src/command-specs-evaluation.lisp` | 7 | `packages/feature/evaluation/src/command-specs-evaluation.lisp` |
| file-tree | `packages/feature/file-tree/src/command-specs-file-tree.lisp` | 33 | `packages/feature/file-tree/src/command-specs-file-tree.lisp` |
| files | `packages/feature/files/src/command-specs-file-save.lisp` | 26 | `packages/feature/files/src/command-specs-file-save.lisp` |
| files | `packages/feature/files/src/command-specs-file.lisp` | 26 | `packages/feature/files/src/command-specs-file.lisp` |
| format | `packages/feature/format/src/command-specs-format.lisp` | 10 | `packages/feature/format/src/command-specs-format.lisp` |
| git | `packages/feature/git/src/command-specs-git.lisp` | 17 | `packages/feature/git/src/command-specs-git.lisp` |
| help | `packages/feature/help/src/command-specs-help.lisp` | 4 | `packages/feature/help/src/command-specs-help.lisp` |
| keyboard-macro | `packages/feature/keyboard-macro/src/command-specs-keyboard-macro.lisp` | 10 | `packages/feature/keyboard-macro/src/command-specs-keyboard-macro.lisp` |
| kill-ring | `packages/feature/kill-ring/src/command-specs-kill.lisp` | 59 | `packages/feature/kill-ring/src/command-specs-kill.lisp` |
| kill-ring | `packages/feature/kill-ring/src/command-specs-yank.lisp` | 26 | `packages/feature/kill-ring/src/command-specs-yank.lisp` |
| lifecycle | `packages/feature/lifecycle/src/command-specs-quit.lisp` | 4 | `packages/feature/lifecycle/src/command-specs-quit.lisp` |
| lisp-structure | `packages/feature/lisp-structure/src/command-specs-sexp.lisp` | 59 | `packages/feature/lisp-structure/src/command-specs-sexp.lisp` |
| lisp-structure | `packages/feature/lisp-structure/src/command-specs-structural-editing.lisp` | 81 | `packages/feature/lisp-structure/src/command-specs-structural-editing.lisp` |
| lsp | `packages/feature/lsp/src/command-specs-lsp-completion.lisp` | 4 | `packages/feature/lsp/src/command-specs-lsp-completion.lisp` |
| lsp | `packages/feature/lsp/src/command-specs-lsp-navigation.lisp` | 7 | `packages/feature/lsp/src/command-specs-lsp-navigation.lisp` |
| lsp | `packages/feature/lsp/src/command-specs-lsp.lisp` | 10 | `packages/feature/lsp/src/command-specs-lsp.lisp` |
| mode | `packages/feature/mode/src/command-specs-major-mode-editing.lisp` | 26 | `packages/feature/mode/src/command-specs-major-mode-editing.lisp` |
| mode | `packages/feature/mode/src/command-specs-modes.lisp` | 7 | `packages/feature/mode/src/command-specs-modes.lisp` |
| project | `packages/feature/project/src/command-specs-project.lisp` | 13 | `packages/feature/project/src/command-specs-project.lisp` |
| register | `packages/feature/register/src/command-specs-register.lisp` | 13 | `packages/feature/register/src/command-specs-register.lisp` |
| search | `packages/feature/search/src/command-specs-isearch.lisp` | 26 | `packages/feature/search/src/command-specs-isearch.lisp` |
| search | `packages/feature/search/src/command-specs-search.lisp` | 37 | `packages/feature/search/src/command-specs-search.lisp` |
| session | `packages/feature/session/src/command-specs-session.lisp` | 7 | `packages/feature/session/src/command-specs-session.lisp` |
| shell | `packages/feature/shell/src/command-specs-shell.lisp` | 5 | `packages/feature/shell/src/command-specs-shell.lisp` |
| terminal | `packages/feature/terminal/src/command-specs-terminal.lisp` | 7 | `packages/feature/terminal/src/command-specs-terminal.lisp` |
| window | `packages/feature/window/src/command-specs-window-scroll.lisp` | 26 | `packages/feature/window/src/command-specs-window-scroll.lisp` |
| window | `packages/feature/window/src/command-specs-window.lisp` | 16 | `packages/feature/window/src/command-specs-window.lisp` |
| workspace | `packages/feature/workspace/src/command-specs-workspace.lisp` | 16 | `packages/feature/workspace/src/command-specs-workspace.lisp` |

## 2. ASDFの所有権と依存

確認した`origin/main`には38個のslice `.asd`があり、各systemのproduction componentは0件である。`loom.asd`のASDF component一覧には`loom`が300件、`loom/test`が181件ある。1.2表のsource inventoryには登録済みcomponentだけでなく、未登録だがtrackedなsourceも含める。
ASDF一覧とtracked sourceを突き合わせると、1.2表の移設先に登録する必要がある未登録production sourceは`src/application/editor-state-bookmarks.lisp`と、`packages/feature/{clipboard,completion,files,help,kill-ring,lang-lisp,lang-markup,lang-nix,lang-web,lifecycle,lisp-structure,minibuffer-ui,mouse}/src/package.lisp`である。
W2aが追加した38個の`command-specs-*.lisp`は、現在はrootの`loom` componentである。うち`packages/core/buffer/src/command-specs-{editing,movement,region}.lisp`は`in-package #:loom/core/command`で`register-command-spec`を呼ぶため、移設先は`core/command`とする。`loom.asd:726-729`はこれらをroot componentとして登録している。
`lang-markup`のslice `.asd`だけは`cl-markdown-kit`と`cl-org-kit`を宣言している。
次表はpackage importと呼び出し箇所から組み立てたW2c後の直接依存案であり、実行済みのASDF依存ではない。
W2bのdependency-union gateで実際の参照と照合してから`.asd`へ記録する。

### 2.1 production systemの直接依存

system名は設計書のhyphen区切りを使う。
ライブラリ欄はproduction codeが直接参照する外部systemである。
`なし`は今回の静的調査で直接参照を見つけなかった意味であり、依存を追加しない判断ではない。

| system | 依存するproduction system | 外部library | 依存根拠と確度 |
|---|---|---|---|
| `loom-core-buffer` | なし | なし | coreの基底。package importにslice参照なし |
| `loom-core-window-tree` | なし | なし | coreの基底。package importにslice参照なし |
| `loom-core-minibuffer` | なし | `cl-tty-kit`、`cl-history-kit` | terminal入力と履歴。source参照から推定 |
| `loom-core-editor-session` | `loom-core-buffer`、`loom-core-window-tree` | なし | `package.lisp`のimport |
| `loom-core-command` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree` | `cl-tty-kit`、`cl-json-kit` | package importと登録、trace実装から推定 |
| `loom-feature-lifecycle` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-core-command`、`loom-feature-buffers`、`loom-feature-files` | `cl-prolog-kit` | buffer終了、保存確認、起動契約 |
| `loom-feature-files` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-feature-buffers`、`loom-feature-mode` | `cl-host-kit`、`cl-boundary-kit` | file I/O、path、mode判定。現file-tree sourceから分離する |
| `loom-feature-buffers` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-core-command` | なし | registryとbuffer command。save genericはcoreで宣言する |
| `loom-feature-file-tree` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-core-command`、`loom-feature-mode`、`loom-feature-buffers`、`loom-feature-files` | `cl-host-kit`、`cl-boundary-kit`、`cl-concurrent-kit` | path操作、buffer open、runtime。file I/O本体はfilesへ移す |
| `loom-feature-minibuffer-ui` | `loom-core-minibuffer`、`loom-feature-completion` | なし | 新設slice。W3-5 APIから逆算した推定 |
| `loom-feature-completion` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-window-tree`、`loom-core-command` | なし | popupと候補処理のpackage import |
| `loom-feature-help` | `loom-core-command`、`loom-core-editor-session`、`loom-core-minibuffer` | なし | help commandと状態参照 |
| `loom-feature-kill-ring` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-core-command` | なし | yank stateとcommand API。S式削除はlisp-structureへ依存させない |
| `loom-feature-clipboard` | W2c時点でなし | W2c時点でなし | 新設slice。W3-8で必要なcommand routeはW3の変更として扱う |
| `loom-feature-mouse` | W2c時点でなし | W2c時点でなし | 新設slice。W3-8で必要なevent APIはW3の変更として扱う |
| `loom-feature-search` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-command` | `cl-regex-kit` | package importとregex call |
| `loom-feature-project` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-feature-buffers`、`loom-feature-files`、`loom-feature-file-tree` | なし | project commandとbuffer/path参照 |
| `loom-feature-mode` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-core-command` | なし | mode providerとtruncate policy |
| `loom-feature-syntax-highlighting` | `loom-core-buffer`、`loom-feature-mode` | なし | highlight providerがmodeを参照 |
| `loom-feature-lisp-structure` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-window-tree`、`loom-core-command` | なし | S式編集API。package importはW2cで確認する |
| `loom-feature-lang-lisp` | `loom-feature-mode`、`loom-feature-syntax-highlighting` | なし | W3-7aのlanguage definition受け渡しに必要。現在のsource importでは未検証 |
| `loom-feature-lang-nix` | `loom-feature-mode`、`loom-feature-syntax-highlighting` | なし | W3-7aのlanguage definition受け渡しに必要。現在のsource importでは未検証 |
| `loom-feature-lang-web` | `loom-feature-mode`、`loom-feature-syntax-highlighting` | なし | W3-7aのlanguage definition受け渡しに必要。現在のsource importでは未検証 |
| `loom-feature-lang-markup` | `loom-feature-mode`、`loom-feature-syntax-highlighting` | `cl-markdown-kit`、`cl-org-kit` | mode定義と既存`.asd` |
| `loom-feature-bookmark` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-feature-buffers`、`loom-feature-files` | `cl-host-kit` | stateとfile identity |
| `loom-feature-window` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-window-tree`、`loom-core-command` | なし | window commandとtree API |
| `loom-feature-workspace` | `loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree` | なし | package import |
| `loom-feature-session` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-feature-bookmark`、`loom-feature-buffers`、`loom-feature-workspace` | なし | package import。`cl-host-kit`はtest側の候補 |
| `loom-feature-register` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-core-command` | なし | register commandとstate参照 |
| `loom-feature-keyboard-macro` | `loom-core-command`、`loom-core-editor-session`、`loom-core-minibuffer` | なし | package import |
| `loom-feature-lsp` | `loom-core-buffer`、`loom-core-command`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-feature-buffers`、`loom-feature-file-tree`、`loom-feature-project` | `cl-json-kit`、`cl-concurrent-kit`、`cl-date-kit`、`cl-host-kit`、`cl-process-kit` | package importとtransport、session実装 |
| `loom-feature-terminal` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-feature-buffers` | `cl-tty-kit` | terminal commandとsession runtime |
| `loom-feature-shell` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-feature-buffers` | `cl-process-kit` | process起動とshell buffer |
| `loom-feature-format` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-feature-shell` | なし | formatter起動はshell経由 |
| `loom-feature-git` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-feature-buffers`、`loom-feature-project` | `cl-vcs-kit`、`cl-resilience-kit` | package importと外部git処理 |
| `loom-feature-evaluation` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-feature-buffers` | なし | evaluation bufferとsession参照 |
| `loom-feature-auto-save` | `loom-core-buffer`、`loom-core-editor-session`、`loom-core-minibuffer`、`loom-core-window-tree`、`loom-feature-buffers` | なし | package import。保存APIはcore genericを実装するfilesに依存させない |
| `loom-feature-user-init` | `loom-core-command`、`loom-core-editor-session` | `cl-host-kit` | init file探索とcommand登録 |

依存表の`core/editor-session -> core/buffer, core/window-tree`は`packages/core/editor-session/src/package.lisp`のimportを基準にする。
`core/command`はeditor-session、buffer、minibuffer、window-treeをimportする。
したがってcoreの移設順は`buffer`と`window-tree`と`minibuffer`、`editor-session`、`command`である。
設計書5章の`command`先行順は現sourceのpackage importと逆になるため、ここでは採用しない。

### 2.2 test systemの依存と共有support

次図の通常の矢印はsystem間の`:depends-on`を表し、左のsystemが右のsystemに依存する。`loom/test`から共有supportとslice testへの矢印は、直接依存ではなく`asdf:prepare-op`の`:in-order-to` prerequisiteである。
各sliceのtest systemは、自分のproduction systemとrootの`loom/test-support`へ依存する。
`loom/test-support`は`loom` production aggregateに依存し、共有test packageと共通fixtureを所有する。packageとfixtureが使う外部systemはsupportのprepare prerequisiteで先にloadする。
各slice testが直接参照するlibraryは別表の候補を照合してslice側へ宣言する。
rootの`loom/test`は現在の外部test library依存を保ち、共有supportと全slice test systemをprepare prerequisiteとしてloadしてから、未移設のroot test componentをloadする。

```text
loom production aggregate -> 全slice production system
loom/test-support -> loom production aggregate
loom/test-support owns 共有test package、共通fixture
slice/test -> 自slice production system、loom/test-support、直接使うtest library
loom/test :prepare-op/:in-order-to -> loom/test-support、全slice/test
loom/test :depends-on -> loom production aggregate、外部test library
```

`loom/test-support`はASDF system名であり、既存test fileのpackage名`loom/test`を変える必要はない。
supportがaggregate testに依存すると逆向きの循環になるため、supportはproduction aggregateだけに依存する。
`t/package.lisp`は複数のfeature packageとcore packageを`:use`するため、support依存が全sliceのproductionを引く広いtest境界になる。
root `loom/test`の`:depends-on`へlocal test system名を加えない。dependency-contractはrootの直接依存をflake inputとして検証するため、local systemは`:in-order-to` prerequisiteとしてloadする。
test packageをslice別に分ける案は、全testのpackage宣言とfixture共有を改めるためW2cの範囲に含めない。

| test system | 直接使うtest library候補 |
| --- | --- |
| `core/buffer/test` | `cl-host-kit` |
| `core/window-tree/test` | `cl-weave` |
| `core/minibuffer/test` | `cl-tty-kit`、`cl-history-kit` |
| `core/editor-session/test` | `cl-host-kit` |
| `core/command/test` | `cl-host-kit`、`cl-tty-kit`、`cl-json-kit` |
| `lifecycle/test` | `cl-host-kit` |
| `files/test` | `cl-host-kit`、`cl-boundary-kit` |
| `buffers/test` | なし |
| `file-tree/test` | `cl-host-kit`、`cl-boundary-kit`、`cl-concurrent-kit` |
| `minibuffer-ui/test` | なし |
| `completion/test` | `cl-host-kit` |
| `help/test` | なし |
| `kill-ring/test` | なし |
| `clipboard/test` | なし |
| `mouse/test` | なし |
| `search/test` | `cl-regex-kit` |
| `project/test` | なし |
| `mode/test` | `cl-host-kit` |
| `syntax-highlighting/test` | なし |
| `lisp-structure/test` | `cl-tty-kit` |
| `lang-lisp/test` | なし |
| `lang-nix/test` | なし |
| `lang-web/test` | なし |
| `lang-markup/test` | なし |
| `bookmark/test` | `cl-host-kit` |
| `window/test` | なし |
| `workspace/test` | なし |
| `session/test` | `cl-host-kit` |
| `register/test` | なし |
| `keyboard-macro/test` | なし |
| `lsp/test` | `cl-json-kit`、`cl-concurrent-kit`、`cl-date-kit`、`cl-host-kit`、`cl-process-kit` |
| `terminal/test` | `cl-tty-kit` |
| `shell/test` | `cl-process-kit` |
| `format/test` | `cl-host-kit` |
| `git/test` | `cl-vcs-kit`、`cl-resilience-kit` |
| `evaluation/test` | なし |
| `auto-save/test` | `cl-host-kit` |
| `user-init/test` | `cl-host-kit` |

このtest library欄は静的調査での候補である。
W2bのdependency-union gateが`.asd`の外部依存集合を`flake.nix`と照合するため、test componentをsliceごとに移す際に未使用依存を除き、直接参照を漏らさない。
package directory内に既存test Lisp fileは0件である。
W2cでは1.1表に割り当てたroot testをsliceまたはroot integrationへ移し、同じcommitでtest systemのcomponent所有権を切り替える。

## 3. 依存DAGと循環の解消

2.1表は各systemの直接依存先を列挙する。次の図は主要なload順を示すため、矢印を依存先から利用側へ向ける。
production依存だけでDAGを作り、test supportは別の集約層に置く。

```text
core/buffer ------> core/editor-session ------> core/command
core/window-tree -> core/editor-session
core/minibuffer ------------------------------> core/command

core/command -> mode -> syntax-highlighting
core/command -> search / completion / help
mode + syntax-highlighting -> lang-* definitions

core + core/command -> buffers -> files -> file-tree -> project
mode -> files and file-tree
buffers -> file-tree
file-tree + project -> lsp
buffers + files -> bookmark
```

図は主要な順序だけを示し、その他の機能sliceは2.1表の直接依存に従う。同じbatch内で独立するsliceは並行できる。

現sourceには移設順を壊す境界がある。
`file-tree-open-selected`は`packages/feature/file-tree/src/application-commands-file-tree.lisp:57-65`でprivateな`%visit-existing-file`を呼ぶ。`visit-file`と`%visit-existing-file`は`packages/feature/file-tree/src/application-commands-file.lisp:52-68`にあり、`visit-file`は同packageのexport list (`packages/feature/file-tree/src/package.lisp:36-41`) に含まれる。`packages/feature/files/src/package.lisp:1-2`にはまだexportがない。このsourceをfilesへ移す際は`visit-file`をfilesのpublic APIとしてexportし、file-tree側を`loom/feature/files:visit-file`呼出しへ切り替える。`%visit-existing-file`はfiles内に残すinternal functionとする。
`buffer-load`と`buffer-save`のgenericは`packages/core/buffer/src/domain-buffer.lisp:86-98`に残し、現在file-tree packageにあるmethod (`packages/feature/file-tree/src/infrastructure-buffer-filesystem.lisp:4-33`) をfilesへ移す。移設後の依存は`mode -> buffers -> files -> file-tree`とし、`buffer-save` genericを下位層に残すためbuffersからfilesへの逆依存は作らない。
**未確定:** `packages/feature/file-tree/src/infrastructure-filesystem-native-paths.lisp:3-57`をfilesへ移す場合、`packages/feature/file-tree/src/infrastructure-file-tree-filesystem-support.lisp:23,37`、`packages/feature/file-tree/src/infrastructure-file-tree-filesystem.lisp:11-54`、`packages/feature/file-tree/src/infrastructure-filesystem-native-delete.lisp:15`、`packages/feature/file-tree/src/infrastructure-filesystem-native-mutations.lisp:5-40`も現在の`*loom-filesystem*`、`*loom-real-filesystem*`、`%native-path-operation-p`、`%native-path-exists-p`、`%native-namestring`、`%native-file-writable-p`、`%native-directory-prefixes`、`%native-directory-p`を参照している。これらの関数は現sourceでprivateであり、複数sourceがslice境界をまたいで参照する。現行package export（`packages/feature/file-tree/src/package.lisp:1-45`）にも共有native filesystem APIの契約にも公開範囲と所属を決める根拠がない。batch 6のfiles/file-tree統合ownerが、native-path sourceを移す前に関数の公開範囲と所属を決め、package exportと呼出し側を同じ差分で更新する。決定が済むまでbatch 6のfile-tree移設を開始しない。

rootのinput routingは`src/application/input-routing-effects.lisp:3-13`で`%clear-last-yank`を呼び、現在のwrapperは`editor-state-clear-last-yank`へ委譲する（`src/application/editor-state-operations.lisp:3-4`）。この既存APIは`loom/core/editor-session`からexportされ（`packages/core/editor-session/src/package.lisp:95`）、定義は`packages/core/editor-session/src/application-editor-state-support.lisp:33`、command invocationの既存callerは`packages/core/command/src/command-invocation.lisp:125,142`にある。W2cではroot input routingを`loom/core/editor-session:editor-state-clear-last-yank`の直接呼出しへ切り替え、`%clear-last-yank`のsourceを設計どおりkill-ringへ移す。新しいkill-ring public APIは追加しない。
`commands-misc.lisp`、`commands-quit.lisp`、`commands-help-test.lisp`、`commands-misc-test.lisp`、`commands-sexp-test.lisp`、`commands-editing-file-test.lisp`も単一sliceに移さず、1.1表の分割先ごとにassertionとfixtureを分ける。

W2a specは`loom.asd:726-729`でroot componentとして登録され、`packages/core/buffer/src/command-specs-*.lisp`の3 fileも`loom-core-buffer`には登録されていない。sourceは`in-package #:loom/core/command`で`register-command-spec`を呼ぶ。
`loom-core-buffer`は依存なしの基底sliceであり、batch 0ではspecを`loom-core-buffer`へ登録しない。specはbatch 0完了までroot `loom` componentに残し、batch 2で`packages/core/command/src/command-specs-{editing,movement,region}.lisp`へ移して`loom-core-command`だけが所有する。batch 0 gateは`loom-core-buffer`の依存先が0件であること、command specがbuffer systemのcomponentに含まれないこと、root componentからspecを外すのがbatch 2であることを確認する。

### 3.1 W2c移設バッチ

batch内のslice sourceとslice testは別担当が並行で準備できる。W2cの進行役は各batchの開始前に一人のintegration ownerを指名し、その人が共有root manifestを適用する。
依存相手がmainに統合される前に、依存するsliceの移設commitをmainへ入れない。

| batch | slice | 先行条件 | 並列実施条件 |
|---|---|---|---|
| 0 | `core/buffer`、`core/window-tree`、`core/minibuffer`、`clipboard`、`mouse` | W2bのsystem discoveryとtest runnerが完了。W2a command specの配置確認とbufferからの依存解消が済んでいる | 初めの3 coreと新設2 sliceは互いのsource pathを編集しない |
| 1 | `core/editor-session` | batch 0のcore三slice | slice testとroot component変更は担当を分け、manifest統合は一人が行う |
| 2 | `core/command` | batch 1、command specの移設先確定 | route登録仕様はW2a完了後に取り込む |
| 3 | `mode`、`search`、`completion`、`help`、`kill-ring`、`window`、`workspace`、`register`、`keyboard-macro`、`lisp-structure`、`user-init` | batch 2 | source/testと`.asd`はsliceごとに独立。kill-ring public APIを先に定める |
| 4 | `syntax-highlighting`、`lang-lisp`、`lang-nix`、`lang-web`、`lang-markup`、`minibuffer-ui` | batch 3。`minibuffer-ui`はcompletionも必要 | 言語定義のownerとfile pathをW3-7aへの受け渡し単位で固定する |
| 5 | `buffers` | batch 2と3 | save genericはcore、providerはfilesに置く契約を確認する |
| 6 | `files`、`file-tree` | batch 4と5。filesを先に統合し、その後file-treeを統合 | filesystem helperとfile-save commandをfilesへ移し、file-treeのback edgeが消えた場合だけ進める |
| 7 | `bookmark`、`project`、`lifecycle`、`evaluation` | batch 6。projectはfile-tree、lifecycleとevaluationはbuffers/filesを必要とする | slice固有pathのみ並行編集し、root integration testは共通ownerが割り当てる |
| 8 | `session` | batch 7と`workspace` | bookmark、buffer registry、workspace stateの依存を固定する |
| 9 | `lsp`、`terminal`、`shell`、`git`、`auto-save` | batch 7。lspはprojectとfile-tree、gitはprojectを必要とする | 外部libraryは各slice `.asd`へ直接宣言し、flake union gateへ含める |
| 10 | `format` | batch 9のshell | formatter process APIのownerをshellに限定する |

batch内でも`loom.asd`、`t/package.lisp`、root test component、runner、coverage、dependency contractは共有競合を起こす。
W2bが所有するrunner、coverage、dependency test、E2E discoveryをW2c担当が変更しない。
各slice ownerは自sliceのsource、test、`t/paths.sexp`、E2E scenarioだけを準備する。
root aggregateへのcomponent切替は統合ownerが一つずつ行い、変更中のshared fileを並行rebaseしない。

## 4. 並列分割と競合の扱い

| path / decision point | 競合の性質 | 担当と対処 |
|---|---|---|
| root `loom.asd` | 全sliceが同じcomponent列を縮め、aggregate dependencyを増やす | slice ownerは編集しない。integration ownerがslice単位で一回の差分にまとめる |
| `t/package.lisp`と共有fixture | 全slice testが共有packageとhelperを使う | W2cではroot test-support ownerが維持し、slice ownerは個別test fileだけを動かす |
| `run-tests.lisp`、coverage、dependency contract、E2E discovery | W2b runner境界と重なる | W2b ownerだけが変更する。W2b完了前はW2cのslice移設を開始しない |
| file-tree/files/buffersのAPI | 現在のsource配置と最終ownerが異なる | filesのhelper移設と`buffer-save` provider移設を先に同時レビューし、DAG上の一方向性を確認する |
| command specの配置 | W2a specはroot `loom` componentに登録済み。3 fileは`packages/core/buffer/src/`にあるが`loom-core-buffer`には未登録。core/commandがcore/bufferに依存するため、buffer systemへ登録すると循環する | W2c着手時にmainへ統合されたW2a成果物とcomponent登録を確認する |
| 混在integration test | 一つのfixtureが複数slice APIを呼ぶ | assertion単位でslice testへ分ける。rootに残るassertionはaggregate integration testに置く |

## 5. W3 laneの開始条件

W3 laneのpath所有権と直接依存は要件11.6と設計6章に従う（`docs/src/notes/requirements-modern-editor.md:488-502`、`docs/src/notes/design-core-and-slices.md:511-530`）。
次表は各laneが必要とするW2c移設完了点と、W3 API依存から決まる最短開始条件を分けて示す。
batch番号は3.1表を参照する。

| lane | W2cで先にmainへ入れるslice | W3内の先行API | 最短の枝作業開始 |
|---|---|---|---|
| W3-1 | `core/command`（batch 2） | なし | batch 2完了後 |
| W3-2 | `user-init`（batch 3）、`lifecycle`（batch 7） | W3-3、W3-5 | batch 7完了後、W3-3とW3-5のAPIが利用可能になってから |
| W3-3 | `buffers`、`files`（batch 6） | なし | batch 6完了後 |
| W3-4 | `core/buffer`（batch 0）と1.1表のroot renderer/presentation path | なし | batch 0のmain統合後、root aggregateのcomponent一覧でrenderer/presentation pathがroot所有と確認できてから |
| W3-5 | `core/minibuffer`（batch 0）、`minibuffer-ui`と`completion`（batch 4）、`help`（batch 3） | W3-3、W3-7a | batch 4完了後、W3-3のresult buffer APIとW3-7aのmode query APIが入ってから |
| W3-6 | `search`（batch 3）、`project`（batch 7） | W3-3 | batch 7完了後、W3-3のresult buffer APIが入ってから |
| W3-7a | `mode`（batch 3）、`syntax-highlighting`と4 language slice（batch 4） | なし | batch 4完了後 |
| W3-7b | `lang-lisp`（batch 4）、`lisp-structure`（batch 3）、`evaluation`（batch 7） | W3-7aのlanguage definition移設commit | batch 7完了後、W3-7aの引渡しcommitがmainへ入ってから |
| W3-7c | `lang-nix`（batch 4） | W3-7aのlanguage definition移設commit | W3-7aの引渡しcommit後 |
| W3-7d | `lang-web`（batch 4） | W3-7aのlanguage definition移設commit | W3-7aの引渡しcommit後 |
| W3-7e | `lang-markup`（batch 4） | W3-7aのlanguage definition移設commit | W3-7aの引渡しcommit後 |
| W3-8 | `kill-ring`（batch 3）、`clipboard`、`mouse`（batch 0） | W3-1、W3-4、W3-10 | W3-10までのAPIとfile-tree item providerが入ってから |
| W3-9 | `lsp`（batch 9） | W3-3、W3-6 | batch 9完了後、buffer-close hookとresult/navigation APIが入ってから |
| W3-10 | `file-tree`、`window`、`workspace`、`bookmark`、`register`、`keyboard-macro`（batch 3、6、7）と`session`（batch 8） | W3-1、W3-3 | batch 8完了後、key registrationとbuffer registry APIが入ってから |
| W3-11 | `shell`、`terminal`、`git`、`auto-save`（batch 9）、`format`（batch 10） | W3-3 | batch 10完了後、files save APIが入ってから |

### 5.1 W2dとW3の重ね方

W2dの完了前にW3 branch上の実装を始めてよい。
条件はW2b runnerが完了し、当該laneが使うsliceのW2c移設とroot manifest更新がmainへ入っており、対象pathの所有者が固定されていることである。
W3 laneは自分のsource、test、`t/paths.sexp`、E2E pathだけを使う。
root aggregate、flake、runner、E2E harnessを編集しない。

枝上の作業を許してもW3 commitはmainへ入れない。
全W2c移設の完了後、W2dのwarningからfailureへの切替と未知依存のnegative controlが通り、allowlistが確定してからmerge gateを開く。
その後はlaneのW2依存とW3先行APIが入った順に統合する。
境界gateの変更でW3 branchが失敗した場合は、W2dのallowlistを広げずlane内の依存を直す。

## 6. commit gateとbatch gate

現要件11.5と設計5章は、W2の各commitで全unit suiteと全E2Eを求めている。W2cでは各slice commitで全unit suiteを実行する。batchごとにpushし、そのpush tipで`nix run .#e2e`を1回実行する。slice数が多いbatchは、1 pushあたり最大5 slice commitを目安に分ける。

push tipは一時bookmarkでoriginへpushし、CIをdispatchする。全jobがsuccessでheadShaがpush SHAと一致することを確認した後、同じSHAをmainへpushする。一時bookmarkをremoteから削除し、mainのref SHAとmain CIも確認する。

ローカルflake checkはpush条件から外す。別プロジェクトの負荷が高い環境でserial flake checkを実行したところ、`MAIN CLI integration`が60秒でtimeoutする失敗を繰り返したためである。in-process suiteは必ずexit 0とし、ほかのin-processとlocal E2Eの失敗は不具合として扱う。GitHub Actions CIではflake check、PTY E2E、Offline release archiveを含む全jobのsuccessを確認する。

origin/mainがpush前に進んでいたらrebaseし、in-process suiteを再実行する。rebase後の新しいpush tipでもlocal E2Eを1回実行する。test件数のbaselineはW2c着手時点のmainで登録されている件数とする。

| gate | 実行範囲 | 合格条件 |
|---|---|---|
| slice commit | `nix develop --command sbcl --script run-tests.lisp` | 全unit testが成功し、登録test件数がbaselineを下回らない |
| push tip（batchごと。slice数が多いbatchは最大5 slice commitごと） | `nix run .#e2e`を1回実行し、一時bookmarkをpushしてCIをdispatchする。その後同じSHAをmainへpushする | E2Eとdispatch CI・main CIの全jobが成功し、headShaと各ref SHAがpush SHAに一致する。ローカルflake checkは実行しない |
| batch境界 | ASDF production/test system一覧、W2b dependency-union gate、root aggregate component一覧と1.1・1.2表のpath割当 | 各pathが意図したsystemへ一度だけ登録され、未登録pathが担当batchで登録される |
| W2d境界 | warningからfailureへの切替、既知allowlist、未知依存/private symbol/domain上位層参照のnegative control | 許可済み違反だけが残り、negative controlはfailureになる |
| W3 lane統合 | lane固有test、全unit、全E2E、GitHub CIのflake check、境界gate | laneのpath所有権、export、他lane API依存を満たし、既存scenarioと追加scenarioおよびCIの全jobが成功する |

batch境界gateはsliceごとのunit gate、およびpush tipのE2E/CI gateを置き換えない。E2Eが失敗した場合は、修正をpushする前に範囲内の各slice commitを検査する。

## 7. 要件と設計との差分と未確定点

| 今回の確認点 | 扱い | 根拠または決定時点 |
|---|---|---|
| split行の内容と移設先 | 確定 | 1.1・1.2表に関数名、assertion内容、source行、固有の移設先を記載 |
| 複数sourceの同一targetへの統合 | 確定 | source file境界を維持し、別sourceを同一targetへ統合しない。表のtarget pathはsourceまたは分割片ごとに固有 |
| application command sourceのASDF owner | 確定 | 最終ownerは`loom-core-command`とする。command macroとeditor state、buffer、minibuffer APIに依存するため、`loom-core-buffer`の0依存条件を保てる。sourceとpackage bootstrapの移設まではroot componentに残す。`keyboard-quit`もbatch 0では物理移設先のpathをroot componentが所有し、package bootstrap移設後のbatch 2で`loom-core-command`へ切り替える。`loom-core-minibuffer`には登録しない | `packages/core/command/src/package.lisp:3-15`、`loom.asd:32-41`、`src/application/commands-misc.lisp:3-6`、`packages/core/minibuffer/src/application-commands-minibuffer.lisp:1`、3節のcore移設順 |
| batch 0の`core/buffer` word-motion helper | 解決済み | `application-word-motion.lisp`とそのcaller `application-commands-movement-support.lisp`、`application-commands-kill.lisp`をbatch 2で`core/command`へ一緒に移す。3 fileは`LOOM` packageを維持し、helperをexportしない。batch 0ではこれらをroot componentのままにできるため、`core/buffer` sliceの移設を進める | `packages/core/editor/src/application-word-motion.lisp:8-25`、`packages/core/editor/src/application-commands-movement-support.lisp:71-72`、`packages/core/editor/src/application-commands-kill.lisp:9-15` |
| file-tree/filesの循環境界API | 一部未確定 | `visit-file`をfilesからexportし、`buffer-load`/`buffer-save` methodをfilesへ移す。native-path helperのexportかsource分割かはbatch 6 integration ownerがfile移設前に決める |
| ASDF所有権の照合 | 確定 | section 8のASDF component列挙で`system`と`pathname`を出し、1.1・1.2の割当と照合する。現在のcomponent未登録sourceも2節に列挙 |

### 要件・設計との差分

| 項目 | 要件と設計の記述 | この計画の扱い | 根拠 |
|---|---|---|---|
| coreの移設順 | 設計5章はcommandをeditor-sessionより先に置く | editor-sessionをcommandより先に移す | core/commandがeditor-sessionをimportする |
| modeとfile I/O | 設計5章の概略順はfiles、buffers、file-treeをmodeより先に置く | mode、buffers、files、file-treeの順へ変える | filesとfile-treeが`major-mode-for-path`を参照する |
| file-treeとfilesの境界 | file-tree既存pathを広く残す順序 | `visit-file` exportとbuffer I/O provider移設で依存方向を固定する。native-path helper境界はbatch 6開始前に確定する | `visit-file`の既存定義とfile-tree callerは3節に記載。private helperはpublic contract未定 |
| command specの配置 | W2a specはroot `loom` componentに登録済み | 3つのspec fileはbatch 0を通じて現在の`packages/core/buffer/src/` pathとroot `loom` ASDF所有を維持し、batch 2でpathと`loom-core-command`所有を同一commitで切り替える | `loom.asd:726-729`、3節のbatch 0/2割当、1commit/1slice規則 |
| test support | 各slice testの配置は定義済みだが、共有packageのsystem所有が残る | `loom/test-support`を追加し、root aggregateの外へ共有packageを置く | slice/testから`loom/test` aggregateへの循環を避ける |
| movement-view helper | 設計資料はscrollとgoto-lineを分割する | 現行sourceにscroll helperはない。W2a catalogの`:core/buffer` ownerを保ち、goto-line helperを同じownerに割り当てる | 現行sourceは`packages/core/editor/src/application-commands-movement-view-support.lisp:3-36`、W2a specは`packages/core/buffer/src/command-specs-movement.lisp:114-122` |
| W3開始時期 | W2完了後にW3開始 | 条件を満たすbranch作業だけW2dと重ねる。main mergeはW2d成功後 | W3 path所有とroot共有pathを分離できる。gate違反は統合前に検出する |
| commit gate | slice commitごとの全unit suite、push tipのE2EとGitHub CI | slice commitごとに全unitを実行し、batchごとのpush tip（slice数が多いbatchは最大5 slice commitごと）でE2Eを1回実行して一時bookmark CIとmain CIの全jobを確認する（6節） | 中間commit単位のE2E保証を失い、失敗時のbisect範囲を1 batch、最大5 slice commitとする。ローカルflake checkはpush条件から外す |
| `commands-internal.lisp` | 設計資料は選択buffer/window registry helperの移設を示唆する | 現root fileを残す。registry関数の新たな移設先は設けない | 現行fileの定義は`%order-region`だけ（`src/application/commands-internal.lisp:3-12`）。buffer registryは`registered-buffers`、`register-buffer`、`unregister-buffer`としてすでにfeature/buffersにある（`packages/feature/buffers/src/domain-buffer-registry.lisp:14-26`）。設計資料の選択window helperとregistry helperの記述は現行sourceにない |

W2c表のtarget pathにはまだ新規作成していないpathが含まれる。

## 8. source inventoryとASDF所有権の再現

`main@origin`へrebaseした後、W2cのsource移動を始める前に次のscriptを実行すると、1.1・1.2表の現在path列をtracked source inventoryと照合できる。欠落、余剰、重複があればexit 1になる。このscriptは移設前pathのbaseline検査であり、各batch完了時にはそのまま再利用しない。

```bash
python3 - <<'PY'
from collections import Counter
from pathlib import Path
import re
import subprocess

doc = Path("docs/src/notes/w2c-move-plan.md").read_text()
sections = (
    ("### 1.1 `src/`と`t/`の全Lispファイル", "### 1.2 `packages/` 配下にすでにあるproduction source"),
    ("### 1.2 `packages/` 配下にすでにあるproduction source", "## 2."),
)
assigned = []
for start, end in sections:
    table = doc.split(start, 1)[1].split(end, 1)[0]
    for line in table.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if len(cells) < 4:
            continue
        match = re.fullmatch(r"`((?:src|t|packages)/[^`]+\.lisp)`", cells[1])
        if match:
            assigned.append(match.group(1))

tracked = subprocess.check_output(
    ["git", "ls-files", "--", "src", "t", "packages"], text=True
).splitlines()
actual = sorted(
    path for path in tracked
    if path.endswith(".lisp")
    and (path.startswith(("src/", "t/")) or (path.startswith("packages/") and "/src/" in path))
)
counts = Counter(assigned)
missing = sorted(set(actual) - set(assigned))
extra = sorted(set(assigned) - set(actual))
duplicates = sorted(path for path, count in counts.items() if count != 1)
print(
    f"tracked={len(actual)} assigned={len(assigned)} unique={len(counts)} "
    f"missing={len(missing)} extra={len(extra)} duplicate={len(duplicates)}"
)
if missing or extra or duplicates or len(actual) != len(assigned):
    print("missing:", missing)
    print("extra:", extra)
    print("duplicate:", duplicates)
    raise SystemExit(1)
PY
```

ASDF ownershipは次のcommandでsystem名とcomponent pathnameのTSVを作る。この出力自体は判定を行わない。各batchの完了時に、実際のcomponent pathとsystem名を1.1・1.2表の移設先と照合し、各pathが意図したsystemに一度だけ登録されていることを確認する。移設前の一覧ではroot componentと各slice `.asd`の所有状態を分けて読める。

```bash
sbcl --noinform --non-interactive \
  --eval '(require :asdf)' \
  --eval '(asdf:load-asd (truename #P"loom.asd"))' \
  --eval '(mapc (function asdf:load-asd) (directory #P"packages/*/*/*.asd"))' \
  --eval '(defun emit-lisp-components (component owner) (let ((source-path (ignore-errors (asdf:component-pathname component)))) (when (and source-path (string-equal "lisp" (pathname-type source-path))) (format t "~A~C~A~%" owner #\Tab (enough-namestring source-path (truename #P"./"))))) (dolist (child (ignore-errors (asdf:component-children component))) (emit-lisp-components child owner)))' \
  --eval '(emit-lisp-components (asdf:find-system "loom") "loom")' \
  --eval '(emit-lisp-components (asdf:find-system "loom/test") "loom/test")' \
  --eval '(loop for asd-path in (directory #P"packages/*/*/*.asd") for owner = (pathname-name asd-path) do (emit-lisp-components (asdf:find-system owner) owner))' \
  > .mediator/asdf-component-owners.tsv
```
