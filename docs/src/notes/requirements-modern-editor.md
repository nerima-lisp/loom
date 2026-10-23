# 要件定義: loom を EDITOR=loom で日常使いできるモダンエディタにする

この文書は、並列で動く実装ストリームが共有する唯一の仕様である。
各ストリームは自分のタスクの完了条件と共有ファイルの担当を第11章で確認してから着手する。
第2章と付録の観測は調査時点のソースと実バイナリに対するもので、実装が進むと古くなる。
着手時には、自分の範囲の観測を実バイナリで再現してから前提にすること。

## 1. 目的

loomは`git commit`の基本フローなら通るが、日常の編集と`$EDITOR`としての利用を止める欠陥を実機で多数確認した。
主なものは、メイン画面の矢印キーが効かない、undoの1回目が空振りする、C-vが先頭からスクロールしない、マウスのシーケンスで異常終了する、CRLFのファイルを保存で壊す、の5点である。

前回の検証（`docs/src/notes/verification-plan.md`と`docs/src/notes/verification-ledger.md`）は、120件のコマンドspecそれぞれにE2Eシナリオが1つ宣言されていることを網羅とみなした。
この数え方では、宣言しただけで実行しないコマンドや、終了コードしか見ないシナリオもカバー済みに数えられる。
上の欠陥のうち2つ（undoとC-v）は、既存のE2Eが不具合を避ける手順で書かれていたために見逃されていた。

この要件の目標は次の3つを同時に満たすことである。

1. 作者の日常編集（Common Lisp / Emacs Lisp、Nix、TypeScript / Web、Markdown / Org）と、`$EDITOR` / `$VISUAL`経由の利用を、loomだけでこなせる。
2. DDDとpackage by featureを、境界テストで機械的に強制する。
3. 全コマンドと全導線を、実バイナリと実PTYの上で、効果の観測によって検証する。

## 2. 現状

根拠の印は次のとおりである。

- **実機**：`.#default`の実バイナリをPTYで動かし、画面、ファイルのバイト列、終了コードを観測した。
- **静的**：ソースを読んで判定した。
- **推定**：観測から導いたが、直接は見ていない。

### 2.1 実機で観測した欠陥

| ID | 観測 | 根拠 |
|---|---|---|
| D1 | ↓、→、End（`CSI F`と`CSI 4~`）、Home、Delete、PgDnを押しても何も起きない。そのあと入力した文字は行頭に入る | 実機 |
| D2 | "XY"を入力してC-x C-uを1回押しても変化しない。2回押すと戻る。"X、RET、Y"の後に2回押すとYだけが戻る。M-x undoも同じ | 実機。既存E2EはC-x C-uを2回送っている（`t/e2e/scenarios/editing_commands.py`のundoシナリオ） |
| D3 | 200行のファイルの先頭でC-vを3回押しても1行目のまま。M-x scroll-up-commandも同じ | 実機。既存E2Eは`goto-line 15`の後でしかC-vを押さない（`t/e2e/scenarios/movement.py`） |
| D4 | SGRマウスシーケンス`ESC[<0;3;2M`を1つ受け取ると、`TYPE-ERROR`（MOUSE-EVENTはKEY-EVENTではない）でexit 1 | 実機 |
| D5 | 同じファイルをC-x C-fで開き直すと、未保存の編集を含まない別バッファができる。C-x bの候補はどちらも`f.txt`で区別できない | 実機 |
| D6 | ブラケットペースト（`?2004h`）とマウスモードを有効にしない。貼り付けたTABは字下げ処理で空白1つに変わる | 実機 |
| D7 | TABを1セルで描く。結合文字を1セルと数え、カーソルが1桁ずれる。ZWJ絵文字の表示が崩れる | 実機 |
| D8 | RETで自動インデントしない（Lisp、Nixとも） | 実機 |
| D9 | MarkdownでM-;を押すと`# hello`になり、コメントではなく見出しになる | 実機 |
| D10 | find-fileでTABを押してもパスを補完しない。M-xの補完は効く | 実機 |
| D11 | 保存しても"Wrote …"を表示しない。M-wの後にOSC 52を出さない | 実機 |
| D12 | C-zを押しても何も起きない。外部からSIGTSTPを送ると、fgで戻った後にrawモードへ戻らない | 実機 |
| D13 | 20,000行のファイルでは1キーにつき約0.2〜0.26秒かかり、5,000行では約0.05秒だった。行数にほぼ比例して遅くなる | 実機。原因は静的に特定した。`buffer-visible-line`が描画する1行ごとにバッファ全文を組み直す |
| D14 | 存在しないファイルを開けない（exit 64）。`+N`も複数ファイルもexit 64 | 実機 |
| D15 | 非ゼロで終了して呼び出し元を中断させる手段がない。SIGTERMを受けてもexit 0で終わる | 実機 |
| D16 | 不正なUTF-8を含むファイルを開くとexit 70で落ちる。CRLFのファイル`ab\r\ncd\r\n`でC-eの後にZを入れると、保存結果が`ab\rZ\ncd\r\n`になる | 実機 |
| D17 | init.lispにエラーがあると起動しない（exit 1）。stdinがttyでないと起動しない（exit 1）。SIGHUPの後に端末がrawのまま残る | 実機 |

### 2.2 実機で問題がなかったもの

次の性質は退行させてはならない（FR-E06）。

- `git commit`（保存して終了、保存せず終了、確認でdを選んで破棄）、`git rebase -i`、crontab型のフロー（一時ファイルを書いて待ち、終了後に読み戻す）がすべて成功した。
- 保存はその場で上書きし、inode、パーミッション（600と755）、シンボリックリンク、ハードリンクを保つ。作業ディレクトリにバックアップや自動保存のファイルを残さない。
- 起動から最初の画面までの中央値は0.11秒だった。
- BOMと末尾改行の有無は保存後もそのまま残った。
- 端末を80x24から60x12へ縮めたとき、キー入力がなくても再描画された。

### 2.3 アーキテクチャ（静的）

loomはルートの`src/`を合成ルートとし、機能を`packages/feature/<slice>/`に分けている。
しかし、package by featureの形は次の点で崩れている。

- ルートの`loom`パッケージと全18スライスの間に依存の循環がある。スライスは`(:use #:loom #:loom/application)`し、ルート側もスライスのシンボルを修飾参照する。`loom`と`loom/application`の間、coreと`window`の間にも循環がある。
- `loom.asd`は1つのシステムで、全パッケージを先に定義してから層の順に読み込む。この順序のおかげで循環があってもロードできている。
- 120件のコマンドspec（M-xの1件は名前が`nil`）とキーは`src/application/command-definitions-*.lisp`に集中している。スライスが自分でコマンドを登録するAPIはない。
- `editor-state`のスロットは34個あり、そのうち約20個はスライスが持つべき状態である（`src/application/editor-state-types.lisp`）。
- 境界を強制するテストはない。`t/unit/dependency-contract-test.lisp`は`loom.asd`と`flake.nix`の依存宣言を突き合わせるだけである。
- ブックマーク、ミニバッファ、補完ポップアップ、ヘルプ、終了処理、kill ring、バッファのファイルI/Oはスライスの外にある。バッファのファイルI/Oは`file-tree`スライスに混ざっている。

詳細は付録Dにある。

### 2.4 検証の現状

- 次の5つのコマンドは、M-xで呼んでC-gを送り、終了コードが0かを見るだけの`probe_command`でしか検証されていない（`t/e2e/scenarios/scenario_helpers.py`）。`eval-buffer`、`eval-expression`、`keyboard-quit`、`backward-kill-word`、`splice-sexp`。
- カバレッジの集計は、シナリオが宣言したコマンド名を数える（`t/e2e/loom_e2e/registry.py`）。`t/e2e/scenarios/project.py`の`project search`シナリオは`previous-line`を宣言しているが実行していない。
- 29個のキーはE2Eでもin-processテストでも一度も押されていない。E2EはほぼすべてのコマンドをM-x経由で呼ぶ。
- TAB補完、ミニバッファ履歴、端末リサイズ、プロセス再起動後のセッション復元、外部ツールの実際の失敗、読み取り専用バッファへの変更系コマンド、変更系コマンドの後のundoは、E2Eで一度も通っていない。
- E2EはRETとしてLFを送る（`t/e2e/loom_e2e/keys.py`）。実端末が送るCRを受け取る経路を、E2Eは一度も試していない。
- `t/integration/main-event-loop-input-test.lisp`の"exits via LOOM-QUIT"テストにはassertionがない。
- `%run-loom`を呼ぶin-processテストは描画を実端末のstdoutに流し、HOMEを隔離していない（推定：作者の`~/.loom/init.lisp`を読む可能性がある）。
- 作者の手動チェックリスト（`docs/src/notes/daily-driver-checklist.md`）は全行がNot runである。

詳細は付録Cにある。

## 3. 決定事項

作者が次のとおり決めた。これらは実装中に見直さない。

| 論点 | 決定 |
|---|---|
| キー | Emacs標準に置き換える。loom独自のC-x C-u（undo）とC-x C-y（redo）は削除する |
| インデントと複数行のハイライト | 言語ごとにLispで手書きする。外部依存は増やさない。Markdown / Orgだけは例外で、cl-markdown-kitとcl-org-kitを使う |
| マウス | クリック、ホイール、ドラッグ選択を実装する |
| ASDF | スライスごとに`.asd`を置く。ルートの`loom.asd`は合成だけを宣言する |
| テストの配置 | テスト、E2Eシナリオ、導線台帳をスライスのディレクトリに置く |
| S式 | 移動は全モードで使える。構造編集はLisp系のモードキーマップだけに割り当てる |
| LSP | 日常の主要機能（FR-L）を揃える |
| Org / Markdownのアウトライン | 見出し移動、折りたたみ、TODO切り替えはoptionalとする。実装する場合はkitを使う |
| SWANK | 今回の範囲に入れない。ソケット層の方針と合わせて別途扱う |
| 性能目標 | 第6章のNFR-01とNFR-02の値で確定した |
| 実機確認 | すべての合格判定を実バイナリと実PTYで行う |

`docs/src/notes/requirements-daily-driver.md`に記録した以前の決定も維持する。multiple-cursorsのコードは撤去済みで、再び追加しない。terminal、workspace、register、keyboard-macroは残す。折り返し表示の設定はセッションに保存しない。

## 4. アーキテクチャ方針

### 4.1 層と依存の向き

依存は合成ルート、feature、core、外部ライブラリの順に下向きだけを許す。

```text
composition root (loom.asd)
  main / 起動の組み立て / イベントループの駆動 / フレームの合成 / 端末レンダラー
        |
        v
packages/feature/<slice>/   各スライスが loom-<slice>.asd、t/、導線台帳を持つ
  スライス間の依存は、各 .asd の :depends-on に宣言した DAG だけを許す
  スライス内の向き: presentation -> application -> domain <- infrastructure
        |
        v
packages/core/   共有カーネル
  buffer | window-tree | command (keymap, registry, prefix-arg, dispatch)
  | minibuffer | editor-session (slice-state 表、フック)
        |
        v
外部ライブラリ (cl-tty-kit、cl-boundary-kit、cl-regex-kit、...)
```

domainのファイルは`*editor-state*`、I/O、上位の層を参照しない。
infrastructureのファイルも`*editor-state*`を参照しない。
合成ルートはスライスのシンボルを名指しで呼ばず、各スライスが登録したフックを順に呼ぶ。

### 4.2 スライス構成

目標のスライスは次のとおりである。
「新設」は新しく作るスライス、「移設」は既存コードを移して作るスライスを表す。

| スライス | 責務 | 由来 |
|---|---|---|
| core/buffer | piece table、undo、narrowing、read-only、位置計算 | 既存core |
| core/window-tree | ウィンドウ木の構造と不変条件 | `window`スライスのdomainから移設 |
| core/command | キーマップ、コマンドレジストリ、前置引数、ディスパッチ | `src/domain/keymap*.lisp`、`command-registry*.lisp`などから移設 |
| core/minibuffer | ミニバッファの状態と入力 | `src/application/minibuffer*.lisp`から移設 |
| core/editor-session | カーネル状態、slice-state表、フック | `editor-state`を分解 |
| lifecycle | CLI、`$EDITOR`契約、シグナル、サスペンド、復旧、`*Messages*` | 新設。`commands-quit.lisp`を含む |
| files | バッファのファイルI/O、エンコーディング、改行コード、外部変更検出、バックアップ、最近使ったファイル | `file-tree`から分離 |
| buffers | switch-to-buffer、kill-buffer、同名バッファの区別、終了時の保存確認 | `window`と`commands-quit.lisp`から移設 |
| file-tree | ディレクトリ表示とファイル操作、dired風のローカルキーマップ | 既存 |
| minibuffer-ui | ミニバッファの編集操作、候補一覧の表示 | 新設 |
| completion | 補完ポップアップと候補の絞り込み | `completion-popup*.lisp`から移設 |
| help | describe系コマンドと`*Help*` | `commands-misc.lisp`から移設 |
| kill-ring | kill ringとyank | coreから移設 |
| clipboard | OSC 52、pbcopy / wl-copy、ブラケットペースト | 新設 |
| mouse | マウスイベントの解釈と各スライスへの振り分け | 新設 |
| search | isearch、query-replace、occur、検索結果一覧と`next-error` | 既存 |
| project | プロジェクトのルート、ファイル一覧、プロジェクト検索 | 既存 |
| mode | major modeの登録、インデントとハイライトのプロトコル | 既存。言語ごとの定義は各言語スライスへ移す |
| syntax-highlighting | 複数行の状態を持つトークン化の枠組み | 既存 |
| lisp-structure | S式移動（全モード）と構造編集（Lisp系） | coreから移設 |
| lang-lisp | Common Lisp / Emacs Lispのモード、インデント、ハイライト、構造編集のキー | 新設 |
| lang-nix | Nixのモード、インデント、ハイライト | 新設 |
| lang-web | TS / JS / JSX / JSON / HTML / CSS / YAMLのモード、インデント、ハイライト | 新設 |
| lang-markup | Markdown / Orgのモード、ハイライト、インデント、アウトライン | 新設。cl-markdown-kitとcl-org-kitに依存する |
| bookmark | ブックマーク | `src/application/commands-bookmark*.lisp`から移設 |
| window、workspace、session、register、keyboard-macro | 既存の責務 | 既存 |
| lsp、terminal、shell、format、git、evaluation、auto-save、user-init | 既存の責務 | 既存 |


### 4.3 slice-stateとフック

各スライスは自分の状態をコンストラクタ付きでslice-stateとして登録する。
`editor-session`はスライス名をキーにした表で状態を持ち、スライスの状態の形を知らない。
合成ルートは起動時にスライス一覧を一度だけ並べ、各スライスが登録したフックを順に呼ぶ。フックは、tick、キー入力、キー以外の入力イベント（マウスとペースト）、描画、端末モードの要求、保存の前後の6種類である。
端末モードの要求フックは、clipboardがブラケットペーストを、mouseがマウスモードを有効にするために使う。
キー以外の入力イベント（マウスとペースト）のフックは、core/commandのディスパッチがイベントの種類で振り分けるために使う。

### 4.4 コマンドとキーの登録

各スライスは自分のapplicationファイルでコマンドspec（名前、関数、キー、ヘルプのグループ、メタデータ）を登録する。
所有者が違う同名のコマンドや、同じキーマップ内のキーの衝突は、登録時点でエラーにする。
同じ所有者による再登録は冪等にする。
いまのカタログ全体での重複検出より緩めてはならない。

メタデータは導線の生成に使う（第7章）。

- `:mutates`：バッファを変更するか
- `:prompts`：入力欄の種類（自由文字列、補完付き、yes/no、数値）
- `:needs-region`：リージョンが必要か
- `:external`：使う外部ツール
- `:modes`：有効なモード

## 5. 機能要件

各要件はmandatoryかoptionalかを示す。
mandatoryは、それがないと日常使用か`$EDITOR`としての利用が成り立たない要件である。
括弧内のDは第2章の欠陥IDを表す。

### 5.1 FR-A アーキテクチャ

FR-Aはすべてmandatoryである。第11章のW3の並列実装は、これが成り立つことを前提にする。

- **FR-A01 境界テスト**：各スライスのソースをLispリーダーで読み、次のいずれかがあれば失敗する。宣言していないスライスのシンボルの参照。他パッケージの非公開シンボルの`::`参照。domainファイルによる`*editor-state*`、I/O、上位層の参照。走査したファイルが0件であること。既存の違反はスライスごとのallowlistにfile:line付きで載せ、完了時点で空にする。
- **FR-A02 依存の向き**：依存の向きを4.1のとおりにする。スライス間の依存は各`.asd`の`:depends-on`に宣言したDAGに限る。付録DのC1〜C4の循環を解消する。
- **FR-A03 スライスによる自己登録**：4.3と4.4の仕組みを実装する。
- **FR-A04 合成ルートの役割**：合成ルートは起動、イベントループの駆動、フレームの合成、レンダラーに限る。
- **FR-A05 スライス外コードの移設**：4.2の「由来」欄のとおりにコードを移す。
- **FR-A06 カタログの出力**：`loom --dump-catalog`が実行時のレジストリからJSON（コマンド、キー、所有スライス、メタデータ）を出力する。E2Eは正規表現でソースを読むのをやめ、この出力を使う。

### 5.2 FR-E `$EDITOR`契約

FR-Eはすべてmandatoryである。

- **FR-E01 引数**：`loom [+LINE[:COL]] FILE...`を受け付ける。存在しないファイルは空のバッファで開き、保存時に作る。親ディレクトリがない場合は保存時に作るかを確認する。複数のファイルはすべてバッファとして開く（D14）。
- **FR-E02 中断**：M-x `kill-loom-abort`はexit 1で終了する。未保存のバッファがあれば確認を出す（D15）。
- **FR-E03 シグナル**：SIGTERMでは端末を復元し、変更のあるバッファを`~/.loom/recovery/`へ退避してexit 143で終わる。SIGHUPでは同じ処理をしてexit 129で終わる。C-zとSIGTSTPでは端末を復元してから停止し、SIGCONTでrawモードに戻って再描画する（D12、D15、D17）。
- **FR-E04 端末の取得**：stdinかstdoutがttyでない場合は`/dev/tty`を使う。TERMが`dumb`か未設定なら、理由を表示してexit 1で終わる（D17）。
- **FR-E05 initのエラー**：init.lispのエラーは`*Messages*`とミニバッファで報告し、編集を続ける。`--no-init`でinitを読まずに起動できる（D17）。
- **FR-E06 既存の合格点**：2.2の性質を維持する。

### 5.3 FR-K キーと入力

FR-Kはすべてmandatoryである。

- **FR-K01 グローバルキーマップ**：Emacsの既定に合わせる。undoは`C-/`、`C-_`、`C-x u`、redoは`C-M-_`とする。矢印、Home/End、PgUp/PgDn、Delete、`C-l`、`C-t`、`M-u`、`M-l`、`M-c`、`M-q`、`C-M-\`、`M-^`、`M-g M-g`、`C-x C-b`、`C-x s`を割り当てる。`C-x C-e`はeval-last-sexpとし、eval-bufferはM-xから呼ぶ（D1）。
- **FR-K02 Emacs既定と食い違う割り当て**：C-x C-uとC-x C-yは削除する。C-x C-t（file-tree）は`C-x d`に移す。C-x r lはEmacsと同じlist-bookmarksにし、load-sessionはM-xから呼ぶ。file-treeの`C-c n/p/o/c/d`はfile-treeバッファのローカルキーマップ（dired風）に移す。slurp、barf、wrap、splice、raiseはLisp系モードのキーマップに移す。割り当ては今と同じで、Emacsのparedit.elと一致する（`C-<right>`、`C-<left>`、`C-M-<left>`、`C-M-<right>`、`M-(`、`M-s`、`M-r`）。Emacs既定の参照表をデータファイルとして置き、意図しない食い違いをテストで検出する。
- **FR-K03 入力の堅牢性**：CRをRETとして扱う。未知のエスケープシーケンスやマウスイベントで異常終了しない（D4）。

### 5.4 FR-B 編集の正しさ

FR-Bはすべてmandatoryである。

- **FR-B01 undo**：undoを1回押すと1つの変更グループが戻る。すべての変更系コマンドについて、undo 1回で元のバイト列に戻る（D2）。D2の原因はまだ特定していない。
- **FR-B02 スクロール**：C-v / M-vとPgDn / PgUpは、どの位置からでも1画面分スクロールする（D3）。
- **FR-B03 大きなファイル**：NFR-01を満たす（D13）。

### 5.5 FR-F ファイルとデータの安全

FR-Fはすべてmandatoryである。

- **FR-F01 二重バッファの防止**：同じファイル（truenameで判定）を開き直したら既存のバッファに移る。同じ名前のバッファは`f.txt<dir>`の形で区別する（D5）。
- **FR-F02 外部での変更**：保存時と、バッファへ切り替えたときに、ディスク上のファイルが外部で変わっていないかを確かめる。変わっていれば保存の前に確認を出す。`revert-buffer`を用意する。
- **FR-F03 エンコーディング**：CRLFとLFを判定して保持する。BOMを保持する。不正なバイト列を含むファイルでも落ちずに開き、編集していない部分のバイトをそのまま保存する。モードラインに改行コードとエンコーディングを表示する（D16）。
- **FR-F04 保存の安全**：保存は今と同じその場上書きにする（FR-E06）。上書きの前に元の内容を`~/.loom/backups/`へ退避する。保存したら"Wrote <path>"を表示する（D11）。

### 5.6 FR-D 表示

FR-D01〜D03はmandatory、FR-D04はoptionalである。

- **FR-D01 文字幅**：TABをモードごとのtab-widthで展開する。結合文字やZWJを含む書記素クラスタを1単位として描く。カーソルの列を描画と一致させる（D7）。
- **FR-D02 行番号**：行番号を表示できる。コード系のモード（markdown、org、text、fundamental以外）では既定で表示する。
- **FR-D03 複数行の構文**：複数行にまたがる文字列とコメントを、言語ごとに正しくハイライトする（FR-G）。
- **FR-D04 末尾の空白**：行末の空白を強調表示する。作者の要望を確認していないためoptionalとする。

### 5.7 FR-S 検索とナビゲーション

FR-Sはすべてmandatoryである。

- **FR-S01 isearch**：C-s / C-rはリテラル検索、C-M-s / C-M-rは正規表現検索にする。
- **FR-S02 置換**：M-%は確認しながら置換するquery-replace（y、n、!、q）にし、C-M-%はその正規表現版にする。`replace-string`と`replace-regexp`も用意する。キャプチャグループを展開する。
- **FR-S03 一覧と移動**：occurとproject-searchの結果を一覧バッファに出し、RETで該当箇所へ移動する。`M-g n` / `M-g p`で次と前の結果へ移る。検索中もエディタを止めず、C-gで中断できる。LSPのreferencesと診断も同じ仕組みを使う。

### 5.8 FR-M ミニバッファ、補完、ヘルプ

FR-Mはすべてmandatoryである。

- **FR-M01 ミニバッファの編集**：C-a、C-e、C-f、C-b、C-k、C-y、M-DELで編集できる。M-p / M-nで履歴をたどれる。
- **FR-M02 補完候補**：候補を縦に一覧表示する。部分一致とflex一致で絞り込む。find-fileでパスを補完する（D10）。
- **FR-M03 ヘルプ**：describe-key（C-h k）、describe-command（C-h x）、describe-bindings（C-h b）、describe-mode（C-h m）を用意する。結果は`*Help*`バッファに出す。
- **FR-M04 メッセージ履歴**：ミニバッファに出したメッセージを`*Messages*`バッファに残す。

### 5.9 FR-G 言語サポート

FR-G01〜G04はmandatory、FR-G05はoptionalである。

- **FR-G01 モードの追加**：`.asd`をCommon Lispモードに対応づける。JS、JSX、MJS、CJS、HTML、CSS、YAMLのモードを追加する。
- **FR-G02 インデント**：RETで自動インデントする。TABで現在行をインデントし直す。C-M-\でリージョンをインデントする。対象はCommon Lisp、Emacs Lisp、Nix、TS / JS、JSON、Markdown / Org（リスト項目の継続）、shellである。規則は言語ごとにLispで書く。Markdown / Orgはkitが返すASTを根拠にする（D8）。
- **FR-G03 コメント**：M-;をcomment-dwimにし、リージョンにも効かせる。Markdownのコメントは`<!-- -->`にする（D9）。
- **FR-G04 括弧の自動補完**：括弧を自動で閉じる。対象はコード系のモードである。Lisp系では、閉じ括弧の上で`)`を打つと挿入せずに読み飛ばす。
- **FR-G05 Org / Markdownのアウトライン**：見出し間の移動、TAB / S-TABによる見出し単位の折りたたみ、OrgのTODO切り替えを用意する。作者がoptionalと指定した。実装する場合は自前の解析を書かず、cl-markdown-kitとcl-org-kitを使う。行の可視性はlang-markupのslice-stateが持ち、レンダラーはフック経由でそれを受け取る。

### 5.10 FR-C クリップボード、ペースト、マウス

FR-Cはすべてmandatoryである。

- **FR-C01 コピー**：killした内容をOSC 52でシステムのクリップボードにも送る。ローカルでpbcopyかwl-copyが使えるなら併用する。`clipboard-yank`はpbpasteかwl-pasteを使う（D11）。
- **FR-C02 ペースト**：ブラケットペーストを有効にする。貼り付けた内容はリテラルとして挿入し、自動インデントしない。undo 1回で取り消せる（D6）。
- **FR-C03 マウス**：SGR 1006を使う。クリックでpointを移動し、ウィンドウを選択する。ホイールでスクロールする。ドラッグでリージョンを選択する。file-treeの項目をクリックすると開く（D4）。

### 5.11 FR-L LSP

FR-Lはすべてmandatoryである。

- **FR-L01 セッション**：プロジェクトと言語の組ごとにセッションを持つ。信頼済みの`.loom-lsp`があれば自動で起動する。didSaveとdidCloseを送る。
- **FR-L02 機能**：hover、references（一覧バッファ）、rename、formattingを使える。診断を行内に表示し、FR-S03の仕組みで次と前の診断へ移動できる。
- **FR-L03 languageId**：major modeの`:language-id`を使う。拡張子をそのまま使う`%lsp-language-id`の粗さを解消する。

### 5.12 FR-V 検証

FR-Vはすべてmandatoryである。

- **FR-V01 導線台帳**：各スライスの`t/paths.sexp`に導線を列挙する。導線の定義は第7章にある。
- **FR-V02 生成規則による網羅**：`--dump-catalog`の出力と導線台帳から、必要な導線の集合を機械的に作る。導線台帳にない組み合わせが1つでもあれば、E2E全体を失敗させる。
- **FR-V03 実行と効果の証明**：コマンドが実行されたことはバイナリ側のコマンドトレース（`LOOM_TRACE_COMMANDS`で出力先を指定）で示す。効果があったことはハーネスが記録した観測で示す。どちらかが欠けた導線はカバー済みに数えない。宣言だけで実行していない導線と、終了コードしか見ない導線は失敗にする。
- **FR-V04 実物で動かす**：外部ツールはすべて実物を使う（git、sh、nixfmt、prettier、nixd、typescript-language-server）。失敗の導線では、PATHにない、非ゼロで終わる、サーバをkill -9する、の3つを実際に起こして確かめる。
- **FR-V05 迂回しているテストの修正**：undoの2回押し、goto-lineの後のC-v、`probe_command`による5件、assertionのないテスト、`%run-loom`のテストがstdoutに出力しHOMEを隔離していない件を直す。付録C.1の後半にある弱いassertion（yank、auto-save、toggle-truncate-lines、new-workspace、git-status、file-treeの開き直し）も、各スライスのレーンが直す。
- **FR-V06 実行環境**：CIのLinuxとaarch64-darwinの両方でE2Eを全件実行し、結果を検証台帳（`docs/src/notes/verification-ledger.md`）に記録する。
- **FR-V07 手動チェックリスト**：自動化できない項目だけに絞って作り直す。対象はIMEの変換、実際の端末エミュレータでのOSC 52・マウス・ブラケットペースト、使い心地である。作者が一巡して記入するまで、リリースの合格にしない。

## 6. 非機能要件

| ID | 目標 | 測り方 |
|---|---|---|
| NFR-01 | 100,000行 / 5MBのファイルを1.0秒以内に開く。キー入力から再描画までのp95を50ms以内にする | PTYベンチマークをE2Eのgateにする |
| NFR-02 | 起動から最初の画面まで0.3秒以内（調査時点の中央値は0.11秒） | 同上 |
| NFR-03 | 1シナリオを10秒以内に終える。固定のsleepは使わない | 既存のdeadline機構 |
| NFR-04 | 境界テストのallowlistを0件にする | FR-A01 |
| NFR-05 | カバレッジ（expressionsとbranches）を調査時点の基線から下げない | `loom-coverage`。基線は`docs/src/notes/coverage-exclusion-ledger.md` |
| NFR-06 | すべてのテストを仮のHOMEで動かし、作者の`~/.loom`を読まない | テスト側で検査する |

## 7. 導線台帳

### 7.1 導線の定義

導線は「入口 × 前提状態 × 結末 × 必要な観測」の組である。

- **入口**：キー（実端末が送るバイト列）、M-x、ミニバッファ、CLI引数、外部ツールからの起動、マウス、ペースト、シグナル。
- **前提状態**：読み取り専用、ナロー中、リージョンの有無、分割ウィンドウ、全角や結合文字や絵文字を含む行、長い行（折り返しと切り詰め）、大きなファイル、マクロ記録中など。
- **結末**：確定、キャンセル（C-g）、空入力、不正入力、外部ツールの失敗など。
- **観測**：画面の文字、画面の属性（色）、カーソル位置、ファイルのバイト列、外部状態（gitのindex、プロセス、終了コード）。

### 7.2 生成規則

4.4のメタデータから、必要な導線を次の規則で生成する。

| 規則 | 対象 | 必要な導線 |
|---|---|---|
| R1 入口 | 全コマンド | 各キーで1本、M-xで1本 |
| R2 プロンプト | `:prompts`を持つコマンド | 確定、C-g、空入力、不正入力（入力に制約がある場合）、TAB補完、M-p履歴 |
| R3 変更 | `:mutates`を持つコマンド | 効果、undo 1回で元に戻る、読み取り専用バッファでは拒否してバイト列を変えない、ナロー中は範囲外に触れない、分割ウィンドウの両方に反映する、マクロで再生しても同じ効果、`C-u 4`を付けたときの効果（前置引数を使うコマンドはspecの定める意味どおり、使わないコマンドは付けないときと同じ） |
| R4 リージョン | `:needs-region`を持つコマンド | リージョンがある場合とない場合 |
| R5 外部ツール | `:external`を持つコマンド | 成功、ツールが見つからない、非ゼロ終了、途中で落ちる |
| R6 横断 | 次元ごと | 全角、結合文字、絵文字、折り返しと切り詰め、リサイズはW3-4、マウスとペーストはW3-8、C-zと各シグナルはW3-2が持つ。各次元で、移動、挿入、削除、undo、保存の5操作を1本ずつ通す |
| R7 `$EDITOR` | 全体 | `git commit`、`git rebase -i`、crontab型、`xargs`経由（stdinがttyでない）、`+N`、新規ファイル、中断 |
| R8 永続化 | 全体 | セッションを保存してプロセスを終了し、新しいプロセスで読み込む。分割ウィンドウ、ワークスペース、履歴を含む |

### 7.3 合格条件

導線は次の4つをすべて満たしたときに限り合格とする。

1. `.#default`の実バイナリを実PTYで起動している。
2. コマンドトレースに対象コマンドの実行が記録されている。
3. ハーネスが効果の観測（画面、属性、カーソル、ファイルのバイト列、外部状態のいずれか）を1つ以上記録している。
4. 観測した値が期待値と一致している。

終了コードだけを見るシナリオは不合格とする。
生成した導線のうち、導線台帳にないもの、トレースがないもの、観測がないものが1つでもあれば、E2E全体を失敗させる。
導線を導線台帳から除外する場合は、理由と、その組み合わせを成り立たなくしているコードのfile:lineを必須にする。
「理論上ありえない組み合わせ」も、同じ形の除外として導線台帳に残す。

### 7.4 導線台帳とトレースの形式

導線台帳は各スライスの`t/paths.sexp`で、1つの導線を1つのplistで書く。
キーは`:id`（スライス内で一意の文字列）、`:commands`、`:rule`（`:r1`〜`:r8`）、`:entry`、`:state`、`:outcome`、`:observe`（観測の種類のリスト）、`:scenario`（E2Eシナリオ名）である。
除外は`(:exclude :id ... :reason ... :evidence "file:line")`と書く。
W0-4はこのキーを変えずに読み書きを実装し、キーを足す場合は空の既定値を持たせる。

コマンドトレースは、`LOOM_TRACE_COMMANDS`に指定したファイルへ、実行したコマンド1件につき1行のJSONを追記する。
各行は少なくとも`command`（コマンド名）、`route`（`key`、`mx`、`mouse`など）、`seq`（通し番号）を持つ。

### 7.5 導線の担当

各レーンは、自分のスライスが所有するコマンドについて、R1〜R5の導線を持つ。
キーマップの仕組みと参照表のテストはW3-1、ミニバッファの編集、補完、履歴の仕組みはW3-5が持つ。
R6の担当は7.2の表のとおりで、R7はW3-2、R8はW3-10が持つ。

## 8. 技術判断

| 判断 | 理由 | 却下した案 |
|---|---|---|
| スライスごとに`.asd`を置き、cl-nix-forgeの`packageArgs`で`lispAsdPath`に`packages//`を渡す | 並列作業で`loom.asd`を取り合わずに済む。cl-nix-forge v0.5.0は`lispAsdPath`を持つ（静的）。`//`による再帰探索が使えるかは推定で、W2bの最初に確かめる | `loom.asd`の中に二次システムを並べる案。共有ファイルが残る |
| 保存はその場上書きのまま、上書きの前に`~/.loom/backups/`へ退避する | inodeとリンクの保持は`$EDITOR`互換として実機で合格済み。退避先をHOMEにすれば作業ディレクトリを汚さない | 一時ファイルとrenameによる保存（inodeが変わる）。`file~`形式のバックアップ（作業ディレクトリを汚す） |
| C-sをリテラル検索にする | Emacs標準に置き換える決定に従う。Lispのソースで`(`を検索できる | 正規表現検索のまま維持する案 |
| 中断コマンドはM-xからのみ呼ぶ | Emacsに対応するキーがない | キーを新しく割り当てる案 |
| 導線台帳はS式で書く | Lisp側（カタログとの照合）とPython側（E2E）の両方で読む。Python側には小さなリーダーを書く | TOML。Lisp側にパーサーの依存が増える |
| 導線の網羅はメタデータから生成する | 手で列挙すると漏れる。前回の検証がその例である | シナリオ側の自己申告（前回の方式） |
| Markdown / Orgの解析はcl-markdown-kitとcl-org-kitに任せる | 作者の指定による。CommonMark 0.31.2の全例とGFMのfixtureに一致し、source spanを持つ | 言語ごとに手書きする方式。他の言語では採用するが、この2言語では二重実装になる |
| kitを取り込むため依存を上げる。cl-codec-kitをv0.5.0からv0.6.0へ、cl-regex-kitをv2.0.0からv2.1.1へ、cl-date-kitをv1.0.0からv1.1.1へ | 両kitの`flake.nix`がこれらの版を固定している | 古い版のままkitを読み込む案。ASDFで版が衝突する |

## 9. 制約

- コミットの担当はオーケストレータが決める。担当でないレーンはコミットしない。この仕様を書いたワークツリーには`.jj/`がなかった。
- Claude CodeのBashツール配下では`asdf:operate`が停止する。in-processのスイートは`launchctl submit`経由で実行する。手順は、`nix develop --command sbcl --script run-tests.lisp`を実行してexit statusをファイルに書くスクリプトを作り、`launchctl submit -l <ラベル> -o <出力> -e <エラー> -- <スクリプト>`で起動し、結果を読んだら`launchctl remove <ラベル>`で必ず消す、である。消さないとlaunchdがジョブを繰り返し起動する。HOMEとPATHはスクリプトの中で明示する。PTY E2Eはダンプ済みのバイナリを使うので影響を受けない。
- gitが追跡していないファイルはflakeから見えない。新しいファイルをflakeのgateで確かめる前に、コミットの担当に追跡対象にするよう依頼する。`flake.nix`の`sourceRoot`は`.py`を除外するので、E2EのPythonは`self`経由で参照する。
- IMEはPTYで再現できないため、FR-V07の手動確認だけで扱う。
- セッション形式はv5のまま変えない。移設でcodecの形が変わる場合は、v5の互換性テストで退行を検出する。
- cl-codec-kitは1.0未満の版なので、v0.6.0で互換性のない変更があるかはW0-6でスイートを回すまで分からない（推定）。

## 10. 未解決事項

利用者の判断を待つ事項はなし。
調査が要る事項は、D2の原因（W3-1）とcl-codec-kit v0.6.0の互換性（W0-6）の2つで、それぞれのタスクで解消する。

## 11. タスク分解

### 11.1 進め方

W0、W1、W2は共有ファイルに集中して触るため、1人の担当者が直列に進める。
W2が終わると、各レーンは自分のスライスのディレクトリだけを書き換える状態になり、W3を並列に進められる。
W4はW3の全レーンが終わってから1人の担当者が行う。

W3を並列にするため、W0〜W2の段階で次の3つを済ませておく。

- W0-6で、E2Eが使う外部ツールをすべて`apps.e2e`に入れておく。W3のレーンは`flake.nix`に触れない。
- W2bで、W3が使う全スライスの雛形（`.asd`、`package.lisp`、空の`t/paths.sexp`）を作り、ルートの`loom.asd`に登録しておく。W3のレーンは`loom.asd`に触れない。
- W2aで、4.3の6種類のフックをすべて用意しておく。W3のレーンは合成ルートに触れない。

E2Eハーネス（`t/e2e/loom_e2e/`）はW0で固め、W3では変更しない。
W3でハーネスの変更、他レーンが専有するexportの追加、共有ファイルの変更が必要になったら、そのレーンはその作業を止め、必要なAPIかファイルと理由をセッションの出力で報告する。オーケストレータがそれを直列の枠で処理する。止めた作業に依存しない作業は続けてよい。

### 11.2 共有ファイルの担当

| 共有ファイル | 直列に触る担当 | W3での扱い |
|---|---|---|
| `flake.nix`、`flake.lock` | W0-6、W2b | 変更しない |
| `loom.asd`（ルート） | W0-3、W1、W2a〜W2d | 変更しない |
| `src/package*.lisp`、`src/package-exports.lisp` | W0-3、W1、W2a〜W2c | 変更しない |
| `packages/core/*/package.lisp`とcoreのexport | W1、W2a。W3ではcore/commandをW3-1、core/bufferをW3-4、core/minibufferをW3-5が持つ。core/window-treeとcore/editor-sessionはW2の後に固め、W3では変更しない | 他のレーンはexportを追加せず、必要なAPIを担当レーンに依頼する |
| `src/application/command-definitions*.lisp` | W0-3（メタデータ付与）、W2a（各スライスへ移したあと削除） | 存在しない |
| キーマップの登録 | 各スライスが自分のファイルで登録する。Emacs既定の参照表はW3-1が持つ | 衝突は登録時のエラーとテストで検出する |
| `src/`の起動、イベントループ、入力ルーティング | W0-3、W1、W2a | 変更しない。フック経由で拡張する |
| `src/infrastructure/terminal-renderer*.lisp`、`src/presentation/` | W1、W2c。W3ではW3-4が専有する | 他のレーンは描画フックを使う |
| `t/e2e/loom_e2e/`、`t/e2e/loom-test.py` | W0-2、W0-4 | 変更しない |
| `t/package.lisp`とルートの`loom/test`の部品一覧 | W0-7、W2c | 変更しない |
| `t/unit/dependency-contract-test.lisp` | W0-5、W2b | 変更しない |
| `packages/feature/README.md`、`packages/README.md` | W2b | 変更しない |
| `docs/src/reference/`、`docs/src/project/`、`README.md` | W4 | 変更しない |
| `.github/workflows/` | W0-2（E2Eの起動方法が変わる場合のみ）、W4 | 変更しない |
| `docs/src/notes/verification-ledger.md`、`docs/src/notes/daily-driver-checklist.md` | W0-1、W4 | 変更しない |

### 11.3 W0 基線と検証基盤

W0は直列に進める。W0-4はW0-3に依存する。

| ID | 内容 | 対象ファイル | 共有ファイル | 依存 | 完了条件 |
|---|---|---|---|---|---|
| W0-1 | 基線の記録。in-processスイート、`nix flake check`、全E2E、第2章の実機観測を再実行して記録する | `docs/src/notes/verification-ledger.md` | 検証台帳 | なし | 各コマンドとexit statusが検証台帳にある |
| W0-2 | ハーネスの強化。RETをCRで送る、リサイズAPI（SIGWINCH）、画面属性の読み取り、生バイトの記録、観測の記録、端末プロファイル、NFR-01とNFR-02を測るPTYベンチマーク（報告モード） | `t/e2e/loom_e2e/` | ハーネス、必要ならCI | W0-1 | 既存シナリオが新ハーネスで動き、結果の差分が記録される |
| W0-3 | `--dump-catalog`、`LOOM_TRACE_COMMANDS`、コマンドspecへのメタデータ付与（4.4） | `src/application/startup-cli.lisp`、`src/application/command-definitions*.lisp`、登録系 | ルートのLisp、`loom.asd` | W0-1 | 全コマンドのメタデータがJSONに出る。トレースが実行したコマンドを記録する |
| W0-4 | 導線生成器、導線台帳のリーダー（7.4）、網羅レポート（報告モード） | `t/e2e/` | ハーネス | W0-2、W0-3 | 現状の不足導線の一覧が出力され、検証台帳に記録される |
| W0-5 | 境界テスト（報告モード） | `t/unit/`の新規ファイル | `loom.asd`の`loom/test` | W0-1 | 現状の違反一覧が出力される |
| W0-6 | 依存の更新（cl-codec-kit、cl-regex-kit、cl-date-kit）と、E2Eが使う外部ツール（git、nixfmt、prettier、nixd、typescript-language-server）の`apps.e2e`への追加 | `flake.nix`、`flake.lock` | `flake.nix` | W0-1 | 更新後に既存スイートとE2Eが全件通る |
| W0-7 | ルートのテストの衛生。assertionのないテストを直す。`%run-loom`のテストの出力先とHOMEを隔離する | `t/integration/main-*.lisp` | ルートのテスト | W0-1 | 該当テストが失敗しうる形になり、通る |

### 11.4 W1 循環の解消

| ID | 内容 | 対象ファイル | 共有ファイル | 依存 | 完了条件 |
|---|---|---|---|---|---|
| W1 | coreをbuffer、window-tree、command、minibuffer、editor-sessionに分ける。slice-state表を入れる。`::`参照の3か所をexportしたAPIに置き換える。workspaceとkeyboard-macroの既定値を注入方式にする | `packages/core/`、`src/application/editor-state*.lisp`、`src/application/commands-internal.lisp`、`src/application/startup-state.lisp`、`packages/feature/window/` | ほぼすべて | W0 | C1〜C4の循環が0件。既存スイートとE2Eが全件通る |

### 11.5 W2 自己登録とスライスの分割

W2は直列に進める。どの段階でも、既存スイートとE2Eは全件通る状態を保つ。

| ID | 内容 | 対象ファイル | 共有ファイル | 依存 | 完了条件 |
|---|---|---|---|---|---|
| W2a | コマンド登録APIとフック（4.3、4.4）を入れる。120件のspecを各スライスへ一括で移し、中央のカタログを削除する。カタログ系のテストを`--dump-catalog`基準に直す | 登録系、全スライスのapplicationファイル、`src/application/command-definitions*.lisp` | 全スライス | W1 | 登録の重複とキー衝突がエラーになる。カタログの内容が移行前と一致する |
| W2b | スライスごとの`.asd`と`lispAsdPath`を入れる。最初に`//`の再帰探索を確かめる。W3が使う全スライスの雛形を作る。依存契約テストを全スライスの和集合で比べる。lang-markupの`.asd`にkitを宣言する | `flake.nix`、`loom.asd`、`packages/**/*.asd`、`t/unit/dependency-contract-test.lisp`、`run-tests.lisp`、`scripts/coverage.lisp` | `flake.nix`、`loom.asd` | W2a | `nix flake check`、dev shellでの実行、ダンプしたバイナリがすべて新構成で動く |
| W2c | 4.2の移設（FR-A05）とテストの同居。振る舞いは変えない | `src/`、`packages/`、`t/` | ほぼすべて | W2b | 移設前と同じテストが同じ結果で通る。テストがスライスの`t/`にある |
| W2d | 境界テストを失敗モードに切り替える | `t/unit/`の境界テスト、各スライスのallowlist | なし | W2c | 残りの違反が各スライスのallowlistに載り、それ以外では失敗する |

### 11.6 W3 並列レーン

各レーンは自分のスライスのコード、テスト、導線台帳（`t/paths.sexp`）だけを書き換える。
第2章の欠陥を再現するときは、`.#default`をビルドし、`t/e2e/loom_e2e/`のハーネスで自分のスライスのE2Eシナリオとして書く。
optionalの要件（FR-D04、FR-G05）は完了条件に含めない。
各レーンの完了条件には共通して次の3つが含まれる。
7.5で自分が持つ導線が導線台帳にあり、7.3の条件で合格していること。
FR-V05のうち自分のスライスに属する迂回を直していること。
境界テストのallowlistから自分の行を消していること。

| ID | 担当スライス | 要件 | 共有ファイルとの関係 | 依存 | 完了条件（共通条件に加えて） |
|---|---|---|---|---|---|
| W3-1 | core/command | FR-K01〜K03、FR-B01（D2の原因調査を含む） | core/commandのexportを専有。Emacs既定の参照表を持つ。D2の原因がcore/bufferにあれば、その変更はW3-4に依頼する。FR-K02のうち各スライスのキーの移動は、そのスライスのレーンが行う | W2 | 参照表のテストが通る。D1、D2、D4が再現しない |
| W3-2 | lifecycle、user-init | FR-E01〜E06 | 端末モードは4.3のフックで要求する | W2 | R7とR6（シグナル、C-z）の全導線 |
| W3-3 | files、buffers | FR-F01〜F04 | なし | W2 | R2、R3、R5のうちファイル操作の導線。D5、D11（保存）、D14、D16が再現しない |
| W3-4 | core/buffer、レンダラー、`src/presentation/` | FR-B02、FR-B03、FR-D01〜D04 | core/bufferのexportとレンダラーを専有。他レーンの描画要求はフックで受ける | W2 | NFR-01とR6の表示の導線。D3、D7、D13が再現しない |
| W3-5 | core/minibuffer、minibuffer-ui、completion、help | FR-M01〜M04 | core/minibufferのexportを専有 | W2 | ミニバッファの編集、補完、履歴の導線。D10が再現しない |
| W3-6 | search、project | FR-S01〜S03 | 一覧バッファと`next-error`の仕組みを提供する。W3-9が利用する | W2 | 共通条件のみ |
| W3-7a | mode、syntax-highlighting | インデントとハイライトのプロトコル、FR-G03の枠組み、FR-G04の枠組み。各言語の定義を言語スライスへ移す | 最初に各言語の定義を言語スライスへ移す。移し終えたら言語スライスには触れず、W3-7b〜eが着手できる | W2 | プロトコルのテストが通る。全言語の定義が言語スライスにある |
| W3-7b | lang-lisp、lisp-structure、evaluation | Common Lisp / Emacs LispのFR-G01〜G04、S式移動と構造編集、FR-K02の構造編集キー、FR-K01の`C-x C-e`（eval-last-sexp） | なし | W3-7a | Lisp系の全導線 |
| W3-7c | lang-nix | NixのFR-G01〜G04 | なし | W3-7a | Nixの全導線。D8（Nix）が再現しない |
| W3-7d | lang-web | TS / JS / JSX / JSON / HTML / CSS / YAMLのFR-G01〜G04 | なし | W3-7a | 各言語の導線 |
| W3-7e | lang-markup | kitのASTを使うMarkdown / OrgのFR-D03、FR-G02、FR-G03（mandatory）。FR-G05（optional）。FR-G01とFR-G04は対象外 | なし | W3-7a | Markdown / Orgの導線。D9が再現しない |
| W3-8 | kill-ring、clipboard、mouse | FR-C01〜C03 | 端末モードとキー以外の入力イベントは4.3のフックで扱う。マウスで操作するウィンドウとfile-treeは公開APIだけを使う | W2、W3-1 | R6のマウスとペーストの導線。D4、D6、D11（OSC 52）が再現しない |
| W3-9 | lsp | FR-L01〜L03 | 一覧と移動はW3-6の仕組みを使う | W2、W3-6 | 実サーバ（nixd、typescript-language-server）によるR5の全導線 |
| W3-10 | file-tree、window、workspace、session、bookmark、register、keyboard-macro | FR-K02のfile-tree、ブックマーク、load-sessionの割り当て、R8（プロセス再起動後の復元） | file-treeのローカルキーマップはW3-1の仕組みを使う | W2、W3-1 | 各スライスの全導線とR8 |
| W3-11 | shell、format、git、terminal、auto-save | 既存コマンドの導線検証と、その導線で見つかった不具合の修正 | なし | W2 | 実物による成功と失敗の導線（R5）。terminalの外部ツールは子プロセスの`/bin/sh`、auto-saveの失敗は書き込めないディレクトリで起こす |

### 11.7 W4 統合

| ID | 内容 | 対象ファイル | 依存 | 完了条件 |
|---|---|---|---|---|
| W4-1 | 導線の網羅gateを失敗モードに切り替える | `t/e2e/` | W3全件 | 全導線が7.3の条件で合格する |
| W4-2 | CIのLinuxとaarch64-darwinで全件を実行し、性能gate（NFR-01、NFR-02）を入れる | `.github/workflows/`、`docs/src/notes/verification-ledger.md` | W4-1 | 両環境の結果が検証台帳に記録される |
| W4-3 | ドキュメントを作り直す。README、`docs/src/reference/`、`docs/src/project/`、パッケージのREADME。手動チェックリストをFR-V07の範囲で作り直す。cold-readを通す | `README.md`、`docs/` | W4-1 | `nix build .#docs`がexit 0。cold-readの指摘が解消している |
| W4-4 | 作者による手動確認の一巡 | `docs/src/notes/daily-driver-checklist.md` | W4-3 | 全行に作者の結果が記入されている |

### 11.8 実装時に前提にしてはいけないこと

- 既存のE2Eが通ることを、機能が正しい証拠として扱わない。D2とD3が前例である。
- `docs/src/notes/verification-plan.md`と`docs/src/notes/verification-ledger.md`にある「120/120」を、網羅の証拠として扱わない。
- `lispAsdPath`の`//`による再帰探索が使えることは、W2bで確かめるまで前提にしない。
- 付録の件数や行番号は調査時点の値である。着手時に現在のツリーで確かめる。

## 付録A 機能の棚卸し（静的）

ソースを読んで判定した。付録Bと第2章で実機確認した項目は、そちらを優先する。

### A.1 状態の一覧

| 機能 | 状態 | 根拠 |
|---|---|---|
| undo / redo | 部分的 | 変更グループはコマンドの種類が変わったときだけ区切られる（`input-routing-command-state.lisp`）。redoは線形で、新しい編集で消える |
| 正規表現検索 | あり | isearch、search-forward、replace-stringはすべて入力を正規表現として扱う（`domain-buffer-search.lisp`）。リテラル検索はない |
| query-replace | なし | `replace-string`は確認なしにバッファ全体を置換し、キャプチャグループを展開しない |
| occur、プロジェクト検索 | なし / 部分的 | `project-search`は結果を1行のメッセージで返し、結果へ移動できない。検索中はエディタが止まる |
| 行番号 | なし | |
| モードラインの行と列 | あり | `layout-windows.lisp` |
| リージョンの強調、括弧の対応表示 | あり | `layout-windows.lisp` |
| RETでの自動インデント | なし | `%insert-newlines`は改行を入れるだけ |
| TABでのインデント | 部分的 | point位置に次のインデント幅の倍数まで空白を入れる。行やリージョンのインデントし直しはない |
| 括弧の自動補完 | なし | |
| コメントの切り替え | 部分的 | 現在行だけが対象。リージョンには効かない |
| システムのクリップボード | なし | |
| ブラケットペースト、マウス | なし | cl-tty-kitは`bracketed-paste`と`mouse`のオプションを持つが、loomは`:raw-mode :alternate-screen :hide-cursor`だけを渡す（`startup-services.lisp`） |
| C-z、SIGHUP、SIGTERM | なし | |
| エンコーディング、改行コード | 部分的 | UTF-8固定で読む。CRとBOMをバッファの文字として扱う |
| 末尾改行の付与、行末の空白の削除 | なし | 末尾改行の有無は保存後もそのまま残る（付録B） |
| 保存方法 | その場上書き | O_TRUNCで書く。原子的ではない（推定） |
| バックアップ、外部変更検出、revert | なし | |
| 存在しないファイル（C-x C-f経由） | あり | 空のバッファで開き、保存時に作る。CLI引数からは開けない（D14） |
| 読み取り専用のファイル | あり | 読み取り専用で開く |
| 同じファイルの二重オープン | 不具合 | `find-file`が毎回`buffer-load`を呼ぶ（D5） |
| 同名バッファの区別 | 不具合 | バッファ名はファイル名だけで、`switch-to-buffer`は最初に一致したものを選ぶ |
| 大きなファイル | 遅い | `buffer-visible-line`が描画する行ごとに全文を組み直す。括弧の対応表示も毎フレームで全文を走査する |
| find-fileのパス補完 | なし | プロンプトに補完関数がない |
| 補完の絞り込み | 前方一致のみ | 候補一覧を表示しない |
| ミニバッファの編集 | 最小限 | 文字入力、Backspace、↑↓、TAB、RET、C-gだけ |
| Unicodeの幅 | 部分的 | 全文字を1セルか2セルで描く。TABは幅1 |
| kill ringとyank-pop、レジスタ、ブックマーク、キーボードマクロ | あり | |
| describe-key、describe-command | なし | C-hはヘルプ文を1行にまとめて表示する |
| ユーザー設定 | 部分的 | init.lispで`define-command`、`bind-key`、`register-major-mode`を使える。tab-widthなどの設定項目はない |
| 構文ハイライト | 行単位 | 複数行の文字列やコメントを追跡しない。Markdownの見出しをコメントの色で描く |
| LSP | 部分的 | 単一の手動セッション。didOpen、didChange、補完、定義、診断だけ |

### A.2 キーの割り当て

調査時点で、メイン画面には矢印、Home、End、PgUp、PgDn、Delete、C-/、C-_、C-l、C-t、M-u、M-l、M-c、M-q、C-M-\、C-z、M-^が割り当てられていない。
特殊キーの割り当ては`C-<left>`と`C-<right>`だけである。
矢印キーはミニバッファと補完ポップアップの中でしか処理されない。

### A.3 major mode

登録済みのモードはfundamental、common-lisp、python、rust、shell、emacs-lisp、nix、typescript、typescript-react、markdown、org、json、textである。
モードが提供するのは、行コメントの接頭辞、インデント幅、キーワード一覧、折り返しの既定、LSPのlanguage idで、インデント関数とブロックコメントの構文はない。
`.asd`、`.js`、`.jsx`、`.mjs`はどのモードにも対応づけられていない。
Markdownの行コメント接頭辞は`#`になっている。

## 付録B `$EDITOR`の実機プローブ

一時的な作業ディレクトリとスクラッチのgitリポジトリで、毎回新しいHOMEを使って実行した。
端末は80x24、TERMは`xterm-256color`、LANGは`en_US.UTF-8`である（明記した場合を除く）。

| 項目 | 観測 | 判定 |
|---|---|---|
| 既存ファイルを開く | 編集、保存、終了でexit 0 | 合格 |
| 存在しないファイル | exit 64、`PATH does not exist` | 不合格（`src/application/startup-state.lisp`） |
| `+12 FILE`、`+12:5 FILE` | exit 64、`Unexpected positional argument` | 不合格（`src/application/startup-cli.lisp`） |
| 複数ファイル | exit 64 | 不合格（同上） |
| `-- -dashfile` | 開ける | 合格 |
| 空白を含むパス | 開ける | 合格 |
| シンボリックリンク | 開ける。バッファ名はリンク先の名前になる | 合格 |
| stdinがパイプ | exit 1。fd 0をrawモードにできない | 不合格（`src/application/startup.lisp`、`startup-services.lisp`） |
| stdoutがファイル | 起動するが、描画がファイルへ流れる | 警告 |
| `GIT_EDITOR=loom git commit` | 保存して終了するとコミットされる。`#`行、LF、末尾改行を保持し、CRを入れない | 合格 |
| 変更せずに終了 | gitが空メッセージで中断する | 合格 |
| 保存確認でdを選ぶ | 保存されず、gitが中断する | 合格 |
| `git rebase -i` | pickをdropに変えて保存すると反映される | 合格 |
| crontab型のフロー | 終了までブロックし、同じinodeとmodeで書き戻す | 合格 |
| 非ゼロで中断する手段 | 専用のコマンドもキーもない。M-:で`(sb-ext:exit :code 3)`を評価すればexit 3になるが、未保存の確認を通らない | 不合格（`src/application/commands-quit.lisp`） |
| 保存方式 | `O_WRONLY|O_CREAT|O_TRUNC`で同じinodeに書く | 合格（原子的ではない、推定） |
| mode 600 / 755、シンボリックリンク、ハードリンク | すべて保持 | 合格 |
| サイドカーファイル | 作られない（auto-saveは既定で無効） | 合格 |
| 読み取り専用のファイル（444） | `Buffer ro.txt is read-only`を表示し、内容は変わらない | 合格 |
| 最初の画面までの時間 | 5回の中央値0.109秒 | 合格 |
| init.lispのエラー | exit 1で起動しない | 不合格（`src/application/startup-services.lisp`、`packages/feature/user-init/src/infrastructure-user-init.lisp`） |
| TERMが`dumb`か未設定 | xterm系のエスケープを出したまま動く | 不合格（軽微） |
| 20x5、1x1の端末 | 起動し、保存と終了ができる | 合格 |
| LANG=C | UTF-8のまま表示と保存ができる | 合格 |
| 通常の終了 | 代替画面を抜け、icanonとechoが戻る | 合格 |
| SIGTERM | 端末は戻るがexit 0 | 不合格 |
| SIGHUP | exit 129だが、端末がrawのまま残る | 不合格（軽微） |
| 内部エラー | 端末を戻し、ログを出してexit 1 | 合格 |
| C-z | 何も起きない | 不合格 |
| 外部からのSIGTSTPとfg | fgの後に再描画せず、rawモードにも戻らない | 不合格 |
| 変更のあるバッファで終了 | `Save X? (s/d/c):`を表示する | 合格 |
| CRLF | `ab\r\ncd\r\n`でC-eの後にZを入れると`ab\rZ\ncd\r\n`になる | 不合格 |
| BOM | 保持する | 合格 |
| 不正なUTF-8、latin-1 | 画面が出ないままexit 70 | 不合格（`packages/feature/file-tree/src/infrastructure-filesystem-native-io.lisp`） |
| 末尾改行なし | 改行を足さない | 合格 |
| NUL、TAB | バイト列を保持する | 合格 |


## 付録C 導線網羅の監査

ソースを読んで判定した。

### C.1 E2Eシナリオのassertionの強さ

| 強さ | 主なシナリオ |
|---|---|
| 終了コードのみ | `macros/eval-buffer`、`macros/eval-expression`、`ui/keyboard-quit`、`movement/splice-sexp`、`editing/backward-kill-word`、`startup directory`（コマンドではない起動のシナリオ）。`ui/help`と`ui/toggle-truncate-lines`などのprobeもあるが、別のシナリオがより強く検証している |
| 画面の文字 | CLI引数、ヘルプ、プロジェクト、スクロール、ナロー、ウィンドウ、ワークスペース、ブックマーク、git、pipe-command、terminal、LSPの各シナリオ |
| カーソル位置 | 移動系、レジスタ、LSPの定義ジャンプ、全角、横スクロール、折り返し |
| ファイルのバイト列 | 編集系、構造編集、保存、マクロ、前置引数、major mode、format、LSP補完 |
| 外部状態 | git-stage / unstage（index）、LSPの信頼確認とプロセス、file-treeのファイル操作、HOMEの隔離 |

画面やファイルを見ていても、効果がなくても通るassertionがある。
`editing/yank`は、killとyankがどちらも何もしなくても通る。
auto-save系の2シナリオは、`auto-save-current-buffer`を明示的に呼んでおり、モード自体の効果を見ていない。
`toggle-truncate-lines`はメッセージだけを見て、描画を見ていない。
`new-workspace`の確認は、コマンドが何もしなくても成り立つ。
`git-status`は`##`の出現だけを待つ。
file-treeのシナリオはツリーを閉じて開き直して更新を強制しており、自動更新の不具合を隠す。

### C.2 一度も押されていないキー

C-b、C-p、M-b、M->、C-v、M-v、C-k、M-d、M-DEL、M-;、C-x C-x、M-:、C-x C-e、C-x r S、C-x r l、C-x r m、C-x r b、C-x r d、C-x r s、C-x r i、C-x r SPC、C-x r j、C-c n、C-c p、C-c o、C-c c、C-c d、C-x 3、C-x o。
C-←、C-→、ESC-DELなどのエスケープシーケンスの復号も、PTY経由では通っていない。

### C.3 横断的な次元

| 次元 | 調査時点の状態 |
|---|---|
| 前置引数C-u | E2Eは自己挿入の`C-u 2 a`だけ |
| プロンプトのキャンセル | in-processでは15コマンド。kill-buffer、set-major-mode、project系、recent-file、レジスタ、pipe、git-stage / unstage、format、eval-expressionにはない |
| 空入力、不正入力 | 部分的 |
| 読み取り専用バッファ | E2Eは自己挿入だけ。変更系コマンドは未検証 |
| ナロー中の編集 | E2Eにない |
| リージョンなし | in-processだけ |
| 分割ウィンドウでの編集 | E2Eにない |
| TAB補完、履歴 | E2Eにない。M-p / M-nの割り当てがない |
| 実行中のリサイズ | ハーネスにAPIがない |
| 全角と絵文字 | 表示、カーソル、挿入、削除はE2Eにある。プロンプト内はin-processだけ |
| 折り返しの切り替え | 描画への効果を見ていない |
| 変更系コマンドの後のundo | E2Eは自己挿入だけ |
| マクロの再生 | 自己挿入だけ |
| セッションの復元 | 同じプロセス内だけ。分割とワークスペースはE2Eにない |
| 外部ツールの失敗 | モックかなし |
| 変更があるときの終了確認 | E2Eにない |
| RETのバイト | E2EはLFを送る |

### C.4 in-processテストの品質

assertionのないテストは`t/integration/main-event-loop-input-test.lisp`の"exits via LOOM-QUIT"だけである。
入力の終わりだけでもループが終わるので、C-x C-cが何もしなくても通る。
gitとフォーマッタの失敗経路は、すべて`with-replaced-function`によるモックで検証されている。

## 付録D DDDとpackage by featureの監査

ソースを読んで判定した。修飾参照は文字列として確認した。`:use`経由の非修飾参照は字句照合による推定である。

### D.1 循環

- **C1**：ルートの`loom`と全スライス。スライスは`loom`を`:use`し、ルートのコードはスライスを修飾参照する（`command-definitions-tooling.lisp`、`event-loop-rendering.lisp`、`layout-windows.lisp`など）。
- **C2**：`loom`と`loom/application`。`loom`は`loom/application`を`:use`し、逆向きの参照もある（`commands-internal.lisp`、`commands-keybindings.lisp`、`commands-prompts.lisp`）。
- **C3**：`loom/application`と`window`。全スライスが使う`%selected-window`と`%selected-buffer`が`window`に依存し、`window`は`loom/application`を`:use`する。
- **C4**：coreと`window`。coreの移動系が`window`を参照し、`window`はcoreのbufferを参照する。`packages/core/README.md`の「featureがcoreに依存する」という説明と逆向きである。

非公開シンボルへの`::`参照は3か所ある（`search`の`application-commands-isearch.lisp`、`lsp`の`application-commands-lsp-support.lisp`）。
スライス同士の辺だけを見ると循環はない。

### D.2 層の違反

- domainからapplication、infrastructure、presentationの関数を呼ぶ箇所は見つからなかった（推定）。
- `terminal-session`構造体がdomainでptyを持つ。
- `lsp-session`はapplication層で定義されている。
- `terminal`のinfrastructureと`file-tree`の`infrastructure-buffer-filesystem.lisp`が`*editor-state*`に触れる。
- coreの`application-commands-movement-visual-lines.lisp`がレンダラーの`loom-renderer-wrap-segments`を呼ぶ。
- ルートのpresentationが、window、lsp、search、file-tree、completion、modeの状態の形に依存する。

### D.3 状態の共有

`editor-state`のスロットのうち、minibufferは23ユニット、window-treeは9ユニットが読む。
sessionは`%register-buffer`を通さずにバッファを登録する。
kill ringと`last-yank-*`はcoreとルートの入力ルーティングが共有する。
ルートは既定値としてスライスのコンストラクタを直接呼ぶ（`startup-state.lisp`など）。
スライスをまたいで使われるスペシャル変数は、`*editor-state*`、`*current-prefix-argument*`、`*command-specs*`、`*loom-filesystem*`、modeのレジストリである。

### D.4 集約と不変条件

bufferの不変条件はcoreのdomainに収まっている。
window treeは生成を制御しているが、`window-leaf`のアクセサがsetf可能で、lspが外部から書き換える。
「状態のwindow-treeは現在のワークスペースの木と同じ」という不変条件を、workspaceとsessionの2スライスが手作業で同期している。
minibufferとfile-treeは操作APIの内側に閉じている。

### D.5 コマンドカタログ

`define-command-spec-catalog`は、全スライスの後にロードされるファイルで、固定した9変数から`*command-specs*`を作り直す。
そのため、スライスがロード時に登録しても上書きされる。
実行時に追加できるのはuser-initだけで、それも`*command-specs*`へ直接appendしている。
E2Eのカバレッジ集計は`src/application/command-definitions*.lisp`を正規表現で読んでおり、specを移すと集計から黙って落ちる。

### D.6 機械的な強制

境界を強制するテストはない。
`t/unit/dependency-contract-test.lisp`は依存の宣言だけを比べ、`t/unit/protocol-test.lisp`はパッケージの存在だけを見る。
`t/package.lisp`は全スライスを`:use`している。
runnerの`(asdf:load-system "loom" :force t)`は指定したシステムしか再コンパイルしないので、スライスを別システムに分けると古いfaslを読む危険がある（推定）。W2bの対象である。
