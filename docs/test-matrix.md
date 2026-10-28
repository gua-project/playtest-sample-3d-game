# Issue #1 と受入証拠の対応

ビルド識別は各実行の `summary.json` の EXE SHA256、Gua 1.1.2 の buildId は `gua-version.json`。固定シナリオ `facility-r1`、seed=3001。初期条件は全バグOFF、新規開始（個別バグ比較は明記したIDのみON）。実行証拠を伴わない計画項目は成功に数えない。

| ID | 要件・目的 / 初期状態・手順 | 期待結果・判定根拠 | 実装 | 証拠・現在の範囲 |
|---|---|---|---|---|
| T01 | タイトルから通常開始 | `screen=play`、A/B未復旧 | `new_run` | acceptance `history.json`, `summary.json` |
| T02 | 工具・電池を照準操作で取得、取得後もう一度操作 | 所持各1、取得物は衝突/対象から消え重複なし | `interact`, `_sync_world` | 同上 |
| T03 | カード取得→中断→保存→ロード | プレイへ復帰、カードと位置保持 | `save_game`, `load_game` | `card-restored.json` と相関操作履歴 |
| T04 | 電池を所持して別区画へ運搬、B→Aの逆順で復旧 | Bだけ稼働→両系統稼働、電池のみ消費 | `interact` | `power-online.json` |
| T05 | A/カードで扉を開き通行 | 物理的な閉鎖面を通過 | `_physics_process` | HUD座標の z<-12 を確認 |
| T06 | リフト移動中に中断→保存、待機、再保存→ロード | 中断中は位置一定、ロード後上階へ搭乗者とともに移動 | `_physics_process`, 保存一式 | `lift-restored.json`, checkpointの実値 |
| T07 | 上階出口を通常操作→結果→再プレイ | `result`、再開後進行/所持品初期化 | `interact`, `new_run` | `escaped.json` |
| T08 | 中断→英語切替→画面サイズ→リセット→ロード | UI表示とプレイ復帰。レイアウトは別途画像確認 | `_show_menu`, `resize_window` | `english-small.json`、描画実行時PNG |
| T09 | `lost_key` ONでT03と同じ取得・保存条件 | 不具合版だけカード消失を検出 | `load_game` | `docs/evidence/bugs`、OFF/ONとも実施 |
| T10 | 電源A手前の遮蔽物と距離境界でE、`through_wall` OFF/ON比較 | OFFは拒否、ONだけ壁越し起動 | `target_id` | `docs/evidence/bugs`、距離外では両方拒否 |
| T11 | 扉閉鎖面に留まり、`door_jam` OFF/ON比較 | OFFは退避可能、ONのみ移動不能を検出 | 扉占有判定 | `docs/evidence/bugs`、リセット後移動も確認 |
| T12 | 狭路・低天井の立ち/しゃがみ、外周へ移動 | 衝突境界を守り、通行可能経路を通れる | 移動/天井判定 | `docs/evidence/edges`、立ち上がり拒否も確認 |
| T12b | 階段と坂の経路から1m足場へ登る | 両方の実移動でy>0.8、帰還可能 | 段差補助と坂コリジョン | `docs/evidence/edges` |
| T13 | A→Bの通常順、電池なしA/条件不足扉/Bなしリフトを操作、Aのみで扉通過後帰還 | 前提不足時は消費・開通せず、反対盤から帰還しB修理後進行 | `interact` | `docs/evidence/edges`。前提不足の出口操作は未実施 |
| T14 | 目的と制約を与えた探索的操作、失敗から再試行 | 操作と観測を残し、到達/失敗/不明を区別 | 通常操作全般 | `docs/evidence/exploration`、`assessment.md`参照 |
| T15 | 破損セーブ、プロセス再起動後ロード | 破損時は状態保持、再起動時は有効状態復元 | `valid_save` | `docs/evidence/restart`、別EXEプロセスで実施 |
| T16 | 無人でリフトを上げ、下から呼戻し→搭乗→脱出 | 固定呼出盤で回収でき、進行不能にならない | `lift_lower/upper` | `docs/evidence/edges`。上側呼出盤の操作自体は未実施 |

## 状態と画像の区別

Gua UI Tree とセーブ状態で、所持・電源・画面遷移・位置・リフト・扉の結果を判定する。文字欠け、視認性、レイアウト、見た目の挟まりは描画あり EXE の画像を観測する必要がある。headless結果から画像品質や人間の操作性を推定しない。音は未実装、音の品質は判定不能。人間による実キーボードの全経路操作も別途未実施。

実行ごとの判定は `summary.json` を一次記録とする。途中で失敗した場合、後続のT番号を未実施と解釈し、行われなかった検証を成功にしない。初回テストでは非表示HUDの残値を誤って参照したため、`state()` は必ず `screen=play` を要求するよう修正した。修正前の記録は受入証拠に使用しない。

## 現在の実行結果

2026-10-28、レビュー修正後 Windows EXE SHA256 `3e5505662d595bb83086e7eaf7a9c8160dcc745a97bf8fce696115278c46df9b` で固定回帰16件成功。Gua core/runtime/Godot plugin/adapter は全て1.1.2、buildId `b398e531558f38220baf0b606e7c3f33904a87a5`。探索は固定回帰と別の判断過程を記録した限定セッションであり、網羅性を主張しない。

描画ありEXEの画像、右ドラッグ/実キーボード入力、音、上階からのリフト呼出し、前提不足の出口操作、扉を反転して通行する全境界、広範な保存破損/状態組合せは未実施。GUI枠は親の調整待ち。main/base commitが空でpush待機中のため、remote CIとDraft PRも未実施。
