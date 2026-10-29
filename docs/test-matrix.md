# テスト契約・初期条件・独立期待値と実行層

source scene起動は正式 `Gua.Testing.Godot 1.1.2`、固定操作・期待値・待機は `Gua.Testing 1.1.2`。両NuGetのrepository commitは `b398e531558f38220baf0b606e7c3f33904a87a5`。配布EXEのE2E基盤はPlaytest側に置き、サンプル内へ第二のrunnerを作らない。

## 現行回帰

`SceneRegressionTests` のS01～S06はsource sceneだけを起動する。S01=開始/中断/保存復帰/設定/reset/破損入力拒否、S02=カード保持とlost_key対照、S03=距離/遮蔽とthrough_wall対照、S04=扉占有とdoor_jam対照、S05=外周/低天井/しゃがみ、S06=3種の取得/重複拒否。6メソッド・13ケース。mutantのケースは正常期待値の違反を検出するテストであり、不具合を正常仕様として承認しない。

固定seed=3001、scenario=facility-r1、標準は全bug OFF。authored checkpointは `tests/fixtures/upper-checkpoint.json` と変更した初期条件をcase JSONへ保存する。出典SHAはfixture source JSONに保持。これは明示的なtest setupであり、E2Eの通常開始からの達成証拠ではない。正常版／各bug単独を比較し、期待値はIssue #1の記述から独立に記載する。古い観測値を新しい期待値として生成しない。

## 要件別の契約と実行層（旧ID対応）

| 旧ID | 初期条件・操作と独立期待値 | 実行層 / 現在の扱い |
|---|---|---|
| T01 | title、bug OFF。start→play、A/B=false、所持なし | サンプルS01 |
| T02 | tool/battery/keyを取得し再操作。各1個、重複しない | サンプルS06（3ケース）。通常探索中の発見・運搬はPlaytest E01 |
| T03 | key取得後に保存/ロード。位置と所持を保持 | S01の位置、S02のkey保持。通常探索中の複合復元はPlaytest E03未実行 |
| T04 | 電池所持でB→Aの逆順。工具保持、電池だけ一度消費、経路開通 | Playtest E02未実行。旧証拠だけでは新E2E成功としない |
| T05 | A/keyで扉を開き通過。閉鎖面を通常移動で越える | Playtest E01/E04未実行。占有安全だけS04 |
| T06 | リフト移動中pause/save/load。停止中は進まず、搭乗者と行先を保持 | Playtest E03/E05未実行。S01静的復元で代替しない |
| T07 | 出口→result→replayで初期化 | reset部分S01。通常クリア後の結果/再プレイはPlaytest E01未実行 |
| T08 | ja/en、1280/960、reset/load | 設定値S01。描画レイアウト/実入力はPlaytest E06、未実行 |
| T09 | key保存前にlost_keyを単独ON。OFFは保持、ONだけ消失 | サンプルS02（2ケース） |
| T10 | 電池所持、Aへの遠距離/近距離/遮蔽。距離外は両方拒否、through_wall ONの距離内だけ不正起動 | サンプルS03（4ケース） |
| T11 | 占有帯にいる閉鎖時。OFFは退避可能、door_jam ONだけ停止。reset再試行 | 占有差分S04（2ケース）、通常再試行導線はPlaytest E04未実行 |
| T12 | 外周/狭路/低天井。壁を越えず、しゃがみで通り、屋根下で立てず、退出後STANDへ戻れる | サンプルS05。探索的な全境界はE04未実行 |
| T12b | 階段と坂から1m足場へ到達し戻る | Playtest E04未実行 |
| T13 | 電池なしA、key/電源不足扉、Bなしリフトを拒否。A先行でも帰還しB修理後に進める | Playtest E02未実行。S03の電池消費だけで代替しない |
| T14 | 目的/制約による探索、失敗から復帰。到達/失敗/不明を区別 | Playtest探索E07未実行。旧86観測はlegacy証拠で、Trace/Recording/Replayではない |
| T15 | 別プロセスでcheckpoint復元、破損入力拒否 | 破損入力はS01。relaunch/attach/cleanup統合はPlaytest E03未実行 |
| T16 | 無人リフトを下から呼戻し→搭乗→脱出 | Playtest E05未実行 |
| T17 | リフト移動中に反転。中間位置でtarget変更、搭乗者と上階へ戻る | Playtest E05未実行 |
| T18 | 上階デッキから無人下降→上階盤で呼戻し | Playtest E05未実行 |
| T19 | lost_key単独ONでカード不足を作り出口操作。playのまま拒否 | Playtest E02の変種、未実行。S02の消失検出で代替しない |
| 旧distribution | PE/PCK/公式DLL照合と2ファイル起動、さらに旧全経路8件 | 構造/起動のみ限定smoke M01。接続・全経路部分はE01/E03へ移管、未実行 |

## 個別の既知バグ

通常は全てOFF。タイトル／中断メニューのIDごとにON/OFFを選べます。設定は保存／復元され、HUDと結果・操作記録に表示します。

| ID | 再現条件 | 正しい期待結果 / バグ時の違反 |
|---|---|---|
| `lost_key` | カード取得後に保存→ロード | カード保持 / 消失し再取得不能 |
| `through_wall` | 電池所持、距離内、Aへ遮蔽物越しに照準・E | 拒否して電池保持 / 壁越しに起動し消費 |
| `door_jam` | 閉鎖時刻に扉の占有帯へ留まる | 閉鎖延期し退避可能 / 移動不能。ロードまたはresetで再試行 |


## 関連文書

実行方法・正式API・同期・合否判定・証拠の識別は [testing.md](testing.md)。Playtest E01～E07の接続条件・独立期待値は [playtest-handoff.md](playtest-handoff.md)。既知バグは正常仕様ではなく、各IDを単独ONにした対照で違反を検出する。
