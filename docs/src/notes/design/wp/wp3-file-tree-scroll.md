# WP3 file-tree のスクロール

- 規模: S
- 所有: `packages/feature/file-tree/src/domain-file-tree*.lisp`（状態）、`src/presentation/layout-file-tree.lisp`（描画）、
  `packages/feature/mouse/src/application-mouse.lisp`（クリック判定）
- 開始条件: すぐ

## 現状（根拠）

- `src/presentation/layout-file-tree.lisp:21-36` の `%layout-draw-file-tree` は、先頭から `height` 行だけ描く。
  docstring に「Entries beyond HEIGHT rows are simply not drawn -- no scrolling is attempted here」とある。
- `packages/feature/mouse/src/application-mouse.lisp:29-42` の `%mouse-file-tree-hit-test` は `(nth screen-y (file-tree-entries tree))` で項目を引く。
  スクロールすると、クリックした行と開く項目がずれる。当たり判定の幅は固定の 24 である（同 37行 `(< screen-x 24)`）。

選択（`C-c n` / `C-c p`）が画面の下へ出ると見えなくなる。

## 仕様

1. file-tree の状態（構造体のスロット）に `scroll-top`（先頭に描く項目の番号、0 始まり）を持つ。domain の純関数で更新する。
2. 選択が変わるたびに、選択が `[scroll-top, scroll-top + height)` に入るよう最小限だけ動かす（Emacs の `recenter` はしない）。
   上下に1行ずつの余白（`scroll-margin` 相当 = 1）を取る。高さが3行以下なら余白は0。
   ディレクトリの開閉で項目数が変わった場合も、同じ規則を当てる。
3. 画面の大きさが変わったら（`:resize`）、また項目が減ったら、`scroll-top` を `max(0, 項目数 - height)` 以下に縮める。
4. 描画は `scroll-top` から `height` 行。クリック判定は `(nth (+ scroll-top screen-y) entries)`。
5. マウスホイール（サイドバー上）は `scroll-top` を3行ずつ動かす。選択は動かさない。
6. 当たり判定の幅を、描画と同じ `(min 24 width)` にそろえる。
7. `src/presentation/layout-file-tree.lisp` は、アクセサで `scroll-top` を読む。`FILE-TREE-ENTRIES` の呼び出しは1回のままにする。

`height` は描画時の値を使う。状態に画面の高さを持たせず、更新関数に引数で渡す。

## 性能

- 1フレームの処理は O(高さ＋scroll-top) にし、エントリのリストを写さない。

## 受け入れ導線（先に書く）

R6 の固定導線として、`t/e2e/loom_e2e/path_generation.py` に WP3 用の関数を足し、`_fixed_paths()` には呼び出しを1行足すだけにする（D15）。
台帳は `packages/feature/file-tree/t/paths.sexp`、シナリオは `packages/feature/file-tree/t/e2e/scenarios/command-paths.json` に書く。

- 200 項目のディレクトリで `C-c n` を連打 → 選択行が常に画面内にある（毎回画面テキストで観測）
- 末尾まで行ってから `C-c p` で戻る → 同上
- スクロールした状態で、画面の下半分の項目をクリック → その項目のファイルが開く
- 端末を縮める → `scroll-top` が `max(0, 項目数 - height)` 以下に縮む
- ホイールで動かしても選択は変わらない

## テスト

- unit: `scroll-top` の更新関数（境界：項目0・1件、高さ1〜3、末尾、縮小）
- 既存の file-tree / mouse のテストが緑のまま
