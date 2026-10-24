# W1/W2 core分割とslice-state設計

## 仕様11.2、11.6からの担当変更

仕様第3章は変更しません。
次の担当範囲と依存だけを設計で具体化します。

| 仕様箇所 | 設計で加える担当 |
|---|---|
| 11.2 W2a | rootにCLI/startup、tty/signal、suspend/resume、shutdown/status、background-work wake/pollのextension pointを用意する。`core/editor-session`のframe snapshot/render operation、hit-test、clipboard queue、startup file request APIもW2でexportを確定する。W2cでcore API本体を同sliceへ実装し、root adapterを接続する。W3-4は既存APIを使い、`core/editor-session`のexportを追加しない。W3-2とW3-6はroot CLI/event loopを変更せずこれらのadapterを使う。commandのE2E coverage readerも中央Lisp fileのregex scanから`--dump-catalog`のcanonical IDへ切り替える |
| 11.2 W2b | slice内のE2E scenario発見と`Session.restart()`をroot E2E harnessへ追加する。W2cではsource/testをsliceへ移すたびroot system inventoryも同期する。この担当変更は進行役承認済みの例外である |
| 11.6 W3-1、W3-8 | W3-1はcore/commandの`:paste`、`:mouse` routeと未知のescape sequenceを担当し、W3-8は正規化mouse eventの動作を担当する。進行役の判断に従い、D4をW3-1のunknown escapeとW3-8のmouse eventに分ける |
| 11.6 W3-2、W3-3、W3-5 | W3-2は`*Messages*`のhistoryとlifecycleを所有し、W3-3のbuffer registryとW3-5のmessage-sink APIを使う。W3-3はbuffer close通知を発火し、file-save commandを`feature/files`へ置く |
| 11.6 W3-4 | W3-4はW2でexportを固定したimmutable frame/render operation APIのroot合成とhit-test providerを実装する。W3で`core/editor-session`のexportは追加しない |
| 11.6 W3-5、W3-6、W3-9 | W3-5はW3-3のresult-buffer APIとW3-7aのmode問い合わせAPIを使う。W3-6とW3-9もW3-3のbuffer APIを使い、W3-9はW3-3に依存する |
| 11.6 W3-3、W3-7b、W3-10 | W2cはfile-save commandと対応testをfilesへ先行移設する。S式移動と構造編集実装はlisp-structureへ移し、移動keyは`:global`、`kill-sexp`と他の構造編集keyは`:lang-lisp`へ登録する。W3-10 session restoreはW3-3 buffer registryとclose hookを通す |
| 11.6 W3 dependency | section 6の完全なDAGにW3-2→W3-3/W3-5、W3-5→W3-3/W3-7a、W3-6→W3-3、W3-8→W3-4/W3-10、W3-9→W3-3、W3-10→W3-3、W3-11→W3-3を追加する |
| 11.6 W3-7a〜e | W3-7aは全言語定義を各言語sliceへ移すcommitがmainに入るまで各言語sliceの`src/`、`t/`、`t/paths.sexp`、`t/e2e/`を一時所有し、その後に各担当へ引き渡す |
| 11.6 W3-10、W3-11 | 各担当sliceの`t/e2e/`にシナリオを追加できる。root harnessと共通実行経路はW2bが用意する |

## 1. core packageの境界

仕様第3章の確定事項は変更せず、この設計はW1とW2の実装境界だけを定めます（`docs/src/notes/requirements-modern-editor.md:90-108`）。
coreを5 packageに分け、各packageはデータと安定した操作だけを公開します。
featureは必要なcore packageを`:import-from`し、root packageはfeatureの実装symbolを参照しません。
仕様4.1と4.2は依存を内側へ向け、rootを起動、event loop、frame合成、rendererに限っています（`docs/src/notes/requirements-modern-editor.md:112-172,203-212`）。
既存のbuffer、keymap、minibuffer、editor-stateのexportは付録1の一覧から移し、公開集合を次のように固定します。

| package | 公開API |
|---|---|
| `loom/core/buffer` | 付録1に列挙したbuffer APIすべて。追加で`buffer`、`buffer-position`、`buffer-position-p`、`buffer-span`、`buffer-span-p`、`buffer-read-only-error-buffer`、`buffer-position-offset`、`buffer-clamped-position-offset`をexportする |
| `loom/core/window-tree` | `window-tree`、`window-tree-p`、`make-window-tree`、`window-tree-windows`、`window-tree-selected-window`、`window-tree-layout`、`make-window-tree-from-layout`、`window-tree-selected-index`、`window-tree-select-index`、`window-tree-width`、`window-tree-height`、`window-split`、`window-select-next`、`window-delete`、`window-delete-other-windows`、`window-buffer`、`window-set-buffer`、`window-scroll-line`、`window-scroll-column`、`window-scroll-sub-row`、`window-x`、`window-y`、`window-width`、`window-height`、`window-tree-resize` |
| `loom/core/command` | 付録1のkeymapとprefix argument APIに加え、`install-default-keybindings`、`command-completion-candidates`、`find-extended-command-spec`、`command-spec`、`command-spec-p`、`command-spec-id`、`command-spec-name`、`help-summary-message`、`defkeys-single-chord-p`、`defkeys-chord`、`defkeys-key-sequence`をexportする。追加で`keymap`、`keymap-p`、`keymap-state`、`keymap-state-p`、`key-event->descriptor`、`register-command-spec`、`register-key-command`、`command-specs`、`find-command-spec`、`register-buffer-keymap-provider`、`keymap-for-buffer`、`invoke-command`、`repeat-command`をexportする。callableを返す`find-extended-command`はexportしない |
| `loom/core/minibuffer` | 付録1に列挙したminibuffer APIすべて。追加で`minibuffer`、`minibuffer-p`、`with-prompts`、`register-message-sink`をexportする |
| `loom/core/editor-session` | `*editor-session*`、`editor-session`、`editor-session-p`、`make-editor-session`、`call-with-editor-session`、`editor-session-slice`、`editor-session-slice-names`、`register-slice-state`、`register-session-hook`、`run-session-hooks`、`register-cli-option`、`startup-context`、`startup-context-argv`、`startup-context-options`、`startup-context-file-requests`、`startup-file-request`、`startup-file-request-p`、`startup-file-request-path`、`startup-file-request-line`、`startup-file-request-column`、`request-terminal-suspend`、`register-visual-row-layout`、`register-buffer-truncate-policy`、`buffer-truncate-lines-p`、`register-hit-test-provider`、`make-hit-test-result`、`hit-test-coordinate`、`hit-test-result`、`hit-test-result-p`、`hit-test-result-kind`、`hit-test-result-owner`、`hit-test-result-window`、`hit-test-result-buffer`、`hit-test-result-position`、`hit-test-result-target`、`hit-test-buffer-position`、`request-terminal-clipboard-write`、`drain-terminal-clipboard-requests`、`register-background-work`、`notify-background-work-ready`、`poll-ready-background-work`、`cancel-background-work`、`make-frame-snapshot`、`frame-snapshot`、`frame-snapshot-p`、`frame-snapshot-width`、`frame-snapshot-height`、`frame-snapshot-cell`、`frame-snapshot-cursor`、`render-operation`、`render-operation-p`、`make-render-operation`、`render-operation-kind`、`render-operation-x`、`render-operation-y`、`render-operation-text`、`render-operation-style`、`render-operation-visible-p`、`apply-render-operations`、`next-visual-line-once`、`previous-visual-line-once` |

`loom/core/buffer`はpiece table、position、undo、narrowing、read-onlyの操作を所有します。
`buffer`、`buffer-position`、`buffer-span`はopaque typeとして公開し、piece tableのstorage readerとraw constructorは内部に残します。
現在はbuffer struct readerとposition/spanの型情報が一部公開されず、condition readerも公開されていません（`packages/core/editor/src/domain-buffer-storage.lisp:16-42`、`packages/core/editor/src/domain-buffer-positions.lisp:3-17`）。
これらを型とconditionのAPIとして揃える案を採ります。
slot readerとpiece table nodeを公開する案は、表現変更をfeatureへ漏らすため却下します。

`loom/core/window-tree`はtree、window handle、selection、geometry、split/deleteを公開します。
`window-leaf`と`window-split-node`は内部表現に留めます。
feature/windowの現行packageはdomain APIとcommand wrapperを一緒にexportしています（`packages/feature/window/src/package.lisp:4-33`）。
domain APIだけをcoreへ移し、`split-window-below`、`split-window-right`、`other-window`、`delete-window`、`delete-other-windows`はfeature/windowに残します。
`switch-to-buffer`と`kill-buffer`はbuffer lifecycleを担うためfeature/buffersへ移します（`packages/feature/window/src/application-commands-window.lisp:3-54`）。
`window-scroll-line`と`window-scroll-sub-row`は読み書きできるcore/window-tree APIにします。
scroll commandはfeature/windowに置き、window stateの表現は参照しません。

`loom/core/command`はkeymap、dispatch state、prefix argument、command catalogの境界を所有します。
`keymap`と`keymap-state`はopaque typeです。binding tableとparent mapは公開せず、利用側は`keymap-define-key`、`keymap-lookup`、`keymap-state-sequence`、`keymap-state-dispatch`で登録・照会・dispatchします。accumulated sequenceも`keymap-state-sequence`が返す値だけを参照し、stateを直接変更しません。
現在のAPI一覧はroot `loom`から移し、command登録APIは節3に定めます（`src/package-exports.lisp:42-43,73-81`）。
`%key-event->descriptor`を`key-event->descriptor`としてexportし、searchとlspの参照を置き換えます。
descriptor変換を各featureに複製する案は、terminal eventの正規化を一貫させられないため却下します（`src/application/input-routing-descriptor.lisp:19-43`）。

`loom/core/minibuffer`は現在のconstructorと操作APIを移し、struct readerは引き続き隠します。
featureはinput、prompt、completion、historyの操作関数を通じてminibufferを使います（`src/application/minibuffer.lisp:3-41`）。
内部slotを直接読む案は、minibufferの状態表現をfeatureに固定するため却下します。

`loom/core/editor-session`はcurrent sessionとslice-state tableを保持し、各sliceの状態形式を知りません。
rootはevent dispatchの間`call-with-editor-session`を呼び、feature commandは`editor-session-slice`で自分のstateを取得します。
`*editor-state*`と個別slot accessorを維持する案は、34個の状態をroot packageへ再結合するため却下します（`src/application/editor-state-types.lisp:3-60`）。
`next-visual-line-once`と`previous-visual-line-once`もここからexportし、LSPのprivate参照を置き換えます。
visual row計算にはrenderer packageを直接呼ばず、rootが`register-visual-row-layout`で注入するlayout関数を使います（`packages/core/editor/src/application-commands-movement-visual-lines.lisp:3-17,31-39,85-89`）。
`register-visual-row-layout(owner, function)`のfunctionは`(session buffer logical-line window-width)`を受け、visual row順のsegment listを返します。logical-lineは0-based buffer line index、window-widthはterminal cell単位の正整数です。segmentは`(start-column end-column cell-prefix-widths)`で、columnはbuffer内の0-based character index、endはexclusive、`cell-prefix-widths`はsegment先頭から各character境界までの累積terminal cell幅を含むvectorです。vectorの要素数は`1 + end-column - start-column`、先頭値は0、以降は非減少とします。
rootのcallbackはrendererの`loom-renderer-wrap-segments`が返すcharacter rangeと`loom-renderer-string-width`の結果からこの値を作ります。coreは現在pointのsegmentとcell offsetを求め、隣のvisual rowでは同じcell offsetを超えない最大のcharacter境界へpointを移します。別のlogical lineへ移るときは次行の先頭segmentまたは前行の末尾segmentを使い、buffer境界ではpointを範囲内に保ちます。
bufferがtruncate mode、usable widthがない、layout providerが未登録、またはproviderがnilを返す場合はlogical line movementへfallbackします。空行は`(0 0 #(0))`の一segmentとして扱います。coreはcallback返却値を呼出し中だけ読み、変更しません。
coreがrendererを呼ぶ案は仕様の層方向と逆になるため採りません。

scroll commandは`core/command:repeat-command(forward, backward)`を呼びます。callbackは引数なしの一回分の操作です。repeat APIはinput dispatchがdynamic bindingした現在のprefix valueを使い、未指定なら1回、正の値なら`forward`、負の値なら`backward`を絶対値回数だけ逐次実行し、0なら何もしません。prefix state自体は変更しません。
従って`C-u 4 C-v`はscroll-up invocation一つのtraceを記録したうえで、page scrollを4回行います。scroll commandは`%repeat-command`、`%command-prefix-count`へ依存しません。repeat callbackは内部の一操作であり、command gatewayを再度呼びません。

既存コードは機能境界ごとに次のpathへ移します。

| 現行pathまたはsymbol | 移設先 | 根拠 |
|---|---|---|
| `packages/core/editor/src/domain-buffer*.lisp` | `packages/core/buffer/src/domain-buffer*.lisp` | buffer domain群、仕様4.2の145行目 |
| `packages/core/editor/src/domain-prefix-argument.lisp`、`src/domain/keymap*.lisp`、`src/application/command-registry*.lisp`、`src/application/commands-keybinding-spec.lisp`、`src/application/commands-keybindings.lisp` | `packages/core/command/src/` | 現行exportとcommand定義、仕様4.2の147行目 |
| `src/application/minibuffer*.lisp` | `packages/core/minibuffer/src/` | minibuffer責務、仕様4.2の148行目 |
| `src/application/editor-state-types.lisp`、`src/application/editor-state.lisp`、`src/application/editor-state-support.lisp`の`*editor-state*`、`src/application/editor-state-save-hooks.lisp` | `packages/core/editor-session/src/` | 現在のstate envelopeとhook registry。`*editor-recent-file-limit*`はfiles sliceへ移す |
| W2で定義するstartup file request、suspend request、frame snapshot/render operation、hit-test、clipboard queue、background-work registryのAPI本体 | `packages/core/editor-session/src/`。wake pipe、signal、suspend、terminal出力のadapterはroot `src/application/`と`src/presentation/` | W2cでcore APIを実装し、root adapterと接続する。W3-4は既存exportを使う |
| `packages/feature/window/src/domain-window*.lisp` | `packages/core/window-tree/src/domain-window*.lisp` | window tree domain群、仕様4.2の146行目 |
| `src/application/editor-state-bookmarks.lisp`、`commands-bookmark*.lisp` | `packages/feature/bookmark/src/` | bookmark slice、仕様4.2の169行目 |
| `src/application/editor-state-recent-files.lisp` | `packages/feature/files/src/` | files slice、仕様4.2の151行目 |
| `src/application/editor-state-operations.lisp`の`%clear-last-yank` | `packages/feature/kill-ring/src/` | yank状態を一括clearする操作、`src/application/editor-state-operations.lisp:3-14` |
| `packages/feature/window/src/application-commands-window.lisp`のbuffer commandと`application-window-buffer-support.lisp` | `packages/feature/buffers/src/` | buffer registrationとkill lifecycle、仕様4.2の152行目 |
| `packages/core/editor/src/application-commands-movement-view-support.lisp` | scroll commandを`packages/feature/window/src/application-commands-window-scroll.lisp`へ、`goto-line`とprompt helperを`packages/feature/buffers/src/application-commands-goto-line.lisp`へ分割する | scrollはwindow操作で、`core/window-tree` APIとprefix-awareな`core/command:repeat-command`を使う。goto-lineはbuffer command。`packages/core/editor/src/application-commands-movement-view-support.lisp:3-66` |
| `packages/core/editor/src/application-commands-sexp.lisp` | `packages/feature/lisp-structure/src/application-commands-sexp.lisp` | S式移動commandと`kill-sexp`を移す。移動keyは全mode共通の`:global` map、`kill-sexp` keyは`:lang-lisp` mapだけへ登録する。仕様4.2の164行目、11.6の495行目 |
| `packages/core/editor/src/application-commands-structural-editing.lisp`、`packages/core/editor/src/application-structural-editing*.lisp` | `packages/feature/lisp-structure/src/` | 構造編集commandとhelper群を同じsliceへ移す。構造編集keyは`:lang-lisp` mode mapだけへ登録し、移動keyとは分ける。仕様4.2の164行目、11.6の495行目 |
| `src/application/commands-internal.lisp`のselected-window helperとbuffer registry helper | core API呼び出しへ分割し、buffer registryは`feature/buffers`へ移す | `src/application/commands-internal.lisp:3-43` |
| `src/application/commands-prompts.lisp`の`with-prompts` | `packages/core/minibuffer/src/` | prompt continuation helper、`src/application/commands-prompts.lisp:3-35` |
| `packages/core/editor/src/application-commands-movement-visual-lines.lisp` | `packages/core/editor-session/src/`のvisual row operation | renderer呼出しを`register-visual-row-layout`で注入するcallbackに置き換える |

循環の切断はC4、C2、C3、C1の順に行います。
C4ではwindow domainを先に`core/window-tree`へ移し、coreからfeature/windowへの参照をなくします。
scroll commandはfeature/windowへ移し、`core/window-tree`のscroll stateとgeometry APIを呼びます。
visual-line operationは`core/editor-session`へ移し、rendererのlayout関数をrootから注入します。
`core/editor-session`はselected windowを`core/window-tree:window-tree-selected-window`で取得し、buffer、width、height、scroll positionを`window-buffer`、`window-width`、`window-height`、`window-scroll-line`、`window-scroll-sub-row`で読み書きします。
scroll commandをcoreに残してfeature/windowを呼ぶ案はC4を残すため採りません（`packages/core/editor/src/application-commands-movement-view-support.lisp:51-66`）。

C2では`editor-state`、keymap、minibufferをそれぞれcore packageへ移し、`loom/application`にあったselected-state参照を廃止します。
root `loom`が`loom/application`を`:use`する構成も解きます。
共有application packageに全slice helperを残す案は逆向き参照を温存するため却下します（`src/package.lisp:1-3`、`src/application/commands-internal.lisp:3-14`、`src/application/commands-keybindings.lisp:7`）。

C3ではselected windowとselected bufferを`editor-session-slice`、`window-tree-selected-window`、`window-buffer`の組合せに置き換えます。
feature/windowから`loom/application`のhelperを呼ぶ案を却下し、featureがcore packageを直接利用できる境界にします（`src/application/commands-internal.lisp:3-14`、`packages/feature/window/src/package.lisp:1-2`）。

C1では最後にfeature packageの`:use loom`を取り除き、依存するcore packageだけを`:import-from`します。
rootのstartup、render、command catalogからfeature symbolを呼ぶ箇所も登録APIとhook dispatchへ移します。
rootのkey routingは`core/command:keymap-for-buffer(session, buffer, fallback)`だけを呼びます。
`feature/mode`はload時に`register-buffer-keymap-provider(owner, function)`でproviderを登録し、providerは`(session buffer fallback-keymap)`を受けてmode keymapまたはnilを返します。coreはmode keymapをfallbackの上へ重ね、mode bindingを優先します。
providerが未登録ならcoreはfallbackをそのまま返します。
これにより`src/application/input-routing-command-state.lisp:37-54`からfeature/modeへの直接参照をなくします。

visual-line operationとroot presentationは`core/editor-session:buffer-truncate-lines-p(session, buffer)`を呼びます。
`feature/mode`は`register-buffer-truncate-policy(owner, function)`で判定関数を登録します。functionは`(session buffer)`を受け、`:default`ならmajor modeの設定を、明示値ならbufferの設定をbooleanで返します。
providerが未登録のときはwrapを選びます。
window geometryとscroll stateは`core/window-tree`のselected-window、buffer、geometry、scroll APIから取得します。
rootの`src/presentation/`にあるtruncate判定も同じeditor-session APIへ置き換え、mode packageを直接参照しません（`src/presentation/frame-layout-cursor.lisp:58-76`、`src/presentation/frame-layout-viewport.lisp:87`、`src/presentation/layout-isearch.lisp:103`、`src/presentation/layout-windows.lisp:48,132`）。
`loom`を全featureの共通namespaceとして残す案はrootとfeatureの循環を残すため却下します（`packages/feature/window/src/package.lisp:1-2`、`src/application/startup-state.lisp:31-63`、`src/presentation/layout-windows.lisp:190-191`）。

この順序なら各移設のあとに一時的な互換aliasを残さず、C4からC1の原因ごとに参照を切れます。
各段階でASDF全体のcompile、unit test、E2Eを通すことをW1の完了条件にします（`docs/src/notes/requirements-modern-editor.md:459-463`）。

## 2. slice-stateとhook契約

`editor-session`はslice名とstate valueを対応付けるopaque tableを持ちます。
stateful sliceはASDF load時に`register-slice-state`を呼び、constructorを登録します。
APIは次の形にします。

```lisp
(register-slice-state :feature/workspace '%make-workspace-state)
(editor-session-slice session :feature/workspace)
```

constructorは`(session)`を受け取り、そのsliceのstate objectを返します。
`make-editor-session`はrootから受け取るslice順を一度だけ使い、登録済みconstructorを順に呼びます。
`editor-session-slice`は登録されていないnameを参照したときerrorにし、登録済みstateが`nil`でも未登録と区別します。
同じnameと同じconstructorの再登録は冪等にし、異なるconstructorの二重登録はload時errorにします。

全sliceの順序は仕様4.2の並びに固定します。
coreは`buffer`、`window-tree`、`command`、`minibuffer`、`editor-session`の順に並べます。
`editor-session`はregistry envelopeを作るpackageなので、slice state constructorは登録しません。
その後、`lifecycle`、`files`、`buffers`、`file-tree`、`minibuffer-ui`、`completion`、`help`、`kill-ring`、`clipboard`、`mouse`、`search`、`project`、`mode`、`syntax-highlighting`、`lisp-structure`、`lang-lisp`、`lang-nix`、`lang-web`、`lang-markup`、`bookmark`、`window`、`workspace`、`session`、`register`、`keyboard-macro`、`lsp`、`terminal`、`shell`、`format`、`git`、`evaluation`、`auto-save`、`user-init`を続けます（`docs/src/notes/requirements-modern-editor.md:143-171`）。
slice constructorが依存するstateは先行sliceが生成します。
例えばworkspace constructorは`editor-session-slice`で`:core/window-tree`を読み、`make-workspace-manager`へ渡します。
keyboard-macro constructorは同じAPIに登録し、`make-keyboard-macro`を呼びます。
rootがこれらのfeature constructorを直接呼ぶ現行方式は、load時登録へ置き換えます（`src/application/editor-state.lisp:10-15`、`src/application/startup-state.lisp:51-63`）。

34 slotすべての実装時ownerを付録2に示します。付録2で`確定`と記した行は依頼者が確認した割当てで、その他は設計提案です。
`window-tree`、`keymap`、`minibuffer`はそれぞれ`core/window-tree`、`core/command`、`core/minibuffer`のstateです。
`buffers`、`file-tree`、`workspaces`、`recent-files`、`bookmarks`、kill/yank state、LSP state、registers、keyboard macro、search、completion、auto-save、format、terminal stateは対応するfeature sliceへ移します。
`concurrent-runtime`は`feature/file-tree`のstateで、rootは起動、終了、pollのadapterを持ちます。
`renderer`はslice stateにせずroot compositionのserviceとして保持します。
kill/yank stateとkillの連続性は`feature/kill-ring`、`last-command-self-insert-p`はundo境界用に`core/command`、`jump-origins`はLSP navigation stateとして`feature/lsp`が持ちます。
before/after-save hook listはslotから外し、registryを`core/editor-session`へ移します。
formatとauto-saveは各featureのcallbackをregisterします。
`buffers`は`feature/buffers`のregistry stateです。
他の候補ownerと根拠は付録2に記録します。

hookは`register-session-hook`でkind、owner、functionの順に登録し、rootが同じslice順でdispatchします。
`:startup`、`:signal`、`:suspend`、`:resume`、`:shutdown`、`:exit-status`も同じregistryへ登録するroot lifecycle event kindです。登録できるownerとevent固有の返り値は表に定め、`:exit-status`は`feature/lifecycle`だけが登録できます。
一つのslice内では登録順を保ちます。
dispatch開始時にhook listをcopyし、callbackが登録を更新しても現在のdispatchへ反映しません。
これは現行save hookがreverseしたcopyを実行する動作を引き継ぎます（`src/application/editor-state-save-hooks.lisp:15-18`）。
同じowner、kind、functionの登録は重複を作らず、異なるownerの同一function登録は別hookとして扱います。
仕様4.3の6分類は維持します。
save hookだけはbefore/afterを別kindに分け、さらにlifecycleとbuffer closeのroot eventを登録します。
before-save errorはwriteを止めますが、after-save errorでは完了済みwriteを戻せないため、同じcallbackにまとめません（`docs/src/notes/requirements-modern-editor.md:174-180`）。

| hook kind | signatureと戻り値 | 呼び出し順とerror |
|---|---|---|
| `:tick` | `(session monotonic-time)`。戻り値を使わない | input、timeout、background-readyの後、resize確認とframe描画の前にslice順で呼ぶ。hook errorはevent loop外へ伝え、sessionを終了する |
| `:key-input` | `(session key-event route)`。`:pass`または`:handled` | default key dispatchの前に呼ぶ。routeは実キー入力なら`:key`、macro再生なら`:macro`を渡す。`:handled`で後続hookとdefault dispatchを止める。commandを起動するhookは受け取ったrouteで共通gatewayを呼ぶ。errorはcommand dispatchの既存handlerがminibufferへ表示する |
| `:input-event` | `(session event-kind payload)`。`:pass`または`:handled` | decoderが生成した正規化済みの非key eventをkey dispatchの前に渡す。`:handled`で後続hookとdefault handlerを止める。pasteとmouseのcommand起動は共通gatewayを使い、`:paste`と`:mouse` routeはW3-1が追加する。errorはkey dispatchと同じhandlerへ渡す |
| `:render` | `(session frame-snapshot)`。immutableな`render-operation` listを返す | W2aはroot dispatcherを用意する。W3-4がbase frameを`frame-snapshot`として返す経路を接続した後、root adapterがrendererへ渡す前にslice順でhookを呼び、operationを適用した新しいsnapshotをrendererへ渡す。hookはframeを変更せず、errorはrendererの失敗と同じくsession外へ伝える |
| `:terminal-modes` | `(session)`。terminal mode keywordのlistを返す | terminal session開始前に全sliceを呼び、slice順で重複を除いたmode unionを適用する。setup errorは握りつぶさず起動を失敗させる |
| `:before-save` | `(session buffer)`。戻り値を使わない | file write前に呼ぶ。errorならwriteしない。format hookはここへ登録する |
| `:after-save` | `(session buffer)`。戻り値を使わない | writeと`buffer-mark-saved`の後に呼ぶ。errorを返しても完了済みのwriteはrollbackしない。auto-save file cleanupはここへ登録する |
| `:buffer-close` | `(session buffer reason)`。戻り値を使わない | W3-3がbuffer registryから外す前に呼ぶ。LSP callbackはこの時点でdidCloseを送る。通知errorは記録するがlocal buffer closeは続ける |

`:tick`は初回frameの前には呼ばず、event loopのinput、timeout、background-ready turnで一度呼びます。
現行event loopはinputまたはtimeoutの後にauto-save、resize、renderを行い、初回frameはloop前に描画します（`src/application/event-loop.lisp:15-30,32-44`）。
`:key-input`は既存key routing handlerの内側、`:input-event`はcore/commandのevent kind routing内に置きます（`src/application/input-routing-dispatch.lisp:56-73`）。
`:key-input`と`:input-event`のcallbackはcommandを直接`funcall`せず、節3の`invoke-command`を使います。
decoderはkey eventを`:key-input`へ、mouse、paste、unknown escapeを正規化した非key eventとして`:input-event`へ送ります。
mouse payloadは`(:action action :button button :modifiers modifiers :screen-x x :screen-y y :wheel-delta delta)`の正規化plistです。actionは`:press`、`:release`、`:motion`、`:wheel`、buttonは`:left`、`:middle`、`:right`またはnilです。`:press`と`:release`ではbutton必須、`:motion`では押下中のbuttonまたはnil、`:wheel`ではnilを使います。modifiersは重複のない`:shift`、`:alt`、`:control`の集合で、decoderはこの順に正規化します。x/yは0-based terminal cellです。wheel-deltaは縦方向notch数の符号付きintegerで、上が負、下が正です。`:wheel`以外では0、wheelでは0以外にします。
paste payloadは挿入するtextを持ち、raw terminal byte列をfeatureへ渡しません。unknown escapeは`:unknown-escape` kindとdecoderが生成した識別子だけを渡します。
hookがcommandを起動するrouteは、keyが`:key`、macro再生が`:macro`、M-xが`:mx`、pasteが`:paste`、mouseが`:mouse`です。
`:paste`と`:mouse` routeの登録とexportはcore/command ownerのW3-1が行い、W3-8は確定したAPIを使います。
`:render`は`compose-frame`が返すimmutableな`frame-snapshot`を受け取ります。
`make-frame-snapshot(width, height, row-major-cells, :cursor cursor)`はrootがbase frameを作るconstructorです。各cellは`(glyph style)`で、glyphは表示grapheme stringまたはwide glyphの後続cellを示すnil、cursorはnilか`(x y visible-p)`です。constructorは入力sequence、glyph string、styleをcopyし、幅、高さ、cell数、座標を検証します。snapshotはopaque typeで、幅、高さ、cell lookup、cursor位置のread-only accessorだけを公開します。`frame-snapshot-cell(snapshot, x, y)`は範囲内なら`(values glyph style)`、範囲外ならnilを返します。glyph stringとstyleはaccessorが毎回copyして返し、内部状態を変更できないようにします。`frame-snapshot-cursor(snapshot)`は`(values x y visible-p)`を返し、cursorがなければ3値ともnilです。内部のcell列、cursor、style listのreaderやmutable vectorは公開しません。
現行の`compose-frame`はrendererの画面を直接変更して`editor-state`を返すため、W3-4でbase frameを`frame-snapshot`として返す実装に変えます（`src/presentation/frame-layout.lisp:32-46`）。
各hookは描画内容を`make-render-operation`で作ったimmutable operation listとして返します。`render-operation-kind`、`render-operation-x`、`render-operation-y`、`render-operation-text`、`render-operation-style`、`render-operation-visible-p`はread-only accessorです。constructorはtextとstyleをcopyし、textとstyleのaccessorもcopyを返します。`:text`は`(make-render-operation :text x y text :style style)`で作り、`:style`は省略可能なrenderer style S式です。省略時は既存styleを保ち、指定時は文字列が占める全cellへstyleを置き換えて適用します。`:cursor`は`(make-render-operation :cursor x y visible-p)`です。座標は0-based terminal cellで、textは指定位置から右方向へ配置します。
`apply-render-operations(snapshot, operations, glyph-layout-function)`はoperationをlist順に適用した新しいsnapshotを返します。root rendererが渡すfunctionは`(text)`を受け、表示grapheme stringのvectorと対応するterminal cell幅vectorを返します。二つのvectorは同じ長さで、幅は正のintegerです。適用はcopy-on-writeで元snapshotを変更せず、後のoperationが同じcellへの先行書込みを上書きします。textはframe右端でclipし、wide glyphが収まらない場合は描画しません。範囲外の開始座標、不正operation、vector長不一致、非正のcell幅はhook errorとして扱います。
W3-4がbase frameを`frame-snapshot`として返す経路を接続した後、root adapterはこのAPIを呼び、結果をrendererへ渡します。feature hookはrenderer objectに触れず、snapshot readとrender operation生成だけを行います。

syntax highlight hookは各画面cellを`hit-test-coordinate`でbuffer textへ対応づけ、buffer positionを含むsyntax tokenを調べ、既存cell文字とtoken styleから`:text` operationを作ります。たとえば`:comment` tokenには`(:fg 8)`、`:keyword` tokenには`(:bold (:fg 6))`を指定します。現行の描画呼出しは`src/presentation/layout-windows.lisp:132-140`、style定義とtoken描画は`packages/feature/syntax-highlighting/src/presentation-syntax-highlighting.lisp:3-10,48-70`にあります。
LSP diagnostic hookも同じhit-test結果からbuffer positionを得て、診断range内の文字に`((:bg 1) (:fg 7))`を指定した`:text` operationを返します。現行ではdiagnostic取得を`src/presentation/layout-windows.lisp:9-13`で行い、overlayを`src/presentation/layout-windows.lisp:142-145`、spanとstyleを`src/presentation/layout-windows.lisp:207-244`で描きます。slice順ではsyntax-highlightingの後にLSPを呼ぶため、診断styleが重なるcellでは後から適用されます。
hookはframe cellとrenderer objectを変更できず、frameの作成と最終的な描画はrootが行います（`src/application/event-loop-rendering.lisp:17-20`）。
`:terminal-modes`はraw modeとalternate screenを開始する前に照会します（`src/application/startup-services.lisp:32-43`）。
`:before-save`と`:after-save`は`buffer-save`の現在の順序を維持します（`packages/feature/file-tree/src/infrastructure-buffer-filesystem.lisp:21-34`）。

`:terminal-modes`のkeywordとroot terminal adapterの対応は次のとおりです。

| keyword | terminal mode | 用途 |
|---|---|---|
| `:mouse-sgr` | DECSET/DECRST 1006 | SGR形式でmouse coordinateを送る |
| `:mouse-button-event` | DECSET/DECRST 1002 | press/releaseに加えてbutton押下中のmotionを送り、drag selectionを可能にする |
| `:bracketed-paste` | DECSET/DECRST 2004 | pasteを入力文字と区別する |

1002はbutton tracking、1006はmouse protocol encodingを選びます。
rootは要求をdedupeし、開始時に有効化したmodeをterminal session終了時に無効化します（[XTerm Control Sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#Mouse_Tracking)、仕様`docs/src/notes/requirements-modern-editor.md:291-292`）。
modeを各featureが直接設定する案は、terminal lifecycleをsliceごとに分散させるため却下します（`docs/src/notes/requirements-modern-editor.md:178-180`）。

W2aは`core/editor-session`にhit-testと端末出力の安全なrequest APIを置きます。
`hit-test-result`はopaque recordです。`make-hit-test-result(owner, kind, :window window, :buffer buffer, :position position, :target target)`はvalid resultを作ります。`:kind`は`:buffer-text`、`:window-blank`、`:mode-line`、`:feature-item`のいずれかです。`:buffer-text`ではwindow、buffer、positionが必須です。`:window-blank`と`:mode-line`ではwindowが必須です。`:feature-item`ではtargetが必須です。ownerはprovider ownerです。
`hit-test-coordinate(session, screen-x, screen-y)`は0-based terminal cellを受け、frame外ならnil、それ以外は`hit-test-result`かnilを返します。`register-hit-test-provider(owner, priority, function)`のfunctionは`(session screen-x screen-y)`を受け、ownerと一致するresultまたはnilを返します。異なるownerを指定したresultやkindとpayloadの不整合はregistration errorにします。大きいinteger priorityから順に照会し、同値では登録順を保ちます。W3-4のroot providerは`:core/presentation`、priority 0でbuffer text、window内の空白、mode lineを識別します。W3-10のfile-tree providerは`:feature/file-tree`、それより高いpriorityでfile-tree itemを`:feature-item`として返し、targetに選択可能なentryのopaque IDを入れます。旧`hit-test-buffer-position`は`:buffer-text`だけを`(values window buffer position)`へ変換し、それ以外はnilを返すcompatibility wrapperです。
W3-8はcore/editor-sessionのhit-test APIだけを呼び、`src/presentation/`をimportしません（現在の変換はbuffer positionからscreen cellへの一方向です。`src/presentation/frame-layout-cursor.lisp:58-76`）。

`request-terminal-clipboard-write(session, text)`はstringだけを受け取り、FIFO queueへ追加して`:queued`を返します。featureはterminalへ直接書きません。rootはrender/event-loop境界で`drain-terminal-clipboard-requests(session)`を呼び、その時点のtext listをFIFO順に受け取ります。drainはqueueをatomically空にし、呼出中に追加されたrequestは次回へ残します。rootは受け取ったtextをUTF-8/base64へ変換し、固定のOSC 52 framingで端末へ出力します。APIはescape sequenceやterminal targetを引数に取りません（`src/application/event-loop-rendering.lisp:17-20`、仕様`docs/src/notes/requirements-modern-editor.md:290`）。

W2aはroot lifecycle adapterも実装します。
`register-cli-option(owner, long-name, value-kind)`はfeature/lifecycleがCLI optionを登録します。`value-kind`は値を取らない`:switch`か、次のargvを値として取る`:value`です。同名optionの再登録と未登録optionはerrorにします。
rootは登録済みoptionと`loom [+LINE[:COL]] FILE...`をparseし、元argv、option map、各fileのpathと開始line/columnを持つfile-request listをopaqueな`startup-context`へ格納します。
`startup-context-file-requests(context)`はargv順のimmutable `startup-file-request`値のlist copyを返します。constructorはpath stringをcopyし、`startup-file-request-path`もcopyを返します。`startup-file-request-path`はargvで指定されたpath、`startup-file-request-line`と`startup-file-request-column`は1-based開始位置を返し、省略値はともに1です。rootだけがこれらの値を構築します。
rootはttyを取得し、opaqueな`terminal-session`と`startup-context`を`:startup(session, startup-context, terminal-session)`へ渡します。
`:startup`はterminal session取得後、user-initのloadと初回frameの前に呼びます。
`request-terminal-suspend(session)`はlifecycle commandがrootへsuspendを要求するAPIで、新規要求に`:queued`、保留中要求との重複に`:coalesced`を返します。rootは要求時にwake pipeを通知し、dispatch後にこの要求を処理します。`:suspend` hookを呼びterminal modeを復元してから自身をSIGTSTPで停止します。SIGCONT後はttyとterminal modeを取り直し、`:resume` hookを呼んでframeを描き直します。OSのSIGTSTPも同じsuspend/resume経路を使います。C-z commandはこのAPIを呼びます。

| root event | signature | 登録owner | 順序 |
|---|---|---|---|
| `:startup` | `(session startup-context terminal-session)` | `feature/lifecycle` | tty取得後、user-initと初回frameの前に呼ぶ。lifecycleはsession復旧とinit方針を適用する |
| `:signal` | `(session signal-name)`。signal-nameは`:term`、`:hup`、`:tstp`、`:cont`。戻り値は`:continue`または`:terminate` | `feature/lifecycle` | rootがOS signalを受けた直後に呼ぶ。lifecycleがrecoveryや終了方針を決める。TERM/HUPはrecovery後にterminateし、TSTP/CONTはsuspend/resume eventへ対応させる |
| `:suspend` | `(session)` | `feature/lifecycle` | rootがterminal modeを復元してプロセスを停止する前に呼ぶ |
| `:resume` | `(session terminal-session)` | `feature/lifecycle` | rootがttyを再取得してmodeを有効にした後、再描画前に呼ぶ |
| `:shutdown` | `(session reason)` | `feature/lifecycle` | event loop終了後、terminal sessionを閉じる前に呼ぶ |
| `:exit-status` | `(session reason)`。0〜255のinteger | `feature/lifecycle`のみ | rootはcleanup後にこの値をprocess statusとして返し、未処理errorは1にする |

OS signal、shutdown reason、終了statusの対応は次のとおりです。

| 入力 | `:signal`の値と処理 | shutdown reason | status |
|---|---|---|---|
| SIGTERM | `:term`。recovery callback後に`:terminate` | `:sigterm` | 143 |
| SIGHUP | `:hup`。recovery callback後に`:terminate` | `:sighup` | 129 |
| SIGTSTP | `:tstp`。`:suspend`、停止、SIGCONT後に`:resume`。processは継続 | なし | なし |
| SIGCONT | `:cont`。停止後のresume処理を実行 | なし | なし |
| C-z | signal eventなし。`request-terminal-suspend`でSIGTSTPと同じ処理 | なし | なし |
| 正常終了 | signal eventなし | `:normal` | 0 |
| 未処理runtime error | signal eventなし。rootの既存error境界でshutdown | `:runtime-error` | 1 |

TERM/HUPの`:exit-status`は表の固定値を返します。TSTP、CONT、C-zはshutdownではないため終了statusを生成しません。

rootはsignal handler、tty取得、terminal復元を所有します。
feature/lifecycleはargv optionを登録し、startup、signal、suspend、resume、shutdown callbackで復旧と保存を行います。
これによりW3-2は`src/application/startup-cli.lisp`やevent loopを編集せずFR-Eを実装できます（仕様`docs/src/notes/requirements-modern-editor.md:218-222`、現行CLI `src/application/startup-cli.lisp:3-13`）。

`*Messages*`のhistoryとnamed bufferのlifecycleは`feature/lifecycle`が所有し、W3-5は表示commandだけを実装します。
W2aは`core/minibuffer:register-message-sink(owner, function)`を追加し、`minibuffer-message`が各messageをsinkへ通知します。
W3-2はsink callbackから現在sessionを取り、W3-3の`feature/buffers:ensure-result-buffer(session, "*Messages*")`でbufferを得てmessageを追記します。
W3-5の`*Help*`とW3-6のsearch resultも同じresult-buffer APIを使います。
W3-2はbuffer registryのW3-3とmessage sink APIのW3-5に依存します。

W3-3は`feature/buffers`から`register-buffer(session, buffer)`、`unregister-buffer(session, buffer, :reason reason)`、`registered-buffers(session)`、`find-buffer-by-name`、`find-buffer-by-path`、`ensure-result-buffer`を公開します。
`ensure-result-buffer`は同名の既存bufferを返し、なければsession registryへ登録したbufferを作ります。
`registered-buffers(session)`はregistry順のlist copyを返します。`unregister-buffer(session, buffer, :reason reason)`はregistryから外す直前に`:buffer-close(session, buffer, reason)` hookを一度呼びます。
W3-9はこのhookへLSP callbackを登録してdidCloseを送り、closeを呼ぶW3-3にも依存します。

W3-10のsession restoreはsnapshotの検証とbuffer再構築をregistry変更前に完了します。その後`registered-buffers`で現行bufferを列挙し、各bufferを`unregister-buffer`へ`:reason :session-restore`で渡してclose hookを発火し、復元bufferを`register-buffer`で登録します。window tree、workspace、bookmarkなどの残りの状態はbuffer registry更新後にinstallします。restoreから`editor-state-buffers`を直接置き換えることは禁止します。これによりW3-9は復元で閉じたdocumentにもdidCloseを受け取ります。

`feature/mode:mode-description-for-buffer(buffer)`はmode nameとdescriptionを返します。
`describe-mode`を実装するW3-5はこのAPIを使い、mode registryの内部を直接読みません。
この問い合わせAPIとmode keymap providerはW3-7aが所有します（`packages/feature/mode/src/application-major-mode.lisp:3-15`）。

非同期作業は`core/editor-session`のbackground-work registryへ登録します。
`register-background-work(session, owner, poller, cancel-function)`はtokenを返します。pollerは`(session token)`を受け、nonblockingで`(values frame-dirty-p done-p)`を返します。workerは完了または出力可能時にthread-safeな`notify-background-work-ready(session, token)`を呼び、通知結果は新規queue時`:queued`、すでにqueue済みの同一tokenなら`:coalesced`、解除済みtokenなら`:ignored`です。
ready queueはFIFOで、tokenごとに重複を一つへcoalesceします。queueが空から非空へ変わるとrootのwake pipeを通知します。rootはterminal input fdとwake pipeを同時に待ち、wake後に`poll-ready-background-work(session)`をevent-loop threadで一度呼びます。このAPIは呼出開始時点のqueueをatomically drainして各tokenのpollerを一度ずつ呼び、`(values frame-dirty-p more-ready-p)`を返します。frame-dirty-pならrootはframeを再描画し、more-ready-pなら次のwaitをせず次のevent-loop turnでpollします。
drain後、poll中に同じtokenを含むready通知が来た場合は次batchにqueueし、現在のbatchへ再入しません。`done-p`がtrueならregistryと次batchからtokenを外します。`cancel-background-work`はtokenをcancelledにし、cancel callbackを一度だけ呼びます。workerは終了時にもreadyを通知し、pollerが`done-p`を返すまで登録を維持します。cancelled tokenのpoll結果はframe-dirtyに含めず、登録解除後の通知は`:ignored`です。
pollerがerrorをsignalした場合は成功扱いで握りつぶさず、既存event-loop error境界へ伝播してshutdown reason `:runtime-error`、status 1にします。rootはshutdown時に登録済みworkをcancelします。
入力がない間もready通知で検索結果を反映し、既存の50ms poll timeoutに検索featureを追加する案は採りません（`src/application/event-loop-control.lisp:24-54`、仕様`docs/src/notes/requirements-modern-editor.md:265`）。

hook errorは実行位置の既存error境界へ流します。
key/input hookのerrorはminibufferへ報告してevent loopを継続し、tick/render/terminal setupのerrorはstartup境界へ伝えてsessionを終了します。
save前hookのerrorはbufferを保存せず、save後hookのerrorは保存済みfileを残したまま呼出元へ伝えます。
buffer-close通知のerrorは診断へ残してcloseを続け、LSP serverの失敗でlocal buffer registryを残しません（仕様`docs/src/notes/requirements-modern-editor.md:298`）。
hook errorを全種類catchして継続する案は、失敗した保存やframeを成功に見せるため却下します。
現行key dispatchはcommand errorをminibufferへ報告し、起動境界は未処理errorをstatus 1へ変換します（`src/application/input-routing-dispatch.lisp:56-71`、`src/application/startup-services.lisp:32-51`）。

## 3. command登録API

各sliceは自分の`commands-*.lisp`から`loom/core/command:register-command-spec`を呼びます。
登録関数はowner、ID、M-x name、command function designatorを受け取り、specをASDF load時に登録します。

```lisp
(register-command-spec :feature/search "isearch-forward" "isearch-forward"
                       #'isearch-forward
                       :keys '((:control #\s))
                       :keymap :global
                       :group "editing"
                       :help "Search forward"
                       :help-order 30
                       :mutates nil
                       :prompts '(:free-string)
                       :needs-region nil
                       :external nil
                       :modes '(:all))
```

canonical specは`:owner`、`:id`、`:name`、`:group`、`:command`、`:keys`、`:keymap`、`:help`、`:help-order`と5種のmetadataを保持します。
W2aの`command-spec`はopaqueで、command functionのreaderはexportしません。callerが読めるM-x用readerは`command-spec-id`と`command-spec-name`です。
`:id`は全commandで一意なstable stringです。
`:name`はM-x名なので`nil`を許し、`nil`のspecも`:id`を必ず持ちます。
W0-3の`%command-spec-identifier`は`:name`がある場合はその値、ない場合はcommand symbolのlowercase nameを返し、catalogとtraceの両方が同じ関数を使います。
W2aはその値をcanonical `:id`としてspecに保持し、catalog JSONの`id`とtrace JSONの`command`へ出力します。
無名の`execute-extended-command`はID `execute-extended-command`でcatalogに含めますが、`:name nil`なのでM-x候補には含めません。
そのcommandを起動するM-x keyは`:key`、promptから選んだcommandは`:mx`でtraceします。
`command-completion-candidates(prefix)`はprefixに合うM-x対象のopaque `command-spec` listをstable name順で返し、`:name nil`のspecを除きます。completion UIは`command-spec-name(spec)`を表示し、選択されたspecを値として保持します。確定時は`command-spec-id(spec)`でcanonical IDを取り、`invoke-command(id, :mx)`を呼びます。`find-extended-command-spec(name)`もcallableではなくspecを返します。W2aでcallableを返す`find-extended-command`をexport対象から外し、M-x candidateの表示文字列からIDを再生成する経路をなくします。

5種のmetadataは`:mutates`、`:prompts`、`:needs-region`、`:external`、`:modes`です。
parserは5キーの省略をerrorにし、`nil`や空listを値にする場合もキーを明示させます。
登録関数も同じ検査を行い、移行でparserを通らないspecが入っても登録時errorになります。
`:mutates`と`:needs-region`はboolean、`:prompts`は入力種別のlist、`:modes`はkeyword listです。
`:prompts`の入力種別は`:free-string`、`:completion`、`:yes-no`、`:numeric`です。
`:external`は空でないASCII lowercase identifier stringのlistです。各文字は`a-z`、`0-9`、`-`、`_`、`.`のいずれかに限ります。
parseと登録の両方でこの語彙を検証し、他の表記はerrorにします（`src/application/command-registry-forms.lisp:34-47`）。

W0-3がmainへ入れた起動関数は`invoke-command(command, route)`です（`src/application/commands-misc.lisp:27-34`）。
現状はcallableとrouteを受け取り、`record-command-trace`を呼んでからcommandを引数なしで実行します。
W2aではこれを`invoke-command(command-id, route, &rest args)`へ拡張します。
gatewayはcanonical IDから登録specをlookupし、引数を順序どおりcommand functionへ渡します。
key dispatch、M-x、C-uのuniversal-argument action、macro playback、mouse hook、その他のcommand hookはすべてこのgatewayを通り、callerからの直接`funcall`とtrace書き込みを禁止します。
routeは`:key`、`:mx`、`:macro`、`:paste`、`:mouse`を使います。W3-1が`:paste`と`:mouse`をcore/commandへ追加してexportし、W3-8はそのrouteを使用します。

`bind-key`に渡す任意callableも、keymapへ保存する前に登録します。
user-initは`register-key-command(owner, id, function, keymap, keys, metadata)`を使い、M-x名のないkey-only specとして登録します。
closureを含むfunctionを許しますが、owner内で安定した明示IDと5 metadataを必須にします。
keymapにはcallableではなくcanonical IDを保存し、dispatchは必ずgatewayへIDを渡します。
登録されていないcallableを受けた場合はbinding時にerrorにします。

self-insertとpaste insertionはinternal specとして登録し、通常keyは`invoke-command("core/self-insert", :key, character)`、macro再生は同じIDと`:macro`、pasteは`invoke-command("core/insert-pasted-text", :paste, text)`を呼びます。
この2つのinternal specはpublic catalogとtraceの両方から除外します。traceはcommand選択を記録するためのもので入力本文を保存せず、入力ごとのIDをpublic catalogへ加えると既存120件のuser-facing catalogとの比較も変わるためです。
両specにも5 metadataを必須にし、非公開扱いはcatalog/traceの出力だけに適用します。
他のkey-only callable specはcanonical IDを持ち、public catalogとtraceの双方に含めます。

既存120件の`universal-argument` specは`:key`または`:macro` routeでgatewayを通りtrace対象になります。繰返しC-uも同じcommand invocationとして記録します。
prefix digitとnegative signはcore/command内の状態遷移であり、独立したcommand invocationではないためcatalogとtraceの対象外です。
trace eventはcommand ID、route、sequence、pidに加え、command起動直前のnormalized prefix valueとexplicit flagを記録します。universal-argument eventには更新前の値が入り、蓄積後の値は次にprefixを消費するcommand eventに記録します。
command argsとraw prefix keystrokeはtraceへserializeしません。traceは入力内容やcallable引数を保存する再生ログではありません。

`:owner`は`:core/command`または`:feature/<slice>`のようなkeywordです。
`:keymap`はbindingを登録するmapのIDで、既定値を`:global`にします。
`keymap` IDが同じspec同士だけをcollision検査の対象にします。
`:modes`はcommand metadataとして保持し、keymap IDの代用にはしません。
modeごとに別keymapを使う場合は異なる`:keymap`を指定します。

登録は次の規則で検査します。

| 条件 | 処理 |
|---|---|
| 同じ`:id`が別ownerに存在する | 登録時にconditionをsignalし、両ownerとIDをerrorへ含める |
| 同じ`:name`が別ownerに存在する | M-x名の曖昧さを避けるため登録errorにする |
| 同じowner、ID、正規化済みspecが再登録される | 既存specを返し、catalogを変更しない |
| 同じownerとIDで異なるspecが登録される | metadataの上書きを避けるため登録errorにする |
| 同じ`:keymap`で登録済みsequenceとexact matchまたは一方が他方のprefixになる | nameの有無によらず登録errorにする。二つのsequenceが共通prefixを持つだけなら許可する |
| `:name`が`nil` | M-x lookupから除外し、`:id`によるcatalogとtraceの識別は維持する |

key sequenceの検査前に`defkeys-key-sequence`でdescriptorへ変換し、`normalize-key-descriptor`でmodifier順を揃えます。
登録済みsequence全体と比較し、exact matchまたは一方が他方のprefixの場合だけ衝突として扱います。
共通prefixはkeymapの複数段dispatchに必要なので許可します。
実際のkeymapを書き換える前に全registrationを検査し、衝突時はbinding tableを変更しません。
現在の`keymap-define-key`はcollisionを検査せず、同じkeyを後のcommandで上書きします（`src/domain/keymap.lisp:12-28`）。
この上書きを許す案は、どのsliceがbindingを奪ったかを登録時に特定できないため却下します。

登録関数は同じownerの再loadに備えて冪等にします。
異なるmetadataを持つ再登録を最後の値で上書きする案は、ASDF load順によってcatalogが変わるため却下します。
query APIは`command-specs`と`find-command-spec`を公開し、callerに`*command-specs*`の破壊的変更を許しません。
`--dump-catalog`はこのquery APIからJSONを出し、ownerとIDでstable sortします。
catalogの`id` fieldとtraceの`command` fieldは同じcanonical IDを使います。
W0-3現在、catalog JSONの`name` valueとtrace JSONの`command` valueは`%command-spec-identifier`により一致し、catalogには`mx-eligible`も出力します。
現行dumpにないcanonical ID、owner、keymap IDをW2aのcatalog schemaへ加え、canonical specを比較できるbaselineを取ります（`src/application/command-registry.lisp:86-108`、`src/main.lisp:12-16`）。
登録後のcatalogを直接編集する現在のuser-init方式は、同じ登録APIに置き換えます（`packages/feature/user-init/src/application-user-configuration.lisp:36-65`）。

W2aでは現行120件のownerをimplementation functionの所属で確定します。
既存の九つのgroup file名は分類表示に使い、owner判断には使いません。
例えばmovement groupはcore/buffer、lisp-structure、window、core/commandに分かれます。
files/projectsはfiles、file-tree、project、mode、auto-saveに分かれます。
toolingはshell、terminal、git、format、lspへ分けます。
未修飾symbolはfunction定義の移設先を4.2の責務表と照合してからownerを付けます（`src/application/command-definitions.lisp:3-12`、`docs/src/notes/requirements-modern-editor.md:145-171`）。

catalog比較の前に、中央定義の全120件へowner、ID、5種metadataを付けます。
登録関数がmetadataの欠落をerrorにするため、120件をsliceへ移す作業では、移したspecが5キーすべてを持つことを登録時errorで保証します。
値が`nil`または空listでも、各キーを省略してはいけません。
その状態で`loom --dump-catalog > catalog-before.json`を取り、120件であることとcanonical JSON schemaを確認します。
次に全specを一括移設し、中央の`command-definitions*.lisp`を削除します。
移設後も`loom --dump-catalog > catalog-after.json`を実行し、JSONをbyte単位で比較します。
順序が固定されていない場合は、dump自体をowner/name/idでstable sortしてから比較します。
名前、command identity、key、help group、help order、metadata、ownerの差分はすべてerrorです。
120件の数だけ比べる案は、同数のspecを入れ替えても検出できないため却下します。

## 4. slice別ASDF system

cl-nix-forge v0.5.0の`lispAsdPath`は`CL_SOURCE_REGISTRY`へ追加pathを渡す引数です。
workspace外の最小fixtureで、nested ASDF systemを`lispAsdPath = [ "packages//" ]`からbuildできることを確認しました。
fixtureは`packages/demo/loom-asd-probe.asd`、`probe.lisp`、`probe-test.lisp`の3ファイルです。
positive buildはtest-opを含めexit 0でした。
`lispAsdPath = [ "packages" ]`へ変えたnegative controlはnested systemを発見できずexit 1でした。
cl-nix-forgeは追加pathを`$PWD/${path}`の形でsource registryへ渡します（`lib/core/asdf-derivation.nix:271,352-357`）。

実装担当は同じ最小fixtureで実験を再現します。

1. workspace外の一時directoryに`packages/demo/`を作ります。
2. production system `loom-asd-probe`とtest system `loom-asd-probe/test`を定義し、testはproduction functionの戻り値をassertします。
3. `mkPackageFlake`の`packageArgs`から`lispAsdPath = [ "packages//" ]`を設定し、productionとtest systemをloadしてbuildします。
4. `lispAsdPath`を`[ "packages" ]`へ変更して同じbuildを行い、system discovery failureをcontrolとして確認します。
5. positiveが成功し、negativeがsystem discoveryで失敗した場合に`packages//`を採用します。

`packages//`が使えない場合は、4.2で確定した各`packages/core/<slice>/`と`packages/feature/<slice>/`を`lispAsdPath`へ個別に列挙します。
通常の`packages/`を渡す案は、nested `.asd`を見つけられなかったため却下します。
実際の実験は既にnegative controlを含めて完了し、再現手順のためだけに同じ条件を文書化しました。

W2bでは各slice directoryにASDF定義を一つずつ置きます。
system名は`loom-core-buffer`、`loom-feature-files`のようにuniqueにし、ASDF file名もsystem名に合わせます。
package名は既定の`loom/core/buffer`、`loom/feature/files`を使います。
W2bではslice別のproduction/test `.asd` skeletonと再帰discoveryを追加しますが、root `loom.asd`と`loom/test`は現在の全source/test component listを維持します。
この段階ではslice skeletonをroot aggregateの依存先にせず、各sourceとtestの唯一の所有先はrootのままです。
W2cでは一つのsliceのsource、test、`t/paths.sexp`を同じcommitでslice systemへ移し、同じcommitで旧root componentを外してaggregateの`:depends-on`へ切り替えます。
この移設をsliceごとに繰り返し、最後のlegacy source/testが移ったcommitで初めてroot `loom.asd`をcomposition system、root `loom/test`をtest aggregateにします。
各中間commitでは移設済みcomponentはslice systemだけ、未移設componentはroot systemだけに属し、二重loadも未登録testも発生させません。
全段階で一回の`asdf:test-system "loom"`から全unit suiteを実行します。
system名のslash表記をASDF名に流用する案はpackage名とsystem discoveryを結び付けるため避け、filenameとsystem名はhyphen区切りにします（`loom.asd:1-`、`flake.nix:317-349`）。

Nixの`mkPackageFlake`に次を加えます。

```nix
packageArgs = _: {
  lispAsdPath = [ "packages//" ];
};
```

現行flakeは`asd = ./loom.asd`を渡し、`packageArgs`を設定していません（`flake.nix:317-349`）。
`flake.nix`のsource filterには`.asd`と`.lisp`が含まれるため、slice system fileもflake sourceへ含めます（`flake.nix:100-137`）。

`run-tests.lisp`、`scripts/coverage.lisp`、dependency contract testはrootだけをloadする前提を外します。
runnerは`packages/`をASDFのtree registryへ加え、root `loom/test`からlegacy test componentと移設済みslice test systemを一度ずつloadして全suiteを実行します。
`t/unit/dependency-contract-test.lisp`は全sliceの`.asd`を再帰列挙してsystem formを読み、repository内systemとexternal systemを分けます。
全production sliceのexternal `:depends-on`の和集合を`flake.nix`の`lispDependencies`と比較します。
全test systemのexternal dependencyからproduction dependency集合を除いた和集合を`lispCheckDependencies`と比較します。
runnerがloadするroot aggregate systemは、productionとtest systemの全体を依存に含むことを検査します。
lang-markupのexternal kit dependencyはlang-markup sliceの`.asd`へ移します。
現在のtestはroot `loom.asd`しか読みません（`t/unit/dependency-contract-test.lisp:97-149`）。
runnerもrootとsibling directoryを列挙し、`loom`と`loom/test`をforce loadしています（`run-tests.lisp:44-61`、`scripts/coverage.lisp:62-69,132-134`）。

## 5. W2a〜W2dの移設順

W2は直列に進め、各commitでunit testとE2E全件を実行します。
この条件はW2仕様が各段階へ求めています（`docs/src/notes/requirements-modern-editor.md:465-474`）。

| phase | commit列 | commitごとの検査 |
|---|---|---|
| W2a | 1. owner-aware registry、5 metadataのparse時必須化とregistration時検査、dump query APIとcommand invocation gatewayを追加する。2. E2E coverage readerを`--dump-catalog`へ切り替え、既存120 specにownerとIDを付け、5キーの存在を登録時errorで検査してcanonical dumpを保存する。3. specを一度にslice別fileへ移し、中央定義を削除する | 5キー各々の省略でparse時と登録時の両方がerrorになるtest、invalid `:external` identifier、duplicate ID/name、same-owner idempotency、key collision、catalog/trace ID一致とnil-name spec、任意callable登録と引数転送、prefix snapshot、self-insertのcatalog/trace除外、key/M-x/C-u/macro routeのgateway test。key/input-event hookも同じgatewayを通す。各段階で全unitとE2E。最後にbefore/after dumpの`diff -u`が空、catalog件数が120 |
| W2b | 1. `lispAsdPath`最小実験とflake `packageArgs`を追加する。2. 全sliceのproduction/test `.asd` skeletonと再帰system discoveryを用意する。3. root `loom.asd`と`loom/test`の現行source/test inventoryを維持したままrunner、coverage、dependency union test、E2E scenario discoveryと`Session.restart()`を追加する | positive/negative ASDF discovery fixture、Nix eval、`nix flake check`、dev shellでのtest、dumped binary起動、E2E全件 |
| W2c | 4.2の移設を依存順に行う。一commitで一sliceのsource、test、`t/paths.sexp`を移し、root component listをslice dependencyへ同時に切り替える。最後の移設commitでrootをaggregate-onlyにする | 各commitで移設対象のunit、aggregateからの全unit、E2E全件を実行する。直前baselineとtest件数および結果を比較し、source/testの二重loadと未登録がないことを確認する |
| W2d | boundary testをwarningからfailureへ切り替え、残存違反をowner別allowlistへ記録する | allowlist内の違反だけが通り、未知の依存辺、private `::`、domain上位層参照を追加したcontrolでtestが失敗する |

W2bはE2E harnessも更新します。
`t/e2e/loom-test.py`のscenario discoveryは既存の`t/e2e/scenarios/`に加え、`packages/<slice>/t/e2e/scenarios/*.py`を再帰的に読み込みます。
各slice scenarioは既存`@scenario`登録規約を使い、`--list`のscenario一覧と`--only <scenario-fragment>`の検索対象へ追加します。command coverageはW2aで切り替えた`--dump-catalog` readerが引き続き検査します。
実行経路は既存の`nix run .#e2e -- --only <scenario-fragment>`とし、引数なしではrootとsliceの全scenarioを実行します。
`t/e2e/loom_e2e/session.py`の`Session.restart()`は現在のchildを閉じてreapし、同じscratch HOME、argv、locale、profile、session file path、trace pathで新processを起動します。
scratch directoryは保持し、screenとchild handleは新process用に初期化します。
R8再起動scenarioは`packages/feature/session/t/e2e/scenarios/`へ置き、root harnessはW2b以降W3 laneが変更しません。

W2cの移設順はcore/buffer、core/window-tree、core/minibuffer、core/command、core/editor-sessionから始めます。
その後、files、buffers、file-tree、minibuffer-ui、completion、help、kill-ring、clipboard、mouse、search、project、mode、syntax-highlightingを移します。
最後にlisp-structureと言語slice、bookmark、window、workspace、session、register、keyboard-macro、lsp、terminal、shell、format、git、evaluation、auto-save、lifecycle、user-initを移します。
files sliceを移すW2c commitでは`packages/feature/file-tree/src/application-commands-file-save.lisp`と対応するtestを`packages/feature/files/src/application-commands-file-save.lisp`へ同時に移します。W3開始時点でこのfileはW3-3だけが所有し、W3-10のfile-tree pathには含めません。
4.2に記載の責務を基準にしてもdependency DAGが循環する場合は、core APIの不足としてそのcommitを止め、allowlistで隠しません。

各sliceの移設commitは、実装fileとtestを一緒に移し、旧pathと新pathの重複loadを残しません。
既存test結果を保つためにtemporary shimを根として残す案は、境界testで違反を見逃すため却下します。
W2cでは既存E2E scenarioと`t/paths.sexp`のownerを揃えます。
E2E shared harnessとroot package inventoryはW2bが専有し、各slice ownerは自sliceの`src/`、`t/`、`t/paths.sexp`、`t/e2e/`だけを変更します（`docs/src/notes/requirements-modern-editor.md:425-443`）。

W2bでは`.asd`をNix sourceへ含めるため、新規`.asd`をgit indexへ追加してから`nix build`を実行します。

## 6. W3のpathとexport境界

W2bで各sliceの`.asd`、`src/package.lisp`、`t/paths.sexp`を作り、W2cで既存実装とtestをslice directoryへ移します。
W3のlaneは所有sliceの`src/**`、`t/**`、`t/paths.sexp`、`t/e2e/**`を編集できます。`t/`にはunit testとE2E scenarioを含めます。
共有root、`flake.nix`、root `loom.asd`、全体test runner、E2E harnessはW3で編集しません（`docs/src/notes/requirements-modern-editor.md:416-423,425-443`）。

| lane | 所有path | exportと他laneへの境界 | 仕様根拠 |
|---|---|---|---|
| W3-1 | `packages/core/command/src/`、`packages/core/command/t/`、`packages/core/command/t/paths.sexp`、`packages/core/command/t/e2e/` | `packages/core/command/src/package.lisp`のexportを専有し、`:paste`と`:mouse` routeを追加する。global key reference、登録衝突検査、未知escape sequenceのD4処理を持つ。各featureが移すkeyは各feature ownerが登録し、W3-8は追加routeを使う | `docs/src/notes/requirements-modern-editor.md:488` |
| W3-2 | `packages/feature/lifecycle/src/`、`packages/feature/lifecycle/t/`、`packages/feature/lifecycle/t/paths.sexp`、`packages/feature/lifecycle/t/e2e/`、`packages/feature/user-init/src/`、`packages/feature/user-init/t/`、`packages/feature/user-init/t/paths.sexp`、`packages/feature/user-init/t/e2e/` | `*Messages*`のhistoryとbuffer lifecycleを所有する。W2 root adapterでargv、signal、suspend/resume、`request-terminal-suspend`を扱う。W3-3のbuffer APIとW3-5のmessage-sink APIに依存する。root CLIとevent loopは編集しない | `docs/src/notes/requirements-modern-editor.md:489` |
| W3-3 | `packages/feature/files/src/`、`packages/feature/files/t/`、`packages/feature/files/t/paths.sexp`、`packages/feature/files/t/e2e/`、`packages/feature/buffers/src/`、`packages/feature/buffers/t/`、`packages/feature/buffers/t/paths.sexp`、`packages/feature/buffers/t/e2e/` | file I/O、buffer registry、switch/kill commandを所有する。`register-buffer`、`unregister-buffer`、`registered-buffers`、`find-buffer-by-name`、`find-buffer-by-path`、`ensure-result-buffer`を公開し、close前に`:buffer-close` hookを発火する。file-save commandはW2cでfilesへ移し、W3-3が所有する | `docs/src/notes/requirements-modern-editor.md:490` |
| W3-4 | `packages/core/buffer/src/`、`packages/core/buffer/t/`、`packages/core/buffer/t/paths.sexp`、`packages/core/buffer/t/e2e/`、`src/infrastructure/terminal-renderer.lisp`、`src/infrastructure/terminal-renderer-cursor.lisp`、`src/infrastructure/terminal-renderer-text.lisp`、`src/infrastructure/terminal-renderer-text-wrapping.lisp`、`src/presentation/` | `packages/core/buffer/src/package.lisp`のexportとrenderer/presentationを専有する。root `compose-frame`を`make-frame-snapshot`でimmutable frameを返す実装へ変更し、W2のhit-test providerを登録する。`:render` operationはcopy-on-write適用APIで反映する。他laneは描画APIを追加せず`:render` hookを使う | `docs/src/notes/requirements-modern-editor.md:491` |
| W3-5 | `packages/core/minibuffer/src/`、`packages/core/minibuffer/t/`、`packages/core/minibuffer/t/paths.sexp`、`packages/core/minibuffer/t/e2e/`、`packages/feature/minibuffer-ui/src/`、`packages/feature/minibuffer-ui/t/`、`packages/feature/minibuffer-ui/t/paths.sexp`、`packages/feature/minibuffer-ui/t/e2e/`、`packages/feature/completion/src/`、`packages/feature/completion/t/`、`packages/feature/completion/t/paths.sexp`、`packages/feature/completion/t/e2e/`、`packages/feature/help/src/`、`packages/feature/help/t/`、`packages/feature/help/t/paths.sexp`、`packages/feature/help/t/e2e/` | `packages/core/minibuffer/src/package.lisp`のexportを専有し、`register-message-sink`を公開する。`describe-mode`はW3-7aの`mode-description-for-buffer`を使い、`*Help*`はW3-3の`ensure-result-buffer`を使う。W3-2が所有する`*Messages*` storageには触れない | `docs/src/notes/requirements-modern-editor.md:492` |
| W3-6 | `packages/feature/search/src/`、`packages/feature/search/t/`、`packages/feature/search/t/paths.sexp`、`packages/feature/search/t/e2e/`、`packages/feature/project/src/`、`packages/feature/project/t/`、`packages/feature/project/t/paths.sexp`、`packages/feature/project/t/e2e/` | result listと`next-error` APIを所有する。search resultはW3-3の`ensure-result-buffer`を使い、background-work APIへworkerを登録してwake/pollを行う。completionは`poll-ready-background-work`のframe-dirty-pで再描画する | `docs/src/notes/requirements-modern-editor.md:493` |
| W3-7a | `packages/feature/mode/src/`、`packages/feature/mode/t/`、`packages/feature/mode/t/paths.sexp`、`packages/feature/mode/t/e2e/`、`packages/feature/syntax-highlighting/src/`、`packages/feature/syntax-highlighting/t/`、`packages/feature/syntax-highlighting/t/paths.sexp`、`packages/feature/syntax-highlighting/t/e2e/`、`packages/feature/lang-lisp/src/`、`packages/feature/lang-lisp/t/`、`packages/feature/lang-lisp/t/paths.sexp`、`packages/feature/lang-lisp/t/e2e/`、`packages/feature/lang-nix/src/`、`packages/feature/lang-nix/t/`、`packages/feature/lang-nix/t/paths.sexp`、`packages/feature/lang-nix/t/e2e/`、`packages/feature/lang-web/src/`、`packages/feature/lang-web/t/`、`packages/feature/lang-web/t/paths.sexp`、`packages/feature/lang-web/t/e2e/`、`packages/feature/lang-markup/src/`、`packages/feature/lang-markup/t/`、`packages/feature/lang-markup/t/paths.sexp`、`packages/feature/lang-markup/t/e2e/` | mode provider、truncate policy、mode問い合わせAPIを所有する。全言語定義を各language sliceへ移すcommitがmainに入るまでそのsliceのpathを一時所有し、その後にW3-7b〜eへ移譲する | `docs/src/notes/requirements-modern-editor.md:494` |
| W3-7b | `packages/feature/lang-lisp/src/`、`packages/feature/lang-lisp/t/`、`packages/feature/lang-lisp/t/paths.sexp`、`packages/feature/lang-lisp/t/e2e/`、`packages/feature/lisp-structure/src/`、`packages/feature/lisp-structure/t/`、`packages/feature/lisp-structure/t/paths.sexp`、`packages/feature/lisp-structure/t/e2e/`、`packages/feature/evaluation/src/`、`packages/feature/evaluation/t/`、`packages/feature/evaluation/t/paths.sexp`、`packages/feature/evaluation/t/e2e/` | Lisp mode、S式操作、evaluationを所有する。S式移動keyは`:global` mapへ登録し、`kill-sexp`と他の構造編集keyは`:lang-lisp` mode mapへ登録する | `docs/src/notes/requirements-modern-editor.md:495` |
| W3-7c | `packages/feature/lang-nix/src/`、`packages/feature/lang-nix/t/`、`packages/feature/lang-nix/t/paths.sexp`、`packages/feature/lang-nix/t/e2e/` | Nix modeとlanguage definitionを所有する | `docs/src/notes/requirements-modern-editor.md:496` |
| W3-7d | `packages/feature/lang-web/src/`、`packages/feature/lang-web/t/`、`packages/feature/lang-web/t/paths.sexp`、`packages/feature/lang-web/t/e2e/` | TS、JS、JSX、JSON、HTML、CSS、YAMLのlanguage definitionを所有する | `docs/src/notes/requirements-modern-editor.md:497` |
| W3-7e | `packages/feature/lang-markup/src/`、`packages/feature/lang-markup/t/`、`packages/feature/lang-markup/t/paths.sexp`、`packages/feature/lang-markup/t/e2e/` | MarkdownとOrgのparser integrationを所有する | `docs/src/notes/requirements-modern-editor.md:498` |
| W3-8 | `packages/feature/kill-ring/src/`、`packages/feature/kill-ring/t/`、`packages/feature/kill-ring/t/paths.sexp`、`packages/feature/kill-ring/t/e2e/`、`packages/feature/clipboard/src/`、`packages/feature/clipboard/t/`、`packages/feature/clipboard/t/paths.sexp`、`packages/feature/clipboard/t/e2e/`、`packages/feature/mouse/src/`、`packages/feature/mouse/t/`、`packages/feature/mouse/t/paths.sexp`、`packages/feature/mouse/t/e2e/` | mouse eventのD4はW3-8が担当し、W3-1はunknown escapeだけを担当する。W3-1の`:mouse` routeを使い、正規化eventは`:input-event` hookから受ける。terminal modeは`:terminal-modes` hookで1006 SGR encoding、1002 button tracking、2004 bracketed pasteを要求する。hit-testはW3-4、file-tree item providerはW3-10が実装し、clipboard requestはroot drain APIを使う。core/command exportは変更しない | `docs/src/notes/requirements-modern-editor.md:499` |
| W3-9 | `packages/feature/lsp/src/`、`packages/feature/lsp/t/`、`packages/feature/lsp/t/paths.sexp`、`packages/feature/lsp/t/e2e/` | W3-6のresult list/navigation APIとW3-3のbuffer registryへ依存する。W3-3の`:buffer-close` hookからdidCloseを送り、restore中のcloseも処理する。他laneのpath/exportは編集しない | `docs/src/notes/requirements-modern-editor.md:500` |
| W3-10 | `packages/feature/file-tree/src/`、`packages/feature/file-tree/t/`、`packages/feature/file-tree/t/paths.sexp`、`packages/feature/file-tree/t/e2e/`、`packages/feature/window/src/`、`packages/feature/window/t/`、`packages/feature/window/t/paths.sexp`、`packages/feature/window/t/e2e/`、`packages/feature/workspace/src/`、`packages/feature/workspace/t/`、`packages/feature/workspace/t/paths.sexp`、`packages/feature/workspace/t/e2e/`、`packages/feature/session/src/`、`packages/feature/session/t/`、`packages/feature/session/t/paths.sexp`、`packages/feature/session/t/e2e/`、`packages/feature/bookmark/src/`、`packages/feature/bookmark/t/`、`packages/feature/bookmark/t/paths.sexp`、`packages/feature/bookmark/t/e2e/`、`packages/feature/register/src/`、`packages/feature/register/t/`、`packages/feature/register/t/paths.sexp`、`packages/feature/register/t/e2e/`、`packages/feature/keyboard-macro/src/`、`packages/feature/keyboard-macro/t/`、`packages/feature/keyboard-macro/t/paths.sexp`、`packages/feature/keyboard-macro/t/e2e/` | file-tree local keymapはW3-1のregistration APIを使う。file-save commandと対応testはW2cでfilesへ移し、W3-10のfile-tree `src/`と`t/`所有pathから除外する。session restoreはW3-3のbuffer registryと`:buffer-close` hookを使う。core/window-treeとcore/editor-sessionのexportは追加しない。R8 restart scenarioは`packages/feature/session/t/e2e/scenarios/`に置く | `docs/src/notes/requirements-modern-editor.md:501` |
| W3-11 | `packages/feature/shell/src/`、`packages/feature/shell/t/`、`packages/feature/shell/t/paths.sexp`、`packages/feature/shell/t/e2e/`、`packages/feature/format/src/`、`packages/feature/format/t/`、`packages/feature/format/t/paths.sexp`、`packages/feature/format/t/e2e/`、`packages/feature/git/src/`、`packages/feature/git/t/`、`packages/feature/git/t/paths.sexp`、`packages/feature/git/t/e2e/`、`packages/feature/terminal/src/`、`packages/feature/terminal/t/`、`packages/feature/terminal/t/paths.sexp`、`packages/feature/terminal/t/e2e/`、`packages/feature/auto-save/src/`、`packages/feature/auto-save/t/`、`packages/feature/auto-save/t/paths.sexp`、`packages/feature/auto-save/t/e2e/` | command導線と外部toolの成功・失敗を検証する。auto-saveはW2のeditor-session save-hook registry、W3-3のfiles save APIを使い、root terminal lifecycleとflakeは編集しない | `docs/src/notes/requirements-modern-editor.md:502` |

### W3 laneの依存DAG

全laneはW2完了後に開始します。下表は11.6に記載された依存に、上記API所有とpath引渡しのための設計依存を加えた直接依存です。

| lane | 直接依存 | 依存理由 |
|---|---|---|
| W3-1 | W2 | core/command routeとcatalogを実装する |
| W3-2 | W2、W3-3、W3-5 | buffer lifecycle APIとmessage-sink APIを使う |
| W3-3 | W2 | files、buffer registry、close hookを実装する |
| W3-4 | W2 | renderer、frame snapshot、hit-test root providerを実装する |
| W3-5 | W2、W3-3、W3-7a | result bufferとmode問い合わせAPIを使う |
| W3-6 | W2、W3-3 | search result bufferを使う |
| W3-7a | W2 | mode/truncate/query APIと初回language移設を実装する |
| W3-7b、W3-7c、W3-7d、W3-7e | W3-7aによる全言語定義の移設commit | このcommitがmainに入った後でW3-7aから各言語sliceへpathを引き継ぐ |
| W3-8 | W2、W3-1、W3-4、W3-10 | mouse route、hit-test実装、file-tree item providerとactionを使う |
| W3-9 | W2、W3-3、W3-6 | buffer close hookとresult/navigation APIを使う |
| W3-10 | W2、W3-1、W3-3 | keymap registrationとbuffer registry/close hookを使う |
| W3-11 | W2、W3-3 | auto-saveがfiles sliceのsave APIを使う |

この依存DAGで並列に開始できるwaveは、`{W3-1, W3-3, W3-4, W3-7a}`、`{W3-5, W3-6, W3-7b, W3-7c, W3-7d, W3-7e, W3-10, W3-11}`、`{W3-2, W3-9}`、`{W3-8}`です。wave内のlaneは共有pathを編集しない範囲で並行できます。

仕様11.6の依存列との差分は次のとおりです。仕様列は変更しません。

| lane | 設計で追加・変更した依存 | 理由 |
|---|---|---|
| W3-2 | W3-3、W3-5 | buffer registryとmessage sink |
| W3-5 | W3-3、W3-7a | result bufferとmode問い合わせ |
| W3-6 | W3-3 | search result buffer |
| W3-8 | W3-4、W3-10 | hit-test implementationとfile-tree item/action |
| W3-9 | W3-3 | buffer-close hookからdidCloseを送る |
| W3-10 | W3-3 | restoreをbuffer registryとclose hook経由で行う |
| W3-11 | W3-3 | auto-saveからfiles save APIを呼ぶ |
| W3-7b〜e | W3-7a全体の完了から、全言語定義を移設するcommitのmain反映へ変更 | 言語sliceのpathを引き渡した後、W3-7aがmode/highlighting protocolを仕上げる間に各言語laneを開始できる |

W3-1、W3-4、W3-5だけが各自のcore package exportを変更できます。
core/window-treeとcore/editor-sessionのexportはW2で確定し、W3 laneは不足APIを追加せず、必要なsymbolと利用理由を報告します（`docs/src/notes/requirements-modern-editor.md:432-436,423`）。
W3-4の描画拡張はimmutable `frame-snapshot`と`:render` operation hook、W3-8のpaste/mouse処理は`:input-event` hookを通します。
W3-10のlocal keymapは`:keymap` IDを指定してcore/commandへ登録します。
この境界を越える変更が必要になった場合、laneはその依存作業を止め、owner担当へAPI追加を依頼します。

## 指摘事項の解決状況

`Done`は、該当事項を設計で解決し、実装担当が使う契約またはpathを本文へ記載したことを示します。

| ID | 指摘 | 状態 | 設計上の対応 |
|---|---|---|---|
| B1 | C4のscroll command移設漏れ | Done | scroll commandをfeature/windowへ移し、core/window-treeのscroll stateとgeometry APIを使う。section 1 |
| B2 | rootのmode参照とvisual-line truncate判定 | Done | mode keymap providerとtruncate policyをcore APIへ注入し、visual-line operationはcore/window-tree APIでwindow stateを読む。section 1 |
| B3 | W3-2向けroot CLI/lifecycle拡張点不足 | Done | W2 root adapterにCLI option、file request type、suspend request、signal/reason/status表を定義する。sections 2、6 |
| B4 | mouse decoder、hit-test、OSC 52契約不足 | Done | payloadのbutton/modifier/wheel規約、window blank/mode line/file-tree hit-test、clipboard request/drainを定義する。sections 2、6 |
| B5 | didCloseを届けるbuffer-close経路不足 | Done | W3-3のregistry/close APIをsession restoreも通し、W3-9がdidCloseを送り、依存先へW3-3を追加する。sections 2、6 |
| B6 | process restart用E2E配置と実行経路不足 | Done | W2bがslice E2E discoveryと`Session.restart()`を用意し、共通runnerとsession slice内のR8 scenarioを定義する。sections 5、6 |
| B7 | 非同期検索のwake-upとpoll契約不足 | Done | background-work APIのsignature、drain/coalesce、再通知、poll error、重複token処理を定義する。section 2 |
| B8 | callable、引数、prefixを含む入力経路不足 | Done | callable登録、引数付きgateway、`:paste`/`:mouse` route、prefix trace scopeとinternal insertionの除外に加え、M-x candidateのcanonical ID取得を定義する。section 3 |
| B9 | W2bからW2cのsource/test構成不足 | Done | W2bはroot source/test listを維持し、W2cでsource、test、pathsを一sliceずつatomicに移す。section 4 |
| S1 | S式実装の移設先とkey登録先不足 | Done | S式移動と`kill-sexp`、構造編集実装をlisp-structureへ移し、移動keyはglobal、`kill-sexp`と構造編集keyはlang-lisp mode mapへ登録する。sections 1、6 |
| S2 | W3-8のterminal mode API対応未確定 | Done | SGR 1006、button tracking 1002、bracketed paste 2004をterminal mode APIへ割り当てる。section 2 |
| S3 | `:render`と現行compose-frameの契約不一致 | Done | snapshot constructor/readers、operation readers/apply API、`:text` styleとsyntax/LSP例を定義する。sections 2、6 |
| S4 | W3-7aの言語slice移設path不足 | Done | W3-7aに4言語sliceの全移設pathを一時付与し、migration commitのmain反映後にW3-7b〜eへ移譲する。section 6 |
| S5 | D4の完了責任重複 | Done | D4をW3-1のunknown escapeとW3-8のmouse eventに分割する。sections 1、6 |
| S6 | W3-10/11が編集できるslice test path不足 | Done | W3-10、W3-11を含む各sliceに`src/`、`t/`、`t/paths.sexp`、`t/e2e/`の編集範囲を明記する。section 6 |
| S7 | `:mouse` route exportのowner不一致 | Done | W3-1がcore/commandの`:paste`、`:mouse` routeを追加し、W3-8は消費だけを行う。sections 1、6 |
| S8 | buffer/mode/message/save APIのowner不足 | Done | registry/list/close/result-buffer、mode問い合わせ、`*Messages*` owner、W2c file-save移設先を定める。sections 2、5、6 |
| R2-1 | visual-row layout callback契約未確定 | Done | renderer rangeとcell-prefix幅の戻り値、point変換、logical-line fallbackを定める。section 1 |
| R2-2 | scroll移設後のprefix/repeat API未確定 | Done | `core/command:repeat-command`が動的prefixを使い、正負の向きと反復回数を決める。section 1 |
| R2-3 | frame/operationのexportとrender style例不足 | Done | frame constructor、read-only accessors、copy-on-write適用API、syntax/LSP hook例を定める。sections 2、6 |
| R2-4 | lifecycleからのsuspend要求とstartup/signal契約不足 | Done | `request-terminal-suspend`、startup file request type/accessors、signal/reason/status対応を定める。section 2 |
| R2-5 | hit-test対象とclipboard drain、mouse値域不足 | Done | hit-test result、provider priority、OSC 52 queue/drain、button/modifier/wheel規約を定める。section 2 |
| R2-6 | structural editing移設漏れ | Done | commandとhelperをlisp-structureへ移し、global movementとLisp mode key登録を分ける。sections 1、6 |
| R2-7 | background pollのdrain/coalescing/error契約不足 | Done | poll signatureとready queue、coalescing、re-notification、error伝播を定める。section 2 |
| R2-8 | M-x candidateからcanonical IDを得る契約不足 | Done | candidateはopaque specを保持し、name表示後に`command-spec-id`をgatewayへ渡す。sections 3、6 |
| R2-9 | session restoreがbuffer registry/close hookを迂回 | Done | W3-10はW3-3のlist/unregister/registerを使い、W3-3依存を追加する。sections 2、6 |
| R2-10 | file-save pathのW3-3/W3-10重複 | Done | W2cでfilesへ移し、W3-10のfile-tree ownershipから除外する。sections 5、6 |
| R2-11 | W3 lane依存DAGが未整理 | Done | 全laneの直接依存、起動wave、仕様11.6との差分を表にする。section 6 |

## 付録 調査根拠表

この付録は設計項目1〜6の判断材料と現行コードの観測を記録します。

### 1. core分割と循環の現状

| 調査項目 | 観測した事実 | 根拠 |
|---|---|---|
| 分割対象 | 仕様はcoreを`buffer`、`window-tree`、`command`、`minibuffer`、`editor-session`に分け、層の依存を内側へ向ける | `docs/src/notes/requirements-modern-editor.md:112-172` |
| C1 ルートとfeature | feature packageが`loom`を`:use`し、root側もfeature名を修飾して呼ぶ。startup state、key routing、visual-line operation、presentationにもmode/windowへの直接参照がある | `packages/feature/window/src/package.lisp:1-2`、`src/application/startup-state.lisp:31,35-36,53,61,63`、`src/application/input-routing-command-state.lisp:37-54`、`packages/core/editor/src/application-commands-movement-visual-lines.lisp:11-17`、`src/presentation/frame-layout-cursor.lisp:58-76`、`src/presentation/frame-layout-viewport.lisp:87`、`src/presentation/layout-isearch.lisp:103`、`src/presentation/layout-windows.lisp:48,132,190-191`、仕様`docs/src/notes/requirements-modern-editor.md:680` |
| C2 rootとapplication | `loom` packageが`loom/application`を`:use`し、application側からroot関数も参照する | `src/package.lisp:1-3`、`src/application/commands-internal.lisp:5-14`、`src/application/commands-keybindings.lisp:7`、仕様`docs/src/notes/requirements-modern-editor.md:681` |
| C3 applicationとwindow | `%selected-window`と`%selected-buffer`がwindow APIを利用し、window packageは`loom/application`を`:use`する | `src/application/commands-internal.lisp:3-14`、`packages/feature/window/src/package.lisp:1-2`、仕様`docs/src/notes/requirements-modern-editor.md:682` |
| C4 coreとwindow | coreのvisual-line移動がfeature/windowとrendererを参照し、view-supportのscroll commandもfeature/windowを呼ぶ。window packageはrootを`:use`し、window treeを定義する | `packages/core/editor/src/application-commands-movement-visual-lines.lisp:11-17`、`packages/core/editor/src/application-commands-movement-view-support.lisp:51-66`、`packages/feature/window/src/package.lisp:1-2`、`packages/feature/window/src/domain-window.lisp:18-22`、仕様`docs/src/notes/requirements-modern-editor.md:683-694` |
| `::`参照 | private symbolは3種類、参照式は4か所。`%key-event->descriptor`はsearchとlspで各1か所、visual-line関数はlspで前後各1か所 | `packages/feature/search/src/application-commands-isearch.lisp:53`、`packages/feature/lsp/src/application-commands-lsp-support.lisp:45,50,53`、仕様`docs/src/notes/requirements-modern-editor.md:685` |
| workspaceの既定値 | `make-editor-state`がworkspace featureのmanagerを直接生成する。startupもmanagerを直接生成して渡す | `src/application/editor-state.lisp:3-15`、`src/application/startup-state.lisp:51-55` |
| keyboard-macroの既定値 | `editor-state` slotのデフォルトとstartupの両方でfeature constructorを直接呼ぶ | `src/application/editor-state-types.lisp:14-15`、`src/application/startup-state.lisp:61-63` |
| buffer APIの現行root export | `make-buffer`、`buffer-p`、`buffer-name`、`buffer-path`、`buffer-major-mode`、`buffer-set-major-mode`、`buffer-truncate-lines`、`buffer-set-truncate-lines`、`buffer-text`、`buffer-narrow-start-offset`、`buffer-narrow-end-offset`、`buffer-narrowed-p`、`buffer-visible-text`、`buffer-visible-line-count`、`buffer-visible-line`、`buffer-visible-point-line`、`buffer-visible-point-column`、`buffer-visible-offset-position`、`buffer-narrow-to-region`、`buffer-widen`、`buffer-line-count`、`buffer-line`、`buffer-point-line`、`buffer-point-column`、`buffer-set-point`、`buffer-mark`、`buffer-set-mark`、`buffer-insert-string`、`buffer-delete-char`、`buffer-delete-region`、`buffer-region-string`、`buffer-active-region-span`、`buffer-modified-p`、`buffer-read-only-p`、`buffer-set-read-only`、`buffer-read-only-error`、`buffer-mark-saved`、`buffer-mark-modified`、`buffer-offset`、`buffer-position-line`、`buffer-position-column`、`make-buffer-span`、`buffer-span-start`、`buffer-span-end`、`buffer-point-offset`、`buffer-offset-position`、`buffer-undo`、`buffer-redo`、`buffer-record-undo-boundary`、`buffer-load`、`buffer-save`、`buffer-position-offset`、`buffer-clamped-position-offset` | `src/package-exports.lisp:17-33,83` |
| core/bufferの型境界 | `buffer`構造体のslot readerとraw constructorは内部。`buffer-position`型情報と`buffer-span`型情報の一部、read-only condition readerも非公開 | `packages/core/editor/src/domain-buffer-storage.lisp:16-42`、`packages/core/editor/src/domain-buffer-positions.lisp:3-17` |
| core/window-treeの現行export | `make-window-tree`、`window-tree-windows`、`window-tree-selected-window`、`window-tree-layout`、`make-window-tree-from-layout`、`window-tree-selected-index`、`window-tree-select-index`、`window-tree-width`、`window-tree-height`、`window-split`、`window-select-next`、`window-delete`、`window-delete-other-windows`、`window-buffer`、`window-set-buffer`、`window-scroll-line`、`window-scroll-column`、`window-scroll-sub-row`、`window-x`、`window-y`、`window-width`、`window-height`、`window-tree-resize` | `packages/feature/window/src/package.lisp:4-26` |
| core/window-treeの型境界 | `window-leaf`、`window-split-node`、`window-tree`の構造体型とpredicateは非公開。command wrapperの一部とbuffer操作も同じfeature packageからexportされている | `packages/feature/window/src/domain-window.lisp:4-22`、`packages/feature/window/src/package.lisp:27-33` |
| core/command候補の現行root export | keymap系は`make-keymap`、`keymap-define-key`、`keymap-lookup`、`make-keymap-state`、`keymap-state-sequence`、`keymap-state-dispatch`。prefix系は`self-insert-command`、`*current-prefix-argument*`、`prefix-argument-for-editor`、`prefix-argument-action`、`apply-prefix-argument-action`、`prefix-argument-value-for-editor`、`consume-prefix-argument-for-editor`、`record-undo-boundary-for-command`、`prefix-argument`、`make-prefix-argument`、`prefix-argument-active-p`、`prefix-argument-explicit-p`、`prefix-argument-value`、`prefix-argument-universal`、`prefix-argument-digit`、`prefix-argument-negative`、`prefix-argument-consume`、`prefix-argument-reset` | `src/package-exports.lisp:42-43,73-81` |
| core/minibufferの現行export | `make-minibuffer`、`minibuffer-active-p`、`minibuffer-prompt-string`、`minibuffer-input-string`、`minibuffer-activate`、`minibuffer-complete`、`minibuffer-handle-key`、`minibuffer-set-prompt`、`minibuffer-message`、`minibuffer-message-string`、`minibuffer-history-entries`、`minibuffer-set-history-entries` | `src/package-exports.lisp:44-48` |
| editor-session関連の現行root export | `*editor-state*`、`editor-state`、`make-editor-state`、`editor-state-window-tree`、`editor-state-workspaces`、`editor-state-minibuffer`、`editor-state-keymap`、`editor-state-file-tree`、`editor-state-concurrent-runtime`、`editor-state-renderer`、`editor-state-buffers`、`editor-state-recent-files`、`editor-state-bookmarks`、`editor-state-kill-ring`、`editor-state-last-yank-ranges`、`editor-state-lsp-session`、`editor-state-registers`、`editor-state-keyboard-macro`、`editor-state-isearch`、`editor-state-completion`、`editor-state-jump-origins`、`editor-state-auto-save-mode-p`、`editor-state-auto-save-buffers`、`editor-state-auto-save-last-run-at`、`editor-state-format-on-save-p`、`editor-state-format-command`、`editor-state-before-save-hooks`、`editor-state-after-save-hooks`、`editor-state-terminal-sessions`、`editor-state-prefix-argument`。hook APIは`add-before-save-hook`、`remove-before-save-hook`、`run-before-save-hooks`、`add-after-save-hook`、`remove-after-save-hook`、`run-after-save-hooks` | `src/package-exports.lisp:49-56,62-66,70-72` |
| application integrationの現行root export | `define-selected-buffer-command`、`define-selected-tree-window-command`、`%selected-window`、`%selected-window-tree`、`%selected-buffer`、`%editor-buffers`、`%register-buffer`、`%unregister-buffer`、`%order-region`、`with-prompts`、`command-spec`、`command-spec-group`、`define-command-spec-groups`、`build-command-specs`、`define-command-specs`、`define-command-spec-catalog`、`*command-specs*`、`command-completion-candidates`、`find-extended-command`、`help-summary-message`、`defkeys-single-chord-p`、`defkeys-chord`、`defkeys-key-sequence`、`install-default-keybindings` | `src/package-exports.lisp:7-15` |
| core packageの有無 | `packages/core/editor/src/package.lisp`は存在しない。buffer sourceは`loom` packageに属し、window sourceは`loom/feature/window`に属する | `packages/core/editor/src/domain-buffer.lisp:1`、`packages/feature/window/src/package.lisp:1-3` |
| stateに隣接するroot export | completion constructor/accessor、bookmark型とaccessor、recent-file APIも現在は`loom`にexportされる | `src/package-exports.lisp:57-61,67-72` |

### 2. editor-stateとslice-stateの現状

仕様はslice constructorを登録し、`editor-session`がslice名をキーにopaque stateを保持する形を定める。rootは順序を一度決め、6種類のhookを呼び出す（`docs/src/notes/requirements-modern-editor.md:174-180`）。

`editor-state`は次の34 slotを持ちます（`src/application/editor-state-types.lisp:27-60`）。
仕様4.2はsliceの責務を定めますが、slot単位の割当ては記載していません。
表のowner案は、`確定`と付けた行がユーザー確認済みの割当てで、それ以外はこの設計で提案する割当てです。

| slot | 現行初期値 | 候補owner（確定表記のない行は設計案） | 根拠 |
|---|---|---|---|
| `window-tree` | `nil` | `core/window-tree` | 仕様4.2の146行目、定義27行目 |
| `workspaces` | `nil` | `feature/workspace` | 既定managerをfeature constructorで生成、`src/application/editor-state.lisp:10-15`。仕様4.2の170行目、推定 |
| `minibuffer` | `nil` | `core/minibuffer` | 仕様4.2の148行目、定義29行目 |
| `keymap` | `nil` | `core/command` | 仕様4.2の147行目、定義30行目 |
| `file-tree` | `nil` | `feature/file-tree` | 仕様4.2の153行目、定義31行目 |
| `concurrent-runtime` | `nil` | `feature/file-tree`（確定。rootが起動、終了、poll adapterを提供） | startup serviceが起動・停止を担う、`src/application/startup-services.lisp:3-20` |
| `renderer` | `nil` | root composition service（確定） | rendererをstartupが生成して保持、`src/application/startup-state.lisp:38-45` |
| `buffers` | `nil` | `feature/buffers`（registry APIのownerとして確定） | 仕様4.2の152行目、buffer登録箇所`src/application/commands-internal.lisp:28-42` |
| `recent-files` | `nil` | `feature/files` | 仕様4.2の151行目、recent-file API`src/application/editor-state-recent-files.lisp:11-30`。推定 |
| `bookmarks` | `nil` | `feature/bookmark` | 仕様4.2の169行目、定義36行目 |
| `kill-ring` | `nil` | `feature/kill-ring`（確定） | 仕様4.2の157行目、定義37行目 |
| `last-yank-buffer` | `nil` | `feature/kill-ring`（確定） | kill-ringのyank状態、定義38行目 |
| `last-yank-start-offset` | `nil` | `feature/kill-ring`（確定） | kill-ringのyank状態、定義39行目 |
| `last-yank-end-offset` | `nil` | `feature/kill-ring`（確定） | kill-ringのyank状態、定義40行目 |
| `last-yank-ranges` | `nil` | `feature/kill-ring`（確定） | kill-ringのyank状態、定義41行目 |
| `last-yank-ring-index` | `nil` | `feature/kill-ring`（確定） | kill-ringのyank状態、定義42行目 |
| `last-yank-repeat-count` | `nil` | `feature/kill-ring`（確定） | kill-ringのyank状態、定義43行目 |
| `last-command-kill-p` | `nil` | `feature/kill-ring`（確定） | kill command状態、定義44行目 |
| `last-command-self-insert-p` | `nil` | `core/command`（undo境界stateとして確定） | undo境界とcommand dispatchの状態、定義45行目 |
| `lsp-session` | `nil` | `feature/lsp` | 仕様4.2の171行目、定義46行目。slice分担は仕様、個別slot対応は推定 |
| `registers` | `nil` | `feature/register` | 仕様4.2の170行目、定義47行目。slice分担は仕様、個別slot対応は推定 |
| `keyboard-macro` | feature constructor | `feature/keyboard-macro` | slot defaultがconstructorを直接呼ぶ、定義48行目と14-15行目。仕様4.2の170行目 |
| `isearch` | `nil` | `feature/search` | 仕様4.2の160行目、定義49行目 |
| `completion` | `nil` | `feature/completion` | 仕様4.2の155行目、定義50行目 |
| `jump-origins` | `nil` | `feature/lsp`（navigation stateとして確定） | 定義51行目。LSP navigation履歴 |
| `auto-save-mode-p` | `nil` | `feature/auto-save` | 仕様4.2の171行目、定義52行目。slice分担は仕様、個別slot対応は推定 |
| `auto-save-buffers` | `nil` | `feature/auto-save` | 仕様4.2の171行目、定義53行目。推定 |
| `auto-save-last-run-at` | `nil` | `feature/auto-save` | 仕様4.2の171行目、定義54行目。推定 |
| `format-on-save-p` | `nil` | `feature/format` | 仕様4.2の171行目、定義55行目。slice分担は仕様、個別slot対応は推定 |
| `format-command` | `nil` | `feature/format` | 仕様4.2の171行目、定義56行目。推定 |
| `before-save-hooks` | `nil` | `core/editor-session` hook registry（確定） | generic save hook registry、定義57行目と`src/application/editor-state-save-hooks.lisp:15-55` |
| `after-save-hooks` | `nil` | `core/editor-session` hook registry（確定） | generic save hook registry、定義58行目と`src/application/editor-state-save-hooks.lisp:15-55` |
| `terminal-sessions` | `nil` | `feature/terminal` | 仕様4.2の171行目、定義59行目。slice分担は仕様、個別slot対応は推定 |
| `prefix-argument` | `nil` | `core/command` | 仕様4.2の147行目、定義60行目 |

### 3. コマンドカタログの現状

| 調査項目 | 観測した事実 | 根拠 |
|---|---|---|
| spec数と分類 | 現行カタログは120件。movement 26、editing 26、files/projects 12、windows/workspaces 12、session/registers 10、macros/evaluation 5、tooling 17、file-tree 8、UI/lifecycle 4 | `src/application/command-definitions.lisp:3-12`と`src/application/command-definitions-*.lisp`各群。調査時の集計 |
| 固定カタログ | 9個のグループ変数を中央ファイルが集約して`*command-specs*`を生成する | `src/application/command-definitions.lisp:3-12`、仕様`docs/src/notes/requirements-modern-editor.md:714-717` |
| 現行spec fields | W0-3は`:name`、`:group`、`:command`、`:keys`、`:help`、`:help-order`と5種metadataを保持する | `src/application/command-registry-forms.lisp:29-50`、`src/application/command-registry-build.lisp:3-15,50-68` |
| 重複検査 | 同名specはカタログ構築時に検査する。owner-awareなslice登録APIはW2aの設計範囲 | `src/application/command-registry-build.lisp:27-41,71-87` |
| key衝突 | keymap登録は既存bindingを置き換え、衝突検査をしない | `src/domain/keymap.lisp:18-28`、`src/application/commands-keybindings.lisp:4-9` |
| 無名spec | `nil`名の`execute-extended-command`がある | `src/application/command-definitions-ui.lisp:26-34` |
| user-init登録 | user-initは`*command-specs*`を直接appendし、同名があるとerrorにする | `packages/feature/user-init/src/application-user-configuration.lisp:36-65` |
| W0-3のmetadata validation | main上で5 metadata keyすべての省略を拒否し、`:mutates`と`:needs-region`はboolean、`:prompts`と`:modes`はkeyword list、`:external`はnonempty lowercase ASCII identifier listとして検証する | mainの`src/application/command-registry-forms.lisp:15-49` |
| W0-3のcatalog | JSONは現状`name`値にcanonical identifierを出し、`mx-eligible`、group、keys、5 metadataを出す。`execute-extended-command`のnil nameはcommand symbolから`execute-extended-command`へfallbackし、`mx-eligible`はfalse | mainの`src/application/command-registry.lisp:21-24,86-107`、`src/application/command-definitions-ui.lisp:26-34` |
| W0-3のtrace起動口 | mainの実関数名は`invoke-command(command, route)`。ここから`record-command-trace`を呼び、その後callableを実行する。trace eventのcommand valueもcatalog helperが返すidentifier | mainの`src/application/commands-misc.lisp:27-34`、`src/application/command-registry.lisp:108-144` |
| W0-3の残る入力形 | `invoke-command`は引数を受けない。self-insertとmacro内self-insertは文字引数を渡して直接実行され、C-u prefix transitionはkey dispatch前の経路にある。W2aはgatewayへ統合し、prefix-state policyを設計する | mainの`src/application/input-routing-effects.lisp:10-17`、`src/application/commands-keyboard-macro.lisp:62-70`、`src/application/input-routing-dispatch.lisp:35-43` |
| W0-3の`:external`語彙 | 非空文字列で、各文字はlowercase ASCII `a-z`、数字、`-`、`_`、`.`に限られる | mainの`src/application/command-registry-forms.lisp:34-47` |
| カタログ集計の依存 | E2E coverage readerは中央の`src/application/command-definitions*.lisp`を正規表現で読み、nil名specを`execute-extended-command`へ置き換える | `t/e2e/loom_e2e/commands.py:1-26`、runnerからの呼出し`t/e2e/loom-test.py:49-55`、仕様`docs/src/notes/requirements-modern-editor.md:717` |

### 4. スライスごとのASDFと依存検査

| 調査項目 | 観測した事実 | 根拠 |
|---|---|---|
| 現行ASDF構成 | rootの`loom.asd`にシステムとserialな全componentを集約する | `loom.asd:1-`、仕様`docs/src/notes/requirements-modern-editor.md:381-385` |
| Nix設定 | `flake.nix`の`mkPackageFlake`は`asd = ./loom.asd`を渡す。`packageArgs`は未設定 | `flake.nix:317-349` |
| cl-nix-forge実装 | `lispAsdPath`はASDF source registryに`$PWD`配下の追加pathを組み込む | cl-nix-forge v0.5.0 `lib/core/asdf-derivation.nix:271,352-357` |
| 再帰探索の実験 | 一時treeに`packages/demo/`のsystemを置き、`lispAsdPath = [ "packages//" ]`でbuildとtestが成功した。`[ "packages" ]`のnegative controlはsystem不在で失敗した | 調査時の最小fixture実験。positive `nix build --impure --expr ...` exit 0、negative exit 1。実験treeはworkspace外 |
| 依存契約テスト | 現状はroot `loom.asd`のruntime/test依存、Nix依存、runner依存を比較する | `t/unit/dependency-contract-test.lisp:97-149` |
| test runner | `run-tests.lisp`と`scripts/coverage.lisp`はrootとsibling directoryをASDF source registryへ追加し、`loom`と`loom/test`をforce loadする | `run-tests.lisp:44-61`、`scripts/coverage.lisp:62-69,132-134` |
| E2E配置 | Python E2E harnessとscenarioは`t/e2e/`以下にあり、flake appが`loom-test.py`を起動する | `t/e2e/loom-test.py`、`t/e2e/scenarios/`、`flake.nix:453-466` |

### 5. W2移設と逐次作業の現状

| 調査項目 | 仕様上の完了条件または現行根拠 | 根拠 |
|---|---|---|
| W2a | 120件を各sliceへ一括移設し、中央catalogを削除する。重複とkey collisionをerrorにし、移行前後のcatalogを一致させる | `docs/src/notes/requirements-modern-editor.md:465-472` |
| W2b | slice `.asd`、`lispAsdPath`、全slice雛形、依存契約test、runner、lang-markup依存を更新する | `docs/src/notes/requirements-modern-editor.md:471-472` |
| W2c | 4.2に従って実装とtestを移し、既存挙動とtest結果を保つ | `docs/src/notes/requirements-modern-editor.md:472-473` |
| W2d | 境界testをfailure modeにし、allowlist外の違反で失敗させる | `docs/src/notes/requirements-modern-editor.md:473-474` |
| E2Eの維持 | W2中は全段階で既存suiteとE2Eを通す | `docs/src/notes/requirements-modern-editor.md:467-468` |
| runnerのsystem分割 | force loadが指定systemのみ再compileするため、別system化後に古いfaslを読む危険があるという仕様上の推定 | `docs/src/notes/requirements-modern-editor.md:719-723` |

### 6. W3レーンの現行分担

| lane | 現行のslice担当 | 仕様上の境界と根拠 |
|---|---|---|
| W3-1 | core/command | core/command exportを専有。keymap参照表を持つ。`docs/src/notes/requirements-modern-editor.md:488` |
| W3-2 | lifecycle、user-init | terminal modeは4.3 hookで要求。`docs/src/notes/requirements-modern-editor.md:489` |
| W3-3 | files、buffers | file operationを担当。`docs/src/notes/requirements-modern-editor.md:490` |
| W3-4 | core/buffer、renderer、`src/presentation/` | buffer exportとrendererを専有し、描画要求はhookで受ける。`docs/src/notes/requirements-modern-editor.md:491` |
| W3-5 | core/minibuffer、minibuffer-ui、completion、help | core/minibuffer exportを専有。`docs/src/notes/requirements-modern-editor.md:492` |
| W3-6 | search、project | 一覧bufferと`next-error`を提供。`docs/src/notes/requirements-modern-editor.md:493` |
| W3-7a | mode、syntax-highlighting | language定義を各language sliceへ移してprotocolを作る。`docs/src/notes/requirements-modern-editor.md:494` |
| W3-7b | lang-lisp、lisp-structure、evaluation | Lisp modeと構造編集、評価。`docs/src/notes/requirements-modern-editor.md:495` |
| W3-7c | lang-nix | Nix mode。`docs/src/notes/requirements-modern-editor.md:496` |
| W3-7d | lang-web | TS、JS、JSX、JSON、HTML、CSS、YAML。`docs/src/notes/requirements-modern-editor.md:497` |
| W3-7e | lang-markup | Markdown、Org。`docs/src/notes/requirements-modern-editor.md:498` |
| W3-8 | kill-ring、clipboard、mouse | mouse eventのD4はW3-8が担当し、W3-1はunknown escapeだけを担当する。W3-1の`:mouse` routeを使い、正規化eventは`:input-event` hookから受ける。terminal modeは`:terminal-modes` hookで1006 SGR encoding、1002 button tracking、2004 bracketed pasteを要求する。hit-testはW3-4、file-tree item providerはW3-10が実装し、clipboard requestはroot drain APIを使う。core/command exportは変更しない |
| W3-9 | lsp | W3-6のresult list/navigation APIとW3-3のbuffer registryへ依存する。W3-3の`:buffer-close` hookからdidCloseを送り、restore中のcloseも処理する。他laneのpath/exportは編集しない |
| W3-10 | file-tree、window、workspace、session、bookmark、register、keyboard-macro | file-tree local keymapはW3-1のregistration APIを使う。file-save commandと対応testはW2cでfilesへ移し、W3-10のfile-tree `src/`と`t/`所有pathから除外する。session restoreはW3-3のbuffer registryと`:buffer-close` hookを使う。core/window-treeとcore/editor-sessionのexportは追加しない。R8 restart scenarioは`packages/feature/session/t/e2e/scenarios/`に置く |
| W3-11 | shell、format、git、terminal、auto-save | command導線と外部toolの成功・失敗を検証する。auto-saveはW2のeditor-session save-hook registry、W3-3のfiles save APIを使い、root terminal lifecycleとflakeは編集しない |
| 共通の書込範囲 | 各laneは担当sliceのcode、test、`t/paths.sexp`だけを変更する | `docs/src/notes/requirements-modern-editor.md:478-484` |
