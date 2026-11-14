# Claude Code 向けの作業規則（loom）

loom は SBCL 上の Emacs 風ターミナルエディタ。作者が `EDITOR=loom` で毎日使えることが目標。

このファイルの前半は、loom で常に成り立つ規則。最後の節は、進行中の版の作業にだけ当てはまる規則。

## まず読む

- `docs/src/project/development.md`（ビルド・テスト・jj の作法。このファイルより優先）
- `docs/src/reference/architecture.md`（core とスライスの境界）
- `docs/src/notes/command-path-scenarios.md`（受け入れ導線の書き方）

## 進め方

1. 依頼文に入っているタスクの仕様だけを実装する。仕様にないことは足さない。
2. 実装の前に受け入れ導線を書く。導線は所有スライスの `t/paths.sexp` と `t/e2e/scenarios/command-paths.json`
   （例: `packages/feature/files/t/paths.sexp`。JSON が無ければ作る）に、新しいコマンドの ID はそのスライスの
   `t/command-ids.lisp` に足す。書いた導線が main で失敗する出力を報告に残す。
3. 変更は依頼の仕様・担当範囲・明示の許可に閉じる。
   自分のスライスの中で追加だけで済む隣のファイルの変更（シナリオの JSON への記録、package への export、
   テスト用の補助）は、依頼が許可したパスに載っていなくても認める。報告に、そのファイルと理由を書く。
4. 既存テストの期待値は、仕様が直接に引き起こす追従に限って変えてよい。例: 導線を足したことで変わる導線の件数の assert、
   仕様で移した欄を読む参照先、仕様で足した記号の export 一覧。変えたテストごとに、どの要件から決まるかを報告に書く。
5. 境界テストの許可表（`boundary-allowlist.lisp`）は増やさない。
6. 新しいグローバルコマンドには `:help` と `:help-order` を付ける。ローカルコマンドは `:help nil`。キーは Emacs の既定どおり。
7. 次のときは、実装せずに止めて報告する。
   - 許可表を増やさないと書けない。
   - 仕様が求めていない既存の振る舞いについて、テストの期待値を変える必要がある。
   - 他のスライスの責務を変える必要がある。
   - 仕様と現状のソースが食い違う。

## 検証

```sh
jj status                      # 新規ファイルを snapshot して flake から見えるようにする
nix build
nix develop -c loom-test
nix run .#e2e -- --only <slice または scenario の一部>
nix run .#e2e -- --require-path-coverage
nix run .#e2e -- --benchmark-gate
nix fmt -- --ci
```

合格を主張するときは、exit status、選ばれたテストの件数、assert の数を書く。ベンチマークは変更の前と後を同じマシンで測る。

性能ゲート（初回画面 0.3 秒、入力→再描画 p95 50ms）を通らなくする変更は入れない。新しい I/O は、ファイルを開くとき、保存した後、
起動時、終了時に限る。描画とキー1打の経路では I/O をせず、外部プロセスも足さない。

## jj と push

- 1タスクを筋の通った小さなコミットに分ける。jj は `jj status` のように組み込みのコマンド名で使う。
- 依頼が明示した bookmark だけに push する。loom の main への push と着地は作者が行う。
- push の前に `gitleaks git --log-opts=<範囲> <repo>` を実行する。`jj git push` がフックに止められたら、
  拒否文が示す prefix を付け、単独のコマンドとして実行する。
- CI は `gh workflow run CI --ref <push した bookmark>` で流す。

## してはいけないこと

- `docs/src/notes/daily-driver-checklist.md` の `Author result` 列を埋める（作者の実機観測だけが証拠）
- git でコミット・ブランチ操作をする（記録は jj、git は読み取りだけ）
- `main` へ push する。依頼が明示した bookmark 以外に push する
- 他のセッションの jj workspace を動かす・消す
- テストを通すためにテストや導線を弱める。仕様が直接に引き起こす追従のほかに、テストの期待値を変える

## v0.2 の作業中の規則

v0.2 が終わったらこの節を消す。詳細は `docs/src/notes/design/`（`README.md` から読む）を参照する。
依頼文の型、タスクごとのワークスペース・change の説明・push 先の表は `docs/src/notes/design/claude-code-prompts.md` にある。

- v0.2 のタスク・決定・仕様の正本は v0.2 実行計画書で、リポジトリには入っていない。各タスクの依頼文に、計画書の該当する節が入る。
- このファイルの Dn は、計画書の決定番号（一覧は `docs/src/notes/design/decisions.md`）。
- まず読む文書に `docs/src/notes/design/README.md`（v0.2 日常使い版の設計。計画書に合わせて直した参照用の文書）を足す。
- 「進め方」1 のタスクの仕様は、計画書6章の該当節。`docs/src/notes/design/` と食い違ったら、計画書を正とする。
- 「進め方」2 の main で失敗する出力について、S1 は main で通る回帰テストなので、通った出力を残す。
- 「進め方」3 の担当範囲は、依頼文の「変えてよいパス」（計画書6章の各タスクの「所有」）。所有スライスの付け替えと、
  core と `src/` への小さな公開 API と呼び出しの追加は認める（D2）。複数のタスクが触る共有ファイルは、
  計画書5章の表の規則に従う。
- `:help-order` は WP1 が 40〜41、WP4 が 42〜43、WP5 が 44〜49 を使う。ローカルコマンドの `:help nil` は D11 による。
- 「進め方」7 の止まる条件に、次を加える。
  - 他のタスクが所有するファイルの既存の行を書き換える必要がある（他のスライスの責務の変更に含める）。
  - `docs/src/notes/design/decisions.md` の未決事項に触れる判断が要る。
- ワークスペースは `<repo>.git/.worktrees/v02-<task>` の形にする（キットを除く）。
- change の説明は `feat(<slice>): <要約> (<task>)` の形にする。
- push 先は、依頼文が許可した `wp/<task>` の bookmark。キットのタスク（K1〜K4）は、loom 側の
  `wp/<kit-task>-probe` を push する（この bookmark は着地させない）。
- CI は `gh workflow run CI --ref wp/<task>` で流す。
