# WP7 LSP サーバ要求への応答

- 規模: M
- 所有: `packages/feature/lsp/src/application-lsp-protocol-*.lisp`、`packages/core/minibuffer/src/minibuffer-activation.lisp`、
  `t/e2e/scenarios/lsp.py`
- 開始条件: すぐ

## 現状（根拠）

- `packages/feature/lsp/src/application-lsp-protocol-routing.lisp:27-38` の `%lsp-route-message` は、
  shutdown 応答・publishDiagnostics・initialize 応答・保留中の応答の4種だけを扱い、**それ以外は何もせず捨てる**。
  サーバからの要求（`id` と `method` を両方持つメッセージ）にも応答しない。
- `application-lsp-protocol-initialize.lisp:3-17` の `%lsp-client-capabilities` は
  `workspace.workspaceFolders: true` と、2か所の `dynamicRegistration: true` を広告している。
  そのため、サーバは `client/registerCapability` や `workspace/configuration` を送ってよい前提で動く。
  応答を待つ作りのサーバは、初期化の途中で止まりうる。

## 仕様

### 1. 要求の判別

受信メッセージに `id` と `method` が両方あれば「サーバからの要求」。`%lsp-route-message` の最初の分岐で拾い、
`%lsp-handle-server-request` に渡す。**どの要求にも1回だけ応答する。**

### 2. 応答の表

| method | 応答 |
|---|---|
| `client/registerCapability` | 登録内容を session に記録し、`result: null` |
| `client/unregisterCapability` | 記録から外し、`result: null` |
| `workspace/configuration` | `params.items` の数だけ `null` を並べた配列（設定は今回は渡さない） |
| `workspace/workspaceFolders` | initialize で送ったものと同じ。ルートがなければ `null` |
| `window/workDoneProgress/create` | `result: null`（進捗は表示しない） |
| `window/showMessageRequest` | `actions` の title を補完候補にしたプロンプトで選ばせ、選んだ action を返す。`C-g` なら `null` |
| その他 | `error: { code: -32601, message: "Method not found" }` |

`window/showMessageRequest` は、ミニバッファを使っているときは列に積み、空いたときに出す。セッションが終わったら、列を捨てる。

応答の送信は `application-lsp-protocol-send.lisp` に `%lsp-send-response` / `%lsp-send-error-response` を足す
（既存の `%lsp-send-object` を使う）。

### 3. 広告をそろえる

`dynamicRegistration` は、2か所とも `false` にする（使わないものを広告しない）。`registerCapability` への応答は、それでも上の表どおりに行う。
`publishDiagnostics` の能力は、`capabilities` の直下から `textDocument` の下に移す。

### 4. 未知の要求の記録

未知の method を受けたら `*Messages*` に1行（`lsp: unhandled server request <method>`）。エコー行には出さない。
そのために、core/minibuffer に、エコー行に出さずに `*Messages*` にだけ書く公開関数を足す（D2）。

### 5. サーバから届いた文字列

title、message、method 名は、TAB 以外の C0・C1 制御文字を U+FFFD に置き換えてから、表示または記録する。

## テストの期待値

`lsp-session-lifecycle-initialize-test.lisp` は、仕様に合わせて次の行を追従させる。

- 27〜28行（`synchronization` の `dynamicRegistration` の assert）。FR-705 から決まる。
- 24行の `publishDiagnostics` を読む束縛と、それを使う29〜30行の assert（`publishDiagnostics` の位置の参照）。FR-706 で能力を `textDocument` の下に移すことから決まる。

ほかのテストの期待値は、仕様が直接に引き起こす追従のほかは変えない。

## 受け入れ導線（先に書く）

R5 の固定導線として、`t/e2e/loom_e2e/path_generation.py` に WP7 用の関数を足し、`_fixed_paths()` には呼び出しを1行足すだけにする（D15）。
台帳は `packages/feature/lsp/t/paths.sexp`、シナリオは `packages/feature/lsp/t/e2e/scenarios/command-paths.json` に書く。

- 偽トランスポート（`t/test-helpers-lsp.lisp` 3〜57行）で、表の各 method を送る → 正しい `id` で正しい応答が返る
- 同じく未知の method → `-32601`
- 偽の LSP サーバ（Python のスクリプトを `.loom-lsp` から exec し、`t/e2e/scenarios/lsp.py` 244〜395行の supervisor のひな形を使い回す）が、
  `workspace/configuration` への応答を待ってから補完を返す → 補完ポップアップが出る
- ESC を含む title を送る → 置換文字が表示される
- 実物: typescript-language-server と nixd の既存の補完のシナリオ（`lsp.py` 782〜839行、999〜1023行）に、
  プロトコルのログで「サーバからのすべての要求に、同じ ID の応答が1回ずつ返った」ことを確かめる assert を足す（FR-V04）

あわせて、`lsp.py` のプロキシの方向ラベルが `nixd` に固定されている問題（335行、349行）を直す。

## 非目標

- `workspace/configuration` に実際の設定値を渡すこと（init.lisp からの LSP 設定は後で）
- 進捗の表示
