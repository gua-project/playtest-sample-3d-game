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

## 文書

| 文書 | 内容 |
|---|---|
| [testing.md](docs/testing.md) | テスト責務、source回帰・限定smokeの実行方法、正式API、同期・判定制約 |
| [test-matrix.md](docs/test-matrix.md) | 初期条件、手順、独立期待値、seed、個別バグ、実行層 |
| [playtest-handoff.md](docs/playtest-handoff.md) | Playtest接続条件、独立期待値、未実行範囲。補助JSONは [playtest-handoff.json](docs/playtest-handoff.json) |
| [design.md](docs/design.md) | ゲーム固有の設計と判断理由 |
| [export-diagnosis.md](docs/export-diagnosis.md) | 未解決のWindows editor終了クラッシュの限定対照・再現条件 |

既知バグ `lost_key` / `through_wall` / `door_jam` は通常OFFで、タイトル／中断メニューから個別に切り替えます。再現条件と期待値はテスト一覧を参照してください。

描画・文字欠け・実キーボード／右ドラッグ、Playtest E2E、広範な保存状態の組合せ、未導入クリーンWindows互換性は未検証です。音は未実装、export終了クラッシュは未解決です。CIのload完了待ちとstrict teardownには原因未確定の断続的失敗記録もあります。source回帰や限定smokeの成功から、これらを解決済み・受入完了とは扱いません。

検証履歴は [PRの出典記録](https://github.com/gua-project/playtest-sample-3d-game/pull/2#issuecomment-6494339001) と [CI初回失敗・再実行の比較](https://github.com/gua-project/playtest-sample-3d-game/pull/2#issuecomment-6487520105) を参照してください。CI artifactは期限付きです。既存の [レビュー台帳](docs/review.md) と [移行レビュー記録](docs/migration-review.md) は履歴資料であり、現行仕様や最新の合否一覧ではありません。
