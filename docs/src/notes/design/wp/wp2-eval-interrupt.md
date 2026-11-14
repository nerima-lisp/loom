# WP2 評価の中断

- 規模: M
- 所有スライス: `feature/evaluation`
- 波: 第3波 — **[decisions.md](../decisions.md) の Q3 が決まるまで着手しない**

## 現状（根拠）

`feature/evaluation/src/infrastructure-lisp-evaluator.lisp:35-69`（`%evaluate-form` / `evaluate-lisp-source`）が、
エディタと同じスレッドで `LOOM-USER` の式を評価する。タイムアウトも中断もない。
`M-:` で `(loop)` を評価するとイベントループが止まり、`C-g` も効かず、端末から kill するしかない。

## 仕様（Q3 の推奨案 A を前提）

1. 評価はワーカースレッドで走らせる。イベントループは止めない。
   結果の受け渡しは file-tree と同じ形（ワーカー → 結果チャネル → `:tick` フックで drain、
   `feature/file-tree/src/infrastructure-concurrent-runtime-results.lisp` の `loom-concurrent-runtime-drain` を参照）。
2. 評価中はモードラインに `eval…`、300ms を超えたら経過秒を出す（`eval 3s`）。
3. 評価中に `C-g`（`keyboard-quit`）が来たら、ワーカーに `sb-thread:interrupt-thread` で `abort` を送る。
   エコー行は `Evaluation interrupted`。`*Loom-Eval*` に途中までの出力を残す。
4. 同時に走る評価は1つまで。評価中にもう一度 `M-:` したら `An evaluation is running — C-g to interrupt`。
5. 1回目の `C-g` から 2 秒たってもワーカーが止まらなければ、`sb-thread:terminate-thread` で強制終了し、
   `Evaluation terminated` と出す（UX の約束「C-g はいつでも安全」）。

### Q3 の推奨案 A: エディタ状態にはメインスレッドで触る

評価中のコードがエディタの状態（バッファ・ウィンドウ・ミニバッファ）に触る公開 API を呼んだら、
その呼び出しをメインスレッドのキューに積んで、結果を待つ（`loom:call-in-editor-thread` を新設）。
ワーカーから直接 `*editor-state*` を書き換えることは禁止。

## 受け入れ導線（先に書く）

`feature/evaluation/t/paths.sexp`:

- `M-:` に `(loop)` → `C-g` でエディタに戻り、バッファのバイト列が不変、エコー行に `Evaluation interrupted`
- `M-:` に `(sleep 1) 42` → 評価中もカーソル移動が効き、終わると `42`
- 評価中にもう一度 `M-:` → 拒否メッセージ
- `C-x C-e` と `eval-buffer` でも同じ中断が効く
- 評価中の式が `(loom:current-buffer-name)` のような API を呼んでも壊れない（案 A の検査）

## 非目標

- SWANK / SLY 互換（範囲外のまま）
- 複数評価の並列実行
