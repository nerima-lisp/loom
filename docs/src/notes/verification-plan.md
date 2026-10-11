# 検証計画: 端末操作、外部プロセス、手動確認

## 1. 要約と現状

**要求**: 実装済み機能を実バイナリと PTY で検証し、根拠のない文書記述を修正する。
日常の編集操作は作者による手動確認を別に記録する。

**背景**: in-process のテスト（`t/unit`、`t/integration`）は全コマンドの実装シンボルを参照して
いるが、それは「関数が呼ばれる」ことの証明であり、raw-mode 端末で描画と入力経路を通した証明では
ない。実バイナリを PTY で叩く E2E（`t/e2e`）は全 command-spec を照合し、CI の実PTYジョブ
から実行する。

この文書の P0 と P1 の件数は履歴である。現行のシナリオ数、被覆、slop 測定は検証台帳の最新行と
`requirements-daily-driver.md` に合わせる。

### 1.1 確認済みの事実

| 観点 | 事実 | 根拠（verified） |
| --- | --- | --- |
| Executable | `.#default` builds the executable; `.#loom` is the Lisp library derivation | `flake.nix`, `packages` output |
| PTY E2E | 独立した PTY gate。現行の pass 状態はこの文書では主張しない | `nix run .#e2e` |
| E2E の到達範囲 | 現行の `command-spec` 集合とシナリオのマニフェストを照合し、未カバーを報告する | `nix run .#e2e -- --list` と全件実行 |
| E2E observations | pyte reconstructs the screen grid and cursor. Scenarios can also assert saved file bytes | `t/e2e/loom_e2e/session.py`, `screen.py` |
| CI | Sandboxed checks, real PTY E2E, and offline release archive restoration run in separate jobs. PTY E2E runs `nix run .#e2e` outside the sandbox | `.github/workflows/ci.yml`, `check`, `e2e`, and `release-archive` jobs |
| 外部プロセス依存 | `terminal`（PTY 子）、`git-*` 5 件、`pipe-command`、`format-current-buffer`、`lsp-*` 6 件 | 各コマンドの実装から `cl-tty-kit:make-pty`、`vcs-kit:run-git`、`process-kit:run-shell`、`uiop:launch-program` への到達を確認 |
| Historical measurements | Ledger results apply only to the source and environment recorded there | [verification-ledger.md](verification-ledger.md) |
| 要件書 | `requirements-daily-driver.md` は実装状態ではなく、判断と未実装境界を記録する | FR-000 から FR-010 の状態と判断理由を現行コード・検証結果と突き合わせ |
| External tools | The E2E app supplies Python with pyte and nixd | `flake.nix`, `apps.e2e` |

### 1.2 検証の三層

| 層 | 証明すること | 証明しないこと | CI |
| --- | --- | --- | --- |
| in-process（`loom/test`） | 関数、状態遷移、境界 | raw-mode 入力経路、画面描画とカーソル列、実子プロセス I/O | Sandbox3 の `nix flake check`。PTY 依存チェックは skip され得る |
| PTY E2E（`t/e2e`） | 実バイナリと実 PTY でのコマンド動作、画面グリッド | 日本語入力の体感、日常フローの快適さ | 現行 CI の `e2e` job |
| 手動チェックリスト | 作者が実端末で日常フローを一巡 | 再現性 | CI 外 |

## 2. 要件

### 2.1 機能要件

| ID | 優先度 | 内容 | 受け入れ基準（観測可能な挙動） |
| --- | --- | --- | --- |
| FR-V01 | mandatory | PTY ハーネスが画面グリッドを復元し、行と列の単位でカーソル位置と描画内容を assert できる | 「あいう」の後ろに point がある状態でカーソル列が 6 と読める。半角のみの行では現行値と一致する |
| FR-V02 | mandatory | 現行の `command-spec` 全件に対し、実バイナリを PTY で起動して叩くシナリオが 1 つ以上存在する | シナリオ側のマニフェストと `command-spec` 一覧を機械照合し、未カバーのコマンド名があれば E2E 全体が fail する |
| FR-V03 | mandatory | 外部プロセス依存コマンドを実バイナリで検証する | `git-*` は一時 git リポジトリ上、`pipe-command` と `format-current-buffer` は shell コマンド、`terminal` は `/bin/sh` 子プロセス、`lsp-*` は nix 提供の実サーバ（nixd を Nix ファイルに対して）で、結果バッファまたはミニバッファに期待文字列が現れる |
| FR-V04 | mandatory | 全角、横スクロール、折り返しの表示要件を画面グリッドで検証する | 全角混在行のカーソル列、右外へ移動したときの追従、折り返し行での次行移動が画面上で期待位置になる |
| FR-V05 | mandatory | E2E が単一コマンドで darwin と CI の両方で走る | `nix run .#e2e` を aarch64-darwin と CI の `e2e` job（実 PTY を持つ runner、sandbox 外）で実行し、各結果を記録する |
| FR-V06 | mandatory | 動かないコマンドの処置は個別判断 | 失敗ごとに「直す / 消す」を file:line 付きで台帳に記録する。消す場合は `command-spec`、実装、テスト、docs、exports の全参照を除去する |
| FR-V07 | mandatory | slop 除去。既知の指摘を修正し、全ドキュメントおよび Lisp のコメントと docstring を cold-read する | 変更した各 path と残る指摘を記録する。roadmap の自賛表現を事実記述に置換し、要件書を現状の決定記録に書き直す。 |
| FR-V08 | mandatory | 手動チェックリストの作成と作者による一巡 | [daily-driver-checklist.md](daily-driver-checklist.md) の日常フロー（CL、Nix、TS、Markdown の編集、日本語入力、LSP、terminal、git）に作者の結果が記録される。未実施は合格と扱わない |
| FR-V09 | optional | Mechanically compare exports with API reference headings | Proposed gate: any difference fails the docs check. This gate is not implemented. The reference currently documents selected APIs rather than every export; adopting this criterion requires expanding it |

### 2.2 非機能要件

- **NFR-V01 非空振り**: すべての gate は入力の非空を assert する。E2E は現行マニフェストと
  `command-spec` 集合を突き合わせ、in-process 側は失敗数と skip 数を記録する。Sandbox3 の
  PTY skip は E2E 結果として扱わない。
- **NFR-V02 決定性**: シナリオは固定 sleep ではなく画面状態の到達を待つ。現行ハーネスの
  `time.sleep` 依存箇所は待機条件に置き換える。
- **NFR-V03 隔離**: 各シナリオは一時ディレクトリと仮 `HOME` で動き、作者の `~/.loom/init.lisp`
  を読まない。
- **NFR-V04 Time limit**: The full E2E run must fit the CI job timeout, and each
  scenario must finish within 10 seconds, including cleanup. The harness now
  applies a scenario-wide deadline with a reserved cleanup budget. The deadline
  tests and a separate real three-child cleanup probe passed; their exact scope
  and earlier unexplained failures are recorded in the verification ledger.
  These host results do not establish the CI job's elapsed time.
- **NFR-V05 後方互換**: 検証で除去が決まったコマンド以外、キーバインドと挙動を変えない。

### 2.3 技術判断

| 判断 | 根拠 | 却下した代替 |
| --- | --- | --- |
| 画面復元に pyte を使う | nixpkgs にあり、検証器が検証対象と別コードになる | loom 自身の ANSI スクリーンモデル。対象と検証器が同一コードで、描画バグを両側が同じ向きに持つ |
| Run E2E as an app outside the Nix sandbox | The sandbox does not provide a PTY. The CI `e2e` job runs `nix run .#e2e` separately from `nix flake check` | Run E2E as a sandboxed check, where the required PTY is unavailable |
| LSP 実サーバは nixd | 作者の対象言語に Nix が含まれ、単一バイナリで Node 依存が無い。typescript-language-server は第 2 候補 | `cat` などの偽サーバ。in-process テストが既に持っており、実プロトコル交換を証明しない |
| Retain the requirements document | It records display-row movement, deferred display-mode persistence, and deferred SWANK support. Session snapshots are supported independently of display-mode persistence | Delete the decisions and rely on implementation alone |
| Decide failed commands individually | Each failure needs evidence and a repair or removal decision | Remove command groups without checking their behavior |

### 2.4 制約

- Run the source suite with its declared ASDF dependencies available. Report
  runner failures separately from application failures; do not assume a historical
  ASDF startup problem applies to the current environment.
- Configuration changes require task-specific authorization. This plan does not
  grant permission to modify CI, publish a release, or change version-control state.
- CI runs on Linux. Darwin results require a separate local run.
- FR-009 (SWANK) remains deferred in the daily-driver requirements.

### 2.5 テスト要件（受け入れ判定に使う観測）

- E2E: `nix run .#e2e` を実行し、出力と現行マニフェストを比較して未カバーコマンドを報告する。
- in-process: 失敗数と skip 数を記録する。Sandbox3 の PTY skip は E2E の結果ではない。
- 静的: `grep -rnP '\x{2014}'` の英語散文ヒット、除去した export の参照、`nix flake check`
  の exit status を記録する。
- 手動: チェックリスト全項目に結果記入。

## 3. タスク分解

依存: P0 → P1 → P2 → P3 → P5。P4 は P1 以降いつでも並行できる。P6 は P3 の後。

| Phase | 内容 | 主な対象 | 完了条件 |
| --- | --- | --- | --- |
| P0 基線 | in-process スイート（sandbox 外）、`nix flake check`、現行 E2E、slop grep の結果を台帳に記録する | 変更なし | 各コマンドの出力と観測結果が台帳にある |
| P1 Harness | The split harness, pyte screen, isolated child HOME, E2E app, and scenario-wide deadline exist. Verify real cleanup against the shared deadline | `flake.nix`, `t/e2e/`, development guide | Record a full E2E run and remaining NFR failures |
| P2 Command coverage | Manifest comparison exists. Check actual scenario assertions and real external-process results, including successful LSP completion and definition jumps rather than only empty responses | `t/e2e/` | Record uncovered commands, failed scenarios, and behavior not established by their assertions |
| P3 処置 | 失敗コマンドごとに「直す / 消す」を判断する。直す場合は in-process テストも追加する。消す場合は spec、実装、テスト、docs、exports、api.md を一括除去する | 該当スライス | E2E と in-process の独立した結果と判断理由が台帳にある |
| P4 Documentation | Cold-read README, guides, API, architecture, roadmap, package documentation, Lisp comments, and docstrings. Correct unsupported claims and record unresolved findings. FR-V09 remains optional | Documentation and Lisp sources | Required review findings resolved and `nix build .#docs` exits 0 |
| P5 CI | CI separates sandboxed checks from real PTY E2E. The release workflow runs E2E too | `.github/workflows/ci.yml`, `.github/workflows/release.yml` | Record both gates on the source revision intended for release |
| P6 手動 | CL、Nix、TS、Markdown の編集、日本語入力、折り返し、横スクロール、LSP 実運用、terminal、git、session の保存と復帰を作者が一巡する | [daily-driver-checklist.md](daily-driver-checklist.md) | 全項目に作者の結果。未実施項目は残課題 |

## 4. 前提にしてはいけないこと

- `requirements-daily-driver.md` の証拠 file:line と「未実装」記述。現コードから再導出する。
- `.#loom` が実行ファイルであること。実行ファイルは `.#default`。
- in-process スイートがどの実行環境でも直接走ること。
- コマンド名文字列でテスト参照を検索すること。9 コマンドは実装シンボル名が異なる
  （`undo` は `undo-command`、`help` は `help-command` など）。
- A successful subset E2E run does not establish full coverage. Unfiltered runs
  enforce the manifest comparison; use `--require-full-coverage` when checking a subset.
- 単一呼び出しの private な `%` 接頭辞 defun を削減対象と見なすこと。意図的な分解スタイルである。

進捗と基線の数値は [verification-ledger.md](verification-ledger.md) に記録する。
