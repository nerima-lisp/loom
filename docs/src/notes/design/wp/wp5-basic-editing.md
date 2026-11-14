# WP5 Emacs 基本編集6種

- 規模: S
- 所有: `core/buffer`（実装 `src/application-commands-editing.lisp`）、`core/command`（`src/command-specs-editing.lisp`）
- 波: 第1波

## 現状

次の6つは、command-spec にもキーマップにも登録がない（v0.1.0 で確認）。日常の手癖で毎日押すキー。

## 仕様（すべて Emacs の既定どおり）

| キー | コマンド | 動作 | 前置引数 |
|---|---|---|---|
| `M-m` | `back-to-indentation` | 行の最初の空白でない文字へ | — |
| `M-\` | `delete-horizontal-space` | point の前後の空白とタブを消す | `C-u` で前だけ |
| `M-SPC` | `just-one-space` | point の前後の空白を1つにする | N で N 個 |
| `M-t` | `transpose-words` | point の前後の単語を入れ替え、後ろへ進む | N 回 |
| `M-z` | `zap-to-char` | 文字を聞き、その文字まで（含む）を kill | N 番目まで、負で後ろ向き |
| `M-=` | `count-words-region` | リージョン（なければバッファ）の行・単語・文字数をエコー行へ | — |

- 単語の境界は既存の `application-word-motion.lisp` と同じ定義を使う（`M-f` / `M-b` とずれないこと）。
- `M-z` の kill は kill-ring に入る（`C-y` で戻せる）。
- 読み取り専用バッファでは、`M-m` と `M-=` 以外は拒否してバッファを変えない（既存の R3 の規則）。
- 変更するコマンドは、どれも undo 1回で元に戻る1つの編集にする。

## 受け入れ導線（先に書く）

`packages/core/command/t/paths.sexp`（または owner に応じた slice の ledger）:

- R1: 6コマンドのキー入口と M-x 入口
- R2: `M-z` の文字プロンプトと `C-g`
- R3: 変更する4つ（`M-\`・`M-SPC`・`M-t`・`M-z`）の読み取り専用での拒否と undo 1回
- 全角文字・結合文字を含む行でも位置がずれない（R6 の端点）

## テスト

- unit: 各コマンドの純関数部分（行頭・末尾・空行・タブ混在・全角）
- emacs-keymap-reference に6件を `:implemented` で追加
