# WP5 Emacs 基本編集（WP5a 基本編集5種、WP5b M-z）

- 規模: S
- 分け方: WP5a は `M-m`・`M-\`・`M-SPC`・`M-t`・`M-=` の5つ、WP5b は `M-z` の1つ。
  `M-z` は1打鍵の文字プロンプト（`:prompts (:char)`、D4）を使うので、F1 の後に回す。

## 現状

次の6つは、command-spec にもキーマップにも登録がない（v0.1.0 で確認）。

## 共通の規則

- キーは Emacs の既定どおりにする。
- 6つとも新しいグローバルコマンドなので、`:help` と `:help-order` を付ける（D11。`:help-order` は 44〜49）。
- 単語の境界は既存の `packages/core/command/src/application-word-motion.lisp` と同じ定義を使う（`M-f` / `M-b` とずれないこと）。
- 読み取り専用バッファでは、`M-m` と `M-=` 以外は拒否してバッファを変えない（既存の R3 の規則）。
- 変更するコマンドは、どれも undo 1回で元に戻る1つの編集にする。
- 変更する4つ（`M-\`・`M-SPC`・`M-t`・`M-z`）は、生成される R3 の7件（effect・undo・read-only・narrow・split-window・
  macro-replay・prefix-u4）をすべて満たす（D14）。
- 新しいコマンドの ID は、所有するスライスの `t/command-ids.lisp` に足す。
- `packages/core/command/t/emacs-keymap-reference.lisp` は共有ファイルなので、自分の行だけを足す。

## WP5a 基本編集5種

- 所有: `packages/core/command/src/application-commands-emacs-defaults.lisp`、`packages/core/command/src/command-specs-editing.lisp`
- 開始条件: すぐ

### 仕様

| キー | コマンド | 動作 | 前置引数 |
|---|---|---|---|
| `M-m` | `back-to-indentation` | 行の最初の空白でない文字へ | なし |
| `M-\` | `delete-horizontal-space` | point の前後の空白とタブを消す | 前置引数があれば前だけ |
| `M-SPC` | `just-one-space` | point の前後の空白を1つにする | N で N 個（既定は1）。N が負なら、絶対値の個数にしたうえで改行も消す |
| `M-t` | `transpose-words` | point の前後の単語を入れ替え、後ろへ進む | N 回 |
| `M-=` | `count-words-region` | `Region has L lines, W words, and C characters.` を出す。リージョンがなければ `Buffer has …` | なし |

- `M-t` で入れ替える単語が2つない場合は、`Don't have two things to transpose` を出し、バッファを変えない。

### 性能

- 2万行で `M-=` が 100ms 以下であることを、測って報告する。

### 受け入れ導線（先に書く）

台帳は `packages/core/command/t/paths.sexp`、シナリオは `packages/core/command/t/e2e/scenarios/command-paths.json` に書く。

- R1: 5コマンドのキー入口と M-x 入口
- R3: 変更する3つ（`M-\`・`M-SPC`・`M-t`）の R3 の7件
- 全角文字・結合文字を含む行でも位置がずれない（R6 の端点）

### テスト

- unit: 各コマンドの純関数部分（行頭・末尾・空行・タブ混在・全角）
- emacs-keymap-reference に5件を `:implemented` で足す

## WP5b M-z

- 所有: `packages/feature/kill-ring/`
- 開始条件: F1（`:char` 種別）が着地してから

### 仕様

| キー | コマンド | 動作 | 前置引数 |
|---|---|---|---|
| `M-z` | `zap-to-char` | `:prompts (:char)` で、プロンプトは `Zap to char: `。N 番目の出現までを、その文字を含めて kill する | N 番目まで、負で後ろ向き |

- 見つからなければ `Search failed: "<c>"` を出し、バッファを変えない。
- kill した文字列は kill-ring に入る（`C-y` で戻せる）。続けて kill したときに追記するかどうかは、`C-k` と同じ規則に従う。

### 受け入れ導線（先に書く）

台帳は `packages/feature/kill-ring/t/paths.sexp`、シナリオは `packages/feature/kill-ring/t/e2e/scenarios/command-paths.json` に書く。

- R1: `M-z` のキー入口と M-x 入口
- R2: `:char` プロンプトの accept・cancel・invalid の3件
- R3: R3 の7件

### テスト

- unit: `zap-to-char` の純関数部分（行頭・末尾・空行・タブ混在・全角、後ろ向き、見つからない場合）
- emacs-keymap-reference に `zap-to-char` の1件を `:implemented` で足す
