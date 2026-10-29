# 検証台帳

[検証計画](verification-plan.md) の基線と、実機検証で見つかった失敗ごとの処置を記録する。
数値はすべて実行した出力から転記する。未実行のものは「未実行」と書く。

Sections 1 through 3 are historical results for the commits named in each entry.
They do not establish that the current working tree passes those checks.

## 1. 基線（P0）

対象コミット: `f3a5d87`（main と同一）。実行環境: aarch64-darwin。
§3の進捗表にある`1420df3`はP0基線作業のコミットで、ここに記録した測定対象は`f3a5d87`である。

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
stdout に流していることを観察した。

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

### 1.5 Part 2 着手前の再測定

対象は Part 1 完了後の `514c5a3` とし、Part 2 の編集前に親コミットを直接検査した。
英語散文の em dash は 4 行 / 3 ファイル、`Return true` の docstring は 32 件で、うち
3 件を署名の言い直しと判定した。公開 export の対象は 7 件、roadmap の自賛表現は 2 件だった。

### 1.6 Part 2 完了時の再測定

| 項目 | 着手前 | 完了後 | 判定とコマンド |
| --- | ---: | ---: | --- |
| 英語散文の em dash | 4 行 / 3 ファイル | 0 行 / 0 ファイル | `perl -ne 'print if /\\x{2014}/' README.md docs/src packages/README.md src packages .github` |
| `Return true` docstring | 32 件、冗長 3 件 | 29 件、冗長 0 件 | `grep -rn '\"Return true' src packages` を全件再読 |
| 対象 export | 7 件 | 0 件 | `src/package-exports.lisp` の全体トークン照合 |
| roadmap の自賛表現 | 2 件 | 0 件 | `grep -Eic 'actively hardened|verified engineering baseline' docs/src/project/roadmap.md` |
| SWANK のソケット実装 | 未実装 | 未実装 | `grep -rln 'socket\\|usocket\\|sb-bsd-sockets\\|swank' src packages` は出力なし、exit 1 |

残った `successfully` は終了状態や処理結果を記述する文であり、署名だけを言い直す文ではない。
`overall width/height` はウィンドウ寸法の用語であり、締めの言い直しではない。

## 2. 処置台帳（P3 以降）

| # | 発見元 | 対象 | 症状 | 判断 | 状態 |
| --- | --- | --- | --- | --- | --- |
| 1 | 基線 §1.1 | `t/integration/project-missing-root-test.lisp` | 一時ディレクトリの祖先にプロジェクトマーカーがあると errored になる | 修正（テスト内で未作成の専用マーカー名を使い、ホスト祖先の環境に依存しない） | closed |
| 2 | 基線 §1.1 | `t/integration/main-run-loom-test.lisp` ほか `%run-loom` を呼ぶテスト | 描画の escape 列がテストランナーの stdout に混入する | 据え置き（判定には影響しない stdout ノイズで、今回の配線修理の対象外） | deferred |
| 3 | P1 ハーネス | `t/e2e/loom_e2e/screen.py`（観察のみ、製品側の処置は未決） | 描画は各行を全幅で埋めて素の LF で終える。pyte はこの列を LNM 無しで食わせると deferred autowrap が LF をまたいで残り、行が 1 つずれる。ハーネス側は LNM を有効にして回避した。実端末での見え方は作者の日常使用で問題が出ていないため製品側は据え置き | 観察 | open |
| 4 | P2 PTY E2E | `t/e2e/scenarios/tooling.py:200-211` の `terminal` | `M-x terminal RET` 後に `/bin/sh` の警告は画面へ出るが、`printf terminal-e2e RET` は端末子プロセスへ届かず、画面に `Buffer *Loom-Terminal* is read-only` が出る。再現: `nix run .#e2e -- --only tooling/terminal` | 修正（`terminal-input-event-p` は真だったが、RET に通常の `newline-command` が束縛され `(null command)` が偽になり、端末分岐が選ばれなかった。特殊キーを端末へ送り、`:enter` は子シェルが受理する LF にした） | closed |
| 5 | P2 PTY E2E | `t/e2e/scenarios/lsp.py:92-95` の `lsp-completion-at-point` | nixd 起動経路後の completion で `No LSP session for this buffer` がミニバッファに出て、期待した completion 結果が現れない。再現: `nix run .#e2e -- --only lsp/completion` | 修正（session は束縛済みだったが initialize 応答を drain する前で `initialized-p` が偽だった。要求コンテキストで初期化を待ち、main loop の background polling に LSP を加えた） | closed |
| 6 | P2 PTY E2E | `t/e2e/scenarios/lsp.py:97-100` の `lsp-find-definition` | nixd 起動経路後の definition で `No LSP session for this buffer` がミニバッファに出て、期待した定義結果が現れない。再現: `nix run .#e2e -- --only lsp/find-definition` | 修正（#5 と同じ初期化応答の処理漏れを共有していた） | closed |

## 3. 過去の進捗

| Phase | 状態 | コミット | 検証 |
| --- | --- | --- | --- |
| P0 基線 | 完了 | `1420df3` | §1 |
| P1 ハーネス | 完了 | `a8c7f09`（flake: pyte と `apps.e2e`）、`22b7415`（`t/e2e` 再構成） | `nix run .#e2e` を 2 回連続実行、いずれも `12 passed, 0 failed, 12 total`、`commands covered: 12 / 120`、exit 0。`nix run .#e2e -- --list` が 12 件を列挙。固定 sleep はハーネスから除去済み（`grep -rn 'time.sleep' t/e2e` はプロセス終了待ちの 1 箇所のみ） |
| P2 全コマンド | 完了 | `a76ee02`, `a7cdca3`, `6f3db63`, `86d09a3`, `4298135`, `6b6187a` | `nix run .#e2e -- --list` は 120/120、未カバー 0。`nix run .#e2e` は 107 passed, 3 failed, 110 total。失敗 3 件は §2 の #4-#6 に記録済み |
| P3 配線処置 | 完了 | `473b43f`, `c2e2cbf`, `fbbbf7f` | PTY E2E は `110 passed, 0 failed, 110 total`、`commands covered: 120 / 120`、exit 0。in-process は launchctl 経由で `1408 passed, 0 skipped, 0 todo, 0 failed, 0 errored, 1408 total`、exit 0。`nix flake check --print-build-logs` は `all checks passed!`、exit 0。#1/#4/#5/#6 は closed、#2 は対象外として deferred |
| P4 Documentation: 要件書と slop | 完了 | `ccb2c34` | `requirements-daily-driver.md` を現行の判断記録へ書き直し、FR-000 から FR-010 の状態、対象言語、SWANK と LSP の境界、v5 永続化境界、Org の範囲を記録。dead export 7 件、冗長 docstring 3 件、roadmap 自賛 2 件、英語 em dash 4 行 / 3 ファイルを除去。 |
| P5 CI | 実装済み | `cb5022c` | `nix build .#default` は実測 3.73 秒、`nix run .#e2e` は実測 28.47 秒。いずれも exit 0。E2E は `110 passed, 0 failed, 110 total`、`commands covered: 120 / 120`。この実測を根拠に E2E ジョブの `timeout-minutes` は 10 とした。CI の両ジョブは未実行 |
| 統合（presentation） | 完了 | `9bbca23`, `cc0380d`, `f892bb4`, `e6ae4d5` | `nix run .#e2e` は `110 passed, 0 failed, 110 total`、`commands covered: 120 / 120`、未カバー `0`、exit 0。launchctl 経由の in-process は `1427 passed, 0 skipped, 0 todo, 0 failed, 0 errored, 1427 total`、exit 0。`nix flake check` は `all checks passed!`、exit 0。`nix build --no-link --print-out-paths .#default` は exit 0。実PTY は mode-line、C-x 2/C-x 3 の mode-line 分離、C-SPC の緑背景、M-x terminal の `pty-integration` 出力を画面ダンプで確認し、exit 0 |
| 診断可視化実機 | 完了 | `514c5a3`, `ed0b49c` | 実 `nixd` を使った一時 PTY スクリプトが exit 0。診断付き画面は mode-line に `Diag: E1 W1`、診断範囲は赤背景、リージョン重畳は緑背景と診断範囲の赤背景を同一画面で確認。LSP セッション無しと診断ゼロでは `Diag:` が無く、40 列の長い日本語名でも mode-line は `cells=40` で折り返さなかった。 |

## 4. Development verification and open criteria

This section groups evidence by gate and workstream, not chronology. Use the
phase table in section 3 for project order.

The table records intermediate working-source checks on aarch64-darwin across
evolving source revisions. Per-row source SHAs were not recorded, and the check
sets changed as gates were added; the rows do not describe one revision or the
latest edits. Subsequent findings and checks follow the table; earlier passes do
not clear gates affected by later changes.

| Gate | Observation | Remaining criterion |
| --- | --- | --- |
| Source suite | `sbcl --script run-tests.lisp`, using the declared SBCL 2.6.7 and ASDF dependencies from the Nix test derivation: exit 0; 1467 passed, 0 skipped, 0 todo, 0 failed, 0 errored, 1467 total. This run includes the UTF-16 and document-synchronization fixes. The CLI subprocess limit remained 40000 ms | This host run does not establish Linux CI or sandbox behavior. The earlier CLI timeout cause remains unestablished |
| Executable | ASDF loaded the working source and `sb-ext:save-lisp-and-die` produced an executable; exit 0. `loom --version` returned `loom 0.1.0`; exit 0. `nix build --no-link --no-update-lock-file --print-out-paths .#default .#docs` also exited 0. The fresh executable from the full flake check's build derivation passed `python3 t/e2e/loom-test.py --binary <nix-built-executable> --require-full-coverage`: exit 0; 113 passed, 0 failed, 113 total, and 120/120 commands covered. Its source snapshot matched all 442 working Lisp and ASDF files by SHA-256 | These local results do not establish Linux CI or author acceptance |
| PTY suite | `python3 t/e2e/loom-test.py --binary <built-executable> --require-full-coverage`: exit 0; 113 passed, 0 failed, 113 total, with 120/120 commands covered and no unknown or uncovered commands. This includes real Unicode definition navigation and return, completion insertion, and the deadline preflight. Before adding the Unicode scenario, a full rerun passed all 112 scenarios; exit 0 | An earlier full run reported 111 passed and 1 timeout in the no-completions scenario. Neither the isolated pass nor the full reruns establish that timeout's cause. These runs do not establish accurate wide-character text rendering; see the rendering finding below |
| E2E CLI coverage | From `t/e2e`, `python3 -m unittest -v test_deadline test_cli`: exit 0; all 37 tests passed, including all 8 CLI tests. Before the runner fix, the CLI tests had 2 failures: a selected subset reported commands from unselected scenarios, and `--require-full-coverage` incorrectly returned success. Runtime coverage now uses selected scenarios. `python3 loom-test.py --list` compared all registered scenarios and reported 120/120 commands, no uncovered or unknown names; exit 0 | These CLI unit tests replace process execution with mocks. They establish selection, reporting, and exit-status behavior. The list command establishes static manifest coverage, not real command execution or a passing PTY suite |
| Deadline preflight | From `t/e2e`, `python3 -m unittest -v test_deadline test_cli`: exit 0; all 29 deadline tests passed alongside the 8 CLI tests. A separate real-process probe with a 0.3-second scenario budget and 0.1-second cleanup reserve closed and reaped three registered children and their FDs | Earlier failures of the PTY-close, multi-session, and long-finalizer tests remain unexplained; a later pass does not establish their cause. Exhausted cleanup reports remaining scratch directories rather than guaranteeing removal. No time budget or existing process/removal assertion was relaxed |
| Documentation | After the common and feature API corrections, both `mkdocs build --strict --config-file docs/mkdocs.yml --site-dir <temporary-directory>` and `nix build --no-link --no-update-lock-file --print-out-paths .#docs` exited 0. Eight generated Nix pages had nonempty main content and checklist navigation links. A later strict build covering the Unicode and renderer findings also exited 0; its generated checklist retained all 11 `Not run` results, and its feature API page contained 18 package sections | Later documentation edits require rechecking. The generated checklist is not author acceptance evidence |
| Nix sandbox tests | Building the fresh flake test derivation with `nix build --no-link --print-build-logs --print-out-paths <test-derivation>` exited 0: 1464 passed, 3 skipped, 0 todo, 0 failed, 0 errored, 1467 total. The CLI subprocess test passed in 22.595 seconds under its unchanged 40000 ms limit. This source includes the UTF-16, synchronization, test-helper, and benchmark corrections | The three sandbox skips cover real PTY and child-process lifecycle tests. The host source suite exercised them, but these results do not establish Linux CI. The earlier sandbox CLI timeout cause remains unestablished |
| Nix coverage | Building the fresh flake coverage derivation with `nix build --no-link --print-build-logs --print-out-paths <coverage-derivation>` exited 0: 1464 passed, 3 skipped, 0 todo, 0 failed, 0 errored, 1467 total. Expressions: 19981/20891 (95.64%); branches: 1909/2034 (93.85%). Parsing the generated HTML confirmed nonempty linked reports and matching totals for the 259 product-source files. No exclusions were accepted | The report also contains 179 test-harness pages; those pages are not included in the product coverage rates. Coverage does not establish author acceptance or unexecuted platform behavior |
| Full Nix checks | `nix flake check --no-update-lock-file --print-build-logs`: exit 0 on aarch64-darwin. Outputs exist for all six gates: build, tests, coverage, documentation, formatting, and structural parsing. Formatting reported zero changed files; pinned Paredit 1.6.2 parsed 442 files with 0 parse errors. All 442 Lisp and ASDF inputs still matched the built source by SHA-256 | Nix omitted x86_64-linux. The dependency fixup warning below remains unresolved; the successful command does not establish author acceptance or correct wide-character rendering |
| Host structural parse | `paredit inspect workspace --output json .`, using Paredit 1.6.3: exit 0; 442 parsed files, 0 parse errors. The generated report's paths and byte counts matched every current Lisp and ASDF file | Structural parsing does not establish runtime behavior. This host result supplements the pinned Paredit 1.6.2 flake check |
| FR-V07 | Cold-read findings were corrected in 14 Lisp files. Their non-string source was unchanged, and all 14 passed `paredit inspect check --file <path>`; exit 0. Later word-motion and file-save docstring corrections passed Paredit checks. Both selected first-save tests passed; exit 0. Documentation review corrected package paths, command-registry responsibilities, auto-save overrides, file-tree generations, ANSI terminal behavior, syntax matching, and common API signatures and return values. A static comparison found all 382 exported names in the corresponding sections for 18 feature packages; exit 0. The cold-read scope includes all repository Markdown pages and all comments and docstrings in the Lisp source, tests, and scripts; path manifests were compared with the actual files | Export-name presence and prose review do not establish runtime behavior. The Lisp reader required manual inspection of reader-evaluation forms, as described below |
| FR-V08 | The [author checklist](daily-driver-checklist.md) exists; no author results have been supplied | All manual results remain `Not run` |
During the Paredit dependency's Nix fixup, the `audit-tmpdir.sh` file-classifier
subprocess exited with `Segmentation fault: 11`, although the full flake check
exited 0. The script waits for its audit handlers but not for the classifier;
therefore the overall exit status does not establish a completed temporary-path
audit. Separate inspection found one regular file in the installed dependency,
the Mach-O executable. Its bytes contained no Nix build-temporary-directory
reference, `otool -l` exited 0 with no such reference, and
`codesign --verify --strict` exited 0. These artifact checks do not explain the
classifier failure or replace the interrupted audit. An isolated classifier
pipeline using the original `isELF` and `isScript` functions with the build's
Bash 5.3.15 passed three cases: a script control, a Mach-O control, and the
Paredit executable. Each pipeline exited 0; the build-time failure was not
reproduced. No audit was disabled and no dependency build configuration was
changed.

Further test-helper cold-read corrections affected
`t/test-helpers-core.lisp`, `t/integration/main-test-support.lisp`,
`t/integration/command-keybinding-consistency-test.lisp`, and
`t/integration/frame-layout-wrapping-test.lisp`. Their docstrings now identify
the sandbox flag rather than guessing platform or PTY availability, describe the
startup state and disk-backed child lister, cite the actual keymap path, and avoid
claiming every wrapping-enabled buffer has more display rows than logical lines.
Each file passed `paredit inspect check --file <path>`; exit 0.

The cold-read manifests cover `rg --files src packages -g '*.lisp'`,
`t/*.lisp`, `t/unit/*.lisp`, `t/integration/*.lisp`, `scripts/*.lisp`, and
`run-tests.lisp`. Source docstring extraction initially stopped at a `#.` form;
the completed extraction plus manual inspection of `src/package.lisp` was
compared with the actual source paths. The other reader-evaluation locations,
`src/package-application.lisp` and
`packages/feature/evaluation/src/infrastructure-lisp-evaluator.lisp`, were also
read directly. Test and script extraction finished with exit 0, and its manifest
matched the actual input paths. Comments were read separately from docstrings.
This establishes the reviewed prose scope, not the correctness of every function.

`sbcl --script scripts/benchmark-concurrency.lisp` initially exited 1 because its
file-tree runtime calls still used the former `LOOM` namespace. The calls now use
`LOOM/FEATURE/FILE-TREE`. The corrected script exited 0, accepted all eight
requests, and checked that each asynchronous result matched its synchronous
control. This run establishes that the documented benchmark is executable;
it is not evidence for a production performance claim.

The scratch-allocation regression delivers a real `SIGALRM` after creating a real
temporary directory but before returning its pathname. Before the fix,
`test_alarm_before_scratch_return_removes_directory` failed because the session
had not retained the pathname; exit 1. `Session.__enter__` now blocks the alarm
only while allocating and retaining the pathname, then restores the prior signal
mask inside its existing cleanup boundary. The creation-failure regression checks
that the original error and signal mask are preserved without starting a process.

The project marker predicate previously lowercased only its input, so configured
mixed-case markers such as `Cargo.toml` and `Makefile` did not match. The regression
failed before the fix; exit 1. The predicate now compares marker names with
`string-equal`. The regression checks original, lowercase, and uppercase spellings
for every configured marker. All 22 selected project tests passed after the fix;
exit 0. This predicate defect does not establish a defect in filesystem root
discovery, which uses a different lookup path.

The host's SBCL 2.6.0 also errored in two directory-race tests when formatting
wildcard pathnames. A standalone `namestring` call on a `simple-base-string`
pathname reproduced the same error without loading Loom. The declared SBCL 2.6.7
passed that control, all 12 selected directory-creation tests, and the full source
suite. No test path or assertion was changed to conceal the host runtime defect.

LSP positions use UTF-16 code units, while buffer columns count Common Lisp
characters. Three regressions failed before conversion at the completion,
definition, and diagnostic-rendering boundaries; exit 1. All six selected
UTF-16 tests passed after the fix; exit 0. The checks include a supplementary
Unicode character, surrogate-interior offsets, and offsets beyond line end.

A wire trace also showed a definition request preceding `didOpen`. Rendering
previously synchronized the document only after processing the command.
Completion and definition commands now synchronize before sending a supported
request. All four ordering regressions failed before the fix; exit 1. All four
passed afterward; exit 0. They check `didOpen`, versioned `didChange`, request
ordering, and the absence of redundant changes for unchanged text.

An initial verification-only executable omitted `:save-runtime-options t`, so
SBCL consumed `--help` and `--version`. That full PTY run reported 110 passed
and 2 failed; exit 1. The replacement executable uses the runtime-option setting
from the project's ASDF program build. Both CLI scenarios then passed in the
full run reported above. The first result is a probe-construction failure, not
evidence of a production CLI regression.

The Unicode definition scenario checks outgoing UTF-16 offsets after an astral
character, incoming definition offsets, and restoration of the original point.
A direct JSON-RPC probe without Loom found that the pinned nixd rejected offsets
11 and 12 in the reference identifier with `unknown node type for definition`,
but offset 13 returned the definition range 11 through 16 on line 1. The scenario
requests inside the identifier at buffer column 12, which maps to UTF-16 offset
13; without conversion, offset 12 fails. This server boundary behavior remains
unfixed and is not evidence against Loom's offset conversion.

Wide-character rendering exposed a separate dependency defect. With only cl-tty-kit 1.6.1
loaded, a fresh eight-column renderer emits `あ X` for input `あX` and `😀 X`
for input `😀X`; the ASCII control emits `aX`. All three probes exited 0.
The screen writer stores a spacer cell after a wide character, and
`src/render-style.lisp` in that dependency emits every cell's character, including
the spacer. A pyte control fed `  /* 😀 */ value` directly preserves the single
space after the emoji; the Loom PTY screen contains two. The passing cursor
assertions do not establish correct text placement. The dependency source was
consulted read-only; no adjacent checkout was edited.

The Nix build now applies `patches/cl-tty-kit-wide-character-rendering.patch`
to that dependency. It skips only continuation cells during output, keeps real
spaces, normalizes incremental ranges that start inside a wide character, and
uses the same range rules for output-length estimates. Replacing a wide lead
also marks its former continuation cell for output, including when that cell
lies just beyond the screen's dirty range. Row boundaries constrain both rules.

The focused command loading the patched dependency and running
`cl-weave:run-all` with `:name-filter "wide-character ANSI output"` and
`:pass-with-no-tests nil` exited 0 on host SBCL 2.6.0: all 20 selected tests passed,
with no skipped, failed, or errored tests. Before the final patch, the same
20-test selection exited 1 with 13 passes and 7 failures: one output-length
estimate and six wide-to-narrow replacement cases. These focused results are
not a full-suite or author-acceptance result.

A PTY run of the intermediate patch passed full-screen text placement but
failed during wide-to-narrow deletion. A direct pyte control reproduced the
orphan continuation cell after overwriting only the wide lead; explicitly
writing its following space cleared it. The final patch includes that write.
The intermediate PTY failure remains part of the verification history.
`python3 t/e2e/loom-test.py --binary <fresh-nix-built-executable> --only ansi-wide`
then exited 0: both scenarios passed, including the 30-test deadline preflight.
The incremental scenario checks exact reconstructed text and cursor positions
through Japanese and emoji insertion, space insertion, deletion, and replacement,
then verifies changed file bytes before exiting. An earlier test-only timeout
waited for a save message that the save command does not emit; the file assertion
now observes bytes different from the initial fixture. This focused selection
does not cover the command registry; a full PTY rerun remains required.

The patched dependency's rendering selection also passed 83 tests with no skips,
failures, or errors; exit 0. The complete upstream test system could not load
because `CL-PROLOG` was unavailable. The render-only result does not establish
that the complete upstream suite passes.

PTY child processes now inherit only the parent's `PATH`; their `HOME`, `TERM`,
`SHELL`, `LANG`, and `LC_ALL` come from the harness. A regression supplies a
synthetic credential and `LOOM_INIT_FILE` in the parent environment and verifies
that neither reaches the child. `python3 -B -m unittest discover -s t/e2e -p
'test_*.py'` exited 0 with all 38 tests passing. Explicit process environments
remain caller-controlled replacements rather than inheriting the parent.

The LSP server-discovery confirmation now requires an exact `yes` after review. All 15
selected discovery and session-start tests passed on declared SBCL 2.6.7;
exit 0. These include constructor and initialization-send failures that preserve
the old session, and replacement with an old transport that fails during receive
or close. Neither replacement failure probe demonstrated a product defect.

A full PTY run reported 115 passes and one failure, with all 120 registered
commands covered; exit 1. The rejection scenario expected `/tmp` while discovery
returned its canonical macOS pathname. Canonicalizing the fixture directory
preserves all provenance, rejection, restoration, and no-process assertions.
The isolated scenario then passed, with its 30-test deadline preflight; exit 0.
This does not establish a passing full PTY run after the harness correction.

An intermediate Nix run reported 1,492 passes, three skips, and one failure out
of 1,496 tests; exit 1. The CLI integration test exceeded its unchanged 40-second
test deadline. A subsequent sequential build used the following command:

```sh
nix flake check path:. --no-update-lock-file --max-jobs 1 --print-build-logs
```

All six aarch64-darwin checks passed; exit 0. Both test and coverage runs reported
1,497 passes, three sandbox skips, and no failures or errors out of 1,500 tests.
The CLI test took 3.848 seconds in the test run and 4.574 seconds in coverage.
Coverage was 20,049/20,959 expressions (95.66%) and 1,913/2,038 branches (93.87%).
The earlier deadline failure remains unexplained; this pass does not identify its
cause. Linux checks were omitted. These results precede the follow-up work to
make long LSP review text navigable while the trust prompt is active.

From `t/e2e`, this focused run passed all six selected tests; exit 0:

```sh
python3 -m unittest -v \
  test_deadline.ScenarioDeadlineTests.test_alarm_before_scratch_return_removes_directory \
  test_deadline.ScenarioDeadlineTests.test_scratch_creation_failure_restores_alarm_signal_mask \
  test_deadline.ScenarioDeadlineTests.test_expired_locale_setup_does_not_allocate_scratch_directory \
  test_deadline.ScenarioDeadlineTests.test_session_setup_failure_removes_scratch_directory \
  test_deadline.ScenarioDeadlineTests.test_session_screen_setup_failure_closes_registered_process \
  test_deadline.ScenarioDeadlineTests.test_session_setup_preserves_original_error_when_cleanup_fails
```

### Long LSP command review verification

The trust prompt now accepts PageDown, PageUp, C-v, and M-v for navigating
wrapped review text without changing the answer. The integration cases cover
empty answers, cancellation, and exact `yes`, including restoration of the
original viewport and preservation of the existing session until approval.

The following check includes these changes and the wide-character dependency
patch. All six aarch64-darwin checks passed; exit 0:

```sh
nix flake check path:. --no-update-lock-file --max-jobs 1 --print-build-logs
```

Both test and coverage runs reported 1,506 passes, three sandbox skips, and no
failures or errors out of 1,509 tests. The CLI test took 1.737 seconds in the test
run and 3.878 seconds in coverage, within its unchanged 40-second deadline.
Coverage was 20,085/20,995 expressions (95.67%) and 1,917/2,042 branches (93.88%).
The structural check inspected 442 Lisp and ASDF files without errors. Formatting
changed no files. Linux checks were omitted.

The full PTY run used the executable produced by that build:

```sh
python3 -B t/e2e/loom-test.py --binary <fresh-nix-built-executable> --require-full-coverage
```

It exited 0 with all 117 scenarios passing and all 120 registered commands
covered. The deadline preflight passed all 30 tests. The long-review scenario
checks both paging key pairs, unchanged answers, original-buffer restoration,
and absence of a child before approval. After exact `yes`, it observes the child
PID and a diagnostic from the running server, then checks that the process exits
after `lsp-stop`, before quitting the editor. The full run also includes the
previously corrected rejection fixture and both exact-text wide-character
rendering scenarios. These results supersede the earlier partial PTY reruns,
not the author's outstanding real-terminal acceptance checks.

The source suite also ran outside the Nix sandbox, using the declared SBCL 2.6.7
and an explicit `CL_SOURCE_REGISTRY` containing this checkout and the declared
Nix dependencies, including the patched terminal renderer:

```sh
sbcl --script run-tests.lisp
```

It exited 0 with 1,509 passes, no skips, and no failures or errors out of 1,509
tests. This exercises the three cases skipped in the sandbox; it does not
establish Linux behavior or replace author acceptance.

### Linux CI verification

[CI run 38114178710](https://github.com/nerima-lisp/loom/actions/runs/38114178710)
checked commit `3dbc8a11d999ccd2e6a8d1ffec1d25d965beaa9a` on x86_64-linux.
Both jobs completed successfully. The workflow ran:

```sh
timeout --signal=TERM --kill-after=15s 1800s nix flake check --print-build-logs
nix build .#default --print-build-logs
timeout --signal=TERM --kill-after=15s 600s nix run .#e2e
```

All six flake checks passed: build, tests, formatting, strict documentation,
structural lint, and coverage. Both test and coverage runs reported 1,506 passes,
three sandbox skips, and no failures or errors out of 1,509 tests. Coverage was
20,081/20,991 expressions (95.66%) and 1,917/2,042 branches (93.88%). Structural
lint inspected 442 Lisp and ASDF files without errors; formatting changed no
files. The workflow's diff-hygiene check also passed.

The PTY job built the executable from the same commit and passed all 117
scenarios, covering all 120 registered commands with none uncovered. Its
deadline preflight passed all 30 tests. This includes the real-server LSP
scenarios and the wide-character rendering scenarios described above.

Together with the preceding aarch64-darwin results, this establishes the two
automated platform gates for this source revision. The author's real-terminal
[acceptance checklist](daily-driver-checklist.md) remains unrun; these results
do not clear that release gate.

### Release archive validation

The archive verifier now checks the digest against the exact archive basename
and copies only the expected regular files into a private directory. It rejects
duplicate or unexpected members, traversal paths, links, special files, and
sparse files before extraction. Archive ownership and executable or special
permission bits are not restored. Packaging refuses existing artifacts,
including dangling symbolic links.

On aarch64-darwin with Python 3.9.6, the following run passed all 25 tests; exit 0:

```sh
python3 -B t/release/test-archives.py -v
```

The known-good controls include GNU and PAX archives, reversed member order,
and an archive produced by the packaging script. The packaging fixture replaces
`nix-store` with a checked stub; this run does not establish real closure import
or offline startup.

The same dangling-link cases were also run against the preceding published
packaging script without changing the working copy:

```sh
LOOM_PACKAGE_REVISION=1c2a2600ff40bd91396749570d8381d9bea75667 \
  python3 -B t/release/test-archives.py -v \
  PackageTests.test_dangling_directory \
  PackageTests.test_dangling_archive \
  PackageTests.test_dangling_checksum
```

That comparison exited 1: the directory case passed, but the archive and
checksum cases created their dangling links' targets. Both cases pass with
the current script and leave the target absent.

The release workflow checks out an explicit version tag, records the verified
commit, and builds that commit rather than resolving the tag again. Before
creating a draft release, it checks the live remote tag against the verified
commit. Shell syntax, ShellCheck, and actionlint passed; these static checks do
not establish a live release run. The author's real-terminal acceptance remains
required before release.

### Lower-level terminal library gate

The full `cl-tty-kit/test` system initially failed to load because it still
depended on the former `cl-prolog` system and package. No tests ran in that
attempt. The compatibility patch updates the test dependency and package
references to `cl-prolog-kit`; it does not change the test assertions. Prolog
and the test runner are check-only dependencies, not runtime dependencies.

The `cl-tty-kit` flake check loads the entire test system and calls
`cl-weave:run-all` without a test filter. An empty selection is a failure.
The upstream suite's 120-second timeout is retained, with the script check's
600-second process limit and 30-second termination grace period.

[Linux CI for `7f7fdb8d9434dd96debd059b99de7344162c7076`](https://github.com/nerima-lisp/loom/actions/runs/38121695300)
completed successfully:

- `nix flake check --print-build-logs`: all seven checks passed. The lower-level
  suite passed all 1,696 tests, with no skips, failures, or errors. Loom's test
  and coverage runs each passed 1,506 tests and skipped three out of 1,509.
  Coverage was 20,081/20,991 expressions (95.66%) and 1,917/2,042 branches
  (93.88%).
- `nix run .#e2e`: the deadline preflight passed all 30 tests. All 117 PTY
  scenarios passed, covering all 120 registered commands with none uncovered.
- `python3 -B t/release/test-archives.py -v`: all 25 tests passed.
- The offline archive job packaged the real closure, restored it into an empty
  store, verified closure completeness and its profile GC root, and started the
  restored executable without network access.

All three CI jobs exited successfully. These Linux results do not establish
the author's real-terminal acceptance or a completed release.

On aarch64-darwin, the same lower-level check failed in three unchanged
attempts:

```sh
nix build path:.#checks.aarch64-darwin.cl-tty-kit --no-link --no-update-lock-file --print-build-logs
```

All attempts exited 1 with `test suite timed out after 120 seconds` during
compilation. None produced a test-count summary, so none establishes a
passing suite or a test-case regression. The timeout covers loading the test
system as well as running it. The host had high load during these attempts;
its contribution to the timeout is unverified. No timeout or assertion was
changed. These attempts did not clear the Darwin lower-level gate. A subsequent
passing run is recorded below; the author's real-terminal acceptance remains
outstanding, and release has not proceeded.

### Release guard corrections

The push-triggered release now checks out the event commit and verifies that
the checkout matches it before recording the build revision. Manual runs still
resolve the requested tag once. Both trigger paths use the same per-tag
concurrency group, and the live remote tag check remains before draft creation.

Archive validation now requires the expected numeric version and compares the
restored executable's complete version output with that exact line. The previous
check accepted a different numeric version and extra output; isolated fixtures
reproduced both defects before the correction. Both workflow callers supply the
expected version.

Draft creation refuses a tag that already has a release. It uses create-only
GitHub CLI operations and exact asset paths rather than updating an existing
release or replacing its assets. Release-list and creation errors remain fatal.
The remote-tag check is not an atomic guarantee against an external tag update
between that check and creation.

Local checks on aarch64-darwin passed:

```sh
bash -n scripts/test-release.sh
python3 -B t/release/test-archives.py -v
python3 -B t/release/test-workflow.py -v
```

Each command exited 0. The archive suite selected and passed all 30 tests; the
workflow suite selected and passed all 11 tests. The new cases execute the real
archive script or workflow shell bodies with isolated Nix, Git, and GitHub CLI
fixtures. They do not establish real Linux store restoration or live GitHub
release behavior. The Linux CI results below cover real store restoration on
the corrected revision. No release was created, published, or overwritten during
validation.

The following static checks also exited 0:

```sh
nix run nixpkgs#actionlint -- .github/workflows/release.yml .github/workflows/ci.yml
nix run nixpkgs#shellcheck -- scripts/test-release.sh
paredit --dry-run inspect check --file scripts/check-cl-tty-kit.lisp
```

An independent source review found no additional concrete implementation defect
in the release corrections. The fixtures for `.github/workflows/release.yml` and
`.github/workflows/ci.yml` execute extracted shell bodies, not GitHub's checkout
expressions, output wiring, permissions, or job scheduling. Those connections
were inspected in the workflow files. The CI workflow subsequently ran on
GitHub; the release workflow itself has not been invoked for these corrections.

### Darwin lower-level verification

The lower-level check now logs test-system loading and compilation progress before
running the full suite. Its 120-second timeout still covers loading and execution;
the selected suite, assertions, and rejection of an empty suite are unchanged.

```sh
nix build path:.#checks.aarch64-darwin.cl-tty-kit --no-link --no-update-lock-file --print-build-logs
```

This run exited 0 after reporting 1,696 passed, zero skipped, zero todo, zero
failed, and zero errored, out of 1,696 tests. Both compilation and execution
completed inside the existing gate. This result clears the Darwin lower-level
check for the diagnostic change; it does not establish the cause of the earlier
timeouts or validate the release corrections on Linux.

### Linux CI on the corrected revision

[CI run 38130828081](https://github.com/nerima-lisp/loom/actions/runs/38130828081)
completed successfully on `1e30fd01b66bfa50ebe5199dbfd9c19fa813813b`.
All three jobs passed: sandboxed checks, real PTY E2E, and offline archive
restoration. The following commands exited 0 in those jobs:

```sh
python3 -B t/release/test-archives.py -v
python3 -B t/release/test-workflow.py -v
timeout --signal=TERM --kill-after=15s 1800s nix flake check --print-build-logs
nix build .#default --print-build-logs
timeout --signal=TERM --kill-after=15s 600s nix run .#e2e
bash scripts/package-release.sh result loom-ci-x86_64-linux "$RUNNER_TEMP/dist"
sudo env "PATH=$(dirname "$(command -v nix)"):/usr/bin:/bin" \
  bash scripts/test-release.sh "$RUNNER_TEMP/dist/loom-ci-x86_64-linux.tar.gz" "$version"
```

The archive and workflow fixture suites passed 30 and 11 tests respectively.
The lower-level suite passed all 1,696 tests without skips. The Loom suite passed
1,506 tests and skipped three real-child-process cases in the sandbox: terminal
session output, LSP session lifecycle errors, and LSP transport roundtrip. There
were no failed or errored tests. The coverage run selected the same suite and
reported 20,081/20,991 expressions (95.66%) and 1,917/2,042 branches (93.88%).

Outside the sandbox, the E2E preflight passed 30 tests and all 117 PTY scenarios
passed. The manifest comparison reported 120/120 commands covered and none
uncovered. This is separate evidence from the sandboxed child-process skips.

The archive job packaged 29 store paths, restored the complete closure into an
empty store, verified the profile GC root, and started the restored executable
offline on Linux. Its version check compared the complete output against the
source version, `0.1.0`; the help output contained `Usage: loom [PATH]`.

### Darwin verification on the corrected revision

The real PTY E2E run used the same corrected source revision:

```sh
nix run path:.#e2e --no-update-lock-file
```

It exited 0 after passing all 30 preflight tests and 117 PTY scenarios. The
manifest comparison reported 120/120 commands covered and none uncovered.

The full Darwin check did not pass on its first run:

```sh
nix flake check path:. --no-update-lock-file --print-build-logs
```

It exited 1. The Loom suite reported 1,505 passed, three skipped, one failed,
and zero errored, out of 1,509 tests. The failure was `MAIN CLI integration >
passes process arguments to cl-cli and exits successfully`, which exceeded the
unchanged 40-second per-test limit after 40.315 seconds. The test source is
unchanged from the preceding revision. This result does not establish a code
regression or an environmental cause. The interrupted coverage check is not a
passing result.

An isolated rebuild of the same immutable test derivation also exited 1 after
the same case exceeded its limit at 40.251 seconds. Outside the Nix sandbox,
both the isolated CLI cases and the complete suite passed with the pinned SBCL,
an empty home directory, and the same dependency registry. A sandbox diagnostic
run with child-start, source-registry, and system-load tracing then passed. That
instrumented run was not used to clear the production gate.

After these probes, the unmodified test and coverage derivations were rebuilt:

```sh
nix build '/nix/store/2cbxjyph3i5kd2m4pb1c5qyn4f6pakym-loom-test-0.1.0.drv^*' --no-link --print-build-logs
nix build '/nix/store/054g2q9ikpd00s0752gpjgpp6460s1bw-loom-coverage-0.1.0.drv^*' --no-link --print-build-logs
```

Both exited 0 on the corrected source revision. Each selected all 1,509 tests
and reported 1,506 passed, three skipped, zero failed, and zero errored. The
previously failing CLI case passed in 1.363 seconds in the uninstrumented test
run. Its assertions and 40-second limit were unchanged. The coverage run
reported 20,085/20,995 expressions (95.67%) and 1,917/2,042 branches (93.88%),
wrote its HTML report, and completed successfully. These passing rebuilds do
not explain the earlier timeouts; no timing-related production change was made.

The full Darwin check was then repeated with the updated verification record.
The same `nix flake check path:. --no-update-lock-file --print-build-logs`
command exited 0, reporting all eight checks passed. The Loom and coverage
checks each passed 1,506 tests with three skips, zero failures, and zero errors;
the CLI case passed in 1.978 seconds in the test check. The parser check read
443 Lisp files without errors, and the configured Nix formatter completed
without changes. That formatter does not check Markdown. Linux results above
are from the separate CI run, not from this Darwin invocation.

The author's eleven real-terminal acceptance rows remain `Not run`. Automated
checks do not establish Japanese IME usability or author acceptance. No draft
or published release has been created.
## 5. W0-1 仕様書コミット後の基線

コミット `5f24574071e69b053b65f2f15cfe770ee2b37b3f` で `docs/src/notes/requirements-modern-editor.md` を `origin/main` に反映した。この文書を実機基線として、macOS arm64で `.#default` のバイナリを実PTYから観測した。アプリ、テスト、ハーネスの変更はない。

仕様2.2にある端末縮小後の自動再描画は再現しなかった。確認条件と結果は「仕様2.2の維持項目」に記録した。

### ビルドと自動テスト

| コマンド | 結果 |
|---|---|
| `nix build .#docs --print-build-logs` | exit 0。生成HTMLを確認した。 |
| `nix build .#default --no-link --print-out-paths` | exit 0。 |
| `nix flake check --print-build-logs` | exit 1。通常のLoomテストは1,506件成功、3件skip。同じCLIテストは39.643秒で成功した。Coverage側は1,505件成功、3件skip、1件error。Coverageでは`MAIN CLI integration > passes process arguments to cl-cli and exits successfully`が60.232秒でタイムアウトした。`t/package.lisp`はテスト期限を40秒、`t/integration/main-cli-test.lisp`は子プロセス期限を60秒に設定している。Coverageがテスト期限を越えて実行した理由は未特定で、どちらの上限も変更していない。実行時は16コア環境でload averageが108だったと操作者から連絡があった。高負荷下のタイムアウトとして記録する。失敗時点の`uptime`値は採取していない。節4の40.315秒の結果は別実行である。 |
| `nix run .#e2e` | exit 0。事前テスト30件、PTYシナリオ117件が成功し、コマンド網羅は120/120。実行時間は約108.8秒。シナリオのタイムアウトはなかった。 |
| `nix develop --command sbcl --script run-tests.lisp` | 未完了。31分待ってもNixクライアントはdaemonからの応答を待ち、SBCLは起動しなかった。起動したジョブにSIGTERMを送り、ラッパーはexit 1（`interrupted by the user`）で終了した。テストは未実行。 |

E2Eと起動計測は16コアのマシンに別プロジェクトのビルドが並行する高負荷下で行った。E2E開始時の`uptime`は`1:51 up 2 days, 16:08, 1 user, load averages: 98.76 88.10 66.57`、終了時は`1:53 up 2 days, 16:10, 1 user, load averages: 74.13 83.94 67.66`だった。E2Eシナリオにタイムアウトはなく、単独再実行はしていない。

### D1〜D17の実機観測

| ID | 基線で観測した結果 |
|---|---|
| D1 | ↓、→、End、Home、Delete、PgDnで移動せず、カーソルは行頭に残った。続けて入力した`X`は行頭に入った。再現。 |
| D2 | `XY`の後のC-x C-uは初回に変化せず、2回目で戻った。`X`、RET、`Y`の後に2回押すと`X`と改行が残った。M-x undoも同様。再現。 |
| D3 | 200行ファイルの先頭でC-vを3回押しても、M-x `scroll-up-command`を実行しても先頭行に残った。再現。 |
| D4 | SGRマウス入力1件で`TYPE-ERROR`となり、exit 1。再現。 |
| D5 | 同一ファイルを開き直すとディスク内容の別バッファが開き、未保存の旧バッファは残った。C-x bの候補名はどちらも`f.txt`。再現。 |
| D6 | マウスとブラケットペーストの端末モードは有効にならず、貼り付けたTABは空白1つになった。再現。 |
| D7 | TABは1セルで表示された。結合文字の後のカーソル列が描画とずれ、ZWJ絵文字は`👩`だけ表示した。再現。 |
| D8 | RETでLisp、Nixのどちらも自動インデントしなかった。再現。 |
| D9 | Markdownの`# hello`でM-;を押して保存してもファイルは`# hello\n`のままで、コメントにならなかった。再現。 |
| D10 | find-fileのTABは曖昧なパス候補を絞らなかった。M-xでは`save-bu`が`save-buffer`に補完された。再現。 |
| D11 | 保存後の`Wrote`表示とM-w後のOSC 52はなかった。内部kill ringのコピーと貼り付けは動作した。再現。 |
| D12 | C-zは何も起こさなかった。SIGTSTPで停止したとき端末はcookedになったが、SIGCONT後にrawへ戻らなかった。再現。 |
| D13 | 5,000行での1キー応答中央値は2バッチで0.0797秒、0.0369秒。20,000行では0.2849秒、0.1627秒。両バッチで行数の多い側が遅く、再現。 |
| D14 | 存在しないファイル、`+2`、`+2:3`、複数パスはいずれもexit 64。再現。 |
| D15 | M-x `kill-loom-abort`は利用できず、SIGTERMではexit 0。再現。 |
| D16 | 不正UTF-8はexit 70。CRLFファイルの編集後は`ab\rZ\ncd\r\n`になった。再現。 |
| D17 | initエラー、非TTY stdinはいずれもexit 1。SIGHUP後に端末のICANON/ECHOは無効のまま。再現。 |

D13と起動の時間値は高負荷下の参考値である。起動は5回ずつ2バッチ測定し、中央値は0.1361秒と0.4308秒、10サンプル全体の中央値は0.1819秒だった。NFR-02の上限0.3秒をバッチごとの中央値がまたいだため、安定した合否は判定しない。仕様2.2の記録値0.11秒とも単純比較しない。起動計測前後の`uptime`は`1:51 up 2 days, 16:08, 1 user, load averages: 100.87 88.88 67.10`から`1:51 up 2 days, 16:08, 1 user, load averages: 106.49 90.24 67.71`だった。

D13の測定中に採った`uptime`は次のとおり。すべて高負荷下の測定である。

| データ量とバッチ | 測定前後の`uptime` |
|---|---|
| 5,000行、第1 | 前後とも`1:51 up 2 days, 16:08, 1 user, load averages: 106.49 90.24 67.71` |
| 20,000行、第1 | `1:51 up 2 days, 16:08, 1 user, load averages: 106.49 90.24 67.71`から`1:52 up 2 days, 16:08, 1 user, load averages: 106.77 90.57 67.96` |
| 5,000行、第2 | 前後とも`1:52 up 2 days, 16:08, 1 user, load averages: 106.77 90.57 67.96` |
| 20,000行、第2 | 前後とも`1:52 up 2 days, 16:08, 1 user, load averages: 106.77 90.57 67.96` |

### `docs/src/notes/requirements-modern-editor.md` の2.2にある維持項目

| 項目 | 結果 |
|---|---|
| 保存してGit commit、保存せず終了、確認で`d`を選ぶフロー | 成功。破棄後も既存コミットメッセージとclean状態を保った。 |
| 一時Gitリポジトリで`git rebase -i`のコミットdrop | 成功。対象コミットとファイルだけが履歴から外れた。 |
| crontab型の待機と読み戻し | 成功。親プロセスはLoom終了を待ち、編集後の内容を読み戻した。 |
| 既存ファイルへの保存 | inode、600/755のmode、symlink、hardlinkを維持し、追加ファイルを作らなかった。成功。 |
| BOMと末尾改行なしの保存 | 元のバイト列を維持した。成功。 |
| 80x24から60x12への端末縮小 | TIOCGWINSZで12x60を確認したが、キー入力前のPTY出力は0バイトで再描画しなかった。仕様2.2を再現せず。 |
| 起動時間 | 上記の高負荷計測を記録。 |
## W0-2: PTY E2E harness

The pre-change source at `071c407` passed 117/117 PTY scenarios and reported
120/120 commands covered with `HOME=$(mktemp -d) nix run .#e2e` (exit 0). The
pre-rebase source commit `e41d392` passed 118/118, including the new
`harness resize and typed observations` self-test, with
`env HOME=$(mktemp -d) nix run .#e2e` (exit 0). The rebase added the
`runtime/command-trace` scenario from `origin/main`. The final run on source
commit `8f0958e` passed 119/119 scenarios and covered 120/120 commands with the
same command (exit 0). All 117 baseline scenarios remained passing.

After a later fetch/rebase of `origin/main`, the same command again passed
119/119 scenarios and covered 120/120 commands (exit 0).

The harness self-test checked the actual PTY window size `(6, 80)`, terminal
cell attributes, file bytes, and raw CSI output in `output.pty`. Its result JSON
records each observation's type, actual value, expected value, and pass state;
examples include screen text, cell attributes, file bytes, external state, and
PTY output. In the final run, the artifact directory printed by the command
contained `harness-resize-and-typed-observations-2ddeaf1104/result.json`,
`output.pty`, and `trace.jsonl`; the trace file held three records for
`newline`, `save-buffer`, and `save-buffers-kill-terminal`. The
`runtime/command-trace` scenario separately checked these records in order:
`forward-char/key/1`, `execute-extended-command/key/2`,
`backward-char/mx/3`, and `save-buffers-kill-terminal/key/4`.

`keys.RET` changed the default Enter byte from LF (`\n`) to CR (`\r`). The
pre-rebase 118-scenario and final 119-scenario full runs passed with CR.

One intermediate run failed `project file commands`. The screen then showed
only a prefix of the project-root prompt, and the same scenario failed when run
alone. The scenario previously waited for that prefix; it now waits for the
full expected root. Its isolated rerun and the final full run passed. This
supports a prompt-render timing race diagnosis. No timeout was extended.

The `--benchmarks` mode reports measurements without failing against the NFR
targets. NFR-01 targets opening a 100,000-line, 5 MB file within 1.0 second and
input-to-redraw p95 within 50 ms; NFR-02 targets the first screen within 0.3
second. Redraw p95 uses 25 cursor-move samples. Each scenario kept the existing
10-second total and 5-second execution deadlines. Numerical results below are
**高負荷下の参考値** and do not characterize Loom performance. The operator
reported load average 108 on 16 cores earlier in the run.

| Run | Measurement | Value |
| --- | --- | --- |
| 1 | Startup to first screen (NFR-02) | 0.0736 s (**高負荷下の参考値**) |
| 1 | Redraw p95 (NFR-01, 25 samples) | 1.0042 ms (**高負荷下の参考値**) |
| 1 | Open 100,000-line / 5 MB file (NFR-01) | No valid measurement; 5-second execution deadline expired |
| 2 | Startup to first screen (NFR-02) | 0.0793 s (**高負荷下の参考値**) |
| 2 | Redraw p95 (NFR-01, 25 samples) | 0.8956 ms (**高負荷下の参考値**) |
| 2 | Open 100,000-line / 5 MB file (NFR-01) | No valid measurement; 5-second execution deadline expired |
| Isolated retry | Open 100,000-line / 5 MB file (NFR-01) | No valid measurement; 5-second execution deadline expired |

Two runs of `env HOME=$(mktemp -d) nix run .#e2e -- --benchmarks` exited 1 when
the large-file benchmark timed out; a separate run of that scenario alone also
exited 1 at the unchanged 5-second execution deadline. Because each report run
stops at that failure, neither produced a combined benchmark summary; the
completed startup and redraw values remain in their per-scenario result files.
These timeouts do not establish whether the NFR-01 open target passes or fails.

For the post-rebase source code, the following checks exited 0; the docs build
was repeated after the final ledger edit:

```sh
PYTHONPATH=t/e2e python3 -m unittest -v test_cli test_deadline test_harness
python3 -m py_compile t/e2e/loom-test.py t/e2e/loom_e2e/*.py t/e2e/scenarios/*.py t/e2e/test_cli.py t/e2e/test_harness.py
env HOME=$(mktemp -d) nix run .#e2e
nix flake check --print-build-logs
nix build .#docs --no-link --print-build-logs
```

The Python unit suite passed all 58 tests. The final PTY run passed 119/119
scenarios and covered 120/120 commands. After the later rebase, the Nix flake
check also exited 0 with all checks passing. Its default and coverage checks
each passed 1504 tests, skipped 3, and reported 0 failures and 0 errors; coverage
measured 20340/21278 expressions (95.59%) and 1946/2082 branches (93.47%).

An earlier `nix flake check --print-build-logs` exited 1 after two tests exceeded
their existing 40-second test timeout: `%run-loom` / `enables and restores raw
mode against a real terminal descriptor, then returns 0` and `MAIN CLI
integration` / `passes process arguments to cl-cli and exits successfully`.
The isolated retry `nix build .#checks.aarch64-darwin.default --no-link
--print-build-logs` then passed; those tests completed in 0.148 and 13.945
seconds, respectively. A subsequent full flake check exited 0 with all seven
checks passing. The later post-rebase flake check also exited 0. This sequence
does not establish why the first run timed out; no timeout was changed.

The full check warned that `x86_64-linux` was omitted on this Darwin host and
that the E2E app has no `meta` attribute. Nix's `auditTmpdir` hook has printed a
broken pipe from `find` and a segmentation fault in its file-classifier
pipeline during a `loom` package install and docs installs. In the final check,
one docs install printed this fault; a later docs install emitted no such
diagnostic, and the coverage logs did not. The builds and full checks exited 0,
but completion of the affected scans is unverified. The cause was not
established.

### Independent review follow-up

The static review of source `5fc06fc` is resolved below. The runner's `status`
records whether a scenario completed without an exception. W0-4 must use
`observation_class == "effect-verified"` as its sole acceptance gate;
`exit-code-only` is one of the observation classes and does not pass that gate.

| Finding | Status | Resolution |
| --- | --- | --- |
| Precondition observations | Done | `Session` wait helpers and the PTY-size self-check record `purpose=precondition`. All ten `probe_command` scenarios in the final run completed with `observation_class: exit-code-only`. |
| PTY resize redraw | Done | The self-test expands the PTY from 8 to 12 rows, drains already available PTY bytes before resizing, and checks the mode line at the new row after input triggers a redraw. With the redraw call in `src/application/event-loop.lisp` temporarily disabled, the same scenario failed on a blank mode-line row. The temporary source change was restored. |
| Observation API | Done | Public `observe_*` methods no longer accept `passed=`. Screen-text observations read the selected screen region or row from `Session.screen`; assertions use the observation result. |
| Trace collection | Closed by W0-3 | W0-3 removed the wrapper from `t/e2e/scenarios/trace.py` and records `session.trace_bytes`. The final `runtime/command-trace` result is `effect-verified` and records the expected 13 trace events. |
| Result identity | Done | Every runner-produced `result.json` contains `binary_realpath` and `declared_commands`. All 120 `binary_realpath` values pointed to executable files, and all 120 declared command lists were present. |
| Scenario failure handling | Done | The runner catches scenario `Exception` values at the scenario boundary, saves a failed result, and continues the suite. CLI tests cover `ValueError`, `KeyError`, `TypeError`, and `RuntimeError`. |
| Duplicate scenario names | Done | The registry raises `ValueError` when a duplicate scenario name is decorated. |
| PTY output classification | Done | `pty_output` is an effect observation. The four CLI scenarios were `effect-verified`; `observation_class` is the single verification criterion. |
| Trace line counts | Done | Each `Session` observation method snapshots `trace_lines` when called, before internal reads and matching. This is a conservative boundary: trace rows appended after the method begins cannot be counted for that observation. The resize self-test recorded counts from 0 through 5 alongside a five-line trace. |

### Other review cleanup

`expected=None` now means an absent file, with a
sentinel distinguishing no expectation. Observation matching is shared with
assertions. Unused `keys.NAMED` and `registry.covered_commands` were removed.
`layout.validate_dimensions` is shared by the session, PTY, and screen. The
benchmark report imports its deadline values from `deadline.py`. Module-level
key byte constants were removed; `Session.key` resolves each name through its
selected terminal profile.

The normal resize self-test passed alone with the unchanged 5-second execution
budget: `env HOME=$(mktemp -d) nix run .#e2e -- --only 'harness resize'`
returned 0 for 1/1 scenario. The negative run disabled
`%render-event-loop-frame` temporarily and ran the same scenario alone. It
returned 1 after the row-10 mode-line observation remained blank. The harness preflight passed 70/70 tests
in both runs. No timeout was extended.

The final full run after rebasing on `origin/main` used
`env HOME=$(mktemp -d) nix run .#e2e` and returned 0: 120/120 scenarios passed
and 120/120 commands were covered. The baseline classified 114 scenarios as
`effect-verified`; the final run classified 18 that way. Of the 114 baseline
scenarios, 100 now have a stricter classification: 97 are `exit-code-only` and
3 are `effect-unverified`. They still passed functionally; their lane owners
must add explicit effect observations in W3. The final run also classified the
new `--dump-catalog` scenario as `none` because it recorded no observations.

The 97 transitions to `exit-code-only` are:

- Other: `ansi-wide-diff`, `ansi-wide-full`, `bookmarks set jump list delete`, `file-tree toggle`, `keyboard macro`, `major mode editing`, `numeric prefix`, `project find file`, `project search`, `register copy and insert`, `register point and jump`, `workspace switching`.
- Editing: `editing/auto-save-current-buffer`, `editing/auto-save-mode`, `editing/backward-kill-word`, `editing/comment-line`, `editing/delete-backward-char`, `editing/delete-char`, `editing/indent-for-tab-command`, `editing/kill-line`, `editing/kill-region`, `editing/kill-ring-save`, `editing/kill-sexp`, `editing/kill-word`, `editing/mark-whole-buffer`, `editing/narrow-to-region`, `editing/newline`, `editing/open-line`, `editing/redo`, `editing/replace-string`, `editing/set-mark-command`, `editing/toggle-auto-save`, `editing/toggle-read-only`, `editing/undo`, `editing/widen`, `editing/write-file`, `editing/yank`, `editing/yank-pop`.
- LSP: `lsp/completion`, `lsp/completion-success`, `lsp/diagnostics`, `lsp/find-definition`, `lsp/find-definition-success`, `lsp/find-definition-unicode`, `lsp/pop-definition`, `lsp/start`, `lsp/stop`.
- Macros: `macros/eval-buffer`, `macros/eval-expression`, `macros/execute-extended-command`.
- Movement: `movement/backward-barf-sexp`, `movement/backward-char`, `movement/backward-sexp`, `movement/backward-slurp-sexp`, `movement/backward-up-list`, `movement/backward-word`, `movement/beginning-of-buffer`, `movement/down-list`, `movement/end-of-buffer`, `movement/exchange-point-and-mark`, `movement/forward-barf-sexp`, `movement/forward-sexp`, `movement/forward-slurp-sexp`, `movement/forward-word`, `movement/fullwidth cursor column`, `movement/goto-line`, `movement/isearch-backward`, `movement/isearch-forward`, `movement/move-beginning-of-line`, `movement/move-end-of-line`, `movement/next-line`, `movement/previous-line`, `movement/raise-sexp`, `movement/scroll-down-command`, `movement/scroll-up-command`, `movement/search-backward`, `movement/search-forward`, `movement/set-mark-command`, `movement/splice-sexp`, `movement/wrap-round`, `movement/wrapped next-line`.
- Tooling: `tooling/format-current-buffer`, `tooling/format-on-save-mode`, `tooling/git-diff`, `tooling/git-diff-staged`, `tooling/git-stage-file`, `tooling/git-status`, `tooling/git-unstage-file`, `tooling/pipe-command`, `tooling/set-format-command`, `tooling/terminal`, `tooling/terminal-stop`.
- UI: `ui/execute-extended-command`, `ui/help`, `ui/keyboard-quit`, `ui/save-buffers-kill-terminal`, `ui/toggle-truncate-lines`.

The three `effect-unverified` transitions are `lsp/trust-review`,
`session save and load`, and `startup without path`. Their observations include
effect types without a passing expected value. `runtime/command-trace` remains
`effect-verified`: W0-3 now observes the nonempty trace. The `startup directory`
scenario was already `exit-code-only` in the baseline and is not part of the
100 transitions.

After the final rebase, `nix flake check --print-build-logs` exited 0 with all
eight checks passing on aarch64-darwin; Nix omitted x86_64-linux. The coverage
derivation reported 1507 passed, 3 skipped, and 0 failed or errored.

### W0-4 path generation and coverage report

The W0-4 report evaluated source commit
`d22873984258842af0271716b88d9818b34ac4de` on aarch64-darwin. The command
`env HOME="$(mktemp -d)" nix run .#e2e` exited 0. Its preflight ran 135 Python
tests; all passed. The runner prints the temporary artifact directory and the
`path-coverage.json` path within it.

The eleven real-terminal acceptance rows in the
[author checklist](daily-driver-checklist.md) remain `Not run`.

All 120 E2E scenarios completed without an exception (`status=passed`), and
command coverage was 120/120. These counts do not mean that path coverage
passed. The W0-2 observation contract excludes preconditions from classification;
only scenarios classified as `effect-verified` qualify for path acceptance.
The classifier removes `purpose=precondition` observations first. It reports
`none` when none remain, `effect-verified` when one or more effect types remain
and every effect has an `expected` value with `passed=true`, and
`effect-unverified` when any effect lacks either condition. With no effect
types, only `exit_code` observations produce `exit-code-only`; other remaining
types produce `observations-only`. Effect types are `screen_text`, `cell_attrs`,
`cursor`, `file_bytes`, `external_state`, and `pty_output`; the implementation
is in `t/e2e/loom_e2e/results.py`.

| Scenario observation class | Scenarios |
| --- | ---: |
| `none` | 1 |
| `effect-verified` | 18 |
| `effect-unverified` | 3 |
| `exit-code-only` | 98 |
| `observations-only` | 0 |

The generator applies rules R1–R8 from
`docs/src/notes/requirements-modern-editor.md` section 7.2 to the JSON from
`bin/loom --dump-catalog`, then compares required paths with every `t/paths.sexp`
under the repository. At the time of this run, the root `t/paths.sexp` was the
only ledger file.

The generated catalog contains 750 required paths. The report marked 0 as
passing and 0 as excluded. It lists 749 paths as `not-in-ledger` and one as
`no-observation`; the JSON report includes all 750 failed path IDs in
`missing_paths`.

The `no-observation` row is the generated R1 key path for `save-buffer` in
`file and buffer commands`. The scenario is globally `effect-verified`, but its
`file_bytes` observation is a precondition because `wait_for_file` records file
waits that way, including the wait after saving. The scenario types `!` into
the buffer before invoking `save-buffer`; the resulting screen text `!beta`
would still appear if saving wrote nothing. The screen observation therefore
cannot verify the file effect declared by the `:observe (:file_bytes)` field in
the `t/paths.sexp` path ledger. No non-precondition `file_bytes` observation is
available. The scenario is unchanged; W3-3 must add the file-effect assertion.

Current trace rows contain `command`, `route`, `seq`, and `pid`, but no `entry`.
A key path therefore cannot pass the trace check until its exact entry is
recorded. The missing entry is not this path's current failure reason because
it fails the declared-effect-type check first.

The one matched path fails the declared-effect check before trace attribution,
so the attribution-window rule adds no further count change in this run. The
remaining 749 paths fail ledger lookup.

The report attributes an observation only to the latest traced command included
by its `trace_lines` snapshot. That command's trace row must match the path's
route and, when available, entry; the next trace row closes the attribution
window. Every command listed by the generated path needs a declared effect
observation in its own window. The `t/paths.sexp` ledger's `:observe` types
define which observations can satisfy that requirement. This prevents a screen
value that already existed before `save-buffer`, or an effect from only the last
command in a multi-command scenario, from covering the path.

Each `Session` observation method snapshots `trace_lines` when called. For
values read inside the method, this is before sampling, matching, and
serialization. A trace row appended after that snapshot is excluded, even if
it appears before the observation record is serialized.
The report therefore fails closed when the snapshot cannot prove that a target
command was already traced; it does not infer ordering from a later file read.

| Rule | Required | `not-in-ledger` | `no-observation` |
| --- | ---: | ---: | ---: |
| R1 | 218 | 217 | 1 |
| R2 | 211 | 211 | 0 |
| R3 | 210 | 210 | 0 |
| R4 | 8 | 8 | 0 |
| R5 | 60 | 60 | 0 |
| R6 | 32 | 32 | 0 |
| R7 | 7 | 7 | 0 |
| R8 | 4 | 4 | 0 |

Lane IDs refer to the W3 ownership table in section 11.6 of
[`requirements-modern-editor.md`](requirements-modern-editor.md#116-w3).

| Lane | Required | `not-in-ledger` | `no-observation` |
| --- | ---: | ---: | ---: |
| W3-1 | 9 | 9 | 0 |
| W3-2 | 20 | 20 | 0 |
| W3-3 | 42 | 41 | 1 |
| W3-4 | 125 | 125 | 0 |
| W3-5 | 3 | 3 | 0 |
| W3-6 | 62 | 62 | 0 |
| W3-7a | 25 | 25 | 0 |
| W3-7b | 103 | 103 | 0 |
| W3-8 | 62 | 62 | 0 |
| W3-9 | 40 | 40 | 0 |
| W3-10 | 175 | 175 | 0 |
| W3-11 | 84 | 84 | 0 |

On this source commit, `nix flake check --print-build-logs` exited 0 on
aarch64-darwin. All eight checks passed; the coverage derivation reported 1507
passed, 3 skipped, and 0 failed or errored. Nix omitted `x86_64-linux` and
warned that the E2E app lacks `meta`.

## W4-2 cross-platform CI and NFR reporting

The NFR thresholds remain unchanged: first screen within 0.3 seconds,
opening a 100,000-line / 5 MB file within 1.0 second, and input-to-redraw p95
within 50 ms. Startup and large-file open each use three independent trials and
the median; redraw uses 100 key-move samples (four batches of 25) and the
nearest-rank p95. There is no warm-up or retry-until-green. The median limits
the effect of one slow trial, while the fixed sample count bounds CI work. Three
trials do not characterize the full noise distribution. The NFR-01 open sample
starts at Enter after filename entry and stops when the first row marker is
visible. The existing five-second execution budget still includes file creation
and PTY setup, but those steps are outside the measured interval. If that budget
expires while waiting for the first row, the harness records the elapsed open
time as a lower bound, marks that trial incomplete, and reports the metric as
over target even when the median is at or below 1.0 seconds. A deadline before
the open attempt begins still leaves the metric missing. EOF navigation has a
separate informational measurement and no threshold. CI remains report-only
until the NFR-01 product fix is on main and the enforcement change lands
separately. Full E2E results remain required on both platforms.

Main pushes and pull requests run the Linux and aarch64-darwin flake checks,
full PTY E2E, NFR report, and release-archive jobs. W4-2 left path-coverage
reporting in report mode; W4-1 later enabled the fail-closed coverage gate for
full PTY E2E on both platforms. See [W4-1 path-coverage gate](#w4-1-path-coverage-gate).
Dispatches using `workflow_dispatch` default to both platforms and can select
Linux or Darwin to reduce diagnostic queue load. A single-platform dispatch
does not satisfy FR-V06 promotion evidence. The release workflow runs the reusable CI on the
tag-verified commit with both platforms and waits for it before publishing.
Each E2E job summary records the actual checked-out commit and, for a push,
links the pushed commit range. The platform-specific job name identifies which
environment failed. This locates the exact source range and the lane changes
visible in its commits and paths; it does not prove causality automatically if
multiple lane changes are combined in one commit or push.

The report-mode tests verify that an open trial which misses its first-row
deadline retains its measured lower bound and completion status in
`benchmarks.json`, and that it cannot count as within target. A scenario failure before a numeric sample is
available remains named in `scenario_errors` and leaves that metric missing.
The fail-closed NFR enforcement tests belong to the deferred performance-gate
change. The full local E2E harness preflight passed all 251 Python tests after
the deadline-test timing fix prompted by the Darwin failure below.

The macOS `--benchmarks` report-only run from the source tree committed as
`5272f8ea756780cf8dd20346fe3e298669bd2017` (based on
`e4b7c055b083092933a590982e7117a14c537693`) recorded open lower bounds of
4.715, 4.814, and 4.776 seconds. The first-row
marker was not observed in any trial before the existing execution deadline,
so the median remains over the unchanged 1.0-second target and all three
samples are incomplete. EOF has no sample because its navigation starts only
after the first row appears. Startup was 0.365 seconds, redraw p95 was 10.476
ms, and the D13 scenario reported an error. These working-copy measurements
are not CI evidence and do not validate the product-side open fix. The updated
local Python E2E suite passed 257/257 tests. The 251, 252, and 257 preflight
counts above refer to separate local, CI, and current-workspace snapshots.

| Run | Commit | Results |
| --- | --- | --- |
| [40604333588](https://github.com/nerima-lisp/loom/actions/runs/40604333588) | `f2eab7f47ac5ed8324ed5b6cb71ef4d977f95027` | Linux full E2E passed 1,149/1,149 scenarios and covered 147/147 commands. Startup was 0.137 s and redraw p95 was 0.908 ms. All three large-file-open trials exceeded the unchanged 5-second scenario execution deadline, so the required open metric was missing and the performance gate failed. The Linux flake check and archive passed. The three Darwin jobs stopped at the Apple Silicon system guard. |
| [40605055059](https://github.com/nerima-lisp/loom/actions/runs/40605055059) | `964d645313d1b4f007b1099dbac9c22efacdb573b` | Linux full E2E passed 1,149/1,149 scenarios and covered 147/147 commands. Startup was 0.118 s and redraw p95 was 1.830 ms. All three large-file-open trials exceeded the unchanged 5-second scenario execution deadline, so the required open metric was missing and the performance gate failed. Linux flake check and archive passed. Darwin's system guard passed in the flake job, which then exposed a release-workflow guard-test failure; the Darwin E2E and archive jobs still stopped at the system guard. |
| [40605724231](https://github.com/nerima-lisp/loom/actions/runs/40605724231) | `71c68a3013e2a7bd0e3a2bb0887b3023a2af40ee` | Linux and Darwin flake checks passed with 1,811 passed, 6 skipped, and 0 failures on each platform. The Darwin release archive passed; both archive job cards later appeared concluded. The Darwin E2E job failed during its 251-test preflight because `ScenarioDeadlineTests.test_restores_existing_handler_and_timer` attempted a 0.02-second sleep inside a 0.07-second execution budget; its performance gate was skipped. After GitHub API rate limiting, the workflow HTML showed the Linux E2E and archive jobs as concluded, but their conclusions, E2E metrics, and the overall workflow conclusion could not be confirmed. The known Darwin E2E failure already makes this run unusable as promotion evidence. |
| [40614855675](https://github.com/nerima-lisp/loom/actions/runs/40614855675) | `e4b7c055b083092933a590982e7117a14c537693` | Five of six jobs passed; the workflow failed only in Darwin PTY E2E. Linux full E2E passed 1,151/1,151 scenarios and covered 147/147 commands; path coverage reported 999 pass, 2 excluded, and 29 failing required paths. Startup was 0.122 s, redraw p95 was 1.785 ms, D13 was 38.224 ms, and all three large-file-open trials expired before producing a metric. Darwin's 252-test harness preflight passed, including the job-control tests; the log contained no `PermissionError` or `killpg` failure. Darwin full E2E failed with 1,108 passed and 43 failed scenarios: 32 execution-budget expirations, 8 buffer-origin mismatches, and 3 user-init non-TTY I/O expectation failures. Its performance report was skipped. The benchmark changes described above were not present in this tested SHA. The Darwin flake check and archive both passed. |
| [40622923555](https://github.com/nerima-lisp/loom/actions/runs/40622923555) | `acc36bdd39c6ef1762c02b3ebe97d0ec6b481cd7` | Linux full E2E passed 1,164/1,164 scenarios and covered 148/148 commands. Darwin preflight passed 260/260 tests; full E2E passed 1,134/1,164 with 30 failures. Eighteen failures were files-path expectations that compared `/tmp/...` with the screen's `/private/tmp/...`; the remaining 12 were one shell pipe case, three user-init non-TTY cases, seven clipboard cases, and one window cursor case owned outside W4-2. Linux and Darwin flake checks and both release archives passed. Darwin's log contained no `PermissionError` or `killpg` failure. |
| [40629723568](https://github.com/nerima-lisp/loom/actions/runs/40629723568) | `42ad1e19d3b99f1696c913e1aa1f70b4c71eb792` | Darwin preflight passed 261/261 tests; full E2E passed 1,152/1,164 scenarios. Failures were one save-buffer cancellation expectation showing `/tmp/...` while the screen showed `/private/tmp/...`, one W3-11 shell-pipe case, three non-TTY cases (`R7 xargs non-tty stdin`, `non-tty stdin uses /dev/tty`, and `non-tty stdout uses /dev/tty`), and seven W3-8 clipboard-yank cases. Path coverage reported 986 pass, 2 excluded, and 59 failing required paths. The Darwin performance report was skipped. Linux PTY E2E was canceled while building the default package after the job reached its 12-minute maximum, so it produced no E2E result. Linux flake check timed out after 1,800 seconds (exit 124). Linux release archive, Darwin flake check, and Darwin release archive passed. |
| [40639146526](https://github.com/nerima-lisp/loom/actions/runs/40639146526) | `a54f28a21924f2fd7cceafcd7919af2aa956ef54` | Linux flake check and full E2E passed; E2E passed 1,165/1,165 scenarios and covered 148/148 commands. Path coverage reported 1,003 pass, 2 excluded, and 54 failing required paths. Startup was 0.194 s, NFR-01 open was 0.890 s, redraw p95 was 1.773 ms, and D13 was 39.115 ms, all within their unchanged thresholds. The end-of-buffer sample reported 3.556 s, but did not observe the last line before its deadline; it remains informational. Darwin flake check and archive passed; preflight passed 261/261 tests. Darwin E2E passed 1,152/1,165 and failed 13 scenarios: `shell/pipe-command-r5-missing`; three non-TTY user-init scenarios; seven clipboard-yank paths; `file-tree-select-next`; and `split-window-below`. The corrected R2 save-buffer cancellation scenario passed. Darwin path coverage reported 990 pass, 2 excluded, and 67 failing required paths; its performance report was skipped. Linux release archive was canceled after 20m18s while `Build default package` was still running, and its restore step was skipped. |
| [40678259201](https://github.com/nerima-lisp/loom/actions/runs/40678259201) | `3bc69c8a3a262c27db0a3cf1290389b9ab450d01` | Main push CI had five of six jobs succeed and failed only in `PTY E2E (aarch64-darwin)`. Full Darwin E2E passed 1,172/1,172 scenarios (job log line 2114). The `Enforce PTY performance targets` step failed during the 264-test harness preflight in `ScenarioDeadlineTests.test_cleanup_timeout_during_pty_close_still_reaps_child` (line 2249): it raised `ScenarioCleanupDeadlineExceeded: scenario cleanup exceeded 0.1 seconds` (line 2262), followed by `TimeoutError: loom child was not reaped before the scenario deadline` from `LoomProcess.close` (line 2279). The preflight ended `FAILED (errors=1)` at lines 2282–2285, before benchmark scenarios ran. |
| [40698864547](https://github.com/nerima-lisp/loom/actions/runs/40698864547), attempts 1–2 | `b95856646d3e5692683d3b5751309fd70f2c2b1c` | The five non-Darwin-PTY jobs succeeded. Darwin attempt 1 (job 122852895789) passed 1,175/1,177 and failed `lsp/r5-typescript-success/hover-completion` and `lsp/r5-typescript-success/editing` on their 5-second execution budgets; `command-path/r1/split-window-right/key` passed. The single failed-job rerun, attempt 2 (job 122930163273), passed 1,176/1,177: both LSP scenarios passed, while `command-path/r1/split-window-right/key` failed exact screen matching for `WINDOW-COMMAND-PATH`. The failure sets did not overlap. Darwin preflight discovered and passed 264 tests on attempt 2 (`OK`); its `test_*.py` discovery includes the cleanup/reap test in `test_deadline.py`. All three scenarios passed in main Darwin CI 40685957165 (job 122829607784; 1,177/1,177). The two different failures remain unresolved intermittent E2E failures; no cause is established. The performance gate was skipped on both failed Darwin attempts. |

The cleanup-timeout integration test retains its real-timer interruption,
child-reap assertion, and closed-PTY-fd assertion. Its logical contract is
already covered by `ScenarioDeadlineTests.test_cleanup_deadline_interrupts_cleanup`,
which patches the clock and timer and asserts the exact cleanup-deadline
exception. For the real-timer test, a loaded macOS arm64 host with 16 logical
cores and 0% idle was measured over 100 trials. Each trial used an unkillable
Python PTY child and the same 0.2-second execution phase, with a roomy
2.0-second calibration cleanup reserve to avoid censoring close times. The
measured interval ran from the nominal execution deadline through successful
`LoomProcess.close()` completion, including alarm dispatch and verified child
reap/fd closure. It was 7.575 ms minimum, 10.006 ms median, 13.276 ms p90,
14.176 ms p95, 22.995 ms p99, and 23.218 ms maximum. The host load averages
were 122.55/103.50/94.10 before and 95.64/99.95/94.04 after the run; both
snapshots showed 0% idle CPU. The test now reserves 0.25 seconds for cleanup,
10.8 times the observed maximum, while retaining its 0.2-second execution
phase. All 100 calibration trials raised `ScenarioDeadlineExceeded` as
expected and ended with the child reaped and PTY fd closed.
After choosing the 0.25-second reserve, the exact integration test passed
50/50 consecutive local runs with the original child-reap and fd-close
assertions.

On local macOS, the save-buffer scenario initially expected a minibuffer path under
`/tmp/` while the screen displayed the same file under `/private/tmp/`. The revert
scenario displayed the expected initial body, but the one-shot cursor observation
read `(8, 46)` before the terminal reached the declared `(0, 0)` origin. The
feature scenario runner now resolves the expected temporary path and waits for
the declared cursor before retaining the exact origin assertion. After this
change, both selected scenarios passed, each with a 257/257 preflight and 1/1
selected scenario. Revert's prompt and result displayed `/private/tmp/` and
matched the expected strings; file contents matched exactly.

The next full CI run exposed the same spelling difference in the shared files
prompt helper, save-buffer shell scenarios, and the missing-path CLI scenario.
The test harness now resolves temporary paths before constructing prompt input
and expected strings, and filesystem assertions still target the same temporary
files. On local macOS, the selected recent-file completion passed 1/1,
the save-buffer confirmation group passed 6/6, the revert-buffer confirmation
group passed 6/6, the save-buffer shell group passed 4/4, and the missing-path
scenario passed 1/1. Each selected run passed the 260-test harness preflight.
These checks support a harness expectation mismatch, not a product file
identity defect.

Run 40629723568 exposed one more expected-string override in the R2
save-buffer cancellation scenario. It assigned `Wrote {target_path}` after the
shared helper had normalized the target. The scenario now applies the same
display-path normalization at that assignment. The CI trace showed the screen
result under `/private/tmp/` while the raw expected path began with `/tmp/`; the
exact-minibuffer wait then exhausted its five-second scenario budget. This is a
harness expectation fix; it does not change file identity or product behavior.
The local rerun of this selected case did not reach the test: `nix run` waited
on the Nix build for about 15 minutes without further output and was interrupted.
Python compilation of the changed scenario module passed separately.

The other 12 Darwin failures in run 40622923555 do not belong to this path
fix. A local reproduction of the scenario selected by
`nix run .#e2e -- --only 'user-init non-tty stdin uses /dev/tty'` failed because
the editor reported `Polling terminal input or wake pipe found an invalid
descriptor.` and the file remained unchanged. The condition is raised in
`src/application/startup-services.lisp` at line 423; this product-side issue is
left for its owning lane. The other failures were
`shell/pipe-command-r5-missing` (W3-11), seven `clipboard-yank` command paths
(W3-8), and `split-window-below` (W3-10). The Darwin preflight and CI logs
showed no job-control test failure or `killpg` permission error.

The Darwin preflight failure above came from the test harness's timing-sensitive
sleep, not from a product change. The test now performs no sleep inside the
0.1-second total / 0.03-second cleanup deadline and retains its signal-handler
and timer-restoration assertions. The targeted deadline suite passed 31/31 tests,
and the full Python E2E preflight passed 251/251 tests locally. No deadline was
extended.

A separate local full PTY run was concurrent with another session's E2E process
and had a high system load. Its 50 scenario failures are contaminated and are
not used as evidence about product behavior or the CI gate. No other session or
process was changed.

The earlier `w4-2-ci-candidate` ref at
`136af8ab4af29bd5fbb62a33f4a38f760c537275` contains the fail-closed
performance-gate invocation and is not the promotion candidate. Its
single-platform diagnostic dispatch was rejected with HTTP 403 for API rate
limiting. The replacement candidate is based on the current main tip and keeps
benchmark enforcement separate from the cross-platform CI change.

The failed large-file-open runs do not establish whether the 1.0-second target
passes or fails. A separate review stream owns the NFR-01 open issue. The
W4-2 replacement candidate reports the measurement without enforcing the
threshold; the fail-closed NFR gate will be restored after the open fix lands
and passes its threshold. Promotion still requires a fresh full E2E run on Linux and Darwin
with the corrected file-path scenarios. A one-platform dispatch is diagnostic
only and cannot substitute for both platforms in a promotion decision.

The W4-1 entry below covers path-coverage enforcement. NFR-01 threshold
enforcement remains open as recorded above.

## W4-1 path-coverage gate

Full Linux and Darwin PTY CI runs pass `--require-path-coverage`. Scenario-specific
diagnostic runs retain `--only` and do not require complete coverage. W4-2's
`--timing-report` remains enabled for both full runs.

An excluded path is accepted only when its reason is nonblank and its `file:line`
evidence is valid. The two remaining exclusions retain reasons: W3-8
`r3:yank-pop:read-only` points to
`src/application/input-routing-effects.lisp:8`, and W3-11
`r5:terminal-stop:shell:missing` points to
`packages/feature/terminal/src/infrastructure-terminal-session-runtime.lisp:94`.
These evidence references point to the statements that clear the yank context
and close the existing terminal session.

Candidate dispatch run `40830080722` and main push CI run `40874212745` both
completed all six jobs successfully on SHA
`8498ecf5be3d5a92b06e64ab7d73a53b0e9dc308`. Both runs reported the following
coverage totals:

| Lane | Required paths | W3-9 |
|---|---|---|
| Linux | 1,057 pass, 2 excluded, 0 failing / 1,059 | 79 pass, 0 excluded, 0 failures / 79 |
| Darwin | 1,057 pass, 2 excluded, 0 failing / 1,059 | 79 pass, 0 excluded, 0 failures / 79 |

The PTY preflight passed 275 tests in each platform job. The CLI regression test
in `t/e2e/test_cli.py` asserts that `--require-path-coverage` exits nonzero
when the report contains coverage gaps.
