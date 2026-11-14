# WP1 退避からの復元

- 規模: M
- 所有: `packages/feature/lifecycle/`（中心）、`packages/feature/auto-save/`、`packages/feature/files/`（フックの実行、バックアップ）、`packages/core/editor-session/src/application-session-hooks.lisp`（フック種別）、`src/application/startup-state.lisp`。ブックマーク、project、session の、ファイルを開く箇所も含める。`flake.nix` と `flake.lock`（cl-vcs-kit v0.3.0、cl-host-kit v0.4.0）
- 開始条件: F1 と P2 が着地し、K3 と K4 のタグが出た

## 現状（根拠）

退避は2種類あるが、どちらも書くだけで戻す側がない。

1. **auto-save の sidecar。** `packages/feature/auto-save/src/domain-auto-save.lisp` の `auto-save-path` が `foo.lisp` → `#foo.lisp#`。
   `packages/feature/auto-save/src/infrastructure-auto-save.lisp` の `write-auto-save-file` が UTF-8 で本文を書き、通常の保存の後（`:after-save` フック）に消す。
2. **SIGTERM / SIGHUP 時の退避。** `packages/feature/lifecycle/src/application-commands-quit.lisp:86-134`。
   変更ありの各バッファを `~/.loom/recovery/buffer-<reason>-<時刻>-<内部時刻>-<index>-<attempt>.txt` に書く。
   **本文だけで、元のファイルのパスもバッファ名も残していない**。このままでは、どのファイルの退避か分からない。

どちらも `with-open-file` で書いており、権限を指定していない。
また、そのファイルを開いている loom が生きているかを示すもの（ロックや PID）も、ファイルを開くときに退避を調べる処理も、
`recover-file` 系のコマンドもない。

## 仕様

### 1. 退避のメタ（lifecycle）

- 本文 `….txt` の隣に、同じ名前で拡張子だけ違うメタデータ `….sexp` を書く。
  中身は `(:version 1 :path <絶対パスか nil> :buffer-name <名前> :reason <:sigterm か :sighup> :time <universal-time>)`。ファイル形式の欄は入れない（D13）。
- 書く順は本文、メタの順。書き込みは 8節のとおり cl-host-kit を通す。
- 読み込みでは `*read-eval*` を nil にし、形を検証する。4 KiB を超えるものと、読めないもの・形の検証に通らないものは無視する。
- メタのない `.txt` は、パス不明の旧形式として扱う。

### 2. ファイルを開いた後のフック

core/editor-session にフック種別を足す。次の経路のすべてで、application 層の呼び出し元から1回だけ走らせる（D25）。

| 経路 | 呼び出し元 |
|---|---|
| files の `%visit-existing-file` | find-file、recent-file、`visit-file`（file-tree、LSP の定義へのジャンプ、grep の結果） |
| find-file の新規ファイル | `%make-file-buffer` |
| 起動時のファイル | `src/application/startup-state.lisp` |
| ブックマーク | `packages/feature/bookmark/src/application-commands-bookmark-support.lisp` |
| project-find-file | `packages/feature/project/src/application-commands-project.lisp` |
| セッション復元 | `packages/feature/session/src/application-session-restore.lisp`（スナップショットの本文から作る） |

project search が本文を読むためだけに使う読み込みは、ここに含めない。
退避の検出（3節）とロック（4節）は、このフックで行う。

### 3. 開いたときに知らせる

候補は次の2つ。

- `#<name>#`（同じディレクトリ）
- `~/.loom/recovery/*.sexp` で `:path` が一致する最新のもの。パスは、解決した truename どうしで比べる。

候補の mtime がファイルより新しく、内容が現在のバッファの本文と違うときだけ、エコー行で知らせる。ブロックはしない。

- 他の loom がそのファイルのロックを持っている場合は、`<path> is open in another loom (pid N)` を出し、復元の案内は出さない。
- それ以外の場合は、次を出す。選択は `recover-file`（5節）で行う（D3）。

```
Unsaved work found (<auto-save|recovery>, <age> newer); M-x recover-file to restore
```

`<age>` は、差が60秒未満なら `<1 min`、1時間未満なら `N min`、それ以上なら `N h`。
何もしなければ、次に開いたときにまた知らせる。

### 4. ロック

ファイルを開いた後のフックで、K4 のロックを `~/.loom/locks/<FNV-1a 64bit の16進表記>.lock` に取る（D18、D26）。

- ハッシュは、truename の UTF-8 に対して計算する。
- 中身は pid・ホスト・パス。パスでハッシュの衝突を見分け、衝突した場合はロックなしとして `*Messages*` に記録する。
- 同じプロセスの中で同じファイルを開くバッファの数を数える。
- `write-file` でパスが変わったら、ロックを取り直す。
- `:buffer-close` と終了時に放す。
- `~/.loom/locks/` に書けない場合は、ロックなしで動き、`*Messages*` に一度だけ記録する。

### 5. コマンド

| コマンド | キー | 内容 |
|---|---|---|
| `recover-file` | なし（M-x） | 現在のバッファのファイルについて3節の判定を行い、プロンプトを出す（`:prompts (:char)`） |
| `list-recoverable-files` | なし（M-x） | 全退避を読み取り専用の `*Loom-Recover*` に一覧する |

どちらも `:help` を付け、`:help-order` は 40〜41 にする（D11）。

`recover-file` は次のように動く。

- 候補がなければ `No unsaved work for <path>`、ファイルを持たないバッファなら `Buffer is not visiting a file` を出す。
- プロンプトは `Recover from <kind> (<age> newer)? (r, d, i, C-g)`。他の loom が開いている場合は、先頭に3節の警告を付ける。
- `r` は本文全体を退避の本文で置き換える。**undo 1回で元に戻る単一の編集**にし、バッファを「変更あり」にする（保存はしない）。エコー行に `Recovered from <kind>; save to keep` を出す。
- `d` は、K3（cl-vcs-kit v0.3.0）の unified diff を loom の中で計算して `*Loom-Recover-Diff*` に出し、もう一度プロンプトを出す（D6、D17）。差が大きすぎる場合は `Diff too large to display` を出す（D27）。
- `i` は何もしない。C-g は `Quit` を出す。
- narrow 中は `Widen before recovering` で拒否する。読み取り専用では、既存の拒否メッセージを出す。前置引数は無視する。

`list-recoverable-files` は次のように動く。

- 列は、パス・種類・時刻（ローカル時刻の ISO 形式）。
- 旧形式は、`(unknown path)` と退避のファイル名で表示する。
- パスのある行で `RET` を押すと、そのファイルを開いて `recover-file` に進む。パス不明の行で `RET` を押すと、本文を読み取り専用で開く。

### 6. 退避と一時ファイルの削除

- 退避は `r` の後も消さない。通常の保存が成功したときに、auto-save の sidecar と、`:path` が一致する recovery の退避（本文とメタ）をまとめて消す。旧形式は自動では消さない。
- 保存に成功した後と、ファイルを開いたとき（他の loom がロックを持っていない場合に限る）に、`#<name>#.` で始まる古い一時ファイルを消す。消すのは、そのファイルの prefix に完全に一致するものだけ。

### 7. 起動時の知らせ

引数なしで起動したとき、または `$EDITOR` として起動したときに退避があれば、`N recoverable file(s); M-x list-recoverable-files` を出す。どちらも処理を止めない。

### 8. 書き込みと権限（cl-host-kit を通す）

| 書くもの | 方法 |
|---|---|
| 退避の本文とメタ | `write-file-string`（新しいファイルは 0600） |
| `~/.loom/recovery/`、`~/.loom/locks/` | `create-directory :mode #o700` |
| `#file#` | アトミックな書き込み。権限は元のファイルと同じで、元がなければ 0600。一時ファイルの prefix は `#<name>#.` |
| バックアップ | `copy-file`（元の権限を引き継ぐ。`:if-exists :error`） |

### 9. キットの固定先

`flake.nix` と `flake.lock` で cl-vcs-kit を v0.3.0、cl-host-kit を v0.4.0 のタグに向ける。K3 と K4 の probe の統合テストを、この change に含める。

## 性能

- 退避が1,000件あるとき、ファイルを開く時間の増分を 10ms 以下にする。
- メタはディレクトリの一覧とファイルの mtime で記憶しておき、変わったものだけ読み直す。
- 起動の 0.3 秒は維持する。

## 受け入れ導線（先に書く）

`packages/feature/lifecycle/t/paths.sexp` と `packages/feature/lifecycle/t/e2e/scenarios/command-paths.json`。
新しいコマンドの名前は `packages/feature/lifecycle/t/command-ids.lisp` に足す。書式は `docs/src/notes/command-path-scenarios.md` に従う。

- R1: `recover-file` / `list-recoverable-files` の M-x 入口
- R2: `:char` のプロンプトが生成する accept・cancel・invalid の3件
- R3: `recover-file` は生成される7件をすべて満たす（D14）。narrow の件は拒否、prefix-u4 の件は前置引数なしと同じ結果にする。`r` の後に undo 1回で元の本文に戻ることを含む
- 追加シナリオ:
  - auto-save を有効にした後で `kill -9` → 再起動して同じファイルを開く → 知らせが出る → `r` の後のバッファが sidecar と一致する
  - SIGTERM（exit 143）後に `.sexp` のメタをファイルで観測する → 再起動して開く → 知らせが出る
  - 退避がファイルより古い / 内容が同じ → 知らせが出ない
  - 別の loom が開いているときは、別の案内が出る
  - 保存成功の後に sidecar と recovery の退避が消える
  - 0600 の権限と 0700 のディレクトリを、ファイルで観測する
  - バックアップの名前が衝突したとき、既存のものを上書きしない

## テスト

- unit: メタの読み書き、判定（新しさ・内容差・パス一致）、旧形式の扱い
- integration: lifecycle の shutdown フックが本文とメタを両方書く
- integration: K3 と K4 の統合テスト（probe のもの）。git の E2E が緑であること

## 非目標

- 退避の期限切れによる自動削除。保存の成功時の削除（6節）とは別。一覧から手で消す機能も今回は作らない。
- パス不明の旧形式退避の自動照合。
