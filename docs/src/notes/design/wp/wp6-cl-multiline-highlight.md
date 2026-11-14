# WP6 CL の複数行ハイライト

- 規模: M
- 所有スライス: `feature/syntax-highlighting`
- 波: 第2波

## 現状（根拠）

`feature/syntax-highlighting/src/domain-syntax-highlighting-common-lisp.lisp:76-79` の `syntax-highlight-line` の docstring に
「The tokenizer is deliberately line-local. Reader state spanning multiple ...」とある。
1行ずつ独立に色を決めるので、次が2行目以降で崩れる（FR-D03 の目標に届いていない）。

- 複数行の文字列（docstring）
- ブロックコメント `#| ... |#`（入れ子あり）

## 仕様

1. 行の **開始状態** を定義する: `:code` / `(:string)` / `(:block-comment depth)`。
2. `syntax-highlight-line` を `(line start-state) → (values tokens end-state)` に広げる。既存の呼び出し口は `start-state = :code` の薄い包みとして残す。
3. バッファごとに「行番号 → 開始状態」のキャッシュを持つ。キーはバッファの版数（変更カウンタ）。
4. 編集があった行から下だけ再計算し、**ある行の終了状態が前回と同じになったら打ち切る**。
5. 描画は表示範囲の行だけを求める。表示範囲より上が未計算なら、上から順に状態だけ求める（トークンは作らない）。
6. 他のモード（generic）は今のまま（line-local）。このキャッシュの形は、のちに虹色の括弧・固定ヘッダ・パンくず（roadmap の U6）でも使う。

## 性能

- 2万行の CL ファイルで、先頭行に `"` を入れる最悪ケースでも、入力→再描画 p95 50ms のゲートを守る。
  守れない場合は、表示範囲より下の再計算を次の tick に回す（その間、下の行は前回の色のまま）。

## 受け入れ導線（先に書く）

`feature/syntax-highlighting/t/paths.sexp`:

- `#|` を3行にまたがって書く → 各行がコメントの属性（画面の属性で観測）
- 入れ子 `#| #| |# |#` → 内側の `|#` の後もコメントのまま
- 3行の docstring → 各行が文字列の属性
- 1行目の `"` を消す → 下の行の属性が元に戻る
- 2万行で先頭を編集 → 既存の性能ゲートが緑

## テスト

- unit: 状態遷移の表（文字列中の `\"`、`#\"`、`#|` を含む文字列、`;` の後の `#|` など）
- property（cl-weave）: 任意の行分割で、全体を一度に解析した結果と行ごと＋状態引き継ぎの結果が一致
