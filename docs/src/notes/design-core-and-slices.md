# W1/W2 core分割とslice-state設計

## 1. core packageの境界

仕様第3章の確定事項は変更せず、この設計はW1とW2の実装境界だけを定めます（`docs/src/notes/requirements-modern-editor.md:90-108`）。
coreを5 packageに分け、各packageはデータと安定した操作だけを公開します。
featureは必要なcore packageを`:import-from`し、root packageはfeatureの実装symbolを参照しません。
仕様4.1と4.2は依存を内側へ向け、rootを起動、event loop、frame合成、rendererに限っています（`docs/src/notes/requirements-modern-editor.md:112-172,203-212`）。
既存のbuffer、keymap、minibuffer、editor-stateのexportは付録1の一覧から移し、公開集合を次のように固定します。

| package | 公開API |
|---|---|
| `loom/core/buffer` | 付録1に列挙したbuffer APIすべて。追加で`buffer`、`buffer-position`、`buffer-position-p`、`buffer-span`、`buffer-span-p`、`buffer-read-only-error-buffer`をexportする |
| `loom/core/window-tree` | `window-tree`、`window-tree-p`、`make-window-tree`、`window-tree-windows`、`window-tree-selected-window`、`window-tree-layout`、`make-window-tree-from-layout`、`window-tree-selected-index`、`window-tree-select-index`、`window-tree-width`、`window-tree-height`、`window-split`、`window-select-next`、`window-delete`、`window-delete-other-windows`、`window-buffer`、`window-set-buffer`、`window-scroll-line`、`window-scroll-column`、`window-scroll-sub-row`、`window-x`、`window-y`、`window-width`、`window-height`、`window-tree-resize` |
| `loom/core/command` | 付録1のkeymapとprefix argument APIに加え、`install-default-keybindings`、`command-completion-candidates`、`find-extended-command`、`help-summary-message`、`defkeys-single-chord-p`、`defkeys-chord`、`defkeys-key-sequence`をexportする。追加で`keymap`、`keymap-p`、`keymap-state`、`keymap-state-p`、`key-event->descriptor`、`register-command-spec`、`command-specs`、`find-command-spec`、`invoke-command`をexportする |
| `loom/core/minibuffer` | 付録1に列挙したminibuffer APIすべて。追加で`minibuffer`、`minibuffer-p`、`with-prompts`をexportする |
| `loom/core/editor-session` | `*editor-session*`、`editor-session`、`editor-session-p`、`make-editor-session`、`call-with-editor-session`、`editor-session-slice`、`editor-session-slice-names`、`register-slice-state`、`register-session-hook`、`run-session-hooks`、`register-visual-row-layout`、`next-visual-line-once`、`previous-visual-line-once` |

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

`loom/core/command`はkeymap、dispatch state、prefix argument、command catalogの境界を所有します。
`keymap`と`keymap-state`のtable、parent、accumulated sequence以外の内部構造は公開しません。
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
visual row計算にはrenderer packageを直接呼ばず、rootが`register-visual-row-layout`で注入する計算関数を使います。
この関数境界は推定です。
coreがrendererを呼ぶ案は仕様の層方向と逆になるため却下し、実装前にcallbackの引数と戻り値を検証します（`packages/core/editor/src/application-commands-movement-visual-lines.lisp:3-17,31-39,85-89`）。

既存コードは機能境界ごとに次のpathへ移します。

| 現行pathまたはsymbol | 移設先 | 根拠 |
|---|---|---|
| `packages/core/editor/src/domain-buffer*.lisp` | `packages/core/buffer/src/domain-buffer*.lisp` | buffer domain群、仕様4.2の145行目 |
| `packages/core/editor/src/domain-prefix-argument.lisp`、`src/domain/keymap*.lisp`、`src/application/command-registry*.lisp`、`src/application/commands-keybinding-spec.lisp`、`src/application/commands-keybindings.lisp` | `packages/core/command/src/` | 現行exportとcommand定義、仕様4.2の147行目 |
| `src/application/minibuffer*.lisp` | `packages/core/minibuffer/src/` | minibuffer責務、仕様4.2の148行目 |
| `src/application/editor-state-types.lisp`、`src/application/editor-state.lisp`、`src/application/editor-state-support.lisp`の`*editor-state*`、`src/application/editor-state-save-hooks.lisp` | `packages/core/editor-session/src/` | 現在のstate envelopeとhook registry。`*editor-recent-file-limit*`はfiles sliceへ移す |
| `packages/feature/window/src/domain-window*.lisp` | `packages/core/window-tree/src/domain-window*.lisp` | window tree domain群、仕様4.2の146行目 |
| `src/application/editor-state-bookmarks.lisp`、`commands-bookmark*.lisp` | `packages/feature/bookmark/src/` | bookmark slice、仕様4.2の169行目 |
| `src/application/editor-state-recent-files.lisp` | `packages/feature/files/src/` | files slice、仕様4.2の151行目 |
| `src/application/editor-state-operations.lisp`の`%clear-last-yank` | `packages/feature/kill-ring/src/` | yank状態を一括clearする操作、`src/application/editor-state-operations.lisp:3-14` |
| `packages/feature/window/src/application-commands-window.lisp`のbuffer commandと`application-window-buffer-support.lisp` | `packages/feature/buffers/src/` | buffer registrationとkill lifecycle、仕様4.2の152行目 |
| `src/application/commands-internal.lisp`のselected-window helperとbuffer registry helper | core API呼び出しへ分割し、buffer registryは`feature/buffers`へ移す | `src/application/commands-internal.lisp:3-43` |
| `src/application/commands-prompts.lisp`の`with-prompts` | `packages/core/minibuffer/src/` | prompt continuation helper、`src/application/commands-prompts.lisp:3-35` |
| `packages/core/editor/src/application-commands-movement-visual-lines.lisp` | `packages/core/editor-session/src/`のvisual row operation | renderer呼出しを注入callbackに置き換える。位置は推定 |

循環の切断はC4、C2、C3、C1の順に行います。
C4ではwindow domainを先に`core/window-tree`へ移し、coreからfeature/windowへの参照をなくします。
visual row関数は`core/editor-session`へ移し、renderer関数をrootから注入します。
window implementationをfeature/windowに残す案はcore movementからfeatureへの参照を残すため却下します（`packages/core/editor/src/application-commands-movement-visual-lines.lisp:11-16`、`packages/feature/window/src/package.lisp:1-3`）。

C2では`editor-state`、keymap、minibufferをそれぞれcore packageへ移し、`loom/application`にあったselected-state参照を廃止します。
root `loom`が`loom/application`を`:use`する構成も解きます。
共有application packageに全slice helperを残す案は逆向き参照を温存するため却下します（`src/package.lisp:1-3`、`src/application/commands-internal.lisp:3-14`、`src/application/commands-keybindings.lisp:7`）。

C3ではselected windowとselected bufferを`editor-session-slice`、`window-tree-selected-window`、`window-buffer`の組合せに置き換えます。
feature/windowから`loom/application`のhelperを呼ぶ案を却下し、featureがcore packageを直接利用できる境界にします（`src/application/commands-internal.lisp:3-14`、`packages/feature/window/src/package.lisp:1-2`）。

C1では最後にfeature packageの`:use loom`を取り除き、依存するcore packageだけを`:import-from`します。
rootのstartup、render、command catalogからfeature symbolを呼ぶ箇所も登録APIとhook dispatchへ移します。
`loom`を全featureの共通namespaceとして残す案はrootとfeatureの循環を残すため却下します（`packages/feature/window/src/package.lisp:1-2`、`src/application/startup-state.lisp:31-63`、`src/presentation/layout-windows.lisp:190-191`）。

この順序なら各移設のあとに一時的な互換aliasを残さず、C4からC1の原因ごとに参照を切れます。
各段階でASDF全体のcompile、unit test、E2Eを通すことをW1の完了条件にします（`docs/src/notes/requirements-modern-editor.md:459-463`）。

## 2. slice-stateとhook契約

`editor-session`はslice名とstate valueを対応付けるopaque tableを持ちます。
stateful sliceはASDF load時に`register-slice-state`を呼び、constructorを登録します。
APIは次の形にします。

```lisp
(register-slice-state :feature/workspace #'make-workspace-state)
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

34 slotの所属は付録2に示した候補に固定します。
`window-tree`、`keymap`、`minibuffer`はそれぞれ`core/window-tree`、`core/command`、`core/minibuffer`のstateです。
`buffers`、`file-tree`、`workspaces`、`recent-files`、`bookmarks`、kill/yank state、LSP state、registers、keyboard macro、search、completion、auto-save、format、terminal stateは対応するfeature sliceへ移します。
`renderer`はslice stateにせずroot compositionのserviceとして保持します。
before/after-save hook listはslotから外し、`core/editor-session`のhook registryへ移します。
`concurrent-runtime`、`buffers`、`recent-files`、`last-command-self-insert-p`、`jump-origins`のownerと、save hookの所有範囲は現行の型宣言だけでは確定できないため推定です。
実装担当は各state accessorの全参照を検索し、付録2の推定をW1着手前に確認します。

hookは`register-session-hook`でkind、owner、functionの順に登録し、rootが同じslice順でdispatchします。
一つのslice内では登録順を保ちます。
dispatch開始時にhook listをcopyし、callbackが登録を更新しても現在のdispatchへ反映しません。
これは現行save hookがreverseしたcopyを実行する動作を引き継ぎます（`src/application/editor-state-save-hooks.lisp:15-18`）。
同じowner、kind、functionの登録は重複を作らず、異なるownerの同一function登録は別hookとして扱います。
仕様の6分類のうちsave hookはbefore/afterを別kindに分け、registryには7 kindを置きます。
before-save errorはwriteを止めますが、after-save errorでは完了済みwriteを戻せないため、同じcallbackにまとめません（`docs/src/notes/requirements-modern-editor.md:174-180`）。

| hook kind | signatureと戻り値 | 呼び出し順とerror |
|---|---|---|
| `:tick` | `(session monotonic-time)`。戻り値を使わない | input dispatchまたはtimeoutの後、resize確認とframe描画の前にslice順で呼ぶ。hook errorは現行periodic workと同様にevent loop外へ伝え、sessionを終了する |
| `:key-input` | `(session key-event route)`。`:pass`または`:handled` | default key dispatchの前に呼ぶ。routeは実キー入力なら`:key`、macro再生なら`:macro`を渡す。`:handled`で後続hookとdefault dispatchを止める。commandを起動するhookは受け取ったrouteで共通gatewayを呼ぶ。errorはcommand dispatchの既存handlerがminibufferへ表示する |
| `:input-event` | `(session event-kind payload)`。`:pass`または`:handled` | mouse、pasteを含む非key eventの種類ごとに呼ぶ。`:handled`で後続hookとdefault handlerを止める。paste handlerは入力dataをfeature APIで処理する。mouse handlerがcommandを起動するときは共通gatewayを呼び、route `:mouse`をW3-8で追加する。errorはkey dispatchと同じhandlerへ渡す |
| `:render` | `(session frame)`。変換後のframeを返す | rootがframeをcomposeした後、rendererへ渡す前にslice順で適用する。errorはrendererの失敗と同じくsession外へ伝える |
| `:terminal-modes` | `(session)`。terminal mode keywordのlistを返す | terminal session開始前に全sliceを呼び、slice順で重複を除いたmode unionを適用する。setup errorは握りつぶさず起動を失敗させる |
| `:before-save` | `(session buffer)`。戻り値を使わない | file write前に呼ぶ。errorならwriteしない。format hookはここへ登録する |
| `:after-save` | `(session buffer)`。戻り値を使わない | writeと`buffer-mark-saved`の後に呼ぶ。errorを返しても完了済みのwriteはrollbackしない。auto-save file cleanupはここへ登録する |

`:tick`は初回frameの前には呼ばず、event loopの各input/timeout turnで一度呼びます。
現行event loopはinputまたはtimeoutの後にauto-save、resize、renderを行い、初回frameはloop前に描画します（`src/application/event-loop.lisp:15-30,32-44`）。
`:key-input`は既存key routing handlerの内側、`:input-event`はcore/commandのevent kind routing内に置きます（`src/application/input-routing-dispatch.lisp:56-73`）。
どちらのhookもcommandを直接`funcall`せず、節3の`invoke-command(command, route)`を使います。
key hookには入力元のrouteを渡し、macro replayが`:key`として記録されないようにします。
W2aではkey dispatch、C-uのprefix argument経路、M-x、macro replayをこの入口へ集約します。
非key hookがcommandを起動する場合も入口を迂回せず、対応routeが導入されるまではmouse commandを実装しません。
`:render`は`compose-frame`後、`loom-renderer-present`前に置きます（`src/application/event-loop-rendering.lisp:3-20`）。
`:terminal-modes`はraw modeとalternate screenを開始する前に照会します（`src/application/startup-services.lisp:32-43`）。
`:before-save`と`:after-save`は`buffer-save`の現在の順序を維持します（`packages/feature/file-tree/src/infrastructure-buffer-filesystem.lisp:21-34`）。

端末mode要求はclipboardのbracketed pasteとmouseのmouse reportingを有効にするために使います。
rootは要求をdedupeし、既存のterminal session APIへmodeを渡します。
mode keywordとterminal API optionの対応は、そのAPIの現行signatureをW2a実装前に確認する項目です。
modeを各featureが直接設定する案は、terminal lifecycleをsliceごとに分散させるため却下します（`docs/src/notes/requirements-modern-editor.md:178-180`）。

hook errorは実行位置の既存error境界へ流します。
key/input hookのerrorはminibufferへ報告してevent loopを継続し、tick/render/terminal setupのerrorはstartup境界へ伝えてsessionを終了します。
save前hookのerrorはbufferを保存せず、save後hookのerrorは保存済みfileを残したまま呼出元へ伝えます。
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
`:id`は全commandで一意な文字列です。
`:name`はM-x名なので`nil`を許し、`nil`のspecも`:id`を必ず持ちます。
catalogとtraceは同じ`:id`を使い、無名の`execute-extended-command`もcatalogに含めますが、M-x候補には含めません。
M-xキーで起動した`execute-extended-command`は`:key`、promptから選んだcommandは`:mx`でtraceします。
この対応なら、M-xで使う名前の有無に関係なくtraceとcatalogを同じIDで照合できます。

5種のmetadataは`:mutates`、`:prompts`、`:needs-region`、`:external`、`:modes`です。
parserは5キーの省略をerrorにし、`nil`や空listを値にする場合もキーを明示させます。
登録関数も同じ検査を行い、移行でparserを通らないspecが入っても登録時errorになります。
`:mutates`と`:needs-region`はboolean、`:prompts`は入力種別のlist、`:modes`はkeyword listです。
`:prompts`の入力種別は`:free-string`、`:completion`、`:yes-no`、`:numeric`です。
`:external`には固定語彙から機械可読な外部tool IDをlistで指定します。
parserは未登録IDをerrorにし、catalog比較の対象を固定します。
許可する語彙とLisp/JSONでの表現はW0-3修正後のmainで確定した値に合わせます。

この設計では、catalogに登録するcommandの唯一の起動口を`invoke-command(command-id, route)`と呼びます。
`command-id`は登録済みspecのcanonicalな`:id`文字列です。
keymap dispatchとM-xは選択したspecのIDを渡し、gatewayは同じIDでspecをlookupしてcommand functionを実行します。
C-uのprefix argument経路、keyboard macro再生、hookからの起動もこの入口に集約します。
gatewayはtrace有効時にinvocationごとに1件を記録してからcommand functionを呼びます。
既存の二か所のtrace記録はmacro再生とC-uのkey経路を記録できないため、traceと起動を分けません。
callerによるtraceの直接記録と、`funcall`によるcommand functionの直接呼出しを禁止します。
routeは`:key`、`:mx`、`:macro`を使い、W3-8がmouse commandを実装するときに`:mouse`を追加します。
`:input-event` hookはcommandを直接実行せず、commandを起動するときは同じ入口を呼びます。
mouse commandの実装前にrouteを仮装したり、hook専用の実行経路を足したりしません。

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
catalogの`id` fieldとtraceの`command` fieldは同じ識別子文字列を使います。
現在のdumpにはcommand symbol、help、help-order、owner、ID、keymap IDがありません。
W2aではこれらをschemaに加え、canonical specを比較できるbaselineを取ります（`src/application/command-registry.lisp:89-108`、`src/main.lisp:12-16`）。
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

現行command specはmovement 26件、editing 26件、files/projects 12件、windows/workspaces 12件、session/registers 10件、macros/evaluation 5件、tooling 17件、file-tree 8件、UI/lifecycle 4件です。
合計は120件です（`src/application/command-definitions.lisp:3-12`と各group file）。
`nil` nameの`execute-extended-command`には、他のcommandと同じ形式の`:id`を明示します。
このspecはcatalogへ登録しますが、M-x候補の一覧からは除外します（`src/application/command-definitions-ui.lisp:11-14`）。

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
rootの`loom.asd`は各production systemへの`:depends-on`だけを持つcomposition systemにし、source file componentとserial listを置きません。
test用root system `loom/test`は各sliceのtest systemを依存に持ち、従来どおり一回の`asdf:test-system "loom"`で全suiteを動かします。
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
runnerは`packages/`をASDFのtree registryへ加え、root `loom/test`を一度だけloadして全slice testを実行します。
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
| W2a | 1. owner-aware registry、5 metadataのparse時必須化とregistration時検査、dump query APIとcommand invocation gatewayを追加する。2. 既存120 specにownerとIDを付け、5キーの存在を登録時errorで検査してcanonical dumpを保存する。3. specを一度にslice別fileへ移し、中央定義を削除する | 5キー各々の省略でparse時と登録時の両方がerrorになるtest、未登録`:external` ID、duplicate ID/name、same-owner idempotency、key collision、catalog/trace ID一致とnil-name spec、key/M-x/C-u/macro routeのgateway test。key/input-event hookも同じgatewayを通す。各段階で全unitとE2E。最後にbefore/after dumpの`diff -u`が空、catalog件数が120 |
| W2b | 1. `lispAsdPath`最小実験とflake `packageArgs`を追加する。2. 全sliceのproduction/test `.asd`とroot aggregate systemを作る。3. runner、coverage、dependency union testを移行する | positive/negative ASDF discovery fixture、Nix eval、`nix flake check`、dev shellでのtest、dumped binary起動、E2E全件 |
| W2c | 4.2の移設を依存順に行う。1 commitで一つのsliceか同じ所有laneのslice群を移し、sourceとtestを同じcommitに含める | 各commitで移設対象のunit、全unit、E2E全件を実行する。直前baselineとtest件数および結果を比較する |
| W2d | boundary testをwarningからfailureへ切り替え、残存違反をowner別allowlistへ記録する | allowlist内の違反だけが通り、未知の依存辺、private `::`、domain上位層参照を追加したcontrolでtestが失敗する |

W2cの移設順はcore/buffer、core/window-tree、core/minibuffer、core/command、core/editor-sessionから始めます。
その後、files、buffers、file-tree、minibuffer-ui、completion、help、kill-ring、clipboard、mouse、search、project、mode、syntax-highlightingを移します。
最後にlisp-structureと言語slice、bookmark、window、workspace、session、register、keyboard-macro、lsp、terminal、shell、format、git、evaluation、auto-save、lifecycle、user-initを移します。
4.2に記載の責務を基準にしてもdependency DAGが循環する場合は、core APIの不足としてそのcommitを止め、allowlistで隠しません。

各sliceの移設commitは、実装fileとtestを一緒に移し、旧pathと新pathの重複loadを残しません。
既存test結果を保つためにtemporary shimを根として残す案は、境界testで違反を見逃すため却下します。
W2cでは既存E2E scenarioと`t/paths.sexp`のownerを揃えます。
E2E shared harnessとroot package inventoryはW2cの専有担当だけが変更します（`docs/src/notes/requirements-modern-editor.md:425-443`）。

W2aのowner付与は中央catalog上で済ませてからbaselineを取ります。
各command specをimplementation functionの定義先と4.2の責務へ対応させ、既存group名だけからownerを決めないでください。
W2aのkey dispatch、M-x、C-uのprefix argument、macro replayと、4.3のkey/input-event hookは`invoke-command(command, route)`を使います。
command functionを直接`funcall`する経路と、callerごとにtraceを書き分ける経路を加えません。
W2cの移設後はcatalog diffに加え、`t/e2e/`のscenario全件を動かします。
W2bでは`.asd`をNix sourceへ含めるため、新規`.asd`をgit indexへ追加してから`nix build`を実行します。

## 6. W3のpathとexport境界

W2bで各sliceの`.asd`、`src/package.lisp`、`t/paths.sexp`を作り、W2cで既存実装とtestをslice directoryへ移します。
W3のlaneは所有sliceの`src/`、`t/`、`t/paths.sexp`だけを編集します。
共有root、`flake.nix`、root `loom.asd`、全体test runner、E2E harnessはW3で編集しません（`docs/src/notes/requirements-modern-editor.md:416-423,425-443`）。

| lane | 所有path | exportと他laneへの境界 | 仕様根拠 |
|---|---|---|---|
| W3-1 | `packages/core/command/src/`、`packages/core/command/t/`、`packages/core/command/t/paths.sexp` | `packages/core/command/src/package.lisp`のexportを専有する。global key referenceと登録衝突検査を持つ。各featureが移すkeyは各feature ownerが登録する | `docs/src/notes/requirements-modern-editor.md:488` |
| W3-2 | `packages/feature/lifecycle/src/`、`packages/feature/lifecycle/t/`、`packages/feature/lifecycle/t/paths.sexp`、`packages/feature/user-init/src/`、`packages/feature/user-init/t/`、`packages/feature/user-init/t/paths.sexp` | terminal modeは`:terminal-modes` hookから要求する。root CLIとevent loopは編集しない | `docs/src/notes/requirements-modern-editor.md:489` |
| W3-3 | `packages/feature/files/src/`、`packages/feature/files/t/`、`packages/feature/files/t/paths.sexp`、`packages/feature/buffers/src/`、`packages/feature/buffers/t/`、`packages/feature/buffers/t/paths.sexp` | file I/O、buffer registry、switch/kill commandを所有する。`core/buffer` exportは変更しない | `docs/src/notes/requirements-modern-editor.md:490` |
| W3-4 | `packages/core/buffer/src/`、`packages/core/buffer/t/`、`packages/core/buffer/t/paths.sexp`、`src/infrastructure/terminal-renderer.lisp`、`src/infrastructure/terminal-renderer-cursor.lisp`、`src/infrastructure/terminal-renderer-text.lisp`、`src/infrastructure/terminal-renderer-text-wrapping.lisp`、`src/presentation/` | `packages/core/buffer/src/package.lisp`のexportとrenderer/presentationを専有する。他laneの描画拡張は`:render` hookを使う | `docs/src/notes/requirements-modern-editor.md:491` |
| W3-5 | `packages/core/minibuffer/src/`、`packages/core/minibuffer/t/`、`packages/core/minibuffer/t/paths.sexp`、`packages/feature/minibuffer-ui/src/`、`packages/feature/minibuffer-ui/t/`、`packages/feature/minibuffer-ui/t/paths.sexp`、`packages/feature/completion/src/`、`packages/feature/completion/t/`、`packages/feature/completion/t/paths.sexp`、`packages/feature/help/src/`、`packages/feature/help/t/`、`packages/feature/help/t/paths.sexp` | `packages/core/minibuffer/src/package.lisp`のexportを専有する。他laneはminibuffer-ui APIを使う | `docs/src/notes/requirements-modern-editor.md:492` |
| W3-6 | `packages/feature/search/src/`、`packages/feature/search/t/`、`packages/feature/search/t/paths.sexp`、`packages/feature/project/src/`、`packages/feature/project/t/`、`packages/feature/project/t/paths.sexp` | result list bufferと`next-error`のAPIをownerとして公開し、W3-9へ渡す | `docs/src/notes/requirements-modern-editor.md:493` |
| W3-7a | `packages/feature/mode/src/`、`packages/feature/mode/t/`、`packages/feature/mode/t/paths.sexp`、`packages/feature/syntax-highlighting/src/`、`packages/feature/syntax-highlighting/t/`、`packages/feature/syntax-highlighting/t/paths.sexp` | 各languageの既存定義をW3-7b〜eのdirectoryへ移す。移設後、そのlanguage directoryは編集しない | `docs/src/notes/requirements-modern-editor.md:494` |
| W3-7b | `packages/feature/lang-lisp/src/`、`packages/feature/lang-lisp/t/`、`packages/feature/lang-lisp/t/paths.sexp`、`packages/feature/lisp-structure/src/`、`packages/feature/lisp-structure/t/`、`packages/feature/lisp-structure/t/paths.sexp`、`packages/feature/evaluation/src/`、`packages/feature/evaluation/t/`、`packages/feature/evaluation/t/paths.sexp` | Lisp mode、S式操作、evaluationを所有する | `docs/src/notes/requirements-modern-editor.md:495` |
| W3-7c | `packages/feature/lang-nix/src/`、`packages/feature/lang-nix/t/`、`packages/feature/lang-nix/t/paths.sexp` | Nix modeとlanguage definitionを所有する | `docs/src/notes/requirements-modern-editor.md:496` |
| W3-7d | `packages/feature/lang-web/src/`、`packages/feature/lang-web/t/`、`packages/feature/lang-web/t/paths.sexp` | TS、JS、JSX、JSON、HTML、CSS、YAMLのlanguage definitionを所有する | `docs/src/notes/requirements-modern-editor.md:497` |
| W3-7e | `packages/feature/lang-markup/src/`、`packages/feature/lang-markup/t/`、`packages/feature/lang-markup/t/paths.sexp` | MarkdownとOrgのparser integrationを所有する | `docs/src/notes/requirements-modern-editor.md:498` |
| W3-8 | `packages/feature/kill-ring/src/`、`packages/feature/kill-ring/t/`、`packages/feature/kill-ring/t/paths.sexp`、`packages/feature/clipboard/src/`、`packages/feature/clipboard/t/`、`packages/feature/clipboard/t/paths.sexp`、`packages/feature/mouse/src/`、`packages/feature/mouse/t/`、`packages/feature/mouse/t/paths.sexp` | non-key inputは`:input-event` hook、terminal modeは`:terminal-modes` hookを使う。windowとfile-treeは公開API経由で操作する | `docs/src/notes/requirements-modern-editor.md:499` |
| W3-9 | `packages/feature/lsp/src/`、`packages/feature/lsp/t/`、`packages/feature/lsp/t/paths.sexp` | W3-6のresult listとnavigation APIを利用する。W3-6のpathやexportは編集しない | `docs/src/notes/requirements-modern-editor.md:500` |
| W3-10 | `packages/feature/file-tree/src/`、`packages/feature/file-tree/t/paths.sexp`、`packages/feature/window/src/`、`packages/feature/window/t/paths.sexp`、`packages/feature/workspace/src/`、`packages/feature/workspace/t/paths.sexp`、`packages/feature/session/src/`、`packages/feature/session/t/paths.sexp`、`packages/feature/bookmark/src/`、`packages/feature/bookmark/t/paths.sexp`、`packages/feature/register/src/`、`packages/feature/register/t/paths.sexp`、`packages/feature/keyboard-macro/src/`、`packages/feature/keyboard-macro/t/paths.sexp` | file-tree local keymapはW3-1のregistration APIを使う。core/window-treeとcore/editor-sessionのexportは追加しない | `docs/src/notes/requirements-modern-editor.md:501` |
| W3-11 | `packages/feature/shell/src/`、`packages/feature/shell/t/paths.sexp`、`packages/feature/format/src/`、`packages/feature/format/t/paths.sexp`、`packages/feature/git/src/`、`packages/feature/git/t/paths.sexp`、`packages/feature/terminal/src/`、`packages/feature/terminal/t/paths.sexp`、`packages/feature/auto-save/src/`、`packages/feature/auto-save/t/paths.sexp` | command導線と外部toolの成功・失敗を検証する。root terminal lifecycleとflakeは編集しない | `docs/src/notes/requirements-modern-editor.md:502` |

W3-1、W3-4、W3-5だけが各自のcore package exportを変更できます。
core/window-treeとcore/editor-sessionのexportはW2で確定し、W3 laneは不足APIを追加せず、必要なsymbolと利用理由を報告します（`docs/src/notes/requirements-modern-editor.md:432-436,423`）。
W3-4の描画拡張はframeを返す`:render` hook、W3-8のpaste/mouse処理は`:input-event` hookを通します。
W3-10のlocal keymapは`:keymap` IDを指定してcore/commandへ登録します。
この境界を越える変更が必要になった場合、laneはその依存作業を止め、owner担当へAPI追加を依頼します。

## 付録 調査根拠表

この付録は設計項目1〜6の判断材料と現行コードの観測を記録します。

### 1. core分割と循環の現状

| 調査項目 | 観測した事実 | 根拠 |
|---|---|---|
| 分割対象 | 仕様はcoreを`buffer`、`window-tree`、`command`、`minibuffer`、`editor-session`に分け、層の依存を内側へ向ける | `docs/src/notes/requirements-modern-editor.md:112-172` |
| C1 ルートとfeature | feature packageが`loom`を`:use`し、root側もfeature名を修飾して呼ぶ。startup stateとpresentationにも直接参照がある | `packages/feature/window/src/package.lisp:1-2`、`src/application/startup-state.lisp:31,35-36,53,61,63`、`src/presentation/layout-windows.lisp:190-191`、仕様`docs/src/notes/requirements-modern-editor.md:680` |
| C2 rootとapplication | `loom` packageが`loom/application`を`:use`し、application側からroot関数も参照する | `src/package.lisp:1-3`、`src/application/commands-internal.lisp:5-14`、`src/application/commands-keybindings.lisp:7`、仕様`docs/src/notes/requirements-modern-editor.md:681` |
| C3 applicationとwindow | `%selected-window`と`%selected-buffer`がwindow APIを利用し、window packageは`loom/application`を`:use`する | `src/application/commands-internal.lisp:3-14`、`packages/feature/window/src/package.lisp:1-2`、仕様`docs/src/notes/requirements-modern-editor.md:682` |
| C4 coreとwindow | coreのvisual-line移動がfeature/windowとrendererを参照する。window packageはrootを`:use`し、window treeを定義する | `packages/core/editor/src/application-commands-movement-visual-lines.lisp:11-16`、`packages/feature/window/src/package.lisp:1-2`、`packages/feature/window/src/domain-window.lisp:18-22`、仕様`docs/src/notes/requirements-modern-editor.md:683-694` |
| `::`参照 | private symbolは3種類、参照式は4か所。`%key-event->descriptor`はsearchとlspで各1か所、visual-line関数はlspで前後各1か所 | `packages/feature/search/src/application-commands-isearch.lisp:53`、`packages/feature/lsp/src/application-commands-lsp-support.lisp:45,50,53`、仕様`docs/src/notes/requirements-modern-editor.md:685` |
| workspaceの既定値 | `make-editor-state`がworkspace featureのmanagerを直接生成する。startupもmanagerを直接生成して渡す | `src/application/editor-state.lisp:3-15`、`src/application/startup-state.lisp:51-55` |
| keyboard-macroの既定値 | `editor-state` slotのデフォルトとstartupの両方でfeature constructorを直接呼ぶ | `src/application/editor-state-types.lisp:14-15`、`src/application/startup-state.lisp:61-63` |
| buffer APIの現行root export | `make-buffer`、`buffer-p`、`buffer-name`、`buffer-path`、`buffer-major-mode`、`buffer-set-major-mode`、`buffer-truncate-lines`、`buffer-set-truncate-lines`、`buffer-text`、`buffer-narrow-start-offset`、`buffer-narrow-end-offset`、`buffer-narrowed-p`、`buffer-visible-text`、`buffer-visible-line-count`、`buffer-visible-line`、`buffer-visible-point-line`、`buffer-visible-point-column`、`buffer-visible-offset-position`、`buffer-narrow-to-region`、`buffer-widen`、`buffer-line-count`、`buffer-line`、`buffer-point-line`、`buffer-point-column`、`buffer-set-point`、`buffer-mark`、`buffer-set-mark`、`buffer-insert-string`、`buffer-delete-char`、`buffer-delete-region`、`buffer-region-string`、`buffer-active-region-span`、`buffer-modified-p`、`buffer-read-only-p`、`buffer-set-read-only`、`buffer-read-only-error`、`buffer-mark-saved`、`buffer-mark-modified`、`buffer-offset`、`buffer-position-line`、`buffer-position-column`、`make-buffer-span`、`buffer-span-start`、`buffer-span-end`、`buffer-point-offset`、`buffer-offset-position`、`buffer-undo`、`buffer-redo`、`buffer-record-undo-boundary`、`buffer-load`、`buffer-save` | `src/package-exports.lisp:17-33` |
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
仕様4.2はsliceの責務を定めますが、slot単位の割当ては記載していないため、候補ownerはすべて推定です。

| slot | 現行初期値 | 候補owner（推定） | 根拠 |
|---|---|---|---|
| `window-tree` | `nil` | `core/window-tree` | 仕様4.2の146行目、定義27行目 |
| `workspaces` | `nil` | `feature/workspace` | 既定managerをfeature constructorで生成、`src/application/editor-state.lisp:10-15`。仕様4.2の170行目、推定 |
| `minibuffer` | `nil` | `core/minibuffer` | 仕様4.2の148行目、定義29行目 |
| `keymap` | `nil` | `core/command` | 仕様4.2の147行目、定義30行目 |
| `file-tree` | `nil` | `feature/file-tree` | 仕様4.2の153行目、定義31行目 |
| `concurrent-runtime` | `nil` | `feature/file-tree` | startup serviceが起動・停止を担う、`src/application/startup-services.lisp:3-20`。推定 |
| `renderer` | `nil` | root composition | rendererをstartupが生成して保持、`src/application/startup-state.lisp:38-45`。推定 |
| `buffers` | `nil` | `feature/buffers` | 仕様4.2の152行目、buffer登録箇所`src/application/commands-internal.lisp:28-42`。slice分担は仕様、個別slot対応は推定 |
| `recent-files` | `nil` | `feature/files` | 仕様4.2の151行目、recent-file API`src/application/editor-state-recent-files.lisp:11-30`。推定 |
| `bookmarks` | `nil` | `feature/bookmark` | 仕様4.2の169行目、定義36行目 |
| `kill-ring` | `nil` | `feature/kill-ring` | 仕様4.2の157行目、定義37行目 |
| `last-yank-buffer` | `nil` | `feature/kill-ring` | kill-ringのyank状態、定義38行目。推定 |
| `last-yank-start-offset` | `nil` | `feature/kill-ring` | kill-ringのyank状態、定義39行目。推定 |
| `last-yank-end-offset` | `nil` | `feature/kill-ring` | kill-ringのyank状態、定義40行目。推定 |
| `last-yank-ranges` | `nil` | `feature/kill-ring` | kill-ringのyank状態、定義41行目。推定 |
| `last-yank-ring-index` | `nil` | `feature/kill-ring` | kill-ringのyank状態、定義42行目。推定 |
| `last-yank-repeat-count` | `nil` | `feature/kill-ring` | kill-ringのyank状態、定義43行目。推定 |
| `last-command-kill-p` | `nil` | `feature/kill-ring` | kill command状態、定義44行目。推定 |
| `last-command-self-insert-p` | `nil` | `core/command` | undo境界とcommand dispatchの状態、定義45行目。推定 |
| `lsp-session` | `nil` | `feature/lsp` | 仕様4.2の171行目、定義46行目。slice分担は仕様、個別slot対応は推定 |
| `registers` | `nil` | `feature/register` | 仕様4.2の170行目、定義47行目。slice分担は仕様、個別slot対応は推定 |
| `keyboard-macro` | feature constructor | `feature/keyboard-macro` | slot defaultがconstructorを直接呼ぶ、定義48行目と14-15行目。仕様4.2の170行目 |
| `isearch` | `nil` | `feature/search` | 仕様4.2の160行目、定義49行目 |
| `completion` | `nil` | `feature/completion` | 仕様4.2の155行目、定義50行目 |
| `jump-origins` | `nil` | `feature/lsp` | 定義51行目。LSP移動履歴とする推定 |
| `auto-save-mode-p` | `nil` | `feature/auto-save` | 仕様4.2の171行目、定義52行目。slice分担は仕様、個別slot対応は推定 |
| `auto-save-buffers` | `nil` | `feature/auto-save` | 仕様4.2の171行目、定義53行目。推定 |
| `auto-save-last-run-at` | `nil` | `feature/auto-save` | 仕様4.2の171行目、定義54行目。推定 |
| `format-on-save-p` | `nil` | `feature/format` | 仕様4.2の171行目、定義55行目。slice分担は仕様、個別slot対応は推定 |
| `format-command` | `nil` | `feature/format` | 仕様4.2の171行目、定義56行目。推定 |
| `before-save-hooks` | `nil` | `core/editor-session` hook registry | generic save hook候補、定義57行目と`src/application/editor-state-save-hooks.lisp:15-55`。推定 |
| `after-save-hooks` | `nil` | `core/editor-session` hook registry | generic save hook候補、定義58行目と`src/application/editor-state-save-hooks.lisp:15-55`。推定 |
| `terminal-sessions` | `nil` | `feature/terminal` | 仕様4.2の171行目、定義59行目。slice分担は仕様、個別slot対応は推定 |
| `prefix-argument` | `nil` | `core/command` | 仕様4.2の147行目、定義60行目 |

### 3. コマンドカタログの現状

| 調査項目 | 観測した事実 | 根拠 |
|---|---|---|
| spec数と分類 | 現行カタログは120件。movement 26、editing 26、files/projects 12、windows/workspaces 12、session/registers 10、macros/evaluation 5、tooling 17、file-tree 8、UI/lifecycle 4 | `src/application/command-definitions.lisp:3-12`と`src/application/command-definitions-*.lisp`各群。調査時の集計 |
| 固定カタログ | 9個のグループ変数を中央ファイルが集約して`*command-specs*`を生成する | `src/application/command-definitions.lisp:3-12`、仕様`docs/src/notes/requirements-modern-editor.md:714-717` |
| 現行spec fields | W0-3は`:name`、`:group`、`:command`、`:keys`、`:help`、`:help-order`と5種metadataを保持する | `src/application/command-registry-forms.lisp:29-44`、`src/application/command-registry-build.lisp:3-15,50-68` |
| 重複検査 | 同名specはカタログ構築時に検査する。owner情報と登録時検査はない | `src/application/command-registry-build.lisp:27-41,71-87` |
| key衝突 | keymap登録は既存bindingを置き換え、衝突検査をしない | `src/domain/keymap.lisp:18-28`、`src/application/commands-keybindings.lisp:4-9` |
| 無名spec | `nil`名の`execute-extended-command`がある | `src/application/command-definitions-ui.lisp:26-34` |
| user-init登録 | user-initは`*command-specs*`を直接appendし、同名があるとerrorにする | `packages/feature/user-init/src/application-user-configuration.lisp:36-65` |
| W0-3修正前の実装 | fetchした`origin/main`にmetadata validation、`--dump-catalog`、`LOOM_TRACE_COMMANDS`が入っている。今回指示された修正は未反映 | `src/application/command-registry-forms.lisp:14-31`、`src/application/command-registry.lisp:89-142`、`src/main.lisp:12-16` |
| W0-3修正前のmetadata | `:mutates`と`:needs-region`はboolean、`:prompts`は4種のkeyword list、`:external`はstring list、`:modes`はkeyword list。`:modes`だけ`:all`がdefaultで、5キーの有無を検査しない | `src/application/command-registry-forms.lisp:14-31` |
| W0-3修正前のdump | JSONはname、group、keys、mutates、prompts、needs-region、external、modesを出す。command ID、help、help-order、owner、keymap IDは出さない | `src/application/command-registry.lisp:89-108` |
| W0-3修正前のtrace入口 | key経路は`record-command-trace`へ`:key`を渡し、M-x経路は`:mx`を渡してからcommandを直接`funcall`する。二経路はmacro replayとC-u経路を共通化していない | `src/application/input-routing-effects.lisp:20-26`、`src/application/commands-misc.lisp:15-22`。macroとC-uの欠落はW0-3レビュー報告 |
| W0-3修正前の識別子差 | catalogにはcommand IDがなく、traceは`:name`を優先し、無名specだけsymbol nameへfallbackする。`execute-extended-command`は`:name nil` | `src/application/command-registry.lisp:89-108,120-128`、`src/application/command-definitions-ui.lisp:26-34` |
| W0-3修正後の設計前提 | `invoke-command(command, route)`を唯一の実行とtrace入口にする。`:key`、`:mx`、`:macro`を使い、W3-8で`:mouse`を追加する。5 metadataをparseとregistrationで必須にし、`:external`は機械可読な識別子にする | 今回のW0-3修正指示。修正後のmainへ反映された時点で実装名と識別子語彙を照合する |
| カタログ集計の依存 | E2E coverageは中央の`src/application/command-definitions*.lisp`を正規表現で読む | 仕様`docs/src/notes/requirements-modern-editor.md:717` |

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
| W3-8 | kill-ring、clipboard、mouse | non-key input、terminal mode、window/file-tree public APIを使う。`docs/src/notes/requirements-modern-editor.md:499` |
| W3-9 | lsp | W3-6の一覧と移動を使う。`docs/src/notes/requirements-modern-editor.md:500` |
| W3-10 | file-tree、window、workspace、session、bookmark、register、keyboard-macro | file-tree local keymapはW3-1の仕組みを使う。`docs/src/notes/requirements-modern-editor.md:501` |
| W3-11 | shell、format、git、terminal、auto-save | 既存commandのE2Eと不具合修正。`docs/src/notes/requirements-modern-editor.md:502` |
| 共通の書込範囲 | 各laneは担当sliceのcode、test、`t/paths.sexp`だけを変更する | `docs/src/notes/requirements-modern-editor.md:478-484` |

