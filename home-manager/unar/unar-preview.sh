#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/unar-common.sh"

MAX_PASSWORD_ATTEMPTS=3
PASSWORD_ATTEMPTS=0
PASSWORD_SET=0
PASSWORD_NEEDS_VALIDATION=0
PASSWORD=""
WORKDIR=""

show_usage_error() {
    unar_show_error "$1"
    exit 64
}

request_password() {
    if ((PASSWORD_ATTEMPTS >= MAX_PASSWORD_ATTEMPTS)); then
        return 2
    fi

    if ! unar_prompt_password; then
        return 1
    fi

    PASSWORD="$UNAR_PASSWORD"
    PASSWORD_SET=1
    PASSWORD_NEEDS_VALIDATION=1
    PASSWORD_ATTEMPTS=$((PASSWORD_ATTEMPTS + 1))
    return 0
}

show_listing_error() {
    local details
    local message

    details="$(<"$ERROR_FILE")"
    if [[ -z $details ]]; then
        if ((PASSWORD_SET)); then
            details="$(unar_lsar_text "$ARCHIVE" "$PASSWORD" 2>&1 || true)"
        else
            details="$(unar_lsar_text "$ARCHIVE" 2>&1 || true)"
        fi
    fi

    if [[ -z $details ]]; then
        details="lsar 无法列出压缩包内容。"
    fi

    details="${details:0:3000}"
    printf -v message '无法读取压缩包。\n\n%s' "$details"
    unar_show_error "$message"
}

show_password_error() {
    local details
    local message

    details="$(<"$PASSWORD_TEST_LOG")"
    if [[ -z $details ]]; then
        details="密码错误，或压缩包内容无法验证。"
    fi

    details="${details:0:3000}"
    printf -v message '密码错误，或压缩包内容无法验证。\n\n%s' "$details"
    unar_show_error "$message"
}

# shellcheck disable=SC2329
cleanup() {
    unar_remove "$WORKDIR"
}

if (($# != 1)); then
    show_usage_error "请只选择一个压缩包。"
fi

ARCHIVE=$1
if [[ ! -f $ARCHIVE || ! -r $ARCHIVE ]]; then
    message=$(printf '无法读取所选压缩包：\n%s' "$ARCHIVE")
    show_usage_error "$message"
fi

if ! unar_require_commands \
    lsar unar python3 kdialog yad; then
    unar_show_error "unar 预览所需的运行时依赖不完整。"
    exit 127
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/unar-preview-XXXXXX")" || {
    unar_show_error "无法创建预览临时目录。"
    exit 1
}

JSON_FILE="$WORKDIR/list.json"
DISPLAY_FILE="$WORKDIR/preview.txt"
ERROR_FILE="$WORKDIR/lsar.err"
PASSWORD_TEST_LOG="$WORKDIR/password-test.log"

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

while :; do
    if ((PASSWORD_SET)); then
        unar_lsar_json "$ARCHIVE" "$PASSWORD" > "$JSON_FILE" 2> "$ERROR_FILE"
    else
        unar_lsar_json "$ARCHIVE" > "$JSON_FILE" 2> "$ERROR_FILE"
    fi
    LIST_STATUS=$?

    if ((LIST_STATUS == 0)); then
        # A valid JSON listing tells us whether the archive contains encrypted
        # entries. Do this only before a password is supplied because lsar keeps
        # the encrypted flag even after a correct password is provided.
        if ((PASSWORD_SET == 0)); then
            unar_json_encryption_status "$JSON_FILE" >/dev/null 2>&1
            ENCRYPTION_STATUS=$?
            case $ENCRYPTION_STATUS in
                0)
                    request_password
                    PASSWORD_STATUS=$?
                    case $PASSWORD_STATUS in
                        0) continue ;;
                        1) exit 0 ;;
                        2) unar_show_error "密码尝试次数已达到上限。"; exit 1 ;;
                    esac
                    ;;
                1)
                    ;;
                *)
                    show_listing_error
                    exit 1
                    ;;
            esac
        elif ! unar_json_is_valid "$JSON_FILE"; then
            request_password
            PASSWORD_STATUS=$?
            case $PASSWORD_STATUS in
                0) continue ;;
                1) exit 0 ;;
                2) show_password_error; exit 1 ;;
            esac
        fi

        # JSON metadata can still look valid with a wrong password for some
        # formats (notably encrypted ZIP/7z data), so verify it once.
        if ((PASSWORD_NEEDS_VALIDATION)); then
            if ! unar_validate_password "$ARCHIVE" "$PASSWORD" "$PASSWORD_TEST_LOG"; then
                request_password
                PASSWORD_STATUS=$?
                case $PASSWORD_STATUS in
                    0) continue ;;
                    1) exit 0 ;;
                    2) show_password_error; exit 1 ;;
                esac
            fi
            PASSWORD_NEEDS_VALIDATION=0
        fi

        if ! python3 "$SCRIPT_DIR/unar-preview.py" < "$JSON_FILE" > "$DISPLAY_FILE"; then
            unar_show_error "无法生成压缩包预览。"
            exit 1
        fi
        break
    fi

    # lsar uses status 2 when it needs a password. Once a password has been
    # supplied, any failed listing is treated as a bad password and retried.
    if ((PASSWORD_SET == 0 && LIST_STATUS == 2)) || ((PASSWORD_SET == 1)); then
        request_password
        PASSWORD_STATUS=$?
        case $PASSWORD_STATUS in
            0) continue ;;
            1) exit 0 ;;
            2)
                if ((PASSWORD_SET)); then
                    show_password_error
                else
                    show_listing_error
                fi
                exit 1
                ;;
        esac
    fi

    show_listing_error
    exit 1
done

yad \
    --text-info \
    --filename="$DISPLAY_FILE" \
    --title="压缩包预览" \
    --width=600 \
    --height=700 \
    --button="解压:0" \
    --button="关闭:1" \
    </dev/null
RET=$?

case $RET in
    0)
        UNAR_PASSWORD="$PASSWORD" \
        UNAR_PASSWORD_SET="$PASSWORD_SET" \
        UNAR_PASSWORD_NEEDS_VALIDATION="$PASSWORD_NEEDS_VALIDATION" \
            "$SCRIPT_DIR/unar-extract.sh" "$ARCHIVE"
        exit $?
        ;;
    1)
        # The close button and normal window close are user cancellation.
        exit 0
        ;;
    *)
        unar_show_error "预览窗口启动失败。"
        exit "$RET"
        ;;
esac
