# テスト責務移行の独立レビュー #1

ユーザーの明示依頼により、初回ゲーム実装レビュー1回とは**別枠で1回**実施した。既存の回数をリセットせず、[review.md](review.md) の台帳に初回1／移行1と記録する。正式なGitHub Approveは投稿していない。

## 対象と方法

対象差分は `764593e..a28434d`。旧JS wire/EXE/探索runnerの削除、正式Gua.Testing/Gua.Testing.Godot 1.1.2 source回帰、公式gua-tester CI、限定smoke、移管表・handoff・期待値・証拠の読み取り監査に限定した。レビュー担当はファイル変更・実行・GUIを行っていない。ゲーム本体の新しい全体監査として扱わない。

確認した基準は、旧期待値／既知バグ検出範囲の欠落、公式API/CIの利用、初期条件準備と通常操作の区別、未実行Playtest項目を成功にしないこと、smokeを第二runnerにしないこと。レビュー時のCI一次記録は [40806229138](https://github.com/gua-project/playtest-sample-3d-game/actions/runs/40806229138)（source13/13、export0、smoke0）。

## 指摘と対応

| 重要度 | 指摘 | 修正 | 検証 |
|---|---|---|---|
| P2 | 旧T12の「屋根から戻った後にSTANDへ復帰できる」がS05とE04から落ちていた。永久にしゃがみから戻れない退行を見逃す | S05へ通常の後退8回→しゃがみ切替→STAND assertを復元。E04独立期待値と移管表にも明記 | 修正者が正式source hostでS05のみ再検証、1件成功。`docs/evidence/migration-review/source-S05-local.trx`。修正後PR HEADのCIはChecksを一次記録とする |

その他の監査結果は整合：正式1.1.2 APIと公式CI部品を使用、checkpoint準備をtest setupとして明示、smokeは接続/ゲーム操作を持たず、旧項目の移管先とPlaytest未実行を区別している。指摘修正のfocused確認は修正者による実行であり、新しい独立レビュー回数へ加算していない。

## 残余リスク

- Playtest E2Eは未実行。handoffは実行可能な正式Scenarioではなく、Build/Scenario/Environment/予算/独立期待値の接続が別途必要。
- source sceneの13ケースは配布EXEの全経路、探索、Trace/Recording/Replay、process attach/cleanup統合の受入ではない。
- 限定smokeはPE/PCK/DLLと起動/終了だけ。protocol接続、操作、クリア、描画・実入力、クリーンWindows互換性を保証しない。
- GUIは承認待ち・未検証。既存export終了クラッシュの診断とVC++ランタイム前提も残る。source回帰/smoke成功でこれらを解決済みにしない。
