# FACILITY 03 — 故障した小型施設からの脱出

[Issue #1](https://github.com/gua-project/playtest-sample-3d-game/issues/1) の Windows 専用 Godot 一人称探索サンプルです。仮の立体素材を使用しています。

Godot **4.7.stable.official.5b4e0cb0f** / 正式 **Gua 1.1.2**（`gua-v1.1.2`）。ゲームのクリアだけでゲーム QA 全般の網羅を主張するものではありません。

## 起動・ビルド

PowerShell と Node.js 22 以降、Godot 4.7 Windows x64 と同版の Windows release export templates を用意してください。既存インストールを使用でき、共有設定の変更は不要です。

```powershell
./scripts/setup-gua.ps1
./scripts/build.ps1 -Godot 'C:/path/Godot_v4.7-stable_win64_console.exe' -TemplateDirectory 'C:/path/4.7.stable'
./dist/FacilityEscape.exe
```

配布には `dist/FacilityEscape.exe` **と同梱される `gua_godot.windows.release.x86_64.dll` の両方**が必要です。PCK は EXE に内蔵します。タグ・Release はこの作業から公開しません。アドオン ZIP は公式配布から取得し SHA256 `19f89058ca60e48c74a7327da31c0e011b4c053acfda8e5b8e2e2b1fc90ae8c4` を照合します。アドオンソースとライセンスを保持し、バイナリはセットアップ時に取得します。

正式Gua DLLは `MSVCP140.dll`、`MSVCP140_2.dll`、`VCRUNTIME140.dll`、`VCRUNTIME140_1.dll` とWindows CRTを参照します。対応するMicrosoft Visual C++ x64ランタイムが利用可能な環境が前提です。このPCとCIでは利用でき、2ファイルだけの別ディレクトリで通常受入8件を確認しました。ランタイム未導入のクリーンWindowsは未検証です。この作業ではランタイムのインストールやシステムDLLの同梱は行っていません。

`build.ps1` は Godot の APPDATA/TEMP/TMP を checkout の `.runtime` に分離し、渡された既存 template をコピーして使います。実行時の通常セーブは `%APPDATA%/facility-escape-3d` に保存します。並行テストは `APPDATA` を固有ディレクトリに指定してください。テストは自動で分離します。

## 遊び方

タイトルの「新しく開始」。WASD で移動、矢印または右ボタンのドラッグで視点、E で照準の対象を操作、C でしゃがみ、Esc で中断します。画面下の移動・視点・操作ボタンでも同じ物理移動と操作ができます。移動ボタン1回は 0.25 秒、旋回15度、上下視点10度です。

受付で工具と電池を拾い、倉庫でカードを取得。工具で電源 B を修理し、電池を消費して A を起動（逆順も可）。A とカードで隔壁扉を開け、A/B の電源でエレベーターに乗り、上階の出口装置を操作して脱出します。結果画面から再プレイできます。対象は 2.3m 以内かつ照準が当たり、遮蔽物がない場合に操作できます。ガラスは見本色の不透明な仮素材です。

中断メニューに再開、チェックポイント保存／ロード、言語（日本語・英語）、1280×800／960×720 の切替、初期状態リセットがあります。リセットはチェックポイントを消しません。無効・破損したセーブは現在のゲームを変更せず拒否します。

## Gua とテスト

Gua 標準 `GuaAutoAdapter` が画面の UI を公開し、標準観測プロトコルに従います。ゲーム固有の公開範囲・秘匿規則は追加していません。画面上に表示する位置・所持品・電源状態を観測し、人間にも表示される通常の移動／視点／操作ボタンを使います。専用クリア、テレポート、所持品付与の Gua 操作はありません。

既定 bridge は `ws://127.0.0.1:18732`、`GUA_BRIDGE_PORT` で変更できます。3サンプルはそれぞれ別のポート、APPDATA、証拠出力を使用してください。

```powershell
node tests/acceptance.mjs
# 個別バグ比較（新しい保存先）
$env:TEST_SUITE='bugs'; $env:EVIDENCE_DIR='artifacts/bugs'
node tests/acceptance.mjs
# 低天井、外周、階段・坂、A先行と帰還、無人リフト呼戻し
$env:TEST_SUITE='edges'; $env:EVIDENCE_DIR='artifacts/edges'
node tests/acceptance.mjs
# 前のnormal実行で作成したセーブを、別プロセスでロードする
$env:TEST_SUITE='restore'; $env:SAVE_APPDATA="$pwd/artifacts/acceptance/appdata"
$env:EVIDENCE_DIR='artifacts/restart'
node tests/acceptance.mjs
Remove-Item Env:TEST_SUITE,Env:SAVE_APPDATA
# 成功CIの通常プレイで生成された出典付きfixtureから未実施3項目を確認
$env:TEST_SUITE='remaining'; $env:EVIDENCE_DIR='artifacts/remaining'
node tests/acceptance.mjs
Remove-Item Env:TEST_SUITE
# 描画ウィンドウの検証（他担当の GUI 利用と事前調整）
$env:HEADED='1'
$env:EVIDENCE_DIR='artifacts/rendered'
node tests/acceptance.mjs
```

テストは **export した EXE** を起動し、Gua WebSocket のアクション受付・完了を相関 ID で確認します。UI Tree、操作履歴、Gua バージョン、EXE SHA256、実行ログ、結果一覧を `artifacts/acceptance`（または指定出力先）に残します。描画ありの場合は Gua のスクリーンショットも保存します。headless 成功は画面の受入成功を意味しません。

`tests/explore.mjs` は固定クリア手順を持たない探索用 runner です。標準入力に `{"click":"start"}`、`{"click":"forward","count":3}`、`{"observe":true,"note":"この境界で移動結果を調べる"}`、`{"quit":true}` のように JSON を1行ずつ渡し、通常操作と観測を記録できます。`scripts/summarize-evidence.mjs acceptance bugs edges restart` は実行済みの証拠からコンパクトな操作記録を `docs/evidence` に作成します。

ゲーム自身の `last-run.json` はビルド・シナリオ・シード・有効バグと通常操作の結果を記録します。乱数は使わず、固定の記録用 seed=3001、シナリオ版 `facility-r1` です。テスト一覧と未実施範囲は [docs/test-matrix.md](docs/test-matrix.md)、判断した細部は [docs/decisions.md](docs/decisions.md) を参照してください。

## 既知バグを有効化する比較実験

通常は全て OFF。タイトルまたは中断メニューの ID ごとのボタンで個別に ON/OFF。開始時リセットは選択中のバグを保持します。保存／ロードはバグ設定も復元するので、`lost_key` の比較は **設定を選んでから取得・保存**してください。有効 ID はメニュー、プレイ HUD、結果、セーブと操作履歴に記録します。

| ID | 再現条件 | 正しい期待結果 / バグ時の失敗 |
|---|---|---|
| `lost_key` | カード取得後に中断→保存→ロード | 所持カードを保持 / バグ時はカードが消え、再取得もできない |
| `through_wall` | 電源 A の手前の遮蔽物を挟んで、2.3m以内で A に照準、電池所持で E | 操作不可で電池保持 / バグ時は遮蔽物を無視して A が起動 |
| `door_jam` | 扉を開け、閉鎖時刻に扉の通路内で待つ | 通行者が離れるまで閉鎖延期 / バグ時は移動不能。チェックポイント復帰またはリセットで再試行 |

音素材、主観的な見栄え、広範な GPU/OS 互換性、オンライン同期や高負荷は対象外です。無音のため音の適切さは評価していません。
