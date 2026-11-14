# WP7 LSP サーバ要求への応答

- 規模: M
- 所有スライス: `feature/lsp`
- 波: 第1波

## 現状（根拠）

- `feature/lsp/src/application-lsp-protocol-routing.lisp:27-38` の `%lsp-route-message` は、
  shutdown 応答・publishDiagnostics・initialize 応答・保留中の応答の4種だけを扱い、**それ以外は何もせず捨てる**。
  サーバからの要求（`id` と `method` を両方持つメッセージ）にも応答しない。
- `application-lsp-protocol-initialize.lisp:3-17` の `%lsp-client-capabilities` は
  `workspace.workspaceFolders: true` と、2か所の `dynamicRegistration: true` を広告している。
  そのため、サーバは `client/registerCapability` や `workspace/configuration` を送ってよい前提で動く。
  応答を待つ作りのサーバは、初期化の途中で止まりうる。

## 仕様

### 1. 要求の判別

受信メッセージに `id` と `method` が両方あれば「サーバからの要求」。`%lsp-route-message` の最初の分岐で拾い、
`%lsp-handle-server-request` に渡す。**どの要求にも必ず1回だけ応答する。**

### 2. 応答の表

| method | 応答 |
|---|---|
| `client/registerCapability` | 登録内容を session に記録し、`result: null` |
| `client/unregisterCapability` | 記録から外し、`result: null` |
| `workspace/configuration` | `params.items` の数だけ `null` を並べた配列（設定は今回は渡さない） |
| `workspace/workspaceFolders` | initialize で送ったのと同じ workspaceFolders |
| `window/workDoneProgress/create` | `result: null`（進捗の表示は roadmap の U6） |
| `window/showMessageRequest` | ミニバッファで `actions` から選ばせ、選んだ action を返す。`C-g` で `null` |
| その他 | `error: { code: -32601, message: "Method not found" }` |

応答の送信は `application-lsp-protocol-send.lisp` に `%lsp-send-response` / `%lsp-send-error-response` を足す
（既存の `%lsp-send-object` を使う）。

### 3. 広告をそろえる

記録した登録を使わない機能については、`dynamicRegistration` を `false` にするか、記録だけして無視するかを決める。
推奨は **今回は `false` にそろえる**（使わないものを広告しない）。`registerCapability` への応答は、それでも上の表どおりに行う。

### 4. 見える化

未知の method を受けたら `*Messages*` に1行（`lsp: unhandled server request <method>`）。エコー行には出さない。

## 受け入れ導線（先に書く）

`feature/lsp/t/paths.sexp`（R5 外部ツールの系）:

- 擬似サーバが表の各 method を送る → 正しい `id` で正しい応答が返る（擬似サーバ側で観測）
- 未知の method → `-32601`
- `workspace/configuration` を待ってから補完を返す擬似サーバ → 補完ポップアップが出る
- 実物: typescript-language-server と nixd で `lsp-start` → `C-M-i` で候補が出る（FR-V04）

## 非目標

- `workspace/configuration` に実際の設定値を渡すこと（init.lisp からの LSP 設定は後で）
- 進捗の表示（U6）
