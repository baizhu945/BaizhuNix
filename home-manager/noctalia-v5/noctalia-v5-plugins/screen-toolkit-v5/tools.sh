#!/usr/bin/env bash
# External helpers for the Noctalia v5 Screen Toolkit port.
#
# Noctalia v5 plugins cannot embed the v4 QML overlay components, so the
# operations that need a full-screen Wayland surface are delegated to the
# small native tools already used by the V4 workflow. Every action is
# deliberately independent and safe to invoke from a bar hotkey.
set -euo pipefail

ACTION="${1:-}"
HOME_DIR="${HOME:?}"
SCREEN_DIR="${SCREEN_TOOLKIT_SCREENSHOT_DIR:-$HOME_DIR/Pictures/Screenshots}"
VIDEO_DIR="${SCREEN_TOOLKIT_VIDEO_DIR:-$HOME_DIR/Videos}"

need() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'Screen Toolkit: missing dependency: %s\n' "$1" >&2
        exit 3
    }
}

now() {
    date +%Y%m%d_%H%M%S
}

show_result() {
    local title="$1"
    local text="$2"
    if command -v yad >/dev/null 2>&1; then
        printf '%s\n' "$text" | yad --text-info --title="$title" --width=620 --height=420 \
            --button="复制:0" --button="关闭:1" >/tmp/noctalia-screen-toolkit-yad.out || true
        if test -s /tmp/noctalia-screen-toolkit-yad.out; then
            wl-copy < /tmp/noctalia-screen-toolkit-yad.out || true
        fi
        remove-without-permission -f /tmp/noctalia-screen-toolkit-yad.out 2>/dev/null || true
    else
        printf '%s\n' "$text"
    fi
}

capture_region() {
    need slurp
    need grim
    local geometry
    geometry="$(slurp)" || exit 0
    test -n "$geometry" || exit 0
    mkdir -p "$SCREEN_DIR"
    printf '%s\n' "$geometry"
}

case "$ACTION" in
    screenshot-region)
        geometry="$(capture_region)"
        output="$SCREEN_DIR/screenshot_$(now).png"
        grim -g "$geometry" -c "$output"
        wl-copy < "$output"
        ;;

    screenshot-fullscreen)
        need grim
        mkdir -p "$SCREEN_DIR"
        output="$SCREEN_DIR/screenshot_$(now).png"
        grim -c "$output"
        wl-copy < "$output"
        ;;

    annotate-region)
        geometry="$(capture_region)"
        tmp="$(mktemp --suffix=.png /tmp/noctalia-annotate-XXXXXX)"
        trap 'remove-without-permission -f "$tmp" 2>/dev/null || true' EXIT
        grim -g "$geometry" "$tmp"
        if command -v satty >/dev/null 2>&1; then
            mkdir -p "$SCREEN_DIR"
            satty --filename "$tmp" \
                --output-filename "$SCREEN_DIR/annotate_$(now).png" \
                --copy-command wl-copy \
                --actions-on-right-click save-to-clipboard,exit \
                --actions-on-escape exit \
                --title "Noctalia Annotation"
        else
            # Keep the capture usable on installations that have not enabled
            # the optional Satty package yet.
            wl-copy < "$tmp"
            mpv --ontop --force-window=yes --keep-open=yes --title="Noctalia Annotation" "$tmp" >/dev/null 2>&1 || true
        fi
        ;;

    annotate-fullscreen)
        need chameleos
        need chamel
        chameleos --stroke-width 4 >/dev/null 2>&1 &
        sleep 0.1
        chamel toggle
        ;;

    close-annotation)
        need chamel
        chamel exit
        ;;

    color-picker)
        need hyprpicker
        # hyprpicker is wlroots-compatible and provides the same copy-on-pick
        # habit as the V4 ColorPicker overlay.
        hyprpicker --autocopy --format=hex --no-fractional
        ;;

    palette)
        need magick
        geometry="$(capture_region)"
        tmp="$(mktemp --suffix=.png /tmp/noctalia-palette-XXXXXX)"
        trap 'remove-without-permission -f "$tmp" 2>/dev/null || true' EXIT
        grim -g "$geometry" "$tmp"
        colors="$(magick "$tmp" -alpha off +dither -colors 8 -unique-colors txt:- 2>/dev/null \
            | grep -oE '#[0-9a-fA-F]{6}' | head -8 || true)"
        test -n "$colors" || colors="未能从选区提取颜色"
        show_result "Noctalia Palette" "$colors"
        ;;

    ocr)
        need tesseract
        geometry="$(capture_region)"
        tmp="$(mktemp --suffix=.png /tmp/noctalia-ocr-XXXXXX)"
        trap 'remove-without-permission -f "$tmp" 2>/dev/null || true' EXIT
        grim -g "$geometry" "$tmp"
        lang="${SCREEN_TOOLKIT_OCR_LANG:-eng}"
        result="$(tesseract "$tmp" stdout -l "$lang" 2>/dev/null || true)"
        if test -n "$result"; then
            show_result "Noctalia OCR" "$result"
        else
            show_result "Noctalia OCR" "未识别到文字"
            exit 2
        fi
        ;;

    qr)
        need zbarimg
        geometry="$(capture_region)"
        tmp="$(mktemp --suffix=.png /tmp/noctalia-qr-XXXXXX)"
        trap 'remove-without-permission -f "$tmp" 2>/dev/null || true' EXIT
        grim -g "$geometry" "$tmp"
        result="$(zbarimg -q --raw "$tmp" 2>/dev/null || true)"
        if test -n "$result"; then
            show_result "Noctalia QR / Barcode" "$result"
        else
            show_result "Noctalia QR / Barcode" "未检测到二维码或条形码"
        fi
        ;;

    lens)
        need curl
        need jq
        need xdg-open
        geometry="$(capture_region)"
        tmp="$(mktemp --suffix=.png /tmp/noctalia-lens-XXXXXX)"
        trap 'remove-without-permission -f "$tmp" 2>/dev/null || true' EXIT
        grim -g "$geometry" "$tmp"
        response="$(curl -sS -f -A 'Mozilla/5.0' --connect-timeout 20 --max-time 60 \
            -F "files[]=@$tmp" 'https://uguu.se/upload' 2>/dev/null || true)"
        url="$(printf '%s' "$response" | jq -r '.files[0].url // empty' 2>/dev/null || true)"
        if test -n "$url" && [[ "$url" == http* ]]; then
            xdg-open "https://lens.google.com/uploadbyurl?url=$url" >/dev/null 2>&1 &
        else
            show_result "Noctalia Lens" "上传失败，请稍后重试"
            exit 2
        fi
        ;;

    pin-region)
        geometry="$(capture_region)"
        need mpv
        mkdir -p "$SCREEN_DIR"
        output="$SCREEN_DIR/noctalia-pin-$(now).png"
        grim -g "$geometry" "$output"
        mpv --ontop --force-window=yes --keep-open=yes --title="Noctalia Pinned Screenshot" "$output" >/dev/null 2>&1 &
        ;;

    pin-image)
        need mpv
        file=""
        if command -v kdialog >/dev/null 2>&1; then
            file="$(kdialog --getopenfilename "$HOME_DIR" 'Images (*.png *.jpg *.jpeg *.webp *.gif)')" || true
        elif command -v yad >/dev/null 2>&1; then
            file="$(yad --file --title='Pin image or video')" || true
        fi
        test -n "$file" || exit 0
        mpv --ontop --force-window=yes --keep-open=yes --title="Noctalia Pinned Media" "$file" >/dev/null 2>&1 &
        ;;

    measure)
        geometry="$(capture_region)"
        size="${geometry##* }"
        width="${size%x*}"
        height="${size#*x}"
        show_result "Noctalia Measure" "选区大小: ${width} × ${height} px\n\n提示：V5 使用 Satty/Wayland 工具替代 V4 的交互式标尺。"
        ;;

    record-region)
        geometry="$(capture_region)"
        need mkdir
        mkdir -p "$VIDEO_DIR"
        output="$VIDEO_DIR/screen-toolkit_$(now).mp4"
        if command -v wl-screenrec >/dev/null 2>&1; then
            wl-screenrec --geometry "$geometry" --filename "$output" --codec hevc \
                --audio --audio-codec aac --max-fps 60
        elif command -v wf-recorder >/dev/null 2>&1; then
            wf-recorder --geometry "$geometry" --framerate 60 --codec hevc \
                --audio-backend=pipewire --audio-codec=aac -f "$output"
        else
            printf 'Screen Toolkit: install wl-screenrec or wf-recorder for region recording\n' >&2
            exit 3
        fi
        ;;

    record-stop)
        pkill -SIGINT -f '(^|/)wl-screenrec([[:space:]]|$)' 2>/dev/null || true
        pkill -SIGINT -f '(^|/)wf-recorder([[:space:]]|$)' 2>/dev/null || true
        ;;

    stop-all)
        chamel exit 2>/dev/null || true
        pkill -SIGINT -f '(^|/)wl-screenrec([[:space:]]|$)' 2>/dev/null || true
        pkill -SIGINT -f '(^|/)wf-recorder([[:space:]]|$)' 2>/dev/null || true
        ;;

    mirror)
        need mpv
        test -e /dev/video0 || {
            show_result "Noctalia Webcam Mirror" "未找到 /dev/video0 摄像头设备"
            exit 2
        }
        mpv --profile=low-latency --untimed --no-audio \
            --title="Noctalia Webcam Mirror" av://v4l2:/dev/video0 >/dev/null 2>&1
        ;;

    *)
        printf 'Unknown Screen Toolkit action: %s\n' "$ACTION" >&2
        exit 1
        ;;
esac
