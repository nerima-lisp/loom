# 検証台帳

[検証計画](verification-plan.md) の基線と、実機検証で見つかった失敗ごとの処置を記録する。
数値はすべて実行した出力から転記する。未実行のものは「未実行」と書く。

## 1. 基線（P0）

対象コミット: `f3a5d87`（main と同一）。実行環境: aarch64-darwin。

### 1.1 in-process スイート（sandbox 外）

コマンド: `nix develop --command sbcl --script run-tests.lisp`（launchd 経由）

| 実行 | TMPDIR | total | passed | skipped | failed | errored | exit |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 回目 | 既定（`/tmp` 配下） | 1405 | 1404 | 0 | 0 | 1 | 1 |
| 2 回目 | `getconf DARWIN_USER_TEMP_DIR` を指定したが `nix develop` が `/tmp/nix-shell.XXXX` を作るため実質 `/tmp` 配下 | 1405 | 1404 | 0 | 0 | 1 | 1 |

1 回目の errored は `project filesystem integration without a root > reports missing project
roots through every project command`（`t/integration/project-missing-root-test.lisp`）。
条件は `HOST-KIT operation :CALL-WITH-TEMPORARY-DIRECTORY failed on #P"/tmp/nix-shell.XXXX/"`、
期待した `"No project root found"` が出ない。原因はこのホストの `/tmp/Makefile` で、`Makefile` は
`+project-marker-names+` に含まれる（`packages/feature/project/src/domain-project.lisp`）。
一時ディレクトリの祖先にマーカーが無いことをテストが前提にしており、Nix sandbox では成立するが
ホスト実行では環境依存になる。2 回目も同一テストが同一条件で errored になり、再現は決定的。処置は §2 に積む。

同じ実行で、`main-run-loom` 系テストの間に alternate-screen 切り替えと 80x24 の空白フレームが
ジョブの stdout に書き出されている（出力の先頭 `ESC[?1049h ESC[2J`）。テストが描画先を実端末の
stdout に流している観察であり、判定には影響しない。処置は §2 に積む。

### 1.2 `nix flake check`

コマンド: `nix flake check --print-build-logs`。exit 0。aarch64-darwin の 6 check
（default, build, coverage, docs, formatting, paredit-lint）を実行。x86_64-linux は
`--all-systems` 無しのため省略と警告される。

### 1.3 PTY E2E（P2 基線）

コマンド:

```sh
out=$(nix build --no-link --print-out-paths .#default)
HOME=$(mktemp -d) LOOM_BINARY="$out/bin/loom" python3 t/e2e/loom-test.py
```

結果: 12 件 PASS、`12 E2E tests passed`、exit 0。到達コマンドは 120 件中 12 件。

### 1.4 slop grep

対象: `src packages t docs README.md loom.asd flake.nix run-tests.lisp scripts .github`

| 項目 | 生ヒット | 判定後 | コマンド |
| --- | ---: | ---: | --- |
| em dash（英語散文） | 18 | 4 行 / 3 ファイル | `grep -rnP '\x{2014}' <scope>`、`requirements-daily-driver.md`（日本語、15 行）を除外 |
| 空虚な強調語 | 10 | 0 | `grep -rniE '\b(robust\|comprehensive\|seamless\|successfully\|significantly\|powerful\|elegant)\b' <scope>`。10 件はすべて exit 状態を述べる事実記述 |
| ヘッジ | 0 | 0 | `grep -rniE '\b(essentially\|basically\|arguably)\b' <scope>` |
| 宣言と締めの言い直し | 0 | 0 | `grep -rniE 'in this (section\|article\|document)\|^overall,\|in summary\|it is worth noting' <scope>` |
| 署名を言い直す docstring | 33 | 3 | `grep -rn '"Return true' src packages` を全件読んで判定 |
| 参照ゼロの export | | 1（`prefix-argument-p`） | `grep -rn '\bprefix-argument-p\b' src packages t` が export 行のみ |
| 定義ファイル外で未参照の export | | 6 | `buffer-position`、`buffer-span`、`buffer-read-only-error-buffer`、`editor-bookmark`、`prefix-argument-magnitude`、`prefix-argument-negative-p` |
| roadmap の自賛表現 | 2 | 2 | `grep -c 'actively hardened\|verified engineering baseline' docs/src/project/roadmap.md` |
| `command-spec` 件数 | 120 | | `grep -ohE '\(command-spec\s+("[a-zA-Z0-9-]+"\|nil)' src/application/command-definitions*.lisp` |

## 2. 処置台帳（P3 以降）

| # | 発見元 | 対象 | 症状 | 判断 | 状態 |
| --- | --- | --- | --- | --- | --- |
| 1 | 基線 §1.1 | `t/integration/project-missing-root-test.lisp` | 一時ディレクトリの祖先にプロジェクトマーカーがあると errored になる | 修正（テスト内で未作成の専用マーカー名を使い、ホスト祖先の環境に依存しない） | closed |
| 2 | 基線 §1.1 | `t/integration/main-run-loom-test.lisp` ほか `%run-loom` を呼ぶテスト | 描画の escape 列がテストランナーの stdout に混入する | 据え置き（判定には影響しない stdout ノイズで、今回の配線修理の対象外） | deferred |
| 3 | P1 ハーネス | `t/e2e/loom_e2e/screen.py`（観察のみ、製品側の処置は未決） | 描画は各行を全幅で埋めて素の LF で終える。pyte はこの列を LNM 無しで食わせると deferred autowrap が LF をまたいで残り、行が 1 つずれる。ハーネス側は LNM を有効にして回避した。実端末での見え方は作者の日常使用で問題が出ていないため製品側は据え置き | 観察 | open |
| 4 | P2 PTY E2E | `t/e2e/scenarios/tooling.py:200-211` の `terminal` | `M-x terminal RET` 後に `/bin/sh` の警告は画面へ出るが、`printf terminal-e2e RET` は端末子プロセスへ届かず、画面に `Buffer *Loom-Terminal* is read-only` が出る。再現: `nix run .#e2e -- --only tooling/terminal` | 修正（`terminal-input-event-p` は真だったが、RET に通常の `newline-command` が束縛され `(null command)` が偽になり、端末分岐が選ばれなかった。特殊キーを端末へ送り、`:enter` は子シェルが受理する LF にした） | closed |
| 5 | P2 PTY E2E | `t/e2e/scenarios/lsp.py:92-95` の `lsp-completion-at-point` | nixd 起動経路後の completion で `No LSP session for this buffer` がミニバッファに出て、期待した completion 結果が現れない。再現: `nix run .#e2e -- --only lsp/completion` | 修正（session は束縛済みだったが initialize 応答を drain する前で `initialized-p` が偽だった。要求コンテキストで初期化を待ち、main loop の background polling に LSP を加えた） | closed |
| 6 | P2 PTY E2E | `t/e2e/scenarios/lsp.py:97-100` の `lsp-find-definition` | nixd 起動経路後の definition で `No LSP session for this buffer` がミニバッファに出て、期待した定義結果が現れない。再現: `nix run .#e2e -- --only lsp/find-definition` | 修正（#5 と同じ初期化応答の処理漏れを共有していた） | closed |

## 3. 進捗

| Phase | 状態 | コミット | 検証 |
| --- | --- | --- | --- |
| P0 基線 | 完了 | `1420df3` | §1 |
| P1 ハーネス | 完了 | `a8c7f09`（flake: pyte と `apps.e2e`）、`22b7415`（`t/e2e` 再構成） | `nix run .#e2e` を 2 回連続実行、いずれも `12 passed, 0 failed, 12 total`、`commands covered: 12 / 120`、exit 0。`nix run .#e2e -- --list` が 12 件を列挙。固定 sleep はハーネスから除去済み（`grep -rn 'time.sleep' t/e2e` はプロセス終了待ちの 1 箇所のみ） |
| P2 全コマンド | 完了 | `a76ee02`, `a7cdca3`, `6f3db63`, `86d09a3`, `4298135`, `6b6187a` | `nix run .#e2e -- --list` は 120/120、未カバー 0。`nix run .#e2e` は 107 passed, 3 failed, 110 total。失敗 3 件は §2 の #4-#6 に記録済み |
| P3 配線処置 | 完了 | `473b43f`, `c2e2cbf`, `fbbbf7f` | PTY E2E は `110 passed, 0 failed, 110 total`、`commands covered: 120 / 120`、exit 0。in-process は launchctl 経由で `1408 passed, 0 skipped, 0 todo, 0 failed, 0 errored, 1408 total`、exit 0。`nix flake check --print-build-logs` は `all checks passed!`、exit 0。#1/#4/#5/#6 は closed、#2 は対象外として deferred |
| P5 CI | 実装済み | `cb5022c` | `nix build .#default` は実測 3.73 秒、`nix run .#e2e` は実測 28.47 秒。いずれも exit 0。E2E は `110 passed, 0 failed, 110 total`、`commands covered: 120 / 120`。この実測を根拠に E2E ジョブの `timeout-minutes` は 10 とした。CI の両ジョブは未実行 |
