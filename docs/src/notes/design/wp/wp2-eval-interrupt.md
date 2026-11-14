# WP2 評価の中断

- 規模: M
- 所有: `packages/feature/evaluation/`、`packages/core/editor-session/src/application-session-extension-points.lisp`、
  `src/application/input-dispatch.lisp`、`src/application/startup-services.lisp`（WP1 と関数単位で分ける）、
  `flake.nix` と `flake.lock`（cl-tty-kit v1.8.0、cl-concurrent-kit v0.7.0）
- 開始条件: C1（core/buffer の基盤）と P1（cl-tty-kit v1.7.3）が着地し、K1（cl-tty-kit v1.8.0 の入力の監視）と
  K2（cl-concurrent-kit v0.7.0 の中断できる範囲）のタグが出てから着手する
- 方式: メインスレッドで評価し、評価中は入力を監視する（D1、[decisions.md](../decisions.md) の Q3）

## 現状（根拠）

`packages/feature/evaluation/src/infrastructure-lisp-evaluator.lisp:35-69`（`%evaluate-form` / `evaluate-lisp-source`）が、
エディタと同じスレッドで `LOOM-USER` の式を評価する。タイムアウトも中断もない。
`M-:` で `(loop)` を評価するとイベントループが止まり、`C-g` でも中断できず、端末から kill するしかない。

- 端末は `/dev/tty` を開いた fd で、ISIG は無効である（`src/application/startup-services.lisp:41-62`）。
  `C-g` はシグナルではなく入力のバイトとして届く。
- シグナルのハンドラは `sb-sys:enable-interrupt` で登録され、メインスレッドの上で走る。
  wake のパイプに、SIGTERM は 1、SIGHUP は 2、SIGTSTP は 3、SIGCONT は 4、SIGWINCH は 5 を書く
  （`src/application/startup-services.lisp:331-350`）。

## 仕様（D1）

1. `M-:`・`C-x C-e`・`eval-buffer` は、メインスレッドで評価する。評価中は、K1 で `/dev/tty` の fd を監視する
   （fd 0 ではない）。評価中は編集できない。
2. 評価中に `C-g`（従来のバイト 7 の形と CSI-u の形の両方）が来たら、K2 で 200ms 以内に中断し、
   エコー行に `Evaluation interrupted` を出す。途中までの標準出力は、今の結果と同じ場所に出す。
3. 中断は、評価器の `handler-case error` より先に受け取り、エラーとしては表示しない。
   K2 は中断を範囲の境界へ直接移すので、評価する式の中の `handler-case`・`ignore-errors`・`handler-bind` では
   握りつぶせない。
4. `C-g` 以外のキーは、評価の後に、打った順に1バイトも欠けずに処理する。
   監視を始めた時点で Lisp のストリームにたまっているバイトは、読んだバイトより先に戻す。
5. bracketed paste の中の `C-g` は、中断として扱わない。
6. 評価していないときは、監視スレッドを作らない。
7. シグナルのハンドラは、今までどおり wake のバイトを書く。そのうえで、評価中に 1（SIGTERM）か 2（SIGHUP）を受けたら、
   理由を「シグナル」として評価を中断する（D20）。その後、ループが退避を書いて、143 か 129 で終了する。
   それ以外のバイト（SIGWINCH の 5 など）では中断しない。
8. 拡張点は core/editor-session に足し、実装は `src/` が起動時に登録する（D2）。

評価中の式は、メインスレッドで動くので、エディタの状態に触る公開 API をそのまま呼べる。

## 性能

- 評価していないときの、2万行ファイルでのキー応答（要件文書の欠陥番号 D13。計画書の決定 D13 とは別）と再描画の p95 は変えない。

## 既知の制約

v0.2.0 のリリースノートに書く（v0.2 実行計画書 11章）。

- SBCL は、`without-interrupts` の中と GC の間は、中断を遅らせる。
- メインスレッドで評価している間は、画面を更新できない。経過の表示も出せない。
- 評価以外の長いコマンド（例: 30秒のタイムアウトつきの format）の最中は、シグナルの処理がそのコマンドの終了まで遅れる。

## 受け入れ導線（先に書く）

固定導線として、`t/e2e/loom_e2e/path_generation.py` に WP2 用の関数を足し、`_fixed_paths()` には呼び出しを1行足すだけにする（D15）。
台帳は `packages/feature/evaluation/t/paths.sexp`、シナリオは `packages/feature/evaluation/t/e2e/scenarios/command-paths.json` に書く。

- `M-:` に `(loop)` → `C-g` でエディタに戻り、バッファのバイト列が不変、エコー行に `Evaluation interrupted`
- `M-:` に `(loop (ignore-errors (sleep 0.1)))` → `C-g` で中断する
- `M-:` に `(sleep 1) 42` を評価中に `C-f` を打つ → `42` の後に1つ進む
- `C-x C-e` と `eval-buffer` でも、`C-g` で同じように中断できる
- 公開 API を呼ぶ式が、正しい値を返す
- 評価中に端末の大きさを変えても、中断しない
- `(loop)` の最中に SIGTERM を送る → exit 143 になり、退避の本文が書かれる

## 非目標

- SWANK / SLY 互換（範囲外のまま）
- 複数評価の並列実行
