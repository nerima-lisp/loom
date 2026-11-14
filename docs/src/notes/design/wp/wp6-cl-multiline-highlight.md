# WP6 CL の複数行ハイライト

- 規模: M
- 所有: `packages/feature/syntax-highlighting/`、`src/main.lisp` 698〜704行と `src/presentation/layout-wrapping.lisp` 81〜86行（描画の呼び出し元）、
  `t/e2e/loom_e2e/benchmarks.py`、`t/e2e/loom-test.py`
- 開始条件: C1（core/buffer の基盤）が着地してから

## 現状（根拠）

`packages/feature/syntax-highlighting/src/domain-syntax-highlighting-common-lisp.lisp:76-79` の `syntax-highlight-line` の docstring に
「The tokenizer is deliberately line-local. Reader state spanning multiple ...」とある。
1行ずつ独立に色を決めるので、次の構文の2行目以降が、文字列やコメントの色で描かれない（FR-D03 の目標に届いていない）。

- 複数行の文字列（docstring）
- ブロックコメント `#| ... |#`（入れ子あり）

描画は narrow 中の表示行で回っている（`src/presentation/layout.lisp:21-42`）。

## 仕様

版数、変更行の問い合わせ、行の索引は、C1（FR-C101〜C103）が core/buffer に入れる。WP6 はそれを使う。

1. 行の **開始状態** を定義する: `:code` / `(:string)` / `(:block-comment depth)`。遷移の規則は次のとおり。
   - 文字列の中の `\"` は文字列を閉じない。
   - `#\"` は文字のリテラル。
   - 文字列の中の `#|` はコメントを開かない。
   - `;` の後の `#|` もコメントを開かない。
   - `#|` は入れ子にできる。
   - `|sym|` のように複数行にまたがるシンボルは対象外。
2. `syntax-highlight-line` を `(line start-state) → (values tokens end-state)` に広げる。既存の呼び出し口は、`start-state` に `:code` を渡して新しい関数を呼ぶだけの関数として残す。
3. 「行 → 開始状態」のキャッシュを持つ。キーは、絶対行、C1 の版数、メジャーモードの3つ（D24）。
4. 無効化には C1 の変更行の問い合わせ（利用側の版数 V の後に変わった最小の絶対行。記録の上限を超えたら行0）を使い、
   その行から下だけ再計算する。**ある行の終了状態が前回と同じになったら打ち切る**。
5. 描画は表示範囲の行だけを求める。表示範囲より上が未計算なら、上から順に状態だけ求める（トークンは作らない）。
6. 描画の呼び出しでは、バッファと絶対行（表示行に narrow の開始行を足したもの）を渡す。
   折り返した行でも、トークンの計算は1行につき1回にする。
7. 他のモード（generic）は今のまま（line-local）。このキャッシュの形は、のちに虹色の括弧・固定ヘッダ・パンくず
   （roadmap の v0.5 Rich モード）でも使う。
8. 既存のテスト `syntax-highlighting-test.lisp` 60〜69行（閉じていない `#|` を行内に留める）は、新しい挙動に合わせて変える。
   期待値を変えてよいのはこの範囲だけ。

## 性能

- 2万行の `.lisp` の1行目で `"` を入力し、DEL で消すケースを足す。
  - 変わった画面の範囲（`cell_attrs`）が出るまでを1サンプルとし、25件ずつ4回測る。
  - `t/e2e/loom_e2e/benchmarks.py` の `metric_specs` と `_aggregate_trials`、`t/e2e/loom-test.py` の `target_gate_names` に登録してゲートにする。
  - p95 は 50ms 以下。守れない場合は、表示範囲より下の再計算を次の tick に回す（その間、下の行は前回の色のまま）。
- ウィンドウを2つに分けた最悪のケースも測って報告する（ゲートにはしない）。

## 受け入れ導線（先に書く）

R6 の固定導線（観測は `cell_attrs`）として、`t/e2e/loom_e2e/path_generation.py` に WP6 用の関数を足し、
`_fixed_paths()` には呼び出しを1行足すだけにする（D15）。
台帳は `packages/feature/syntax-highlighting/t/paths.sexp`、シナリオは
`packages/feature/syntax-highlighting/t/e2e/scenarios/command-paths.json`（今は無いので作る）に書く。

- `#|` を3行にまたがって書く → 各行がコメントの属性（画面の属性で観測）
- 入れ子 `#| #| |# |#` → 内側の `|#` の後もコメントのまま
- 3行の docstring → 各行が文字列の属性
- 1行目の `"` を消す → 下の行の属性が元に戻る

## テスト

- unit: 状態遷移の表（文字列中の `\"`、`#\"`、`#|` を含む文字列、`;` の後の `#|` など）
- property（cl-weave）: 任意の行分割で、全体を一度に解析した結果と行ごと＋状態引き継ぎの結果が一致
