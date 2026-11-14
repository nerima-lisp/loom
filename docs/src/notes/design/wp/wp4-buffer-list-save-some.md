# WP4 C-x C-b（list-buffers）と C-x s（save-some-buffers）

WP4 は2つのタスクに分かれる。WP4a は buffer-menu と確認つき保存、WP4b は save-some-buffers。

- 規模: M（WP4 全体）
- 開始条件: WP4a はすぐ。WP4b は F1 と WP4a が着地してから
- `:help`: `list-buffers` と `save-some-buffers` に付け、`:help-order` は 42〜43 にする（D11）

## 現状（根拠）

`packages/core/command/t/emacs-keymap-reference.lisp:106-113` で、次の2件が `:status :pending`（owner `:w3-3`）。
FR-K01 の Emacs 標準キーのうち、この2件だけが未実装。

```lisp
(:id "list-buffers-control-x-control-b" ... :target "list-buffers" ... :status :pending)
(:id "save-some-buffers-control-x-s"   ... :target "save-some-buffers" ... :status :pending)
```

## WP4a buffer-menu と確認つき保存

- 所有: 新しい `packages/feature/buffer-menu/`、`loom.asd`（21行と162行のリスト）、`LANE_REGISTRY` の `"feature/buffer-menu": "W3-3"`、`packages/feature/files/src/application-commands-file-save.lisp`、`docs/src/reference/architecture.md`
- 新スライスは buffers・files・mode に依存させる（D5）。

### list-buffers（`C-x C-b`）

- `*Buffer List*` を読み取り専用で作り、別ウィンドウに表示する（Emacs と同じく point は元のウィンドウに残す）。ウィンドウが1つなら分割し、2つ以上あれば別のウィンドウを再利用する。
- 1行1バッファで、バッファの登録順に並べる。列は、状態（`.` は呼び出し時の現在バッファ、`*` は変更あり、`%` は読み取り専用）、名前、文字数、モード、`~` で縮めたパス。
- `*Buffer List*` 用のメジャーモードを登録する。
- ローカルキーマップ `:buffer-list-local`（file-tree と同じ作法）。下の10個のキーはローカルコマンドとして登録し、`:help nil` にする。

| キー | 動作 |
|---|---|
| `n` / `p` | 次・前の行 |
| `RET` | そのバッファを現在のウィンドウに |
| `o` | そのバッファを別ウィンドウに |
| `d` | 削除の印 `D` を付ける |
| `s` | 保存の印 `S` を付ける |
| `u` | 印を外す |
| `x` | 印を実行する。`S` の行は確認つき保存で保存し、`D` の行は kill する（変更ありなら既存の kill-buffer の確認を通す）。実行後に一覧を作り直す |
| `g` | 一覧を作り直す |
| `q` | list-buffers がウィンドウを作った場合はそのウィンドウを閉じ、そうでなければ直前のバッファに戻す |

- 1行の印は1つで、後から付けた印が前の印を置き換える。
- 行とバッファの対応は行番号ではなく、行に付けたエントリで引く。対応表はこのスライスの中に持ち、共通部品にはしない（D12）。

### 確認つき保存（files）

- files に公開関数を足す。外部変更の確認、バックアップ、形式の保持を通したうえで、保存した・飛ばした・取り消したの3つの結果を、必ず続きの処理に渡す。
- 既存の `save-buffer` の挙動は変えない。
- export は `packages/feature/files/src/package.lisp` に足すだけにする。

### 参照表

`list-buffers` の行を `:implemented` にし、`:effective` を実際の束縛にする。`packages/core/command/t/emacs-keymap-reference.lisp` には自分の行だけを触る。

### 性能

一覧の作成は O(バッファ数) にし、バッファ全体を文字列にしない。

### 受け入れ導線（先に書く）

`packages/feature/buffer-menu/t/paths.sexp` と `packages/feature/buffer-menu/t/e2e/scenarios/command-paths.json`（新しいスライスなので作る）。
コマンドの名前は `packages/feature/buffer-menu/t/command-ids.lisp` に足す。書式は `docs/src/notes/command-path-scenarios.md` に従う。

- R1: `list-buffers` のキー入口と M-x 入口（catalog から自動生成される ID を使う）
- R3: `*Buffer List*` での `x` 実行（保存・kill）

## WP4b save-some-buffers

- 置き場所: `packages/feature/files/`（D5）。`packages/feature/files/src/package.lisp` には export を足すだけにする。

### save-some-buffers（`C-x s`）

- `:prompts (:char)` で、ファイルを持つ変更ありのバッファを登録順に聞く: `Save file <path>? (y, n, !, q, C-g)`
  - `y` は保存する。
  - `n` は飛ばす。
  - `!` は残りを聞かずに保存する（外部変更の確認は1件ずつ行う）。
  - `q` はやめて件数を報告する。
  - C-g は `Quit` を出して止める。
- 保存は WP4a の確認つき保存の関数を通す（外部変更の確認・バックアップ・形式の保持も、その関数がそのまま行う）。
- 対象がなければ `(No files need saving)`。終わったら `Saved N file(s)`。

### 参照表

- `save-some-buffers` の行を `:implemented` にし、`:effective` を実際の束縛にする。`packages/core/command/t/emacs-keymap-reference.lisp` には自分の行だけを触る。
- 参照表の `:pending` が0件であることを確かめる assert を、`packages/core/command/t/integration/command-keybinding-consistency-test.lisp` に足す。

### 受け入れ導線（先に書く）

`packages/feature/files/t/paths.sexp` と `packages/feature/files/t/e2e/scenarios/command-paths.json`。
コマンドの名前は `packages/feature/files/t/command-ids.lisp` に足す。

- R1: `save-some-buffers` のキー入口と M-x 入口（catalog から自動生成される ID を使う）
- R2: `:char` のプロンプトが生成する accept・cancel・invalid の3件
- PTY シナリオ: `n`・`!`・`q` と、外部変更があるファイルでの確認
- 参照表の `:pending` が0件（上の assert で確かめる）

## 非目標

- ibuffer 相当のフィルタ・グループ
