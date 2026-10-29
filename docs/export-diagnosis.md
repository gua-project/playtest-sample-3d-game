# Windows editor 終了クラッシュの限定対照

未解決の終了クラッシュに対する限定的な診断記録。正式 Gua 1.1.2 と Godot 4.7 を固定した使い捨てコピーでの対照結果を保持する。通常の受入結果や根本原因の確定とは扱わない。

| 条件 | ローカル Windows | Windows CI (10.0.26100) |
|---|---|---|
| 最小 Node3D、Gua なし | 0 | 0 |
| 最小 Node3D、正式 Gua addon | 0 | -1073741819 |
| ゲーム、Gua を no-op adapter に置換 | 0 | 0 |
| ゲーム、正式 Gua addon | 0 | -1073741819 |
| 最小 Node3D、Gua GDScript を除き native extension のみ | 未実施 | -1073741819 |
| 最小 Node3D、editor の debug slot も正式 release DLL に置換 | 未実施 | -1073741819 |

全条件で pack完了マーカーとEXE生成を観測し、SCRIPT ERRORはなかった。正式DLLは変更せず、release-slotの対照も使い捨てコピーだけで行った。対照は上記6条件で打ち切り、ゲームの受入回帰・独立レビューとは区別する。

一次記録:

- [baseline 4条件](https://github.com/gua-project/playtest-sample-3d-game/actions/runs/40641143625)
- [追加2条件](https://github.com/gua-project/playtest-sample-3d-game/actions/runs/40641455828)
- `docs/evidence/export-controls` の comparison.json と各条件のrawログ

この結果から、ゲームの実行処理、GuaAutoAdapterのattach、GuaのGDScript自体を必要とせず、当該CI上でGua native extensionをGodot editorへロードしたときの終了処理に発生範囲を限定できる。Gua/Godotのどの関数が原因かは判定できない。スタックトレースは取得できず、Windows Applicationイベントログのローカル読み取りは権限不足で拒否されたため再試行していない。既存Gua checkoutのgit tag照会も権限不足で止め、別経路で代替していない。

正式1.1.2のバイナリを維持したゲーム側の修正は、この範囲では見つかっていない。エディター終了クラッシュの解消には、上流のnative extension/Godot連携の調査が必要となる可能性がある。これは推論であり、根本原因の確定ではない。

## 現行のビルド判定

この終了クラッシュは未解決。`build.ps1` はnonzero exportを必ず失敗とし、source scene回帰や限定起動smokeでexport失敗を成功へ変換しない。EXEが生成されpack完了が記録されても、正常終了や配布受入完了の証拠にはならない。

再現時はGodot 4.7、正式Gua 1.1.2、同じWindows環境で上記の最小Node3D＋正式addonとaddonなしを対照にし、終了コード・editorログ・対象DLL/EXEのSHA・pack完了を同一runで保存する。既存の [export-diagnostics workflow](../.github/workflows/export-diagnostics.yml) は手動診断用で、配布受入CIとは区別する。通常のビルド方法は [README](../README.md) を参照する。

旧 `-VerifyPlayer` による継続条件、当時のCI分類、特定SHAの配布物検査結果は [PRの検証記録](https://github.com/gua-project/playtest-sample-3d-game/pull/2#issuecomment-6487371013) に保存した履歴であり、現行の実行方法ではない。raw証拠は `docs/evidence/export-controls` と `docs/evidence/distribution` に保持する。

## 配布前提と未検証範囲

配布にはAMD64 EXE（PCK内蔵）と正式Gua release DLLの両方が必要。限定smokeはPE/PCK境界とDLLのSHA256一致、2ファイルからの起動・終了を確認する。PCK全entryのMD5網羅検査、protocol接続、全経路E2E、全Windowsへの可搬性を保証しない。配布EXEの統合E2EはPlaytest側の未実行項目である。

DLLはMicrosoft Visual C++ x64 runtime (`MSVCP140.dll`, `MSVCP140_2.dll`, `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`) を参照する。未導入のクリーンWindowsは未検証で、既存ランタイムを配布前提とする。システムDLLは配布物に含めない。
