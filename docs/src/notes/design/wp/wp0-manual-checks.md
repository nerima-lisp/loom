# WP0 手動チェック5行

- 規模: S（実装なし）
- 担当: 作者
- 波: 並行

## 目的

FR-V07 の手動範囲（IME・OSC 52・マウス・ブラケットペースト・日常の使い心地）を記入し、
v0.1.0 のリリース検証を閉じる。PTY E2E ではこの5つは確かめられない。

## 手順

`docs/src/notes/daily-driver-checklist.md` の「Preparation」と表のとおり。各行に `Pass` / `Fail` と短い所見を書く。

## 実装者（Claude Code）がすること

- **何もしない。** この表の `Author result` 列を Claude Code が埋めてはいけない（作者の実機観測だけが証拠）。
- 作者が `Fail` を記入した行があれば、その所見を新しい WP として切り出す提案をする。

## 補足（キャンバスより）

- tmux 内では OSC 52 が届かないことがある。tmux の `set-clipboard on` を Getting Started に1行足すかは、作者の結果を見てから決める。
