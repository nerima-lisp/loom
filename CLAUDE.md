# loom — Claude Code 向けの作業規則

loom は SBCL 上の Emacs 風ターミナルエディタ。作者が `EDITOR=loom` で毎日使えることが目標。

## まず読む

- `docs/src/project/development.md` — ビルド・テスト・jj の作法（このファイルより優先）
- `docs/src/reference/architecture.md` — core とスライスの境界
- `docs/src/notes/design/README.md` — いま実装する仕様（v0.2 日常使い版、WP0〜WP7）
- `docs/src/notes/command-path-scenarios.md` — 受け入れ導線（`t/paths.sexp` と `command-paths.json`）の書き方

## 進め方

1. 指示された WP の仕様（`docs/src/notes/design/wp/wpN-*.md`）だけを実装する。仕様にないことは足さない。
2. 実装の前に、受け入れ導線を所有スライスの `t/paths.sexp` と `t/e2e/scenarios/command-paths.json` に書く。
3. 変更は所有スライス（`packages/feature/<slice>` / `packages/core/<package>`）に閉じる。
   境界テストの許可表（各スライスの `t/boundary-allowlist.lisp`）は増やさない。増やす必要が出たら止めて報告する。
4. 新しいコマンドには `:help` を付ける。キーは Emacs の既定どおり。
5. `docs/src/notes/design/decisions.md` の未決事項に触れる判断が要るときは、実装せずに止めて報告する。

## 検証（WP ごとに全部通す）

```sh
nix build
nix develop -c loom-test
nix run .#e2e -- --only <slice>
nix run .#e2e -- --require-path-coverage
nix fmt -- --ci
```

性能ゲート（初回画面 0.3 秒、入力→再描画 p95 50ms）を落とさない。描画・キー1打ごとの経路で I/O をしない。

## してはいけないこと

- `docs/src/notes/daily-driver-checklist.md` の `Author result` 列を埋める（作者の実機観測だけが証拠）
- git でコミット・ブランチ操作をする（記録は jj、git は読み取りだけ）
- 作者の承認なしに `jj git push` する
- 他のセッションの jj workspace を動かす・消す
- テストを通すためにテストや導線を弱める
