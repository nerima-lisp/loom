# Claude Code への依頼文

そのまま貼り付けて使う。1回の依頼で1つの WP（第1波だけは並列可）。
各 WP が終わったら、差分と検証結果を作者が確認してから次へ進む。

## 0. 最初の1回（読み込みと計画だけ）

```text
CLAUDE.md と docs/src/notes/design/README.md、daily-driver-v0.2.md、wp/ 以下の8ファイルを読んでください。
まだコードは変更しないでください。
各 WP について、(1) 仕様に書かれた根拠（ファイルと行）が今のソースと一致しているか、
(2) 仕様のままでは実装できない点や矛盾、(3) 着手の順番の提案、を報告してください。
```

## 1. 第1波（並列可。jj workspace を WP ごとに分ける）

```text
docs/src/notes/design/wp/wp3-file-tree-scroll.md を実装してください。
CLAUDE.md の「進め方」どおり、先に受け入れ導線を書き、それが失敗することを確かめてから実装し、
最後に「検証」のコマンドを全部通してください。jj new で新しい change を作り、
説明は「feat(file-tree): scroll the sidebar to keep the selection visible (WP3)」の形で。push はしないでください。
```

同じ形で WP4（`wp4-buffer-list-save-some.md`）、WP5（`wp5-basic-editing.md`）、WP7（`wp7-lsp-server-requests.md`）。
WP7 は、typescript-language-server と nixd が開発シェルに無ければ、実物での確認を報告に「未確認」と書いて終える。

## 2. 第2波

```text
docs/src/notes/design/wp/wp1-recover.md を実装してください。
lifecycle の退避形式を変えるので、旧形式（メタなしの .txt）が残っていても壊れないことをテストで示してください。
以下、第1波と同じ手順・同じ制約で。
```

```text
docs/src/notes/design/wp/wp6-cl-multiline-highlight.md を実装してください。
性能ゲートの結果（2万行、先頭編集の最悪ケース）を変更前と後の数値で報告してください。
以下、第1波と同じ手順・同じ制約で。
```

## 3. 第3波（decisions.md の Q3 が決まってから）

```text
decisions.md の Q3 の決定に従って、docs/src/notes/design/wp/wp2-eval-interrupt.md を実装してください。
仕様が Q3 の決定と食い違う箇所は、先に仕様の修正案を示して止まってください。
```

## 4. 仕上げ

```text
daily-driver-v0.2.md の「1日のシナリオ」12場面を、1本の PTY シナリオ（導線規則 R9）として t/e2e/scenarios に追加してください。
WP0 の手動チェックの記入は作者が行うので触れないでください。
最後に v0.2 の合格ゲートの各項目について、満たしたか・その証拠（コマンドと結果）を表で報告してください。
```
