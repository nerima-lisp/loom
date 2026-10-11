# 検証台帳

[検証計画](verification-plan.md) の基線と、実機検証で見つかった失敗ごとの処置を記録する。
数値はすべて実行した出力から転記する。未実行のものは「未実行」と書く。

Sections 1 through 3 are historical results for the commits named in each entry.
They do not establish that the current working tree passes those checks.

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
| P5 CI | 実装済み | `cb5022c` | `nix build .#default` は実測 3.73 秒、`nix run .#e2e` は実測 28.47 秒。いずれも exit 0。E2E は `110 passed, 0 failed, 110 total`、`commands covered: 120 / 120`。この実測を根拠に E2E ジョブの `timeout-minutes` は 10 とした。CI の両ジョブは未実行 |
| 統合（presentation） | 完了 | `9bbca23`, `cc0380d`, `f892bb4`, `e6ae4d5` | `nix run .#e2e` は `110 passed, 0 failed, 110 total`、`commands covered: 120 / 120`、未カバー `0`、exit 0。launchctl 経由の in-process は `1427 passed, 0 skipped, 0 todo, 0 failed, 0 errored, 1427 total`、exit 0。`nix flake check` は `all checks passed!`、exit 0。`nix build --no-link --print-out-paths .#default` は exit 0。実PTY は mode-line、C-x 2/C-x 3 の mode-line 分離、C-SPC の緑背景、M-x terminal の `pty-integration` 出力を画面ダンプで確認し、exit 0 |
| 診断可視化実機 | 完了 | `514c5a3`, `ed0b49c` | 実 `nixd` を使った一時 PTY スクリプトが exit 0。診断付き画面は mode-line に `Diag: E1 W1`、診断範囲は赤背景、リージョン重畳は緑背景と診断範囲の赤背景を同一画面で確認。LSP セッション無しと診断ゼロでは `Diag:` が無く、40 列の長い日本語名でも mode-line は `cells=40` で折り返さなかった。 |
| 要件書と slop | 完了 | `ccb2c34` | `requirements-daily-driver.md` を現行の判断記録へ書き直し、FR-000 から FR-010 の状態、対象言語、SWANK と LSP の境界、v5 永続化境界、Org の範囲を記録。dead export 7 件、冗長 docstring 3 件、roadmap 自賛 2 件、英語 em dash 4 行 / 3 ファイルを除去。 |

## 4. Uncommitted work: verification and open criteria

The table records intermediate working-source checks on aarch64-darwin, not a
released revision or the latest edits. Subsequent findings and checks follow the
table; earlier passes do not clear gates affected by later changes.

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
| Release | No commit, push, or release was performed | Current authorization covers implementation and verification only; release also requires the outstanding acceptance evidence |

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

The discovered LSP command now requires an exact `yes` after review. All 15
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

The current checkout also passed the exact PTY app on aarch64-darwin:

```sh
nix run path:.#e2e --no-update-lock-file
```

It exited 0: all 30 deadline preflight tests and all 117 scenarios passed,
covering all 120 registered commands. This confirms the current automated
terminal gate, not real-terminal input-method behavior or the cause of earlier
intermittent failures.

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

On aarch64-darwin, the same lower-level check failed twice, including one
unchanged retry:

```sh
nix build path:.#checks.aarch64-darwin.cl-tty-kit --no-link --no-update-lock-file --print-build-logs
```

Both attempts exited 1 with `test suite timed out after 120 seconds` during
compilation. Neither produced a test-count summary, so neither establishes a
passing suite or a test-case regression. The timeout covers loading the test
system as well as running it. The host had high load during these attempts;
its contribution to the timeout is unverified. No timeout or assertion was
changed. The Darwin lower-level gate and the author's real-terminal acceptance
remain unresolved, and release has not proceeded.
