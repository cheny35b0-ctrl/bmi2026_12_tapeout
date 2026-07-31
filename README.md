# T4lab_BMI

## プロジェクト概要

このプロジェクトは、Brain-Machine Interface (BMI) のディジタル回路実装です。マルチデバイス対応および新型10bit ADCを搭載し、電気/光刺激と測定機能を統合したシステムです。通信データの信頼性向上のため、畳み込み符号化機能を実装しています。

## 主要機能

### 1. 刺激機能（Stimulation）

#### 電気刺激（Electrical Stimulation）
- P極性（正極）とN極性（負極）の独立制御
- パラメータ設定可能：
  - PERIOD：刺激周期（16bit）
  - WIDTH：パルス幅（16bit）
  - LOOP：繰り返し回数（16bit）
  - DELAY：遅延時間（16bit）
  - INTENSITY：強度（5bit）
- モジュール：`STIM.v`, `ELE_STIM_XOR.v`

#### 光刺激（Optical Stimulation）
- 5チャンネル光刺激出力
- 電気刺激と同様のパラメータ設定
- モジュール：`STIM.v`

### 2. 測定機能（Measurement）

#### 電気測定（Electric Measuring）
- 10bit SAR-ADC実装
- コンパレータベースの逐次比較型
- キャリブレーション機能付き（CAL1, CAL2）
- モジュール：`MEASURE.v`, `ADC_logic.v`

#### 光測定（Optical Measuring）
- 10bit SAR-ADC実装
- 電気測定と同じアーキテクチャ
- 独立したバイアス制御
- モジュール：`MEASURE.v`

### 3. 通信機能（Communication）

#### マンチェスターデコーダー
- 外部からのコマンド受信
- クロック抽出機能
- モジュール：`MAN_DECODER.v`, `MAN_DECODER_v2.v`

#### コマンド制御
- 400bitコマンドレジスタ
- アドレス指定による個別/一斉制御
- モジュール：`COMMAND.v`

#### シリアル出力
- 測定データのシリアル化
- 畳み込み符号化ON/OFF切り替え対応
- モジュール：`COM_CON_OUT.v`, `COM_CON_TOP.v`, `SELECT.v`, `SHIFT_REG.v`

### 4. 畳み込み符号化（Convolutional Encoding）

通信データの誤り訂正能力を向上させるため、畳み込み符号化機能を実装しています。

#### パラメータ
- **符号化率（Code Rate）**: 1/2
- **拘束長（Constraint Length）**: K = 3
- **生成多項式（Generator Polynomials）**: G0 = 7 (111₂), G1 = 5 (101₂)
- **自由距離（Free Distance）**: dfree = 5
- **理論誤り訂正能力**: 最大2ビット

#### 機能
- 入力32bit（ADDRESS 8bit + TYPE 2bit + DATA 20bit + 終端2bit）を64bit符号化データに変換
- `command[343]`による符号化ON/OFF制御
- ゼロ終端（Zero Termination）方式
- モジュール：`CONV_ENCODER.v`

#### データフロー
```
入力: {ADDRESS[7:0], TYPE[1:0], DATA[19:0], 2'b00} (32bit)
      ↓
畳み込み符号化器 (K=3, rate 1/2, G=(7,5))
      ↓
出力: 64bit符号化データ
      ↓
シリアル送信
```

詳細は [docs/convolutional_encoder_design.md](docs/convolutional_encoder_design.md) を参照してください。

## モジュール構成

### トップモジュール
- `TOP_202512TO.v` - システム全体のトップモジュール
- `COM_CON_TOP.v` - 通信制御のトップモジュール

### 刺激関連
- `STIM.v` - 刺激パルス生成
- `ELE_STIM_XOR.v` - 電気刺激のP/N制御

### 測定関連
- `MEASURE.v` - 測定制御モジュール
- `ADC_logic.v` - ADC制御ロジック
- `offset_calib.v` - オフセットキャリブレーション

### 通信・符号化関連
- `CONV_ENCODER.v` - 畳み込み符号化器
- `COM_CON_OUT.v` - 通信出力制御
- `SELECT.v` - データセレクタ
- `SHIFT_REG.v` - シフトレジスタ（64bit対応）
- `COM_ENABLE.v` - 通信イネーブル制御
- `COUNTER_COMCON.v` - 通信カウンタ

### デコーダー・エンコーダー
- `MAN_DECODER.v` / `MAN_DECODER_v2.v` - マンチェスターデコーダー
- `MEASUREMENT_TYPE_ENCODER.v` - 測定タイプエンコーダー

### 汎用モジュール
- `counter_4bit.v` - 4bitカウンタ
- `counter_8bit.v` - 8bitカウンタ
- `counter_16bit.v` - 16bitカウンタ
- `6bit_counter.v` - 6bitカウンタ
- `SELECT_2in.v` - 2入力セレクタ

## テストベンチ

以下のテストベンチが用意されています：

- `CONV_ENCODER_TB.v` - 畳み込み符号化器のテストベンチ
- `COM_CON_OUT_tb.v` - 通信出力のテストベンチ
- `SELECT_tb.v` - データセレクタのテストベンチ
- `BMI_testbench_single.v` - システム全体のテストベンチ
- `6bit counter_tb.v` - 6bitカウンタのテストベンチ

## ディレクトリ構成

```
T4lab_BMI/
├── rtl/                  本流の Verilog RTL ソース
│   ├── top/              トップモジュール（TOP_202512TO.v, COM_CON_TOP.v）
│   ├── stim/             刺激（STIM.v, ELE_STIM_XOR.v）
│   ├── measure/          測定（MEASURE.v, ADC_logic.v, offset_calib.v）
│   ├── comm/             通信・符号化（COM_CON_OUT.v, CONV_ENCODER.v など）
│   └── common/           汎用カウンタ（counter_{4,8,16}bit.v）
├── tb/                   テストベンチ
│   └── filelists/        iverilog 用 filelist（リポジトリルート基準パス）
├── sim/                  シミュレーション出力（.vcd / .vvp / .sav）
└── docs/                 設計ドキュメント
```

## シミュレーション実行

Icarus Verilogを使用したシミュレーション例（**リポジトリルートで実行**）：

```bash
# 畳み込み符号化器のテスト
iverilog -o sim/CONV_ENCODER_TB.vvp -c tb/filelists/CONV_ENCODER_TB_filelist.txt
vvp sim/CONV_ENCODER_TB.vvp

# 通信出力のテスト
iverilog -o sim/COM_CON_OUT_tb.vvp -c tb/filelists/COM_CON_OUT_tb_filelist.txt
vvp sim/COM_CON_OUT_tb.vvp

# システム全体のテスト
iverilog -o sim/TOP_202512TO_tb.vvp -c tb/filelists/TOP_202512TO_tb_filelist.txt
vvp sim/TOP_202512TO_tb.vvp

# VCD 波形ファイルは vvp 実行時のカレントディレクトリに出力されるため、
# sim/ に集めたい場合は `cd sim && vvp ../sim/xxx.vvp` のように実行する
```

filelist のパスはリポジトリルート基準で記述されているため、`iverilog` は必ずリポジトリルートから実行してください。

## ドキュメント

- [docs/convolutional_encoder_design.md](docs/convolutional_encoder_design.md) - 畳み込み符号化機能の詳細設計ドキュメント
- [docs/REVIEW.md](docs/REVIEW.md) - レビューガイドライン

## 通信プロトコル

### 符号化なし（従来）
| フィールド | ビット数 | 累積 |
|-----------|---------|------|
| スタート（カウンタ） | 32bit | 32 |
| アドレス | 8bit | 40 |
| タイプ | 2bit | 42 |
| データ | 20bit | 62 |
| ストップ | 3bit | 65 |

### 符号化あり（新方式）
| フィールド | ビット数 | 累積 |
|-----------|---------|------|
| スタート（カウンタ） | 32bit | 32 |
| 符号化データ | 64bit | 96 |
| ストップ | 3bit | 99 |

符号化により伝送時間は約34サイクル増加しますが、誤り訂正能力が大幅に向上します。

## コマンド構成（受信コマンドのビット割り当て）

外部から入ってくるコマンドは、マンチェスター信号 `MAN` → `MAN_DECODER.v` → `ORDER` → `COMMAND.v` の経路で受信され、400bit の `command` レジスタに格納されます。各ビットの意味は `rtl/top/TOP_202512TO.v` での参照箇所が定義そのものです。

### 受信フレーム構造

コマンドは **10bit を 1 フレーム**とするシリアル形式で送られます。

```
[start=0] [d0 d1 d2 d3 d4 d5 d6 d7] [stop=1]
   1bit          データ 8bit           1bit
```

- **プリアンブル**：`ORDER` が `1` のまま 10 クロック以上続いた後に `0` へ落ちると書き込み開始（`COMMAND.v` の `start` カウンタ）
- **ビット順**：各フレームのデータ 8bit は **LSB first**（`command[J]` → `command[J+7]` の順）
- **格納規則**：k 番目のバイト（k = 0〜39）は `command[10k+7 : 10k]` に入り、`command[10k+8]` にストップビット（常に `1`）、`command[10k+9]` に次フレームのスタートビット（常に `0`）が入ります

つまり **10bit ごとに下位 8bit が有効データ、上位 2bit はフレーム同期用**です。パラメータのビット番号が 20、30、40… と 10 刻みで飛んでいるのはこのためです。

### 書き込みの中断条件（`COMMAND.v`）

| 条件 | 動作 |
|------|------|
| 8bit 受信時点で `command[7:0]` が自機アドレスとも `general`(8'hFF) とも不一致 | 書き込み中断（他デバイス宛て） |
| 10bit 受信時点で `command[10] == 1` | 書き込み中断（**短コマンド＝起動トリガ**） |
| `ORDER` が `1` のまま 10 クロック以上継続 | 書き込み中断（フレーム終了） |

この仕様により、**パラメータ設定は `command[10]=0` の長いコマンド（35 フレーム＝350bit）で行い、その後 `command[10]=1` の 2 フレームだけの短いコマンドを general アドレス宛てに送って全デバイスを同時起動する**、という 2 段階の運用になります。

### 全体マップ

| ビット範囲 | ブロック |
|-----------|---------|
| `[7:0]` | デバイスアドレス |
| `[17:10]` | 共通イネーブル |
| `[107:20]` | 電気刺激 P極 パラメータ |
| `[197:110]` | 電気刺激 N極 パラメータ |
| `[227:200]` | 電気測定パラメータ |
| `[317:230]` | 光刺激パラメータ |
| `[347:320]` | 光測定パラメータ・符号化制御 |
| `[399:350]` | 未使用（予約） |

### アドレス・イネーブル部

| ビット | 名称 | 意味 |
|-------|------|------|
| `command[7:0]` | ADDRESS | 宛先デバイスアドレス。自機アドレス（`unique`）または `8'hFF`（general、一斉同報）に一致した場合のみ受理 |
| `command[10]` | システムイネーブル | 全 `OPERATE` に AND される起動ビット。`1` で刺激・測定を開始（同時に書き込みを打ち切る） |
| `command[13:11]` | — | 未使用 |
| `command[14]` | 電気刺激共通制御 | P極・N極の両方に AND される電気刺激マスタイネーブル |
| `command[15]` | 電気測定イネーブル | `MEASURE`(ELE) と `COM_CON_OUT` の `OPERATE_ELE` |
| `command[16]` | 光刺激イネーブル | `STIM`(OPTICAL) の `OPERATE` |
| `command[17]` | 光測定イネーブル | `MEASURE`(OPT) と `COM_CON_OUT` の `OPERATE_OPT` |

自機アドレス `unique` は `unique[7:6]=2'b00`、`unique[5:2]` は `unique_debug` で `4'b1011`/`4'b0000`、`unique[1:0]` は `unique_low` 入力で決まります。

### 電気刺激 P極（`STIM ELE_P_STIM`）

16bit パラメータは **下位バイトが先、上位バイトが後**のフレームに配置されます（`{上位, 下位}` で結合）。

| ビット | 名称 | 意味 |
|-------|------|------|
| `command[27:20]` | PERIOD 下位8bit | 刺激周期（16bit、単位 msec） |
| `command[37:30]` | PERIOD 上位8bit | 〃 |
| `command[47:40]` | WIDTH 下位8bit | パルス幅（16bit） |
| `command[57:50]` | WIDTH 上位8bit | 〃 |
| `command[67:60]` | LOOP 下位8bit | 繰り返し回数（16bit） |
| `command[77:70]` | LOOP 上位8bit | 〃 |
| `command[87:80]` | DELAY 下位8bit | 開始遅延（16bit） |
| `command[97:90]` | DELAY 上位8bit | 〃 |
| `command[104:100]` | INTENSITY | 強度 5bit（`P_STIM[4:0]` へ出力） |
| `command[105]` | OPERATE | P極個別イネーブル（`command[105] & command[14] & command[10]`） |
| `command[107:106]` | — | 未使用 |

### 電気刺激 N極（`STIM ELE_N_STIM`）

| ビット | 名称 | 意味 |
|-------|------|------|
| `command[117:110]` | PERIOD 下位8bit | 刺激周期（16bit） |
| `command[127:120]` | PERIOD 上位8bit | 〃 |
| `command[137:130]` | WIDTH 下位8bit | パルス幅（16bit） |
| `command[147:140]` | WIDTH 上位8bit | 〃 |
| `command[157:150]` | LOOP 下位8bit | 繰り返し回数（16bit） |
| `command[167:160]` | LOOP 上位8bit | 〃 |
| `command[177:170]` | DELAY 下位8bit | 開始遅延（16bit） |
| `command[187:180]` | DELAY 上位8bit | 〃 |
| `command[194:190]` | INTENSITY | 強度 5bit（`N_STIM[4:0]` へ出力） |
| `command[195]` | OPERATE | N極個別イネーブル（`command[195] & command[14] & command[10]`） |
| `command[197:196]` | — | 未使用 |

### 電気測定（`MEASURE ELECTRIC_MEAS`）

| ビット | 名称 | 意味 |
|-------|------|------|
| `command[207:200]` | DELAY 下位8bit | 測定開始遅延（16bit） |
| `command[217:210]` | DELAY 上位8bit | 〃 |
| `command[227:220]` | — | 未使用（テストベンチでは値を送っているが RTL 未参照） |

イネーブルは `command[15] & command[10]`。

### 光刺激（`STIM OPTICAL_STIM`）

| ビット | 名称 | 意味 |
|-------|------|------|
| `command[237:230]` | PERIOD 下位8bit | 刺激周期（16bit） |
| `command[247:240]` | PERIOD 上位8bit | 〃 |
| `command[257:250]` | WIDTH 下位8bit | パルス幅（16bit） |
| `command[267:260]` | WIDTH 上位8bit | 〃 |
| `command[277:270]` | LOOP 下位8bit | 繰り返し回数（16bit） |
| `command[287:280]` | LOOP 上位8bit | 〃 |
| `command[297:290]` | DELAY 下位8bit | 開始遅延（16bit） |
| `command[307:300]` | DELAY 上位8bit | 〃 |
| `command[314:310]` | INTENSITY | 強度 5bit（`OPT_STIM[4:0]` へ出力） |
| `command[317:315]` | — | 未使用 |

電気刺激と異なり個別 OPERATE ビットはなく、イネーブルは `command[16] & command[10]` のみ。

### 光測定・符号化制御（`MEASURE OPTICAL_MEAS`, `COM_CON_OUT`）

| ビット | 名称 | 意味 |
|-------|------|------|
| `command[327:320]` | DELAY 下位8bit | 測定開始遅延（16bit） |
| `command[337:330]` | DELAY 上位8bit | 〃 |
| `command[342:340]` | — | 未使用 |
| `command[343]` | **ENCODE_ENABLE** | **畳み込み符号化 ON/OFF**<br>`1'b1`: 符号化有効／`1'b0`: 符号化無効（スルーモード）<br>外部パッド入力と OR される：`command[343] \| ENCODE_ENABLE_ext` |
| `command[347:344]` | — | 未使用 |

光測定のイネーブルは `command[17] & command[10]`。

### 未使用ビット一覧

`command[13:11]` / `command[107:106]` / `command[197:196]` / `command[227:220]` / `command[317:315]` / `command[342:340]` / `command[347:344]` / `command[399:350]`

（加えて、各 10bit フレームの `command[10k+8]`＝ストップビット、`command[10k+9]`＝スタートビットは同期用のため制御には使用しません。）

### 送信例（テストベンチ `tb/TOP_202512TO_tb.v`）

```verilog
// 1発目: パラメータ設定（bit10 = 0 のまま 35 フレーム = 350bit 送信）
command [7:0]   = 8'b0010_1100;  // address
command [17:10] = 8'b1010_0000;  // bit17=光測定ON, bit15=電気測定ON, bit10=0
{command[37:30], command[27:20]} = 16'h000A;  // ELE_P period
...
command [347:340] = 8'b0000_0111;  // bit343 = 0（符号化OFF）

// 2発目: 起動トリガ（2 フレーム = 20bit だけ送信）
trig_cmd[7:0] = 8'b1111_1111;  // general address（全デバイス宛て）
trig_cmd[10]  = 1'b1;          // 起動ビット
```

## 開発履歴

最近の主な変更：
- 畳み込み符号化機能の追加（K=3, rate 1/2）
- 通信モジュールの64bit対応拡張
- 符号化ON/OFF制御機能の実装
- 各モジュールの動作検証完了

詳細なコミット履歴は`git log`を参照してください。

## ライセンス

T4 Lab - Brain-Machine Interface Digital Circuit Project

## 貢献者

- T4 Lab メンバー

## 参考資料

- Lin, S., & Costello, D. J. (2004). "Error Control Coding" (2nd ed.)
- Viterbi, A. J. (1967). "Error bounds for convolutional codes and an asymptotically optimum decoding algorithm"
