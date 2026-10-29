# FACILITY 03 — 故障した小型施設からの脱出

[Issue #1](https://github.com/gua-project/playtest-sample-3d-game/issues/1) のWindows専用、一人称探索ゲームです。ゲーム本体はGodot **4.7** のGDScript、runtime addonとテストpackageは正式 **Gua 1.1.2**。素材はプリミティブの仮素材、音は未実装です。

## ゲームを起動する

```powershell
./scripts/setup-gua.ps1
./scripts/build.ps1 -Godot 'C:/path/Godot_v4.7-stable_win64_console.exe' -TemplateDirectory 'C:/path/4.7.stable' -Smoke
./dist/FacilityEscape.exe
```

配布にはEXEと `gua_godot.windows.release.x86_64.dll` の両方が必要です。PCKはEXE内蔵。公式addon ZIPのSHA256をsetupで検証します。DLLが参照するMicrosoft Visual C++ x64ランタイム（MSVCP140/VCRUNTIME140系）が利用可能な環境が前提です。未導入のクリーンWindowsは未検証で、ランタイムのインストール・システムDLLの同梱は行っていません。

受付で工具と電池、倉庫でカードを取得。工具でBを修理し、電池を消費してAを復旧（順序は任意）。カードとAで隔壁を開け、A/Bでリフトを動かし、上階の出口装置から脱出します。WASD移動、矢印／右ドラッグ視点、E操作、Cしゃがむ、Esc中断。画面下の通常ボタンも同じ物理移動・照準・操作を行います。操作距離は2.3m、壁・ガラスは遮蔽物です。即時クリアやテレポート操作はありません。

タイトル→開始→プレイ→結果→再プレイ、中断、保存／ロード、リセット、日本語／英語、1280×800／960×720を用意しています。リセットは既存checkpointを消しません。通常保存先は `%APPDATA%/facility-escape-3d`、bridge既定ポートは `18732`（`GUA_BRIDGE_PORT`で変更可能）。乱数は使わず、記録用seed=3001、シナリオ版 `facility-r1` です。

## テストの責務

| 層 | このrepoで実行するもの | 成功から主張できないもの |
|---|---|---|
| サンプル自身の回帰 | 正式 `Gua.Testing.Godot` が **source scene** を起動し、`Gua.Testing` で固定UI・保存・境界・個別バグを確認 | 配布EXEのE2E、探索の網羅、描画・実入力の受入 |
| 限定配布smoke | PE/PCK/公式DLLハッシュ、2ファイルでのheadless起動・終了・bridge起動メッセージ | protocol接続、通常操作、クリア、Scenario、Trace/Recording/Replay |
| Playtest E2E | **未実行**。配布EXEのlaunch/attach、探索、Scenario、予算、cleanup、Trace/Recording/ReplayをPlaytest側が所有 | 既存サンプル内のEXEテスト成功をPlaytest完成の証拠にはしない |

テスト契約・初期条件・独立期待値・旧IDとの対応は [test-migration.md](docs/test-migration.md)、判定制約と証拠の扱いは [test-matrix.md](docs/test-matrix.md)、Playtestへの接続情報は [playtest/handoff.json](playtest/handoff.json) にあります。このhandoffは実行可能なPlaytest Scenarioではありません。配布EXEの全経路・探索runnerはPlaytest側が所有します。

## サンプル回帰を実行する

.NET 10 SDKと既存Godot 4.7を使います。ゲームをC#やGodot Monoへ変更する必要はありません。

```powershell
$env:GODOT_EXECUTABLE='C:/path/Godot_v4.7-stable_win64_console.exe'
$env:NUGET_PACKAGES="$pwd/vendor/nuget"
$env:DOTNET_CLI_HOME="$pwd/.runtime/dotnet"
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE='false'
$env:DOTNET_CLI_TELEMETRY_OPTOUT='1'
dotnet test tests/Facility.Regression/Facility.Regression.csproj --configuration Release --logger 'trx;LogFileName=source-regression.trx'
```

初回のsource importが必要ならGodot editorでprojectをimportするか、headlessの `--editor --path . --quit-after 300` を実行してください。CIは [gua-tester Godot部品 v3.2](https://github.com/gua-project/gua-tester/tree/v3.2/godot) をcommit固定してimportとdotnet testを行います。`gua-plugin-tag=gua-v1.1.2`、NuGetも1.1.2に固定しています。

回帰は6つの代表テストメソッド・13ケースです。公式hostがsource sceneのprocess、接続、相関付き操作完了、reset、破棄を担当します。ゲーム固有の期待値とauthored checkpointだけをテスト側に置き、初期条件準備を通常操作から区別して記録します。ポート18732、ケース別APPDATA/TEMP、`artifacts/source-regression` を使います。最終結果はteardownを含むNUnit TRXを一次記録とし、ケースJSONの `testBodyOutcome` はそれだけで全体成功を意味しません。

## 配布smokeとビルドの限界

`node tests/distribution-smoke.mjs dist` はPE/PCK/DLL照合と、使い捨てフォルダから30frameだけのheadless起動・終了を確認します。Guaへ接続せず、UI操作も行いません。結果は `artifacts/distribution-smoke`。`build.ps1 -Smoke` からも呼べます。

export終了時クラッシュの既存診断は [export-diagnosis.md](docs/export-diagnosis.md) に保持しています。現在のbuildはnonzero exitを失敗とし、source回帰やsmokeの成功で上書きしません。正式1.1.2のバイナリは改変していません。

## 個別の既知バグ

通常は全てOFF。タイトル／中断メニューのIDごとにON/OFFを選べます。設定は保存／復元され、HUDと結果・操作記録に表示します。

| ID | 再現条件 | 正しい期待結果 / バグ時の違反 |
|---|---|---|
| `lost_key` | カード取得後に保存→ロード | カード保持 / 消失し再取得不能 |
| `through_wall` | 電池所持、距離内、Aへ遮蔽物越しに照準・E | 拒否して電池保持 / 壁越しに起動し消費 |
| `door_jam` | 閉鎖時刻に扉の占有帯へ留まる | 閉鎖延期し退避可能 / 移動不能。ロードまたはresetで再試行 |

## 現在の制限と記録

描画・文字欠け・実キーボード／右ドラッグは未検証です。Playtest E2E、広範な保存状態の組合せ、未導入クリーンWindowsでの互換性も未検証です。音は未実装で品質を判定できません。export終了クラッシュは未解決です。source回帰や限定smokeの成功から、これらの受入完了を主張しません。

実行ごとのSHA・結果・ログはCI成果物と [PRの検証記録](https://github.com/gua-project/playtest-sample-3d-game/pull/2#issuecomment-6487371013) を参照してください。既存の [レビュー台帳](docs/review.md) と [移行レビュー記録](docs/migration-review.md) は範囲を限定した履歴資料であり、現行仕様や最新の合否一覧ではありません。
