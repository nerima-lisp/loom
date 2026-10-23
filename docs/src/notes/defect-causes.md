# 欠陥原因の調査

この文書は`docs/src/notes/requirements-modern-editor.md:35-47`のD1、D2、D3、D13と、`docs/src/notes/verification-ledger.md:715`で新たに確認した端末リサイズ後の再描画失敗を扱う。各節の「原因」はコード経路と観測から判断し、推定が残る箇所は観測範囲を併記する。PTY観測には毎回一時HOMEを使い、ビルド済みのdefault実行ファイルを起動した。

## D1: 矢印、Home、End、Delete、PgDn

### 原因

**経路は確定、端末列ごとのイベント対応は推定。** `%key-event->descriptor` はCtrlキー以外のイベントをそのままキーディスクリプタにする（`src/application/input-routing-descriptor.lisp:19-43`）。既定の移動コマンドはC-f、C-b、C-n、C-pなどだけを登録し、編集コマンドはDeleteに対してC-d、後退に対してBackspaceを登録している。↓、→、Home、End、Delete、PgDnの別名はない（`src/application/command-definitions-movement.lisp:3-44`、`src/application/command-definitions-editing.lisp:3-48`）。ディスクリプタに対応するキー割り当てがなければ`keymap-lookup`はNILを返し、通常文字でもないイベントは自己挿入されない（`src/domain/keymap.lisp:63-74`、`src/application/input-routing-decision.lisp:30-46`）。点が動かないため、続く通常文字は元の位置に挿入される。`:up`イベントが変換後もそのまま通ることは既存テストでも確認できる（`t/integration/input-routing-test.lisp:20-23`）。PTYで送った各CSI列が依存ライブラリ内でどのイベントコードになるかは、この調査では計測していない。

### 観測

80x24の実PTYで`.#default`を起動し、100行のファイルを開いた。↓（`CSI B`）、→（`CSI C`）、End（`CSI F`、`CSI 4~`）、Home（`CSI H`、`CSI 1~`）、Delete（`CSI 3~`）、PgDn（`CSI 6~`）の各入力後、カーソルは`(0,0)`のままで画面出力もなかった。続く`X`を入力して保存すると、行頭に`X`が入っていた。イベントコード自体はPTY入力からアプリ内部まで記録していない。

### 修正候補と影響

既定キーマップに矢印を`next-line`、`forward-char`へ、HomeとEndの両形式を行頭・行末移動へ、Deleteを`delete-char`へ割り当て、PgDnをページスクロールへ割り当てる。入力デコーダを変更せず、実際のイベントコードを確認してから割り当てる。ミニバッファ、補完ポップアップ、端末入力はキーマップより先に個別処理へ進むため、その優先順を保つ（`src/application/input-routing-dispatch.lisp:27-43`、`src/application/minibuffer-input.lisp:15-23`、`src/application/completion-popup-input.lisp:73-96`）。`t/integration/command-registration-test.lisp:19-51`は宣言済みコマンドの登録とキー割り当てを確認するが、対象キーの別名は検証していない。`t/integration/input-routing-test.lisp:20-23`は`:up`の通過を確認する。実PTY相当のイベント経路で各キーの移動後に文字を入力する検証を追加する。

## D2: C-x C-uとM-x undo

### 原因

**コード経路は確定。undo履歴の先頭要素は推定。** 自己挿入からキー割り当てコマンドへ切り替わると、ルーターはコマンド実行前にundo境界を記録する（`src/application/input-routing-effects.lisp:19-35`）。境界を記録する条件は前回のコマンド種別との変化である（`src/application/input-routing-command-state.lisp:3-12`）。`buffer-undo`は履歴先頭から境界までを取り出し、最初の要素が境界なら空のグループとなって変更を戻さない（`packages/core/editor/src/domain-buffer-history.lisp:32-46`）。2回目は境界の次にある編集記録を処理する。M-xは入力した名前のコマンドを直接呼ぶため、M-xの起動時にできた境界がundoの前に残る（`src/application/commands-misc.lisp:8-20`、`packages/core/editor/src/application-commands-region.lisp:27-29`）。PTYの結果はこの経路と一致するが、初回undo直前の履歴リストは採取していない。境界が実行時に先頭にあるかは推定であり、初回undo直前の履歴を記録すれば確認できる。

### 観測

`.#default`を新しいHOMEごとに起動し、空ファイルへ`XY`を入力した。実PTYでC-x C-uを1回送って保存すると内容は`XY`のままで、同じundoをもう1回送ると空になった。別の実行でM-x undoを選んでも同じ結果となった。

### 修正候補と影響

`buffer-undo`が先頭の境界を読み飛ばして編集グループまで進む方法は、変更範囲をundo履歴の処理に絞れる。ただし連続undo、グループ境界、redoの関係を確認する必要がある。別案として、undoコマンドを実行する前の境界記録を調整する方法があるが、通常のコマンド遷移、C-xのprefix処理、M-xにも影響する。既存の`t/integration/commands-editing-buffer-history-test.lisp:3-12`はコマンドを直接呼び、`t/unit/buffer-undo-test.lisp:23-43`は境界の後に編集した場合を確認する。キー入力ルーティングを通すテストを追加する。

## D3: 先頭行でのC-vとM-x scroll-up-command

### 原因

**確定。** `scroll-up-command`は選択ウィンドウのスクロール行だけをページ分更新し、バッファの点は動かさない（`packages/core/editor/src/application-commands-movement.lisp:47-53`、`packages/core/editor/src/application-commands-movement-view-support.lisp:51-66`）。入力のたびにフレームを描くと、レイアウト処理が点を表示範囲に保つ。点がビューポートより上にある場合、スクロール位置を点の行へ戻す（`src/presentation/frame-layout.lisp:22-26`、`src/presentation/frame-layout-viewport.lisp:67-83`）。そのためスクロールコマンド直後に先頭へ戻る。

### 観測

200行のファイルを先頭に置いた80x24のPTYでC-vを3回送り、各段階の入力、スクロール行、描画開始行を計測した。C-vは`:SPECIAL :CONTROL-V`として`scroll-up-command`に届き、コマンド内ではスクロール行が0から22になったが、描画時に点追従で0へ戻った。表示は3回とも先頭行から始まった。M-x `scroll-up-command`でも同じ状態遷移を確認した。

### 修正候補と影響

スクロール量に合わせて点も移動させる方法は、現在の「スクロールは点を動かさない」意味を変え、同じバッファを表示する複数ウィンドウの点や折り返し行へ波及する。別案として、手動スクロール中は点追従を止める状態を導入する方法がある。こちらはフレーム合成の共通不変条件を変え、別コマンド後にいつ点追従を再開するかも決める必要がある。既存の`t/integration/frame-layout-cursor-test.lisp:58-65`は合成時に点へ戻ることを期待し、`t/integration/commands-movement-scroll-edit-test.lisp:14-24`は描画を伴わずスクロール行だけを確認する。E2Eの`t/e2e/scenarios/movement.py:214-222`は先に15行目へ移動してからスクロールする。先頭位置からC-vとM-xを実行し、描画後の表示を確認する結合テストが必要である。

## D13: 描画経路の行数比例コスト

### 原因

**描画内の行数比例処理は確定。キー全体の遅延に占める割合は未確認。** `buffer-visible-line`は呼び出すたびに`%visible-lines`を作り、可視テキスト全体を行に分割する（`packages/core/editor/src/domain-buffer-narrowing.lisp:15-31`、`packages/core/editor/src/domain-buffer-narrowing-support.lisp:14-26`）。可視テキストの取得はバッファ全体を再構成してから範囲を切り出す（`packages/core/editor/src/domain-buffer-storage-support.lisp:14-17`、`packages/core/editor/src/domain-buffer-narrowing.lisp:15-19`）。標準描画、構文強調、折り返しレイアウトは表示行ごとに`buffer-visible-line`を呼ぶため、表示行数分、全文再構成と全行分割を繰り返す（`src/infrastructure/terminal-renderer.lisp:55-71`、`packages/feature/syntax-highlighting/src/presentation-syntax-highlighting.lisp:72-86`、`src/presentation/layout-wrapping.lisp:72-87`）。ほかに、カーソル行・列の計算も可視テキストを走査し（`packages/core/editor/src/domain-buffer-narrowing.lisp:33-49`、`packages/core/editor/src/domain-buffer-narrowing-support.lisp:3-12`）、括弧対応表示は可視テキスト全体を調べる（`src/presentation/layout-windows.lisp:262-273`）。点の文字オフセットを得る処理も点より前の行を順に走査し（`packages/core/editor/src/domain-buffer-positions.lisp:31-36`）、座標からオフセットへ移す`%position-to-offset`はバッファ断片の文字を走査する。`buffer-set-point`はこの処理を呼ぶ（`packages/core/editor/src/domain-buffer-piece-table-position.lisp:13-23`、`packages/core/editor/src/domain-buffer-accessors.lisp:49-58`）。これらはキー移動時間にも影響し得るが、今回の計測では寄与を分けていない。

### 観測

一時HOMEで起動したin-process測定で、5,000行と20,000行のバッファに対し、各23回`buffer-visible-line`を呼んだ。行数を4倍にすると、1呼び出し当たりの中央値はwall時間で3.62倍、CPU時間で3.55倍だった。各計測バッチの直前と直後に記録した`uptime`は、4バッチすべて`2:54  up 2 days, 17:11, 1 user, load averages: 18.12 19.82 26.43`だった。これは関数単体の測定で、キー入力からフレーム表示までの新しい有効なPTYサンプルは得られていない。キー応答への寄与を確定するには、点移動とフレーム描画を分けた計測が必要である。既存の実機測定は`docs/src/notes/verification-ledger.md:689-704`にあるが、別の高負荷条件である。

### 修正候補と影響

フレーム単位で可視行と点の位置を一度だけ計算し、renderer、layout、カーソル表示へ渡す方法は、主に描画とレイアウト間の受け渡しに影響する。フレーム外から呼ぶアクセサや点移動時の走査量は変わらない。バッファに行索引を持たせる方法は、編集、narrowing、undo、redoの更新経路まで影響する。どちらを選ぶ場合も、行取得、カーソル位置、折り返し描画をそれぞれ検証する。関数単体の比率をキー全体の改善率として扱わず、修正後に実PTYのキー応答も測る。

## 端末リサイズ後の再描画

### 原因

**アプリケーション内の再描画経路は確定。OSのシグナル処理は未確認。** 背景処理がないと`%wait-for-editor-input`は入力待ちを使わず、イベントループは`read-byte`によるブロック読み込みへ進む（`src/application/event-loop-control.lisp:31-55`、`src/application/input-dispatch.lisp:17-26`）。入力かタイムアウトが返った場合だけサイズを確認して描画する（`src/application/event-loop.lisp:15-30`）。タイムアウトは端末セッション、LSP、auto-saveなど背景作業がある場合だけ設定される。このアイドル経路では、リサイズ通知に応じてアプリケーションコードがサイズ確認へ戻る処理がなく、次のキー入力まで再描画しない。`src`と`t`に`SIGWINCH`または`winch`の参照はなかった。依存ライブラリとSBCLのシグナル処理は調べていない。

### 観測

80x24のPTYで起動した`.#default`を60x12へ変更し、前景プロセスグループに`SIGWINCH`を送った。PTYサイズは12x60になったが、その後1.2秒のアプリ出力は0バイトだった。バッファを変更しないC-aを送ると761 bytes出力され、全消去制御列と60桁のフレームが現れた。アプリ終了コードは0だった。

### 修正候補と影響

入力待ちにタイムアウトを設け、サイズが変わったときだけ既存のresizeと描画処理を動かす方法がある。アイドル時の起床が増え、無変更フレームを抑える判定が必要になる。もう一案は`SIGWINCH`を安全なイベントループ起床通知へ変換する方法で、シグナル処理とスレッド境界を含む。どちらも既存の`resize-terminal-sessions`呼び出しを保つ。`t/integration/main-terminal-size-test.lisp:15-96`はサイズ変更処理と待機を個別に確認するが、実PTYでリサイズから再描画までを通すテストはない。
