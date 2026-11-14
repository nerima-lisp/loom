# v0.3〜v0.5 の提案（設計メモ・未着手）

v0.2（[daily-driver-v0.2.md](daily-driver-v0.2.md)）が合格してから着手する。ここにあるのは方向と制約で、
着手するときに WP と同じ粒度の仕様に書き起こす。画面のモックはデザインキャンバスにある。

この文書の ID は v0.3 以降の提案の番号で、v0.2 実行計画書のタスク ID（P1・P2 など）とは別のもの。
表に行のない U1 は、設計キャンバスの項目番号である（この文書群には定義がない）。

## v0.3 見える・迷わない

| ID | 提案 | 要点 | 制約 |
|---|---|---|---|
| U2 | face 表と Dracula | 各 layout の defparameter に散らばった16色の直書きを、名前つきの face 表1つにまとめる。暗い側は Dracula 公式パレット（Background `#282A36`・Current Line `#44475A`・Foreground `#F8F8F2`、Cyan `#8BE9FD`・Green `#50FA7B`・Orange `#FFB86C`・Pink `#FF79C6`・Purple `#BD93F9`・Red `#FF5555`・Yellow `#F1FA8C`・Comment `#6272A4`）。補助ラベルだけ `#B6BBD6` を足す | truecolor → 256色 → 16色 → NO_COLOR に自動で落とす（cl-tty-kit の `rgb-to-256` / `rgb-to-ansi16`）。`:auto` は OSC 11 で背景を問い合わせ |
| P1 | モードライン | 固定順の文字列連結（`%layout-mode-line-parts`）を、スライスが登録する「優先度つきセグメント」に。幅が足りなければ優先度の低いものから落とし、名前は中を詰める。既定値（LF UTF-8 など）は出さない | セグメントの render は I/O 禁止。Git はキャッシュを読むだけ（Q4） |
| P2 | キーヒント | 接頭辞の後 600ms 止まったら、続きのキーをエコー行の上に出す。新スライス `key-hint` | 描画フックだけで出し、キーマップの状態を変えない。速打ちでは一度も描かない |
| P3 / U3 | 補完の注釈とパレット | 一致文字の強調、選択行と件数、右側の注釈（キー・説明・状態）。M-x は中央のパレットに | 注釈はプロンプト種別ごとにスライスが登録。I/O 禁止（Q1） |
| P4 | 行内診断とホバー | ガターの記号（E/W/I/H）、波線（SGR 4:3、無ければ下線）、行末の要約、point 上で全文、最大10行のホバー枠 | 補完ポップアップと同じ描画レーン。同時に出さない |
| F2 | 確認文法の統一 | 危険度3段: 段1 取り消せる=1キー、段2 編集を捨てうる=1キー・既定なし、段3 外部コード・取り消せない削除=`yes` 完全入力 | Q2 |
| U4 | 起動画面 | 引数なしの `loom` だけで出す。退避の知らせ（WP1）・最近のファイル・プロジェクト・セッション | `$EDITOR`・ファイル指定・`+N` では出さない |
| CC | 制御文字の見える表記 | 本文の C0・C1 制御文字を `^[` の形で見せる。v0.2 では空白のセルとして描き、その挙動を計画書の S1 の回帰テストで確かめる | `src/infrastructure/terminal-renderer-text.lisp` の変更。保存するバイト列は変えない |
| PL 段1〜3 | cl-prolog-kit 化 | コマンドレジストリを事実ベースにし、導線生成 R1〜R5（`t/e2e/loom_e2e/path_generation.py` の生成部）・キーの遮蔽検査・スライス循環検査を同じ rulebase から導く | 描画ループでは問い合わせない。登録時・テスト時に表へ畳む（Q5） |

## v0.4 道具をそろえる

| 提案 | 要点 |
|---|---|
| P5 Git ステータス | `*Loom-Git-Status*` を区分（Staged / Unstaged / Untracked）に分け、行の上で `s` `u` `=` `RET` `k` `g`。`git status --porcelain=v2 --branch -z` を domain の純関数で解析。破棄は `yes` 完全入力 |
| ウィンドウ | `C-x 4 f` / `C-x 4 b`、`C-M-v`、`C-x ^ { } +` |
| `M-\|` と `M-/` | shell-command-on-region（`C-u` で置換）、dabbrev-expand |
| ヘルプ | `C-h a`（apropos）、`C-h e`（*Messages*）、変数の説明 |
| 設定 | `M-x reload-init`、モード → フォーマッタの既定表、`.editorconfig` |
| セッション自動復元 | Q6 |
| PL 段4 | M-x の「いま使えるか」注釈、確認の方針、字下げ規則を init.lisp から拡張 |

## v0.5 Rich モード

起動時に端末の能力を測り（合計 100ms で打ち切り）、使えるものだけ有効にする。部品は cl-tty-kit にそろっている（v0.2 で固定先は v1.8.0 になる）。

| 段 | 内容 | 有効になる条件 |
|---|---|---|
| L0 面 | ASCII と背景の段差、色チップ（U1 の画面） | 常に |
| L1 Unicode | 丸い枠・罫線・字下げガイド・進捗バー（`format-progress-bar`）・スパークライン（`format-sparkline`） | 曖昧幅が1桁と測れたとき（`─` を書いてカーソル位置の報告で桁を測る） |
| L2 アイコン | Nerd Font のアイコン、Powerline の丸い端 | 設定で opt-in（Q9） |
| L3 画像 | Markdown / Org の画像（`ansi-kitty-image` / `format-sixel`） | kitty graphics の応答、または DA1 に sixel |

あわせて使う端末機能: 同期出力（DEC 2026、`ansi-begin-synchronized-update`）、OSC 8 のクリックできるパス、
色つき波線（`style-underline-color`）、カーソル形状、フォーカス通知、kitty keyboard（`C-i` と `TAB` の区別）。
装飾（虹色の括弧・固定ヘッダ・パンくず）は WP6 の行頭状態キャッシュ（キーは絶対行・バッファの版数・メジャーモード）から求め、
描画ごとに解析しない。v0.2 のキャッシュは CL のモードだけが対象で、generic のモードは含まない。
`M-x loom-ui-report` で検出結果と理由を見せる。
