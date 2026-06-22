#!/usr/bin/env bash

ARCHIVE="$1"
PASSWORD="${PASSWORD:-}"

if [ -z "$PASSWORD" ]; then

    PROBE=$(lsar -t "$ARCHIVE" 2>&1)

    if echo "$PROBE" | grep -qi "password"; then

        PASSWORD=$(kdialog --password "请输入压缩包密码：")

        [ -z "$PASSWORD" ] && exit 0

    fi

fi

DEST="$(dirname "$ARCHIVE")"

yad \
    --progress \
    --title="正在解压" \
    --text="正在解压压缩包，请稍候..." \
    --pulsate \
    --no-buttons \
    --auto-close &
YAD_PID=$!

if [ -n "$PASSWORD" ]; then
    unar \
        -o "$DEST" \
        -p "$PASSWORD" \
        "$ARCHIVE"
else
    unar \
        -o "$DEST" \
        "$ARCHIVE"
fi

UNAR_EXIT_CODE=$?

kill "$YAD_PID" 2>/dev/null

# 可选：解压失败时弹出错误提示
if [ "$UNAR_EXIT_CODE" -ne 0 ]; then
    kdialog \
        --error "压缩包解压失败。"

    exit "$UNAR_EXIT_CODE"
fi
