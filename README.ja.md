# VoltFuel(ボルトフューエル)

**電圧だけで残量を推定する EdgeTX 用ゲージと、フライトログの分析ツール**
English: [README.md](README.md)

VoltFuel は、LiPo の**パック電圧テレメトリだけ**(電流センサー不要)から残量を推定し、バーと 2 つの数字(例: `62%(48%)`)で表示します。推定値はテレメトリセンサー `sBAT` としても出力されるので、読み上げや SD ログに使えます。

> **Rotorflight とは無関係です。** Rotorflight の「SmartFuel」は別の機能です。

## 動作環境

- **EdgeTX 2.12 以上**の、カラー液晶タッチ機(TX16S、TX15、GX15 で開発)。白黒液晶機は非対応です。
- **パック電圧のテレメトリ**(RxBt、Vbat、VFAS など)。VoltFuel は電圧だけで動くので、電流センサーは要りません。受信機自身の BEC 電圧しか返さない受信機では使えません。
- 送信機上のツールは、SD ログが `/LOGS` に書き出すログファイルを使います。

## このリポジトリの内容

| 区分 | ファイル | 用途 |
|---|---|---|
| ウィジェット | `VoltFuel_SD/WIDGETS/voltfuel/main.lua` | ゲージ本体(EdgeTX 2.12 以上、カラー液晶タッチ機) |
| VoltFuel Tools(送信機) | `VoltFuel_SD/SCRIPTS/TOOLS/VoltFuel_Tools.lua`(+ `SCRIPTS/TOOLS/VoltFuel/`) | 送信機上のメニュー。**Graph**(ログのグラフ。既定は rCEL・sBAT・rBAT)、**Tune**(ログから MinCv の目安を出す)、**Logs**(ログのサイズと長さの一覧、削除) |
| ログ表示(PC) | `VoltFuel_Compare.html` | ブラウザで複数フライトを比較(表示は日本語) |
| MinCv の調整(PC) | `VoltFuel_Tune.html` | ログから、フライトごと・機体ごとの MinCv の目安を出します(日本語・英語) |
| ドキュメント | `docs/` | 利用ガイドとサポートノート(日本語・英語) |

## かんたんインストール

1. `VoltFuel_SD/` の中身を、送信機の SD カードの直下にコピーします。`/WIDGETS/voltfuel/main.lua`、`/SCRIPTS/TOOLS/VoltFuel_Tools.lua`、`/SCRIPTS/TOOLS/VoltFuel/` になります。
2. 送信機で、メインビューを長押し → ウィジェットを追加 → **VoltFuel**。設定で、パック電圧の **Source** を選びます。
3. 分析したいときは、ウィジェットの **ExtraTelem** をオンにし、`sBAT`、`rBAT`、`rCEL`、`rMIN` を SD ログに記録します。

**飛ばす前に、[ウィジェットの README](VoltFuel_SD/WIDGETS/voltfuel/README.ja.md) をお読みください。** 特に、電圧ソースの較正、MinCv の調整、制限事項の項目が重要です。

## ログの分析

- **送信機で:** SYS → Tools → **VoltFuel_Tools** → **Graph**。ログファイルを選びます。`rCEL`、`sBAT`、`rBAT` が入っていれば、そのままグラフが開きます。
- **PC で:** SD カードの `/LOGS` からログの CSV をコピーし、`VoltFuel_Compare.html` をブラウザで開いて、CSV かフォルダを選びます(インストール不要。ファイルは PC の中だけで処理され、アップロードされません)。

## MinCv の調整と、関連ドキュメント

- **送信機で調整:** SYS → Tools → **VoltFuel_Tools** → **Tune**。機体を選ぶと、新しいログから順に解析し(飛行していないログ、短すぎるログ、末尾に静止区間がないログは、理由つきでスキップ)、MinCv の目安を出します。*Settings* には、ウィジェットと同じ電池種、セル数、ResPct、FallMv、MaxCv を入れてください。送信機の画面は英語です。
- **送信機でログ管理:** **VoltFuel_Tools → Logs** で、機体ごとにログのサイズと長さを一覧にします。ログを選んで削除したり、一括削除(機体のログ全部、N 秒より短い、N 日より古い、最新 N 本以外)ができます。削除は取り消せないので、先にログの記録を止めてください。
- **PC で調整:** `VoltFuel_Tune.html` をブラウザで開き(計算は同じ)、3 フライトほどの CSV ログを読み込むと、機体ごとの MinCv の目安が出ます(インストール不要、アップロードなし)。
- **利用ガイド:** [docs/USER_GUIDE.ja.md](docs/USER_GUIDE.ja.md) — セットアップ、電圧ソースの較正、ログ、MinCv の調整、相談や報告のときに伝えてほしい内容。
- **サポートノート:** [docs/SUPPORT_NOTES.ja.md](docs/SUPPORT_NOTES.ja.md) — sBAT の計算と調整の考え方。相談するときは、AI チャットに貼ってください。

## 制限事項

VoltFuel は**電圧だけからの推定値**で、実際の残量に対する精度は測っていません。着陸判断を、これ 1 つだけに頼らないでください。

## 出典とライセンス

- 推定方式は、Rotorflight Lua スイートの SmartFuel の電圧モードの考え方に沿っています。コピーではなく、独立した再実装です。
- **BattAnalog**(EdgeTX、Copyright Offer Shmuely、GPLv2): セル電圧 → % の表、電池の種類、セル数判別の規則。
- 企画・要件・実機テスト・調整: Masayuki。コードは AI アシスタントの Claude(Anthropic)と一緒に書きました。

**GNU General Public License version 2** のフリーソフトウェアです。[LICENSE](LICENSE) を参照してください。Copyright (C) 2026 Masayuki.

## 変更履歴

[CHANGELOG.ja.md](CHANGELOG.ja.md) をご覧ください。
