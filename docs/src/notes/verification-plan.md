# 検証計画: 実装済み機能を実機で確かめ、必要十分な状態にする

## 1. 要約と現状

**要求**: 実装済みの全機能が実機で動くことを検証し、AI slop を除去して、作者が毎日使うのに
必要十分な状態にする。工数より理想状態を優先する（作者の明言）。

**背景**: in-process のテスト（`t/unit`、`t/integration`）は全コマンドの実装シンボルを参照して
いるが、それは「関数が呼ばれる」ことの証明であり、raw-mode 端末で描画と入力経路を通した証明では
ない。実バイナリを PTY で叩く E2E（`t/e2e`）は 12 シナリオしかなく、CI にも flake にも繋がって
いない。

### 1.1 確認済みの事実

| 観点 | 事実 | 根拠（verified） |
| --- | --- | --- |
| 実行ファイル | `nix build .#default` が `bin/loom` を生成する。`.#loom` はソースと fasl だけのライブラリ派生で `bin/` を持たない | 両方を aarch64-darwin でビルドして中身を確認 |
| PTY E2E | 現行 12 シナリオが aarch64-darwin で全件 PASS、exit 0 | `HOME=$(mktemp -d) LOOM_BINARY=<out>/bin/loom python3 t/e2e/loom-test.py` |
| E2E の到達範囲 | `command-spec` 120 件中 12 件。file-tree、session と register、tooling、window と workspace の 4 グループはゼロ | `t/e2e/loom-test.py` の `main()` を `command-spec` 一覧と突き合わせ |
| E2E の観測能力 | 生バイトの部分一致とディスク上のファイル内容のみ。画面グリッドとカーソル位置は見えない | `t/e2e/loom-test.py` の `LoomProcess` |
| CI | `nix flake check` の単一ジョブ。sandbox に PTY が無く、実子プロセスを使う 3 テストが `LOOM_SANDBOXED_CHECK` で skip する | `flake.nix` の `checks.default`、`t/test-helpers-core.lisp` の `%sandboxed-check-p`、skip 3 箇所 |
| 外部プロセス依存 | `terminal`（PTY 子）、`git-*` 5 件、`pipe-command`、`format-current-buffer`、`lsp-*` 6 件 | 各コマンドの実装から `cl-tty-kit:make-pty`、`vcs-kit:run-git`、`process-kit:run-shell`、`uiop:launch-program` への到達を確認 |
| ダンプ済みバイナリ | 実行時に ASDF を読まないため、`asdf:operate` が停止する環境でも E2E は動く | `flake.nix` の `installSource = false` と実行結果 |
| slop 基線 | 英語散文の em dash 4 行（3 ファイル）、署名を言い直す docstring 3 件、参照ゼロの export 1 件と定義ファイル外で未参照の export 6 件、roadmap の自賛表現 2 箇所 | `grep -rnP '\x{2014}'`、`grep -rn '"Return true' src packages`、`src/package-exports.lisp` の各シンボルを全体 grep |
| 要件書の乖離 | `requirements-daily-driver.md` は FR-001 から FR-007 を未実装と記述しているが、実際は FR-009（SWANK）のみ未実装 | 同書が引く file:line を現コードと突き合わせ |
| 部分実装と孤立コード | TODO と stub はゼロ、参照ゼロの defun はゼロ、`loom.asd` の `:file` と実ファイルは 1:1 | `grep -rniE 'TODO|FIXME|XXX|not yet|stub'`、defun 名の全体トークン計数、`comm` による対応確認 |
| 利用可能な外部ツール | nixpkgs に pyte、nixd、typescript-language-server がある | `nix eval --raw 'nixpkgs#<attr>.version'` |

### 1.2 検証の三層

| 層 | 証明すること | 証明しないこと | CI |
| --- | --- | --- | --- |
| in-process（`loom/test`） | 関数、状態遷移、境界 | raw-mode 入力経路、画面描画とカーソル列、実子プロセス I/O | `nix flake check`（3 件 skip） |
| PTY E2E（`t/e2e`） | 実バイナリと実 PTY でのコマンド動作、画面グリッド | 日本語入力の体感、日常フローの快適さ | 第 2 ジョブ（新設） |
| 手動チェックリスト | 作者が実端末で日常フローを一巡 | 再現性 | CI 外 |

## 2. 要件

### 2.1 機能要件

| ID | 優先度 | 内容 | 受け入れ基準（観測可能な挙動） |
| --- | --- | --- | --- |
| FR-V01 | mandatory | PTY ハーネスが画面グリッドを復元し、行と列の単位でカーソル位置と描画内容を assert できる | 「あいう」の後ろに point がある状態でカーソル列が 6 と読める。半角のみの行では現行値と一致する |
| FR-V02 | mandatory | 120 コマンド全件に対し、実バイナリを PTY で起動して叩くシナリオが 1 つ以上存在する | シナリオ側のマニフェストと `command-spec` 一覧を機械照合し、未カバーのコマンド名がゼロでなければ E2E 全体が fail する |
| FR-V03 | mandatory | 外部プロセス依存コマンドを実バイナリで検証する | `git-*` は一時 git リポジトリ上、`pipe-command` と `format-current-buffer` は shell コマンド、`terminal` は `/bin/sh` 子プロセス、`lsp-*` は nix 提供の実サーバ（nixd を Nix ファイルに対して）で、結果バッファまたはミニバッファに期待文字列が現れる |
| FR-V04 | mandatory | 全角、横スクロール、折り返しの表示要件を画面グリッドで検証する | 全角混在行のカーソル列、右外へ移動したときの追従、折り返し行での次行移動が画面上で期待位置になる |
| FR-V05 | mandatory | E2E が単一コマンドで darwin と CI の両方で走る | `nix run .#e2e` が aarch64-darwin で exit 0。CI の第 2 ジョブ（実 PTY を持つ runner、sandbox 外）が同じコマンドを実行して gate する |
| FR-V06 | mandatory | 動かないコマンドの処置は個別判断 | 失敗ごとに「直す / 消す」を file:line 付きで台帳に記録する。消す場合は `command-spec`、実装、テスト、docs、exports の全参照を除去する |
| FR-V07 | mandatory | slop 除去。既知件数の修正と、全ドキュメントおよび Lisp のコメントと docstring の cold-read | em dash 4 行、docstring 3 件、export 7 件を除去する。roadmap の "actively hardened" と "verified engineering baseline" を事実記述に置換する。要件書を決定の記録として現状に書き直し、旧証拠の file:line を削除する。全 docs ページの cold-read 指摘がゼロになる |
| FR-V08 | mandatory | 手動チェックリストの作成と作者による一巡 | 日常フロー（CL、Nix、TS、Markdown の編集、日本語入力、LSP、terminal、git）の手順書があり、各項目に結果が記録される |
| FR-V09 | optional | `src/package-exports.lisp` と `docs/src/reference/api.md` の乖離を機械検査する | export 一覧と api.md 見出しの差分がゼロでなければ docs check が fail する。理由: api.md は手書きの参照であり、export 削除のたびに黙って古びる |

### 2.2 非機能要件

- **NFR-V01 非空振り**: すべての gate は入力の非空を assert する。E2E は実行シナリオ数と
  `command-spec` 数を突き合わせ、in-process 側は sandbox 外実行で skip 数 0 を確認する。
- **NFR-V02 決定性**: シナリオは固定 sleep ではなく画面状態の到達を待つ。現行ハーネスの
  `time.sleep` 依存箇所は待機条件に置き換える。
- **NFR-V03 隔離**: 各シナリオは一時ディレクトリと仮 `HOME` で動き、作者の `~/.loom/init.lisp`
  を読まない。
- **NFR-V04 時間上限**: E2E 全体が CI ジョブの timeout 内に収まる。1 シナリオの上限は現行の
  10 秒を維持する。
- **NFR-V05 後方互換**: 検証で除去が決まったコマンド以外、キーバインドと挙動を変えない。

### 2.3 技術判断

| 判断 | 根拠 | 却下した代替 |
| --- | --- | --- |
| 画面復元に pyte を使う | nixpkgs にあり、検証器が検証対象と別コードになる | loom 自身の ANSI スクリーンモデル。対象と検証器が同一コードで、描画バグを両側が同じ向きに持つ |
| E2E は Nix sandbox 外の app として実行する | sandbox に PTY が無い。`ci.yml` 冒頭が「実 PTY を要する仕事は第 2 ジョブ」と明記している | `checks.e2e` として sandbox 内で実行する。起動すらできない |
| LSP 実サーバは nixd | 作者の対象言語に Nix が含まれ、単一バイナリで Node 依存が無い。typescript-language-server は第 2 候補 | `cat` などの偽サーバ。in-process テストが既に持っており、実プロトコル交換を証明しない |
| 要件書は削除ではなく書き直す | 決定事項（画面行移動、セッション非永続化、SWANK 保留）は現コードから読めない | 削除。決定の理由が git 履歴にしか残らない |
| 除去判断はコマンド単位で事後に行う | 残すリストは以前のヒアリングで確定済み | 事前の一律削減 |

### 2.4 制約

- `sbcl --script run-tests.lisp` は特定の実行環境で `asdf:operate` が停止する。その環境では
  launchd 経由で実行する。ダンプ済みバイナリは影響を受けない。
- `flake.nix` の変更は承認済み範囲（pyte 追加、`apps.e2e` 追加）に限る。`ci.yml` への第 2 ジョブ
  追加は「理想状態」の明言に基づいて本計画に含める。
- aarch64-darwin には CI gate が無い。darwin での結果は手元実行のみで得る。
- FR-009（SWANK）は本計画の対象外。ソケット層が無いことは
  `grep -rln 'socket\|usocket\|sb-bsd-sockets\|swank' src packages` がゼロであることで再確認済み。

### 2.5 テスト要件（受け入れ判定に使う観測）

- E2E: `nix run .#e2e` の exit 0、出力の PASS 件数がマニフェスト件数と一致、未カバーコマンド 0。
- in-process: sandbox 外実行で failed 0、skipped 0、tests 件数が基線以上。
- 静的: `grep -rnP '\x{2014}'` の英語散文ヒット 0、除去した export の参照 0、`nix flake check`
  exit 0。
- 手動: チェックリスト全項目に結果記入。

## 3. タスク分解

依存: P0 → P1 → P2 → P3 → P5。P4 は P1 以降いつでも並行できる。P6 は P3 の後。

| Phase | 内容 | 主な対象 | 完了条件 |
| --- | --- | --- | --- |
| P0 基線 | in-process スイート（sandbox 外）、`nix flake check`、現行 E2E、slop grep の各件数を台帳に記録する | 変更なし | 4 つの数値とコマンドが台帳にある |
| P1 ハーネス | pyte を dev shell に追加する。`t/e2e` を「起動、入力、画面待機、assert」の共通部とコマンドグループ別シナリオファイルに分割する。仮 `HOME`。`apps.e2e` を追加する。固定 sleep を画面待機に置換する | `flake.nix`、`t/e2e/`、`docs/src/project/development.md` | `nix run .#e2e` が darwin で exit 0、現行 12 件が新構造で PASS |
| P2 全コマンド | グループ別に並列で実装する。editing 26、movement 26、files と projects 12、file-tree 8、windows と workspaces 12、session と registers 10、tooling 17、macros と eval 5、ui 4。外部プロセス系は実バイナリ。FR-V04 は movement と editing に含める。マニフェスト照合 gate を追加する | `t/e2e/` | 未カバー 0、E2E exit 0 または失敗一覧が台帳化されている |
| P3 処置 | 失敗コマンドごとに「直す / 消す」を判断する。直す場合は in-process テストも追加する。消す場合は spec、実装、テスト、docs、exports、api.md を一括除去する | 該当スライス | E2E と in-process が両方 green、台帳に判断理由 |
| P4 slop | em dash、docstring、export、roadmap 段落、要件書の書き直し。README、index、getting-started、core-concepts、architecture、api、features、roadmap、development、packages/README の cold-read。Lisp のコメントと docstring を同じ基準で一巡する。FR-V09 の drift check | `docs/`、`README.md`、`src/package-exports.lisp`、各 `.lisp` | grep 基線が 0、cold-read の指摘 0、`nix build .#docs` exit 0 |
| P5 CI | `ci.yml` に第 2 ジョブを追加する。`nix build` の後に `nix run .#e2e`。`release.yml` の `test -x` を同じ E2E 実行に置換する | `.github/workflows/` | PR で両ジョブ green |
| P6 手動 | チェックリストを作成する（日本語入力、折り返し、横スクロール、LSP 実運用、terminal、git、session の保存と復帰）。作者が一巡し結果を記録する | `docs/src/notes/` | 全項目に結果 |

## 4. 前提にしてはいけないこと

- `requirements-daily-driver.md` の証拠 file:line と「未実装」記述。現コードから再導出する。
- `.#loom` が実行ファイルであること。実行ファイルは `.#default`。
- in-process スイートがどの実行環境でも直接走ること。
- コマンド名文字列でテスト参照を検索すること。9 コマンドは実装シンボル名が異なる
  （`undo` は `undo-command`、`help` は `help-command` など）。
- E2E の exit 0 だけで到達範囲を判断すること。マニフェスト照合が無い間は 12 件のままでも exit 0
  になる。
- 単一呼び出しの private な `%` 接頭辞 defun を削減対象と見なすこと。意図的な分解スタイルである。

進捗と基線の数値は [verification-ledger.md](verification-ledger.md) に記録する。
