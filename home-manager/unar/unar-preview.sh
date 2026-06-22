#!/usr/bin/env bash

PASSWORD=""

FILE_LIST=$(lsar "$1" 2>&1)

if echo "$FILE_LIST" | grep -Eqi \
    "requires a password|password required|encrypted"; then

    PASSWORD=$(kdialog --password "请输入压缩包密码：")

    [ -z "$PASSWORD" ] && exit 0

    FILE_LIST=$(lsar -p "$PASSWORD" "$1" 2>&1)

fi

TMPFILE=$(mktemp /tmp/unar-preview-XXXXXX.txt)

echo "$FILE_LIST" \
    | python3 ~/.local/bin/unar-preview.py \
    > "$TMPFILE"

yad \
    --title="压缩包预览" \
    --text-info \
    --filename="$TMPFILE" \
    --width=400 \
    --height=600 \
    --button="解压:0" \
    --button="关闭:1"

RET=$?

if [ "$RET" -eq 0 ]; then

    PASSWORD="$PASSWORD" \
        ~/.local/bin/unar-extract.sh "$1"

fi
