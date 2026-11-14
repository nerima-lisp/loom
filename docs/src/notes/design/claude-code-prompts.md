# Claude Code への依頼文

v0.2 のタスクは、v0.2 実行計画書9章の型で依頼する。1回の依頼で1つのタスクを渡す。
開始条件（計画書4章）を満たしたタスクは、並列に依頼してよい。後続のタスクは、依存先が着地してから着手する（D8）。
各レーンは `wp/<task>` を push して CI を流し、loom の main への着地は作者が行う（D7）。

## 依頼文の型

計画書9章の型。`<...>` を埋めて使う。

```text
対象: <タスク ID> <名前>
リポジトリとワークスペース: <repo>.git/.worktrees/v02-<task>（main@origin を基点に jj workspace add）
変えてよいパス: <6章の「所有」>
変えてはいけないもの: それ以外のパス、許可表、他のセッションの workspace、loom の main への push、仕様が求めていない既存の振る舞いのテストの期待値
認める追従: 自分のスライスの中で追加だけで済む隣のファイルの変更（シナリオの JSON への記録、package への export、テスト用の補助）。仕様が直接に引き起こす既存テストの追従（導線の件数の assert、仕様で移した欄の参照先、足した記号の export 一覧など）。報告に、変えたファイルと理由、変えたテストごとにどの要件から決まるかを書く
仕様: <6章の該当する節をそのまま>
共通規則: <5章をそのまま>
検証: 5章の検証コマンド。nix を実行する前に jj status。合格の主張には exit status・件数・assert の数を付ける
push: wp/<task> の bookmark だけ。push の前に gitleaks。フックに止められたら、拒否文の prefix を付けて単独のコマンドで実行する。許可の範囲は依頼ごとに書く
秘密: 環境変数の値を出力しない。トークンを記録・文書・PR に書かない
止まる条件: 許可表が増える、仕様が求めていない既存の振る舞いのテストの期待値を変える必要がある、他のスライスの責務を変える（他のタスクが所有するファイルの既存の行を書き換える場合を含む）、仕様と現状のソースが食い違う
報告: 8章の完了条件の全項目
```

- 「仕様」には計画書6章のそのタスクの節を、「共通規則」には計画書5章を、どちらも手を加えずに入れる。
  この文書には6章の中身を写さない。`wp/` 以下の仕様は背景として読ませてよいが、食い違ったら計画書を正とする。
- ワークスペースは、`jj --ignore-working-copy git fetch --remote origin --branch main` を実行した後に作る。
  bare 直下の jj には `--ignore-working-copy` を付ける。
- 1タスクを筋の通った小さなコミットに分ける。説明は `feat(<slice>): <要約> (<task>)` の形にする。
- CI は `gh workflow run CI --ref wp/<task>` で流す。

## タスクごとの開始条件と置き場所

ワークスペース名と bookmark には、タスク ID を小文字にして入れる。`<slice>` は所有の中心になるスライス。

| タスク | 開始条件 | ワークスペース | change の説明 | push 先 |
|---|---|---|---|---|
| D0 | すぐ | `v02-d0` | `feat(<slice>): <要約> (D0)`（このファイルを入れたタスク） | `wp/d0` |
| C1 | すぐ | `v02-c1` | `feat(buffer): <要約> (C1)` | `wp/c1` |
| F1 | すぐ | `v02-f1` | `feat(command): <要約> (F1)` | `wp/f1` |
| P1 | すぐ | `v02-p1` | `feat(<slice>): <要約> (P1)` | `wp/p1` |
| P2 | すぐ | `v02-p2` | `feat(<slice>): <要約> (P2)` | `wp/p2` |
| G1 | すぐ | `v02-g1` | `feat(git): <要約> (G1)` | `wp/g1` |
| S1 | すぐ | `v02-s1` | `feat(<slice>): <要約> (S1)` | `wp/s1` |
| K1〜K4 | すぐ | 各キットの `<repo>.git/.worktrees/v02-k1`〜`v02-k4` | `feat(<slice>): <要約> (K1)` など | キットは PR。loom 側は `wp/<kit-task>-probe` |
| WP3 | すぐ | `v02-wp3` | `feat(file-tree): <要約> (WP3)` | `wp/wp3` |
| WP5a | すぐ | `v02-wp5a` | `feat(command): <要約> (WP5a)` | `wp/wp5a` |
| WP7 | すぐ | `v02-wp7` | `feat(lsp): <要約> (WP7)` | `wp/wp7` |
| WP4a | すぐ | `v02-wp4a` | `feat(buffer-menu): <要約> (WP4a)` | `wp/wp4a` |
| WP6 | C1 が着地 | `v02-wp6` | `feat(syntax-highlighting): <要約> (WP6)` | `wp/wp6` |
| WP2 | C1 と P1 が着地し、K1 と K2 のタグが出た | `v02-wp2` | `feat(evaluation): <要約> (WP2)` | `wp/wp2` |
| WP1 | F1 と P2 が着地し、K3 と K4 のタグが出た | `v02-wp1` | `feat(lifecycle): <要約> (WP1)` | `wp/wp1` |
| WP4b | F1 と WP4a が着地 | `v02-wp4b` | `feat(files): <要約> (WP4b)` | `wp/wp4b` |
| WP5b | F1 が着地 | `v02-wp5b` | `feat(kill-ring): <要約> (WP5b)` | `wp/wp5b` |
| T9 | ここより上のすべてが着地 | `v02-t9` | `feat(<slice>): <要約> (T9)` | `wp/t9` |
| R1 | T9 が着地し、WP0 が記入済み | `v02-r1` | `feat(<slice>): <要約> (R1)` | `wp/r1` |
| WP0 | いつでも | なし | 作者が `docs/src/notes/daily-driver-checklist.md` を記入する。依頼しない | なし |

ワークスペースは、キットを除いて loom の `<repo>.git/.worktrees/` の下に作る。

## 依頼するときに添えること

- **「すぐ」のタスクの順番。** 開始条件が「すぐ」のタスクは同時に始められる。nix の lock と CI の取り合いで遅くなる場合は、
  後続の多いタスクから回す。順番は C1、F1、K1、K2、K3、K4、P1、P2。
- **キット（K1〜K4）。** 計画書5章「キットの公開」の手順を依頼文に入れる。レーンは version の更新を含めた PR と
  リリースノートの下書きを用意し、loom 側に `wp/<kit-task>-probe` を作って loom の CI を Linux と macOS で流す。
  probe の bookmark は着地させない。結合、タグ、公開は進行役が行う（D10、D28）。
- **WP1 と WP2。** probe の統合テストを自分の change に含め、キットの固定先をタグに向ける（`flake.nix`、`flake.lock`）。
  `flake.nix` と `flake.lock` は P1・P2・WP1・WP2 の共有ファイルで、後から着地する側が `nix flake update <input>` を
  やり直して rebase する。
- **WP2。** Q3 は D1 で決まっている（[decisions.md](decisions.md)）。仕様と止まる条件は9章の型のまま渡す。
- **WP7。** 実物の typescript-language-server と nixd の既存の補完シナリオに、応答の assert を足す。両 OS の CI で緑にする。
- **S1。** 受け入れ導線は main で通る回帰テストなので、報告には「main で通った出力」を残す。
- **T9。** 計画書7章の、前夜と、続く12場面を1本のシナリオにする。1章の条件を項目ごとに表にして、
  満たしたかどうかと証拠（コマンドと結果）を報告させる。WP0 の記入には触れさせない。
- **R1。** CI を流すところまでがレーンの作業。タグと公開は作者が行う（D21）。
