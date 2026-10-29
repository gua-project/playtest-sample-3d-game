# 正式1.1.2 APIとテスト実行契約

公開NuGetの `Gua.Testing` と `Gua.Testing.Godot` を1.1.2に固定する。APIの出典は配布packageのREADME・nuspec・公開アセンブリ。nuspecのrepository commitは `b398e531558f38220baf0b606e7c3f33904a87a5`。preview packageや独自wire fallbackへ置き換えない。

- `GodotSceneTestHost.Load("res://main.tscn", options)` がsource project/sceneを起動し接続・破棄する。LoadRenderedやEXE用hostの代用品として使わない。
- `GodotSceneTestHostOptions.ProjectPath / BridgeUrl / EnvironmentVariables / StartupResetPolicy / TeardownResetPolicy` を使用。固定予約port18732、ケース別APPDATA/TEMP、strict resetを設定。process探索・socket・poll・cleanupをサンプル側に実装しない。
- `GuaAssertions.Query(context).ById(id).ClickAsync()` が可視/有効/公開actionを解決し相関付き完了を待つ。操作後のframe更新待ちは `GuaAssertions.WaitUntilAsync` を使う。
- `host.GetVersion()` でcore/runtime/pluginの1.1.2をassert。`host.CreateDiagnosticsSession()` と `Capture`、hostのteardown診断を使用する。最終成功はteardownも含むNUnit TRXで判定。
- `Gua.Testing.Recording` / Trace / Replay の追加実装はこのrepoへ作らない。Playtest側の統合責務とする。

Playtestの正式Scenario/Environment/予算/Trace等への接続は未実装・未検証で、`playtest/handoff.json` はAPI互換を主張しない引継ぎ資料である。

CIは公式 [gua-tester/godot v3.2](https://github.com/gua-project/gua-tester/tree/v3.2/godot)、commit `9a819e252d714ecec80d0d206f3c8894cb8a13a1` を利用する。Godot4.7と `gua-plugin-tag=gua-v1.1.2` を固定した。source importの終了エラーが起きた場合は既存診断を参照して失敗として報告し、actionをコピーして独自runnerで回避しない。

描画・実入力はsource headless回帰の判定対象外で、現在は未検証。実行方法は [README](../README.md)、テスト契約は [test-migration.md](test-migration.md) を参照する。
