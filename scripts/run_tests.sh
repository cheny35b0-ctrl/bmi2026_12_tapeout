#!/usr/bin/env bash
#
# tb/filelists/ にある全テストベンチをコンパイル・実行する。
# 1 つでも失敗したら非ゼロで終了するので、CI からそのまま呼べる。
#
#   使い方: ./scripts/run_tests.sh
#
set -u

cd "$(dirname "$0")/.."   # リポジトリルートへ移動 (filelist のパスがルート基準のため)

mkdir -p sim
status=0

for f in tb/filelists/*_filelist.txt; do
    name=$(basename "$f" _filelist.txt)
    printf '%-28s ' "$name"

    if ! iverilog -o "sim/$name.vvp" -c "$f" > "sim/$name.compile.log" 2>&1; then
        echo "COMPILE FAILED"
        sed 's/^/    /' "sim/$name.compile.log"
        status=1
        continue
    fi

    # VCD が散らからないよう sim/ の中で実行する
    if (cd sim && vvp "$name.vvp" > "$name.run.log" 2>&1); then
        # セルフチェック付きの TB は結果件数を拾って表示する
        summary=$(grep -E '^  (成功|失敗)' "sim/$name.run.log" 2>/dev/null | tr -d '\n' | tr -s ' ')
        echo "PASS${summary:+  $summary}"
    else
        echo "FAILED"
        grep -E '\[FAIL\]|FATAL' "sim/$name.run.log" | sed 's/^/    /'
        status=1
    fi
done

echo
if [ $status -eq 0 ]; then
    echo "すべてのテストベンチが通りました"
else
    echo "失敗したテストベンチがあります"
fi

exit $status
