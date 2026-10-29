# Windows editor 終了クラッシュの限定対照

正式 Gua 1.1.2 と Godot 4.7 を固定し、元の作業treeを変更しない使い捨てコピーで調べた。共有インストール、セキュリティ設定、他repoは変更していない。

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

## 成功の分類

**2026-10-29の責務変更:** 以下の `-VerifyPlayer` は旧方式の記録です。現在は削除しました。`build.ps1` はnonzero exportを必ず失敗とし、source scene回帰や限定起動smokeでexport失敗を成功へ変換しません。配布EXEの全経路E2EはPlaytest側の未実行項目です。旧診断・rawログは保持します。

`build.ps1` は通常、非zero exportで失敗する。`-VerifyPlayer` 指定時だけ、**特定のアクセス違反コード・新規EXE/DLLの存在・当該実行のpack完了**を必要条件とし、生成EXEの通常Gua受入が成功した場合に限り後続のテストを継続する。古いEXEを代替しないようexport前に旧成果物を除去する。未知の終了コード、pack未完了、成果物不足、実EXE受入失敗は継続しない。

CIの緑はプレイヤー受入の結果であり、editor processの正常終了を意味しない。終了コード・pack完了・playerAcceptancePassedを別フィールドで保存し、CI step summaryでもeditorの失敗を表示する。根本原因が残るため、通常のclean export成功とは扱わない。

## 配布物の完全性と限界

CI成果物 SHA256 `22ddebf71db0facb43e9d8c96ed4fcbdeaaf24c3027da748e69d5fd0ce938764` について、AMD64 PE、PCK header/footer とpayload境界、正式Gua release DLLのSHA256一致を検査した。EXEとDLLだけを使い捨てフォルダへコピーし、そのフォルダを作業ディレクトリとして起動、Guaで通常受入8件が通過した。GUA_NATIVE_DIR等のoverrideも空にした。証拠は `docs/evidence/distribution` と `artifacts/distribution`。

これはPCK全entryのMD5網羅検査や、全Windowsへの可搬性検証ではない。DLLはMicrosoft Visual C++ x64 runtime (`MSVCP140.dll`, `MSVCP140_2.dll`, `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll`) を参照する。既存ランタイムがあるこのPC/CIでは動作したが、未導入のクリーンWindowsは未検証。ランタイムを新規インストールしたり、システムDLLを無断で配布物に追加したりしていない。配布前提はREADMEにも明記した。
