# WP1 退避からの復元

- 規模: M
- 所有スライス: `feature/files`（中心）、`feature/auto-save`、`feature/lifecycle`
- 波: 第2波

## 現状（根拠）

退避は2種類あるが、どちらも書くだけで戻す側がない。

1. **auto-save の sidecar** — `feature/auto-save/src/domain-auto-save.lisp` の `auto-save-path` が `foo.lisp` → `#foo.lisp#`。
   `infrastructure-auto-save.lisp` の `write-auto-save-file` が UTF-8 で本文を書き、通常の保存の後（`:after-save` フック）に消す。
2. **SIGTERM / SIGHUP 時の退避** — `feature/lifecycle/src/application-commands-quit.lisp:86-134`。
   変更ありの各バッファを `~/.loom/recovery/buffer-<reason>-<時刻>-<内部時刻>-<index>-<attempt>.txt` に書く。
   **本文だけで、元のファイルのパスもバッファ名も残していない**。このままでは、どのファイルの退避か分からない。

ファイルを開くとき（`find-file`）にどちらの退避も調べていない。`recover-file` 系のコマンドもない。

## 仕様

### 1. 退避の形式を変える（lifecycle）

- 本文 `…txt` の隣に、同じ名前で拡張子だけ違うメタデータ `…sexp` を書く。
  中身は `(:version 1 :path "<元の絶対パス or nil>" :buffer-name "<名前>" :reason :sigterm :time <universal-time> :encoding :utf-8 :newline :lf :bom nil)`。
  `:encoding`・`:newline`・`:bom` は files スライスのファイル形式（`file-format-indicator` の元の値）から取る。
- 書き込みは本文 → メタの順で、両方 `finish-output`。メタが無い本文は「パス不明の退避」として扱う（旧形式の互換）。

### 2. 開くときに知らせる（files）

`find-file` でバッファを作った直後に、次のどちらかが **ファイルの mtime より新しく、内容がファイルと違う** ときだけ知らせる。

- `#<name>#`（同じディレクトリ）
- `~/.loom/recovery/*.sexp` で `:path` が一致するもの（複数あれば最新）

エコー行に次を出す。押さなければ何もしない（ブロックしない）。

```
Unsaved work found (auto-save, 3 min newer) — r recover · d diff · i ignore
```

- `r` … バッファの本文を退避の本文で置き換える。**1回の undo で元に戻せる単一の編集**にし、バッファは「変更あり」にする（保存はしない）。
- `d` … `*Loom-Recover-Diff*` にファイルと退避の差分を出す（既存の diff 表示の仕組みを使う）。その後もう一度 `r` / `i` を選べる。
- `i` / 他のキー … 何もしない。次に開いたときにまた知らせる。
- 退避は `r` の後も消さない。通常の保存が成功したとき（既存の `:after-save`）に、auto-save sidecar と、そのパスの recovery 退避をまとめて消す。

### 3. コマンド

| コマンド | キー | 内容 |
|---|---|---|
| `recover-file` | なし（M-x） | 現在のバッファのファイルについて上の判定を行い、プロンプトを出す。退避がなければ `No unsaved work for <path>` |
| `list-recoverable-files` | なし（M-x） | 全退避を `*Loom-Recover*` に一覧（パス・種類・時刻）。行で `RET` するとそのファイルを開いて上の流れへ |

どちらも `:help` を付ける。`$EDITOR` として起動したときも、知らせは出してよい（ブロックしないため）。

## 受け入れ導線（先に書く）

`feature/files/t/paths.sexp` と `t/e2e/scenarios/command-paths.json`:

- R1: `recover-file` / `list-recoverable-files` の M-x 入口
- R2: プロンプトの `r` / `d` / `i` / `C-g` のそれぞれ
- R3: `r` の後に undo 1回で元の本文に戻る
- 追加シナリオ:
  - auto-save 後に `kill -9` → 再起動して同じファイルを開く → 知らせが出る → `r` でバッファが退避と一致
  - SIGTERM（exit 143）後 → 再起動 → 同上。`.sexp` メタが書かれていることもファイルで観測
  - 退避がファイルより古い / 内容が同じ → 知らせが出ない
  - 保存成功の後に sidecar と recovery 退避が消える

## テスト

- unit: メタの読み書き、判定（新しさ・内容差・パス一致）、旧形式の扱い
- integration: lifecycle の shutdown フックが本文とメタを両方書く

## 非目標

- 退避の自動削除（期限切れの掃除）。一覧から手で消す機能も今回は作らない。
- パス不明の旧形式退避の自動照合。
