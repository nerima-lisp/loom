# WP3 file-tree のスクロール

- 規模: S
- 所有: `feature/file-tree`（状態）、`src/presentation/layout-file-tree.lisp`（描画）、`feature/mouse`（クリック判定）
- 波: 第1波

## 現状（根拠）

- `src/presentation/layout-file-tree.lisp:21-36` の `%layout-draw-file-tree` は、先頭から `height` 行だけ描く。
  docstring に「Entries beyond HEIGHT rows are simply not drawn -- no scrolling is attempted here」とある。
- `feature/mouse/src/application-mouse.lisp:29-42` の `%mouse-file-tree-hit-test` は `(nth screen-y (file-tree-entries tree))` で項目を引く。
  スクロールすると、クリックした行と開く項目がずれる。

選択（`C-c n` / `C-c p`）が画面の下へ出ると見えなくなる。

## 仕様

1. file-tree の状態に `scroll-top`（先頭に描く項目の番号、0 始まり）を持つ。domain の純関数で更新する。
2. 選択が変わるたびに、選択が `[scroll-top, scroll-top + height)` に入るよう最小限だけ動かす（Emacs の `recenter` はしない）。
   上下に1行ずつの余白（`scroll-margin` 相当 = 1）を取る。高さが3行以下なら余白は0。
3. ウィンドウの高さが変わったら、同じ規則で選択を画面内に戻す。項目が減ったら `scroll-top` を `max(0, 項目数 - height)` までに縮める。
4. 描画は `scroll-top` から `height` 行。クリック判定は `(nth (+ scroll-top screen-y) entries)`。
5. マウスホイール（サイドバー上）は `scroll-top` を3行ずつ動かす。選択は動かさない。

`height` は描画時の値を使う。状態に画面の高さを持たせず、更新関数に引数で渡す。

## 受け入れ導線（先に書く）

`feature/file-tree/t/paths.sexp`（R6 の端点として）:

- 200 項目のディレクトリで `C-c n` を連打 → 選択行が常に画面内にある（毎回画面テキストで観測）
- 末尾まで行ってから `C-c p` で戻る → 同上
- スクロールした状態で、画面の下半分の項目をクリック → その項目のファイルが開く
- 端末の高さを縮める → 選択が画面内に戻る
- ホイールで動かしても選択は変わらない

## テスト

- unit: `scroll-top` の更新関数（境界：項目0・1件、高さ1〜3、末尾、縮小）
- 既存の file-tree / mouse のテストが緑のまま
