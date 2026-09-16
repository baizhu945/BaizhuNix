#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/unar-common.sh"

MAX_PASSWORD_ATTEMPTS=3
PASSWORD_ATTEMPTS=0
PASSWORD_SET="${UNAR_PASSWORD_SET:-0}"
PASSWORD_NEEDS_VALIDATION="${UNAR_PASSWORD_NEEDS_VALIDATION:-0}"
PASSWORD="${UNAR_PASSWORD:-}"
ENCRYPTION_STATUS=1
WORKDIR=""
YAD_PID=""
UNAR_PID=""

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

acquire_and_validate_password() {
    local password_status

    while :; do
        request_password
        password_status=$?
        case $password_status in
            1)
                return 1
                ;;
            2)
                return 2
                ;;
        esac

        if unar_validate_password "$ARCHIVE" "$PASSWORD" "$PASSWORD_TEST_LOG"; then
            PASSWORD_NEEDS_VALIDATION=0
            return 0
        fi

        if ((PASSWORD_ATTEMPTS >= MAX_PASSWORD_ATTEMPTS)); then
            return 2
        fi
    done
}

show_probe_error() {
    local details
    local message

    details="$(<"$PROBE_ERROR")"
    if [[ -z $details ]]; then
        if ((PASSWORD_SET)); then
            details="$(unar_lsar_text "$ARCHIVE" "$PASSWORD" 2>&1 || true)"
        else
            details="$(unar_lsar_text "$ARCHIVE" 2>&1 || true)"
        fi
    fi

    if [[ -z $details ]]; then
        details="lsar 无法读取压缩包。"
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

show_extract_error() {
    local details
    local message

    details="$(<"$LOG_FILE")"
    if [[ -z $details ]]; then
        details="unar 未提供具体错误信息。"
    fi

    details="${details:0:4000}"
    printf -v message '压缩包解压失败。\n\n%s' "$details"
    unar_show_error "$message"
}

start_progress() {
    yad \
        --progress \
        --title="正在解压" \
        --text="正在解压压缩包，请稍候..." \
        --pulsate \
        --no-buttons \
        --width=360 \
        --height=100 \
        </dev/null &
    YAD_PID=$!
}

stop_progress() {
    if [[ -n $YAD_PID ]]; then
        kill "$YAD_PID" 2>/dev/null || true
        wait "$YAD_PID" 2>/dev/null || true
        YAD_PID=""
    fi
}

cleanup() {
    if [[ -n $UNAR_PID ]]; then
        kill "$UNAR_PID" 2>/dev/null || true
        wait "$UNAR_PID" 2>/dev/null || true
        UNAR_PID=""
    fi

    stop_progress
    unar_remove "$WORKDIR"
}

run_unar() {
    if ((PASSWORD_SET)); then
        exec unar \
            -o "$DEST" \
            -r \
            -p "$PASSWORD" \
            -- "$ARCHIVE" \
            > "$LOG_FILE" 2>&1
    else
        exec unar \
            -o "$DEST" \
            -r \
            -- "$ARCHIVE" \
            > "$LOG_FILE" 2>&1
    fi
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
    unar_show_error "unar 解压所需的运行时依赖不完整。"
    exit 127
fi

DEST="$(dirname -- "$ARCHIVE")"
if [[ ! -d $DEST ]]; then
    message=$(printf '压缩包所在目录不存在：\n%s' "$DEST")
    show_usage_error "$message"
fi

if [[ $PASSWORD_SET != 1 ]]; then
    PASSWORD_SET=0
fi
if [[ $PASSWORD_NEEDS_VALIDATION != 1 ]]; then
    PASSWORD_NEEDS_VALIDATION=0
fi
if ((PASSWORD_SET == 0)) && [[ -n $PASSWORD ]]; then
    PASSWORD_SET=1
    PASSWORD_NEEDS_VALIDATION=1
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/unar-extract-XXXXXX")" || {
    unar_show_error "无法创建解压临时目录。"
    exit 1
}

PROBE_JSON="$WORKDIR/probe.json"
PROBE_ERROR="$WORKDIR/probe.err"
PASSWORD_TEST_LOG="$WORKDIR/password-test.log"
LOG_FILE="$WORKDIR/extract.log"

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# Probe only archive metadata. Unlike lsar -t, this does not test every file
# before extraction. Encrypted archives are tested after a password is entered
# because JSON listings alone do not validate encrypted file data.
if ((PASSWORD_SET == 0)); then
    unar_lsar_json "$ARCHIVE" > "$PROBE_JSON" 2> "$PROBE_ERROR"
    PROBE_STATUS=$?

    if ((PROBE_STATUS == 0)); then
        unar_json_encryption_status "$PROBE_JSON" >/dev/null 2>&1
        ENCRYPTION_STATUS=$?
        case $ENCRYPTION_STATUS in
            0)
                PASSWORD_REQUIRED=1
                ;;
            1)
                PASSWORD_REQUIRED=0
                ;;
            *)
                show_probe_error
                exit 1
                ;;
        esac
    elif ((PROBE_STATUS == 2)); then
        PASSWORD_REQUIRED=1
    else
        show_probe_error
        exit 1
    fi
else
    PASSWORD_REQUIRED=0
fi

if ((PASSWORD_REQUIRED)); then
    acquire_and_validate_password
    PASSWORD_STATUS=$?
    case $PASSWORD_STATUS in
        0)
            ;;
        1)
            exit 0
            ;;
        2)
            show_password_error
            exit 1
            ;;
    esac
elif ((PASSWORD_NEEDS_VALIDATION)); then
    # Support callers that provide a password explicitly but request checking.
    if ! unar_validate_password "$ARCHIVE" "$PASSWORD" "$PASSWORD_TEST_LOG"; then
        acquire_and_validate_password
        PASSWORD_STATUS=$?
        case $PASSWORD_STATUS in
            0)
                ;;
            1)
                exit 0
                ;;
            2)
                show_password_error
                exit 1
                ;;
        esac
    fi
    PASSWORD_NEEDS_VALIDATION=0
fi

while :; do
    start_progress
    run_unar &
    UNAR_PID=$!
    wait "$UNAR_PID"
    UNAR_EXIT_CODE=$?
    UNAR_PID=""
    stop_progress

    if ((UNAR_EXIT_CODE == 0)); then
        unar_show_success "压缩包已解压到：$DEST"
        exit 0
    fi

    # A few archive formats only reveal that a password is needed during
    # extraction. Validate a newly entered password before retrying.
    if ((UNAR_EXIT_CODE == 2 && PASSWORD_SET == 0)); then
        PASSWORD_REQUIRED=1
        acquire_and_validate_password
        PASSWORD_STATUS=$?
        case $PASSWORD_STATUS in
            0) continue ;;
            1) exit 0 ;;
            2) show_extract_error; exit "$UNAR_EXIT_CODE" ;;
        esac
    fi

    show_extract_error
    exit "$UNAR_EXIT_CODE"
done
