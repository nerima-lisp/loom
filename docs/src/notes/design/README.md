# loom 機能デザイン（実装への引き継ぎ）

このディレクトリは、claude.ai のデザインキャンバス「loom 機能デザイン」（全8ページ・30枚）を、
実装担当（Claude Code を含む）が読める形に書き直したものです。キャンバスは図と画面モックの原本、
ここにあるのは **実装の仕様と受け入れ条件** です。キャンバスと食い違ったときは、このディレクトリを正とします。

v0.2 のタスク・決定・仕様の正本は **v0.2 実行計画書** です。このディレクトリは、計画書に合わせて直した参照用の文書です。
計画書と食い違ったときは計画書を正とします。計画書はリポジトリに入っていません。各タスクの依頼文に、
計画書6章のそのタスクの節と5章の共通規則が入ります。この文書の Dn は計画書の決定番号です（一覧は [decisions.md](decisions.md)）。
R1〜R9 の導線規則の番号は、タスクの R1（v0.2.0 のリリース準備）とは別のものです。

- 基準コミット: `d0d8b75`（2026-10-30, `docs(release): restore manual acceptance status`）
- 作成: 2026-11-14

## 読む順

1. [daily-driver-v0.2.md](daily-driver-v0.2.md)。「日常使いできる」の合格基準、1日のシナリオ、作業パッケージ WP0〜WP7。
   タスクの単位、依存、開始条件は計画書4章の表に従います。
2. `wp/`。作業パッケージごとの仕様です。1タスクが1つの変更単位（jj の1 change）です。
   WP4 と WP5 は、1ファイルの中を a と b の節に分け、節ごとに別のタスクとして着地します。
   - [WP0 手動チェック](wp/wp0-manual-checks.md)
   - [WP1 退避からの復元](wp/wp1-recover.md)
   - [WP2 評価の中断](wp/wp2-eval-interrupt.md)
   - [WP3 file-tree のスクロール](wp/wp3-file-tree-scroll.md)
   - [WP4 C-x C-b と C-x s](wp/wp4-buffer-list-save-some.md)（WP4a buffer-menu と確認つき保存、WP4b save-some-buffers）
   - [WP5 Emacs 基本編集6種](wp/wp5-basic-editing.md)（WP5a M-m・M-\\・M-SPC・M-t・M-=、WP5b M-z）
   - [WP6 CL の複数行ハイライト](wp/wp6-cl-multiline-highlight.md)
   - [WP7 LSP サーバ要求への応答](wp/wp7-lsp-server-requests.md)
3. 計画書で足したタスク。仕様は計画書6章にだけあり、このディレクトリには仕様のファイルがありません。
   - D0 設計文書とルートの `CLAUDE.md`（このディレクトリを入れたタスク）
   - C1 core/buffer の基盤（行の索引、版数、変更行の問い合わせ、中断への耐性）
   - F1 `:prompts` の `:char` 種別（RET なしの1打鍵）
   - P1 cl-tty-kit を v1.7.3 へ、P2 cl-process-kit を v3.4.4 へ
   - G1 git パッケージによる `vcs-kit` の記号の上書きの解消
   - S1 本文の制御文字の回帰テスト
   - K1〜K4 依存キットの改修（cl-tty-kit の入力の監視、cl-concurrent-kit の中断できる範囲、
     cl-vcs-kit の行差分、cl-host-kit の保持ロックと一時ファイルの prefix と新規ファイルの権限）
   - T9 R9「1日」のシナリオと合格ゲートの表
   - R1 v0.2.0 のリリース準備
4. [decisions.md](decisions.md)。計画書の決定 D1〜D29 と、未決事項 Q1〜Q9。Q3（評価の中断の方式）は D1 で決まりました。
5. [claude-code-prompts.md](claude-code-prompts.md)。依頼文の型（計画書9章）と、タスクごとの開始条件、ワークスペース、
   change の説明、push 先。
6. [roadmap-v0.3-v0.5.md](roadmap-v0.3-v0.5.md)。v0.2 の後に積む提案（モードライン、キーヒント、補完の注釈、行内診断、Git ステータス、Dracula と face 表、Rich モード、cl-prolog-kit 化）。**v0.2 の作業中は手を付けない。**
   この文書の ID は、計画書のタスク ID とは別の番号です。

## 守ること（全タスク共通）

キャンバスの設計原則を、実装の規則として書き直したもの。

1. **既定キーは Emacs 標準にする。** 独自の操作は M-x かローカルキーマップに置く。
2. **新しいグローバルコマンドは `C-h x` で引けるようにする。** `:help` と `:help-order`（WP1 は 40〜41、WP4 は 42〜43、
   WP5 は 44〜49）を付ける。ローカルコマンドは `:help nil`（D11）。
3. **外部プロセスは同意してから。** 引数は argv で渡し、パスは `--` の後ろ。v0.2 では外部プロセスを足さない。
4. **保存で作業を失わない。** その場上書き・事前バックアップ・改行と BOM の保持・外部変更の検出を、今の動作のまま保つ。
5. **1機能 = 1スライス。** 変更はタスクの「所有」（計画書6章）に閉じる。所有スライスの付け替えと、core と `src/` への
   小さな公開 API と呼び出しの追加は認める（D2）。複数のタスクが触る共有ファイルは、計画書5章の表の規則に従う。
   境界テストの許可表を増やさない。
6. **観測できたものだけを合格に。** 受け入れ導線は実装の前に、所有スライスの `t/paths.sexp` と
   `t/e2e/scenarios/command-paths.json`（例: `packages/feature/files/t/paths.sexp`。JSON が無ければ作る）に書き、
   新しいコマンドの ID はそのスライスの `t/command-ids.lisp` に足す（書式は `docs/src/notes/command-path-scenarios.md`）。
   書いた導線が main で失敗する出力を報告に残す（S1 は main で通った出力を残す）。

性能ゲート（初回画面 0.3 秒、入力→再描画 p95 50ms、2万行ファイル）を通らなくする変更は入れない。
新しい I/O は、ファイルを開くとき、保存した後、起動時、終了時に限る。描画やキー1打ごとの経路で I/O をしない。

## 検証コマンド

`docs/src/project/development.md` と計画書5章のとおり。タスクごとに最低限これを通す。

```sh
jj status                                  # 新規ファイルを snapshot して flake から見えるようにする
nix build
nix develop -c loom-test
nix run .#e2e -- --only <slice または scenario の一部>
nix run .#e2e -- --require-path-coverage   # 新しい導線が missing_paths に出ないこと
nix run .#e2e -- --benchmark-gate          # 変更の前と後を同じマシンで測る
nix fmt -- --ci
```

合格を主張するときは、exit status、選ばれたテストの件数、assert の数を書く。

変更の記録は jj で、1タスク1 change、説明は `feat(<slice>): <要約> (<task>)` の形にする。各レーンは依頼文が許可した
`wp/<task>` の bookmark（キットのタスクは loom 側の `wp/<kit-task>-probe`）だけを、gitleaks を通してから push し、`gh workflow run CI --ref wp/<task>` で CI を流す。
loom の main への push と着地は作者が行う（D7）。
