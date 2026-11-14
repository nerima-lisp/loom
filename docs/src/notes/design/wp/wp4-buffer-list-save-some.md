# WP4 C-x C-b（list-buffers）と C-x s（save-some-buffers）

- 規模: M
- 所有スライス: `feature/buffers`
- 波: 第1波

## 現状（根拠）

`packages/core/command/t/emacs-keymap-reference.lisp:106-113` で、次の2件が `:status :pending`（owner `:w3-3`）。
FR-K01 の Emacs 標準キーのうち、この2件だけが未実装。

```lisp
(:id "list-buffers-control-x-control-b" ... :target "list-buffers" ... :status :pending)
(:id "save-some-buffers-control-x-s"   ... :target "save-some-buffers" ... :status :pending)
```

## 仕様

### list-buffers（`C-x C-b`）

- `*Buffer List*` を読み取り専用で作り、別ウィンドウに表示する（Emacs と同じく point は移さない）。
- 1行1バッファ。列は「状態（`.` 現在 / `*` 変更あり / `%` 読み取り専用）・名前・サイズ・モード・パス」。
- ローカルキーマップ `:buffer-list-local`（file-tree と同じ作法）:

| キー | 動作 |
|---|---|
| `n` / `p` | 次・前の行 |
| `RET` | そのバッファを現在のウィンドウに |
| `o` | そのバッファを別ウィンドウに |
| `d` | 削除の印 `D` を付ける |
| `s` | 保存の印 `S` を付ける |
| `u` | 印を外す |
| `x` | 印を実行（`S` → 保存、`D` → kill。変更ありの `D` は既存の kill-buffer の確認を通す） |
| `g` | 一覧を作り直す |
| `q` | ウィンドウを閉じる |

- 行とバッファの対応は行番号ではなく、行に付けたエントリで引く（P5 Git ステータスでも同じ部品を使う予定）。

### save-some-buffers（`C-x s`）

- ファイルを持ち、変更ありのバッファを順に聞く: `Save file <path>? (y, n, !, q, C-g)`
  - `y` 保存 / `n` 飛ばす / `!` 残りを全部保存 / `q` やめる / `C-g` 中止
- 保存は既存の `save-buffer` を通す（外部変更の確認・バックアップ・形式の保持はそのまま効く）。
- 対象がなければ `(No files need saving)`。終わったら `Saved N file(s)`。

### 参照表

両方の `:status` を `:implemented` に、`:effective` を実際の束縛に変える。

## 受け入れ導線（先に書く）

`feature/buffers/t/paths.sexp`:

- R1: 2コマンドのキー入口と M-x 入口（catalog から自動生成される ID を使う）
- R2: save-some-buffers の `y` / `n` / `!` / `q` / `C-g`、外部変更があるファイルでの上書き確認
- R3: `*Buffer List*` での `x` 実行（保存・kill）
- 参照表の `:pending` が 0 件（既存の keybinding consistency テストで）

## 非目標

- ibuffer 相当のフィルタ・グループ
