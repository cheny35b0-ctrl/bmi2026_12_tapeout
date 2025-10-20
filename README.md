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
- `TOP_202506TO.v` - システム全体のトップモジュール
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

## シミュレーション実行

Icarus Verilogを使用したシミュレーション例：

```bash
# 畳み込み符号化器のテスト
iverilog -o CONV_ENCODER_TB.vvp -c CONV_ENCODER_TB_filelist.txt
vvp CONV_ENCODER_TB.vvp

# 通信出力のテスト
iverilog -o COM_CON_OUT_tb.vvp -c COM_CON_OUT_tb_filelist.txt
vvp COM_CON_OUT_tb.vvp

# VCD波形ファイルの生成
# 出力されたVCDファイルはGTKWaveなどで表示可能
```

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

## コマンド構成

400bitコマンドレジスタの主要なフィールド：

- `command[10]`: システムイネーブル
- `command[14]`: 電気刺激共通制御
- `command[15]`: 電気測定イネーブル
- `command[16]`: 光刺激イネーブル
- `command[17]`: 光測定イネーブル
- `command[343]`: **符号化ON/OFFフラグ**（新規追加）
  - `1'b1`: 符号化有効
  - `1'b0`: 符号化無効（スルーモード）

刺激・測定パラメータは16bit単位で配置されています。

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
