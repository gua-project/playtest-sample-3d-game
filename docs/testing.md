# テストの責務・実行方法・判定制約

## テストの責務

| 層 | このrepoで実行するもの | 成功から主張できないもの |
|---|---|---|
| サンプル自身の回帰 | 正式 `Gua.Testing.Godot` が **source scene** を起動し、`Gua.Testing` で固定UI・保存・境界・個別バグを確認 | 配布EXEのE2E、探索の網羅、描画・実入力の受入 |
| 限定配布smoke | PE/PCK/公式DLLハッシュ、2ファイルでのheadless起動・終了・bridge起動メッセージ | protocol接続、通常操作、クリア、Scenario、Trace/Recording/Replay |
| Playtest E2E | **未実行**。配布EXEのlaunch/attach、探索、Scenario、予算、cleanup、Trace/Recording/ReplayをPlaytest側が所有 | 既存サンプル内のEXEテスト成功をPlaytest完成の証拠にはしない |

テスト契約は [test-matrix.md](test-matrix.md)、Playtest接続条件と独立期待値は [playtest-handoff.md](playtest-handoff.md) を参照する。

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

export終了時クラッシュの既存診断は [export-diagnosis.md](export-diagnosis.md) に保持しています。現在のbuildはnonzero exitを失敗とし、source回帰やsmokeの成功で上書きしません。正式1.1.2のバイナリは改変していません。


## 正式APIと同期


公開NuGetの `Gua.Testing` と `Gua.Testing.Godot` を1.1.2に固定する。APIの出典は配布packageのREADME・nuspec・公開アセンブリ。nuspecのrepository commitは `b398e531558f38220baf0b606e7c3f33904a87a5`。preview packageや独自wire fallbackへ置き換えない。

- `GodotSceneTestHost.Load("res://main.tscn", options)` がsource project/sceneを起動し接続・破棄する。LoadRenderedやEXE用hostの代用品として使わない。
- `GodotSceneTestHostOptions.ProjectPath / BridgeUrl / EnvironmentVariables / StartupResetPolicy / TeardownResetPolicy` を使用。固定予約port18732、ケース別APPDATA/TEMP、strict resetを設定。process探索・socket・poll・cleanupをサンプル側に実装しない。
- `GuaAssertions.Query(context).ById(id).ClickAsync()` が可視/有効/公開actionを解決し相関付き完了を待つ。操作後のframe更新待ちは `GuaAssertions.WaitUntilAsync` を使う。
- `host.GetVersion()` でcore/runtime/pluginの1.1.2をassert。`host.CreateDiagnosticsSession()` と `Capture`、hostのteardown診断を使用する。最終成功はteardownも含むNUnit TRXで判定。
- `Gua.Testing.Recording` / Trace / Replay の追加実装はこのrepoへ作らない。Playtest側の統合責務とする。

Playtestの正式Scenario/Environment/予算/Trace等への接続は未実装・未検証で、[playtest-handoff.json](playtest-handoff.json) はAPI互換を主張しない引継ぎ資料である。

CIは公式 [gua-tester/godot v3.2](https://github.com/gua-project/gua-tester/tree/v3.2/godot)、commit `9a819e252d714ecec80d0d206f3c8894cb8a13a1` を利用する。Godot4.7と `gua-plugin-tag=gua-v1.1.2` を固定した。source importの終了エラーが起きた場合は既存診断を参照して失敗として報告し、actionをコピーして独自runnerで回避しない。

描画・実入力はsource headless回帰の判定対象外で、現在は未検証。実行方法は [本書の実行方法](#サンプル回帰を実行する)、テスト契約は [test-matrix.md](test-matrix.md) を参照する。

## 判定と証拠

- 所持・電源・画面遷移・位置・リフト・扉はGua UI Treeとセーブ状態で判定する。非表示HUDの残値をプレイ状態として使用せず、プレイ中の状態照会は `screen=play` を必要条件とする。
- 文字欠け、視認性、レイアウト、見た目の挟まりは描画ありEXEの画像、実入力は実キーボード／右ドラッグで確認する。headless結果から画像品質や人間の操作性を推定しない。
- source回帰の最終判定はhost teardownを含むNUnit TRX。ケースJSONの `testBodyOutcome` だけで全体成功としない。途中で失敗した場合は未実行の後続項目を成功に数えない。
- 限定smokeはPE/PCK/公式DLL照合とheadless起動・終了だけ。source成功を配布EXE成功へ、smoke成功をPlaytest E2Eへ読み替えない。
- source回帰はケースJSONの `sourceSha256` と埋込み `version`（Gua BuildId等）、保存済みsummaryの `gameSourceSha256` で対象を識別する。配布build/smokeは `exeSha256`、smokeの `dllSha256` と正式DLL一致を確認する。旧runnerのEXE SHA256と `gua-version.json` は旧証拠専用。結果・初期条件・ログは同じ実行に結び付け、修正前や別ビルドの結果を代用しない。

## 現在の制限

Playtest E2E、描画・実入力、扉反転通行の全境界、広範な保存破損／状態組合せ、未導入クリーンWindows互換性は未検証。音は未実装で品質判定不能。export終了クラッシュは [未解決の診断と再現条件](export-diagnosis.md) を参照し、nonzero exportは失敗とする。

## 過去の検証記録

旧EXE runnerの実行日時・SHA・T番号別の証拠参照・無効な旧判定の説明は [PRの検証記録](https://github.com/gua-project/playtest-sample-3d-game/pull/2#issuecomment-6487371013) と [整理前の文書](https://github.com/gua-project/playtest-sample-3d-game/blob/d97c6fb2582448aee5d3c7981acb36beccad5ea4/docs/test-matrix.md) に保持する。raw証拠は既存の `docs/evidence` にあり、旧実行の成功は現行source回帰やPlaytestの成功を意味しない。実行ごとの最新結果はPRに紐付いたCI runと成果物を参照する。

## 証拠と再検証の範囲

旧実装はGit commit `764593e`、旧PR CIは [40800013008](https://github.com/gua-project/playtest-sample-3d-game/actions/runs/40800013008)。`docs/evidence` のJSON/操作履歴/rawログとfixtureが、ビルドSHA、bug ID、seed、初期条件、実測値の出典となる。これらは旧サンプルrunnerによるEXE証拠であり、Playtestで実行した証拠ではない。旧ID別の証拠パスと実行報告は [PRの検証記録](https://github.com/gua-project/playtest-sample-3d-game/pull/2#issuecomment-6487371013) にある。

現行の一次結果はsource回帰のNUnit TRX（host teardownを含む）、`artifacts/source-regression/*/result.json`、限定smokeの `artifacts/distribution-smoke/result.json`。source結果をEXE結果へ、smoke結果をE2Eへ昇格しない。Playtestでの実行と描画GUIは未検証のまま。

CI成果物は保存期限があるため、リンクがあるだけで恒久保存済みとは扱わない。リポジトリ内の `docs/evidence` とCI artifactは区別し、再現に必要な対象commit・SHA・初期条件をPRの検証記録へ結び付ける。

現在、CIで `Click load` の完了待ちtimeoutに続いて、同じrequestの未消費完了eventをstrict teardownが検出した断続的な失敗の記録がある。同一HEADの一度の再実行は成功したが根本原因は未確定で、解決済みとはしない。失敗・再実行・比較の出典は [PR検証記録](https://github.com/gua-project/playtest-sample-3d-game/pull/2#issuecomment-6487520105)。timeout、teardown、nonzero exportを抑制して成功へ変えず、各attemptを区別する。
