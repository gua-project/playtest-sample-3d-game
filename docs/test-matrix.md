# 受入テストの契約と判定制約

## 契約の参照先

[Issue #1](https://github.com/gua-project/playtest-sample-3d-game/issues/1) に対応する初期条件・手順・期待結果・既知バグ対照・現行テストと旧T01～T19の対応は [test-migration.md](test-migration.md) を一次一覧とする。Playtest E01～E07の独立期待値は [playtest-oracles.md](playtest-oracles.md)、実行方法は [README](../README.md)、正式APIの利用契約は [testing-api.md](testing-api.md) を参照する。

固定シナリオは `facility-r1`、seed=3001。標準初期条件は全バグOFF、新規開始。個別バグ比較は明記したIDのみONとする。checkpointの準備はtest setupとして記録し、通常開始からの達成証拠と区別する。

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
