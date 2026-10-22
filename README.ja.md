# VoltFuel(ボルトフューエル)
TST
**電圧だけで残量を推定する EdgeTX 用ゲージと、フライトログの分析ツール**
English: [README.md](README.md)

VoltFuel は、LiPo の**パック電圧テレメトリだけ**(電流センサー不要)から残量を推定し、バーと 2 つの数字(例: `62%(48%)`)で表示します。推定値はテレメトリセンサー `sBAT` としても出力されるので、読み上げや SD ログに使えます。

> **Rotorflight とは無関係です。** Rotorflight の「SmartFuel」は別の機能です。

## このリポジトリの内容

| 区分 | ファイル | 用途 |
|---|---|---|
| ウィジェット | `VoltFuel_SD/WIDGETS/voltfuel/main.lua` | ゲージ本体(EdgeTX 3.x 以上、カラー液晶タッチ機) |
| ログ表示(送信機) | `VoltFuel_SD/SCRIPTS/TOOLS/VoltFuel_Log.lua` | 送信機上でフライトログをグラフ表示(既定: rCEL、sBAT、rBAT) |
| ログ表示(PC) | `VoltFuel_Compare.html` | ブラウザで複数フライトを比較(表示は日本語) |

## かんたんインストール

1. `VoltFuel_SD/` の中身を、送信機の SD カードの直下にコピーします。`/WIDGETS/voltfuel/main.lua` と `/SCRIPTS/TOOLS/VoltFuel_Log.lua` になります。
2. 送信機で、メインビューを長押し → ウィジェットを追加 → **VoltFuel**。設定で、パック電圧の **Source** を選びます。
3. 分析したいときは、ウィジェットの **ExtraTelem** をオンにし、`sBAT`、`rBAT`、`rCEL`、`rMIN` を SD ログに記録します。

**飛ばす前に、[ウィジェットの README](VoltFuel_SD/WIDGETS/voltfuel/README.ja.md) をお読みください。** 特に、電圧ソースの較正、MinCv の調整、制限事項の項目が重要です。

## ログの分析

- **送信機で:** SYS → Tools → **VoltFuel_Log**。ログファイルを選びます。`rCEL`、`sBAT`、`rBAT` が入っていれば、そのままグラフが開きます。
- **PC で:** SD カードの `/LOGS` からログの CSV をコピーし、`VoltFuel_Compare.html` をブラウザで開いて、CSV かフォルダを選びます(インストール不要。ファイルは PC の中だけで処理され、アップロードされません)。

## 制限事項

VoltFuel は**電圧だけからの推定値**で、実際の残量に対する精度は測っていません。着陸判断を、これ 1 つだけに頼らないでください。

## 出典とライセンス

- 推定方式は、Rotorflight Lua スイートの SmartFuel の電圧モードの考え方に沿っています。コピーではなく、独立した再実装です。
- **BattAnalog**(EdgeTX、Copyright Offer Shmuely、GPLv2): セル電圧 → % の表、電池の種類、セル数判別の規則。
- 企画・要件・実機テスト・調整: Masayuki。コードは AI アシスタントの Claude(Anthropic)と一緒に書きました。

**GNU General Public License version 2** のフリーソフトウェアです。[LICENSE](LICENSE) を参照してください。Copyright (C) 2026 Masayuki.
