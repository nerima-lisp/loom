# 要件定義: loom を日常使用に載せる

## 1. 背景と判断基準

loom は 20 の feature スライスと 106 の M-x コマンドを持つが、作者自身の日常使用に
至っていない。ヒアリングで確定した位置づけは **「作者が毎日使う実用エディタ」** であり、
機能の要不要はこの一点で判定する。

判定基準:

- **残す** — 作者が使う、または使う意思がある。
- **削る** — 使っておらず今後も使う意思がない。LOC ではなく、event loop と
  永続化フォーマットに持ち込む状態とバグ経路がコストの本体である。
- **足す** — それが無いために日常使用が止まっている。

対象言語（ヒアリング確定）: Common Lisp / Emacs Lisp、Nix、TypeScript / Web、
Markdown / Org。Lisp 系と非 Lisp 系の両方を書くため、SWANK と LSP はどちらも
必要であり、一方が他方を代替しない。

## 2. スコープ判定

### 2.1 削る

| スライス | 規模 | 判定根拠 |
| --- | ---: | --- |
| multiple-cursors | 383 LOC | 作者が未使用かつ今後も使う意思なし。行単位のみの部分実装であり、育てる動機も無い |

### 2.2 残す（削減対象外）

terminal、workspace、keyboard-macro、register、file-tree、session、git、
auto-save、format、shell、evaluation、project、search、mode、window、
syntax-highlighting、user-init、core/editor。いずれも作者が使用中または使用意思あり。

### 2.3 LSP スライスの扱い

現行 1,128 LOC は diagnostics と document-sync のみを提供する。Nix と TypeScript を
書く以上、**撤去ではなく拡張**する。ただし優先度は最下位（第 6 章）。

## 3. 機能要件

優先度は **mandatory**（これが無いと日常使用が成立しない）と **optional**
（あると質が上がるが、無くても日常使用は成立する）で表す。

各要件に証拠タグを付す — **verified**（コードを読んで確認）、**inferred**（確認済み
事実からの導出）、**assumed**（ヒアリング由来で未検証）。

---

### FR-000: multiple-cursors スライスの撤去

**優先度: mandatory**（未使用機能を残す判断は、そのテストを恒久的に保守する判断であるため）
**証拠: verified**

**これはディレクトリの削除では済まない。** `grep -rln 'multiple-cursor'` で確認した
参照は 24 ファイルに及び、スライス外の呼び出し側を含む。

スライス本体（削除）:

- `packages/feature/multiple-cursors/src/` 配下 6 ファイル
- `loom.asd` の `:components` エントリ

スライス外（呼び出し側の除去が必要）:

- `packages/core/editor/src/application-commands-yank-support.lisp`
- `packages/core/editor/src/application-commands-yank-pop-support.lisp`
- `packages/core/editor/src/application-commands-editing-support.lisp`
- `src/application/editor-state-types.lisp`
- `src/application/input-routing-effects.lisp`
- `src/application/command-definitions-tooling.lisp`（3 つの M-x コマンドと
  `C-x m n` / `C-x m l` / `C-x m c` のキーバインド）
- `src/presentation/layout.lisp`（副次カーソルの reverse-video 描画）
- `src/package-exports.lisp`

テスト:

- `t/unit/multiple-cursor-{basic,delete,yank}-test.lisp`（削除）
- `t/package.lisp`、`t/integration/input-routing-keymap-test.lisp`、
  `t/integration/frame-layout-test.lisp`（参照の除去）

ドキュメント:

- `docs/src/reference/architecture.md`、`docs/src/reference/api.md`、
  `docs/src/project/roadmap.md`

**受け入れ基準**

- 完了コマンド 4 本（第 4 章 NFR-003 の定義）がすべて exit 0。
- リポジトリ全体の grep で `multiple-cursor` の残存参照がゼロ。
- **単一カーソル時の yank / yank-pop / セルフインサートの挙動が変わらない。**
  core/editor から multiple-cursors への分岐を外す作業であり、今回の撤去で唯一
  回帰の危険がある箇所。既存の kill/yank 系テストで確認する。

---

### FR-001: 全角文字を含む行のカーソル位置整合

**優先度: mandatory**（日本語の文章編集が現状成立しないため）
**証拠: verified**

現状は不整合である。`src/presentation/frame-layout-cursor.lisp:35` はカーソルの
x 座標に `buffer-visible-point-column` を直接使うが、その値は
`packages/core/editor/src/domain-buffer-narrowing.lisp:57-65` が
`%text-offset-to-position-values` から得る**文字数**である。一方バッファ描画は
`src/infrastructure/terminal-renderer-text.lisp:10` で `cl-tty-kit:char-width` を
参照し全角を 2 セルとして描く。結果として、point より前にある全角文字 1 つにつき
カーソルが 1 セル左にずれる。

同じ不整合が `src/presentation/layout-minibuffer.lisp:13` にもある。

**受け入れ基準**

- 表示列（screen column）を文字列先頭から point までの `char-width` 合計として
  求める問い合わせが存在し、カーソル配置がそれを使う。
- `"あいう|"` で point が 3 文字目の後にあるとき、カーソル x は 6 になる。
- 半角のみの行では現行の値と一致する（回帰なし）。
- ミニバッファの日本語入力でもカーソルが入力位置に一致する。

---

### FR-002: 横スクロール（truncate + 追従）

**優先度: mandatory**（画面幅を超える行を編集できないため）
**証拠: verified**

現状、バッファ描画は各行を `src/infrastructure/terminal-renderer-buffer.lisp:15-16`
でウィンドウ幅に切り詰め、ビューポート追従は
`src/presentation/frame-layout.lisp:13-25` の `%layout-keep-point-visible` が
**行方向のみ**を扱う。列方向の追従は存在せず、カーソルは
`frame-layout-cursor.lisp:35` の `(min ... (1- width))` で右端にクランプされる。
したがって point が画面右外にあるとき、カーソルは実際の位置と無関係な右端に描かれる。

**受け入れ基準**

- ウィンドウが水平スクロール位置を状態として持つ（`window-scroll-line` と対になる概念）。
- point が可視列範囲の外に出たとき、次のフレームで可視範囲に入るようスクロール位置が
  調整される。左右いずれの方向でも成立する。
- 描画はスクロール位置を起点とした部分文字列を、表示セル境界を割らずに切り出す
  （全角文字を半分だけ描画しない）。
- カーソル x のクランプが不要になり、常に真の表示列を指す。
- 水平スクロール位置はウィンドウ分割・リサイズ後も破綻しない。

---

### FR-003: 行折り返し（word wrap）

**優先度: mandatory**（Markdown / Org での文章執筆が主用途に含まれるため）
**証拠: verified**（現状の不在。実装方式は inferred）

1 つの論理行を画面幅で複数の画面行に折り返して表示する。

これは FR-002 より影響範囲が広い。**論理行番号と画面行番号が 1:1 でなくなる**ため、
以下すべてが折り返しを考慮する必要がある。

- 垂直スクロール（`%layout-keep-point-visible`、`%scroll-window`）
- `next-line` / `previous-line` の移動単位
- カーソル位置計算（`editor-cursor`）
- バッファ描画（`%layout-draw-windows` 経由の行描画）

**受け入れ基準**

- 画面幅を超える論理行が、幅で折り返されて全文表示される。
- 折り返しは表示セル境界を割らない（全角文字を分断しない）。
- point が折り返し後の何行目にあっても、カーソルがその位置に描かれる。
- 折り返された行をまたぐ垂直スクロールで、行が途中から欠けない。
- `goto-line` と検索ジャンプが論理行番号を維持する（画面行番号に置き換わらない）。

**未決事項**: `next-line` が画面行単位で動くか論理行単位で動くかは Emacs でも
`line-move-visual` として設定項目になっている論点。第 8 章に記録。

---

### FR-004: 表示方式のモード連動と切り替え

**優先度: mandatory**（FR-002 と FR-003 の両方を持つ以上、選択機構が必須であるため）
**証拠: assumed**（ヒアリングでの選択に基づく）

- バッファ単位で「切り詰め + 横スクロール」と「折り返し」を切り替えられる。
- major-mode が既定値を決める。コード系モード（common-lisp / nix / typescript /
  rust / python / shell / json / emacs-lisp）は切り詰め、文章系モード
  （markdown / org / text）は折り返しを既定とする。
- `M-x toggle-truncate-lines` が選択中バッファの設定を反転する。

**受け入れ基準**

- `.md` を開くと折り返し、`.lisp` を開くと切り詰めで表示される。
- `toggle-truncate-lines` の直後のフレームで表示方式が変わる。
- 設定はバッファ単位であり、同一バッファを 2 つのウィンドウに表示した場合も一貫する。

---

### FR-005: major-mode の追加（Nix / TypeScript / Emacs Lisp / Org）

**優先度: mandatory**（対象言語 4 つのうち 2 つにモードが無いため）
**証拠: verified**

現在登録されているモードは `packages/feature/mode/src/domain-major-mode-definitions.lisp`
の `+major-mode-definitions+` にある `:common-lisp :python :rust :shell :markdown
:json :text`（＋ `:fundamental`）のみ。Nix、TypeScript、Emacs Lisp、Org が無い。

シンタックスハイライトは汎用実装である。
`packages/feature/syntax-highlighting/src/domain-syntax-highlighting-generic.lisp:32,36`
が `major-mode-keywords` と `major-mode-comment-prefix` を参照するため、
**モード定義を追加すればキーワード着色とコメント着色は追加実装なしで機能する**
（Common Lisp のみ `:74` で専用パスに分岐する）。

**受け入れ基準**

- `.nix` / `.ts` / `.tsx` / `.el` / `.org` を開くと対応モードが選択される
  （`major-mode-for-path`）。
- 各モードが `:name` `:comment-prefix` `:indentation-width` `:language-id`
  `:keywords` を持つ。`:language-id` は LSP の `languageId` として妥当な値
  （`nix` / `typescript` / `typescriptreact` / `org`）。
- `M-x comment-line` が各モードの正しいコメント接頭辞を挿入する。
- 各モードでキーワードとコメントが着色される。

**境界**: これは構文メタデータの登録であり、Org のアウトライン折り畳み・表・
babel などの機能実装は含まない。

---

### FR-006: インクリメンタルサーチ

**優先度: mandatory**（Emacs キーバインドを名乗る編集体験の中核であるため）
**証拠: verified**（現状の不在）

現状 `search-forward` / `search-backward` はミニバッファでパターンを確定してから
移動する方式であり（`packages/feature/search/src/domain-buffer-search.lisp:42,53`）、
入力中の追従が無い。

**受け入れ基準**

- `C-s` 入力後、パターンを 1 文字打つごとに次の一致へ point が移動する。
- 続けて `C-s` を押すと次の一致へ、`C-r` で前の一致へ移動する。
- 可視範囲内の一致箇所がハイライトされ、現在の一致は他と区別できる。
- `RET` で現在位置に確定、`C-g` で開始位置に戻る。
- 一致が無くなった時点でその旨を表示し、それ以上 point を動かさない。
- 確定したパターンは既存の検索履歴（`cl-history-kit`）に入る。
- narrowing 中は可視領域内のみを探索する（既存の `%visible-buffer-span` の契約を維持）。

---

### FR-007: S 式移動と対応括弧表示

**優先度: mandatory**（Lisp が主対象言語であり、現在リポジトリ全体で実装ゼロであるため）
**証拠: verified**（`forward-sexp` / `backward-sexp` / `show-paren` の grep 一致ゼロ）

**受け入れ基準**

- `C-M-f` / `C-M-b` が前方・後方の S 式単位で point を移動する。
- `C-M-u` / `C-M-d` が括弧の外・内へ移動する。
- `C-M-k` が前方の S 式を kill-ring に送る。
- 文字列リテラル内・行コメント内の括弧を構造として数えない。
- 文字エスケープ（`#\(` 等）を括弧として数えない。
- point が括弧に隣接するとき、対応する括弧が視覚的に区別される。
- 対応が取れていないとき、誤った位置を対応括弧として示さない。

**実装位置**: `packages/core/editor/` が妥当。既存の
`application-word-motion.lisp` が語単位移動の先例であり、同じ層に収まる。

---

### FR-008: 構造編集（paredit 相当）

**優先度: optional**（FR-007 があれば日常使用は成立する。編集速度の向上が目的）
**証拠: assumed**

- slurp / barf / wrap / splice / raise を提供する。
- 操作の前後で括弧の対応が保たれる。
- 各操作が単一の undo 単位を構成する。

---

### FR-009: SWANK 接続

**優先度: optional**（`M-:` と `C-x C-e` による self-image 評価が既にあり、日常使用は
成立する。ただし補完・定義ジャンプ・マクロ展開を CL について一括で得る最短路である）
**証拠: verified**（基盤の不在）

**制約**: リポジトリ内にソケット層が存在しない。`socket` / `usocket` /
`sb-bsd-sockets` の grep 一致はゼロ。LSP は
`packages/feature/lsp/src/infrastructure-lsp-transport.lisp:34` で
`uiop:launch-program` の標準入出力パイプを使っており、この基盤は TCP で待ち受ける
SWANK には流用できない。**新しい infrastructure 境界の追加が必要**。

**受け入れ基準**

- 外部 SBCL プロセスの SWANK に接続し、切断できる。
- 接続中は評価が外部イメージで行われ、結果が結果バッファに入る。
- シンボル補完と定義ジャンプが外部イメージの情報を使う。
- 接続失敗・切断を編集セッションを壊さずに扱う。

---

### FR-010: LSP 補完と定義ジャンプ

**優先度: optional**（Nix / TypeScript の編集品質を上げるが、無くても編集自体は可能）
**証拠: inferred**（現行 LSP スライスの範囲から）

**受け入れ基準**

- `textDocument/completion` の結果を候補として提示し、選択で挿入する。
- `textDocument/definition` の結果位置へジャンプする。ジャンプ元へ戻れる。
- サーバが当該 capability を宣言しない場合、その旨を伝えて何もしない。

**依存**: 補完候補の表示 UI が現時点で存在しない。ミニバッファ補完
（`src/application/minibuffer-completion.lisp`）は前方一致のコマンド名補完であり、
バッファ内ポップアップとは別物である。この UI 実装が本要件の主コストである。

---

## 4. 非機能要件

- **NFR-001（描画計算量）**: 折り返し導入後も、1 フレームの合成コストは
  **表示中の行数に対して線形**であること。論理行と画面行の対応をバッファ全長の
  走査で毎フレーム再構築しないこと。長大な 1 ファイルを開いた状態での
  スクロール応答が観測可能に劣化しないことをもって確認する。
- **NFR-002（表示幅の単一の真実）**: 表示列の算出は `cl-tty-kit:char-width` を
  唯一の根拠とし、カーソル配置・描画切り出し・折り返し境界・横スクロール量が
  同一の計算を共有すること。同じ列を 2 か所で別々に導出しない。
- **NFR-003（後方互換）**: FR-000 で撤去する 3 コマンドを除き、既存の M-x
  コマンドとキーバインドの挙動を変えないこと。
- **NFR-004（セッション互換）**: 表示方式（FR-004）をセッションに永続化する場合、
  v5 エンベロープの変更を伴う。現行の reader は v5 のみを受理し互換パスを持たない
  ため、形式を変える場合はバージョンを上げ、旧形式の扱いを明示すること。
- **NFR-005（層の遵守）**: 表示幅とカーソル幾何は presentation / infrastructure に
  留め、`packages/core/editor` の domain 層に端末依存の概念を持ち込まないこと。
  現行の依存契約テスト（`t/unit/dependency-contract-test.lisp`）で守られる。

## 5. 技術判断と根拠

| 判断 | 根拠 | 影響範囲 |
| --- | --- | --- |
| 横スクロールと折り返しの**両方**を実装し、モードで既定を切り替える | 対象用途がコードと文章の両方を含む。片方だけでは一方の用途が成立しない | window 状態、frame-layout、renderer、mode |
| FR-001（全角カーソル）を FR-002 より先に直す | 表示列という同じ概念の欠落が両者の原因であり、先に単一の算出を用意すれば FR-002 はその利用者になる | frame-layout-cursor、layout-minibuffer |
| FR-002 を FR-003 より先に実装する | 横スクロールは論理行と画面行の 1:1 を保つため影響範囲が小さく、表示列の基盤を先に固められる | — |
| SWANK と LSP を**両方**維持する | CL は SWANK が本質的に強く（実行時定義とマクロ展開後を見る）、Nix / TS は LSP しか無い。代替関係にない | 依存に socket 層が増える |
| multiple-cursors を撤去する | 唯一の未使用回答であり、部分実装のため育てる動機も無い | asd、コマンドカタログ、renderer、テスト |

## 6. 実装順序

| 段階 | 内容 | 理由 |
| --- | --- | --- |
| 1 | FR-005（モード追加） | 真に独立で、ハイライトが追加実装なしで付くため費用対効果が最大。地ならしとして最初に通す |
| 1' | FR-000（撤去） | core/editor の yank 経路に食い込んでおり、当初想定より重い。FR-005 で足場を確認してから着手する |
| 2 | FR-001（全角カーソル） | 表示列の単一算出を導入する。FR-002 / FR-003 の共通基盤 |
| 3 | FR-002（横スクロール） | 段階 2 の基盤の最初の利用者。論理行と画面行の 1:1 を保つ |
| 4 | FR-003 + FR-004（折り返しと切り替え） | 最も影響範囲が広い。基盤が固まってから着手する |
| 5 | FR-006（isearch） | 既存 search スライスの拡張で完結し、他と競合しない |
| 6 | FR-007（S 式移動・対応括弧） | core/editor 内で完結 |
| 7 | FR-008 / FR-009 / FR-010 | optional。段階 6 までで日常使用が成立した後に、実際の不足感で優先順位を再判断する |

段階 1〜6 の完了をもって「日常使用に載る」と判定する。

## 7. 実現性

- **可能** — 表示幅の算出基盤は `cl-tty-kit:char-width` として既に利用されている
  （`src/infrastructure/terminal-renderer-text.lisp:10`）。FR-001 / FR-002 / FR-003 は
  この関数の適用範囲を広げる作業であり、新しい外部依存を必要としない。
- **可能** — major-mode の登録 API は
  `packages/feature/mode/src/domain-major-mode-registry.lisp:8` の
  `register-major-mode` として公開されており、汎用ハイライトが自動的に追随する。
- **可能** — 検索の探索基盤は `buffer-search-forward` / `buffer-search-backward` /
  `buffer-search-spans` として存在する（`domain-buffer-search.lisp:42,53,69`）。
  FR-006 はミニバッファの入力ループを 1 打鍵ごとに探索へ接続する作業である。
- **未確認の制約** — SWANK に必要なソケット層は存在しない。`src` と `packages` を
  `socket` / `usocket` / `sb-bsd-sockets` で検索して一致ゼロ。FR-009 は
  新規 infrastructure 境界を伴う。第 8 章に未解決事項として記録。
- **未確認の制約** — 補完候補のポップアップ UI は存在しない。既存のミニバッファ補完
  （`src/application/minibuffer-completion.lisp`）は用途が異なる。FR-010 の主コストは
  プロトコルではなくこの UI である。

## 8. 未解決事項

1. **`next-line` の移動単位（FR-003）** — 折り返し時に画面行単位で動くか論理行単位か。
   Emacs は `line-move-visual` で設定可能にしている。既定をどちらにするか未決。
2. **表示方式のセッション永続化（FR-004 / NFR-004）** — バッファごとの
   truncate / wrap 設定をセッションに含めるか。含めるなら v5 形式の変更が必要。
3. **SWANK のトランスポート（FR-009）** — `sb-bsd-sockets` を直接使うか、
   ソケット層を扱う `cl-*-kit` を新設・導入するか。nerima-lisp の kit 群の
   方針に関わるため、loom 単独では決められない。
4. **Org の実装範囲（FR-005）** — 構文メタデータ登録までを本要件の範囲としたが、
   アウトライン折り畳みや表編集を将来求めるかは未決。求めるなら独立した feature
   スライスになる規模。

## 9. テスト対応

| 要件 | 種別 | 想定テスト |
| --- | --- | --- |
| FR-000 | 回帰 | 既存の kill/yank・セルフインサート系テストが撤去後も通る。`multiple-cursor` 参照の残存ゼロを検査 |
| FR-001 | unit | 表示列算出: 半角のみ / 全角のみ / 混在 / 空行 / 行頭。既存 `t/unit/terminal-renderer-cursor-test.lisp` に隣接 |
| FR-001 | integration | 日本語行でのカーソル配置。`t/integration/frame-layout-cursor-test.lisp` を拡張 |
| FR-002 | unit | 水平スクロール量の算出: point が左外 / 右外 / 範囲内。全角境界での切り出し |
| FR-002 | integration | 長い行での左右移動にビューが追従すること |
| FR-003 | unit | 論理行 → 画面行の写像: 幅ちょうど / 幅超過 / 全角混在 / 空行 |
| FR-003 | integration | 折り返し行をまたぐスクロールと `goto-line` の論理行維持 |
| FR-004 | unit | モード別既定値の解決 |
| FR-004 | integration | `toggle-truncate-lines` の即時反映 |
| FR-005 | unit | 拡張子 → モード解決（`.nix` / `.ts` / `.tsx` / `.el` / `.org`）。`t/unit/major-mode-test.lisp` を拡張 |
| FR-005 | unit | 各モードのキーワード・コメント着色。`t/unit/major-mode-syntax-highlighting-test.lisp` を拡張 |
| FR-005 | integration | `comment-line` が各モードで正しい接頭辞を挿入。`t/integration/major-mode-comment-line-test.lisp` を拡張 |
| FR-006 | unit | 1 打鍵ごとの次一致位置。一致なし。narrowing 中の探索範囲 |
| FR-006 | integration | `C-s` 連打での前進、`C-r` での後退、`C-g` での復帰、`RET` での確定と履歴登録 |
| FR-007 | unit | S 式移動: ネスト / 文字列内の括弧 / コメント内の括弧 / エスケープ文字 / 対応不備 |
| FR-007 | integration | `C-M-f` / `C-M-b` / `C-M-u` / `C-M-d` / `C-M-k` のキーバインド経路 |
| FR-008 | unit | 各操作の前後で括弧対応が保たれること。単一 undo 単位であること |
| FR-009 | integration | 接続・切断・接続失敗時にセッションが壊れないこと |
| FR-010 | integration | capability 未宣言サーバに対して何もしないこと |
