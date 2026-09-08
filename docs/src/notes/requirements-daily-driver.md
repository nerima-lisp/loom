# 要件定義: loom を日常使用に載せる

この文書は、実装予定表ではなく、日常使用に必要な判断とその理由を記録する。
実装状態は現在のコードと検証結果に合わせて更新する。証拠のためだけの古い
file:line は残さない。

## 1. 判断基準

loom は SBCL 上の Common Lisp で動く Emacs 風ターミナルテキストエディタである。
判断基準は、作者が毎日使えることと、実機の入力・描画経路まで動くことである。

残す機能は作者が使う、または使う意思があるものに限る。削る機能は、実装量よりも
event loop、状態、永続化形式、回帰テストを増やす保守負担を理由に判断する。

対象言語は Common Lisp / Emacs Lisp、Nix、TypeScript / Web、Markdown / Org とする。
Lisp 系では実行中の定義、マクロ展開後の状態、REPL との接続が必要なので SWANK を
使う。Nix と TypeScript ではソース診断、補完、定義ジャンプを言語サーバから得る
ため LSP を使う。両者は対象と得意な情報が違い、一方で他方を代替しない。

## 2. 現在の機能要件

### FR-000: multiple-cursors の撤去

**状態: 撤去済み。**

multiple-cursors は作者が使っておらず、今後も使う意思がない。行単位だけの部分実装を
維持すると、入力分岐、yank、描画、テスト、公開APIを増やし続けるため撤去した。
単一カーソルの insert、kill、yank、yank-pop の経路はこの判断の対象外とし、既存挙動を
保つ。

### FR-001: 全角文字を含む行のカーソル位置

**状態: 実装済み。**

カーソル、mode-line の列表示、ミニバッファは、文字数ではなく
`cl-tty-kit:char-width` を通した表示セル列を使う。全角文字の前にある point が
画面上で左にずれないことを受け入れ条件とする。

### FR-002: 横スクロール

**状態: 実装済み。**

切り詰め表示のウィンドウは point を水平スクロールで可視範囲に保つ。切り出しは
表示セル境界を共有し、全角文字を半分だけ描画しない。

### FR-003: 行折り返し

**状態: 実装済み。**

折り返し表示は論理行を画面セル幅に分け、point、スクロール、カーソルを画面行へ
写像する。`next-line` と `previous-line` の移動単位は画面行とする。これは Emacs の
`line-move-visual` が既定値 t のときの挙動に合わせる決定であり、文章を読むときの
上下移動が端末上の一行と一致するためである。

### FR-004: 表示方式の切り替え

**状態: 実装済み。**

コード系の major-mode は切り詰め、Markdown、Org、plain text は折り返しを既定値と
する。`M-x toggle-truncate-lines` は選択バッファの設定を反転する。

表示方式はセッションに永続化しない。表示方式を保存すると session v5 エンベロープを
変更し、reader の互換性判断が必要になる。現行 v5 は据え置きとし、復帰時は major-mode
の既定値から表示を再構成する。

### FR-005: major-mode

**状態: 実装済み。**

Common Lisp、Python、Rust、Shell、JSON、Markdown、plain text に加えて、Nix、TypeScript、
Emacs Lisp、Org の構文メタデータを登録する。各モードは拡張子、コメント接頭辞、
indentation、language id、キーワードを持ち、コメント操作と汎用ハイライトから利用する。

Org の範囲は構文メタデータの登録までとする。アウトラインの折り畳み、表編集、babel
実行、Org 専用の編集モデルは未決であり、この要件には含めない。

### FR-006: インクリメンタルサーチ

**状態: 実装済み。**

`C-s` と `C-r` は入力中のパターンに合わせて point を移動し、一致箇所を表示する。
`RET` は位置を確定して履歴へ登録し、`C-g` は検索開始位置へ戻す。通常の
`M-x search-forward` は確定入力型の検索として残す。

### FR-007: S 式移動と対応括弧

**状態: 実装済み。**

`C-M-f`、`C-M-b`、`C-M-u`、`C-M-d`、`C-M-k` を S 式単位で実装する。文字列、コメント、
文字リテラル内の括弧は構造として扱わない。point に隣接する括弧と対応括弧を表示し、
対応が無い場合は誤った位置を表示しない。

### FR-008: 構造編集

**状態: 実装済み。**

slurp、barf、wrap、splice、raise を提供する。各操作は括弧の対応を保ち、単一の undo
単位とする。

### FR-009: SWANK 接続

**状態: 未実装。**

理由はソケット層が存在しないことである。次の確認を現行ツリーで再実行し、出力が空で
あることを受け入れ条件とする。

```sh
grep -rln 'socket\|usocket\|sb-bsd-sockets\|swank' src packages
```

LSP は標準入出力を使う外部プロセス接続であり、TCP で待ち受ける SWANK の基盤には
流用できない。SWANK を実装するときは、LSP とは別の infrastructure 境界、接続失敗と
切断の状態、外部 SBCL イメージへの評価経路を追加する。

### FR-010: LSP 補完と定義ジャンプ

**状態: 実装済み。**

実サーバとの initialize、document sync、diagnostics、completion、definition、jump
origin への復帰を実装する。server capability が無い要求は送信せず、結果をミニバッファ、
popup、または対象バッファへ反映する。

## 3. 実機検証で記録した配線切れ

in-process テストが緑でも、raw-mode のキーマップ、外部プロセスの初期化、画面復元を
通る実機経路が切れていれば機能は使えない。この run では次の4件を実PTYで発見し、
原因を修正した。

| 機能 | 症状 | 原因と処置 |
| --- | --- | --- |
| `terminal` | RET 後の入力が子シェルへ届かず read-only エラーになった | RET が `newline-command` に解決され、端末入力分岐の `(null command)` 条件を満たさなかった。端末用の特殊入力と子プロセスが受理する enter を分けた。 |
| `lsp-completion-at-point` | session が無いという表示になった | session は存在したが initialize 応答を drain する前で `initialized-p` が偽だった。要求コンテキストで初期化を待ち、main loop の LSP polling も有効にした。 |
| `lsp-find-definition` | completion と同じ session エラーになった | 同じ initialize 応答の処理漏れだった。completion と共通の初期化処置で直した。 |
| `set-mark-command` (`C-SPC`) | mark が設定されなかった | 素の端末が送るイベントは `:NULL` だが、実装とコメントは `CONTROL-@` を想定していた。`C-SPC` の raw event を mark command へ接続した。 |

この4件が示す判断は、実装シンボルを呼ぶテストだけでは入力の解決、外部プロトコルの
ライフサイクル、端末画面の状態を証明できないということである。機能を「実装済み」と
記録するには、該当する実PTY経路か、同じ境界を通る検証を残す。

## 4. 非機能上の判断

- 表示幅とカーソル幾何は presentation / infrastructure に置き、`packages/core/editor`
  の domain 層へ端末概念を持ち込まない。
- 表示セル幅の根拠は `cl-tty-kit:char-width` に統一する。カーソル、描画、折り返し、
  横スクロールはこの計算を共有する。
- セッション reader は v5 エンベロープを受理する。表示方式は保存しないため、この
  判断だけでは v5 を上げない。
- 実PTY E2E は実サーバを使う。LSP の確認に偽サーバを差し替えない。
- 実行ゲートは入力が空でないことを確認する。E2E はシナリオと command-spec の被覆を
  照合し、in-process は failed、errored、skip の件数を出力から読む。

## 5. 今後の境界

FR-009 の SWANK、LSP の動的登録や追加リクエスト、完全な VT 端末エミュレーション、
Org のアウトラインと表編集は、現在の毎日使う編集経路を置き換えずに別課題として扱う。
新しい機能を追加する前に、raw-mode の入力と描画、外部プロセスの終了処理、session v5
との関係を要件に記録する。
