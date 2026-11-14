# loom 機能デザイン — 実装への引き継ぎ

このディレクトリは、claude.ai のデザインキャンバス「loom 機能デザイン」（全8ページ・30枚）を、
実装担当（Claude Code を含む）が読める形に書き直したものです。キャンバスは図と画面モックの原本、
ここにあるのは **実装の仕様と受け入れ条件** です。食い違ったときは、このディレクトリを正とします。

- 基準コミット: `d0d8b75`（2026-10-30, `docs(release): restore manual acceptance status`）
- 作成: 2026-11-14

## 読む順

1. [daily-driver-v0.2.md](daily-driver-v0.2.md) — 「日常使いできる」の合格基準、1日のシナリオ、作業パッケージ WP0〜WP7 と順番。**最初に実装するのはここだけ。**
2. `wp/` — 作業パッケージごとの仕様。1ファイル = 1つの変更単位（jj の1 change を目安）。
   - [WP0 手動チェック](wp/wp0-manual-checks.md)
   - [WP1 退避からの復元](wp/wp1-recover.md)
   - [WP2 評価の中断](wp/wp2-eval-interrupt.md)
   - [WP3 file-tree のスクロール](wp/wp3-file-tree-scroll.md)
   - [WP4 C-x C-b と C-x s](wp/wp4-buffer-list-save-some.md)
   - [WP5 Emacs 基本編集6種](wp/wp5-basic-editing.md)
   - [WP6 CL の複数行ハイライト](wp/wp6-cl-multiline-highlight.md)
   - [WP7 LSP サーバ要求への応答](wp/wp7-lsp-server-requests.md)
3. [decisions.md](decisions.md) — 作者に決めてほしい未決事項 Q1〜Q9。WP2 は Q3 が決まるまで着手しない。
4. [claude-code-prompts.md](claude-code-prompts.md) — Claude Code にそのまま貼る依頼文（WP ごと・波ごと）。
5. [roadmap-v0.3-v0.5.md](roadmap-v0.3-v0.5.md) — v0.2 の後に積む提案（モードライン、キーヒント、補完の注釈、行内診断、Git ステータス、Dracula と face 表、Rich モード、cl-prolog-kit 化）。**v0.2 の作業中は手を付けない。**

## 守ること（全 WP 共通）

キャンバスの設計原則を、実装の規則として書き直したもの。

1. **Emacs の手癖を裏切らない。** 既定キーは Emacs 標準。独自の操作は M-x かローカルキーマップへ。
2. **見つけられない機能は無いのと同じ。** 新しいコマンドには必ず `:help` を付け、`C-h x` で引けるようにする。
3. **外部プロセスは同意してから。** 引数は argv で渡し、パスは `--` の後ろ。
4. **データは壊さない。** その場上書き・事前バックアップ・改行と BOM の保持・外部変更の検出を崩さない。
5. **1機能 = 1スライス。** 変更は `packages/feature/<slice>`（または `packages/core/<package>`）に閉じ、合成ルート `src/` はフックを呼ぶだけ。境界テストの許可表を増やさない。
6. **観測できたものだけを合格に。** 受け入れ導線は実装の前に、その slice の `t/paths.sexp` と `t/e2e/scenarios/command-paths.json` に書く（書式は `docs/src/notes/command-path-scenarios.md`）。

性能ゲート（初回画面 0.3 秒、入力→再描画 p95 50ms、2万行ファイル）を落とす変更は入れない。
描画やキー1打ごとの経路で I/O をしない。

## 検証コマンド

`docs/src/project/development.md` のとおり。WP ごとに最低限これを通す。

```sh
nix build
nix develop -c loom-test
nix run .#e2e -- --only <slice または scenario の一部>
nix run .#e2e -- --require-path-coverage   # 新しい導線が missing_paths に出ないこと
nix fmt -- --ci
```

変更の記録は jj（`jj new` → 編集 → `jj describe`）。push は作者の承認後に `jj git push`。
