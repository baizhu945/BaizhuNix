#!/usr/bin/env bash

# Shared helpers for the Dolphin unar service menu scripts.

UNAR_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Preserve an explicitly supplied password when this helper is sourced.
# shellcheck disable=SC2034
UNAR_PASSWORD="${UNAR_PASSWORD-}"

unar_require_commands() {
    local missing=()
    local command_name

    for command_name in "$@"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            missing+=("$command_name")
        fi
    done

    if ((${#missing[@]} > 0)); then
        printf '缺少运行时依赖：%s\n' "${missing[*]}" >&2
        return 127
    fi
}

unar_prompt_password() {
    local prompt="${1:-请输入压缩包密码：}"

    if UNAR_PASSWORD=$(kdialog --password "$prompt"); then
        return 0
    fi

    # A non-zero exit status means that the dialog was cancelled or failed.
    # shellcheck disable=SC2034
    UNAR_PASSWORD=""
    return 1
}

unar_lsar_json() {
    local archive=$1

    if (($# >= 2)); then
        lsar -j -p "$2" -- "$archive"
    else
        lsar -j -- "$archive"
    fi
}

unar_lsar_text() {
    local archive=$1

    if (($# >= 2)); then
        lsar -p "$2" -- "$archive"
    else
        lsar -- "$archive"
    fi
}

unar_validate_password() {
    local archive=$1
    local password=$2
    local log_file=$3

    # JSON listings expose encrypted metadata but do not decrypt file data for
    # every format. Test only password-protected archives to verify the input.
    lsar -t -p "$password" -- "$archive" > "$log_file" 2>&1
}

unar_json_encryption_status() {
    python3 "$UNAR_SCRIPT_DIR/unar-preview.py" --check-encrypted < "$1"
}

unar_json_is_valid() {
    local status

    unar_json_encryption_status "$1" >/dev/null 2>&1
    status=$?

    [[ $status -eq 0 || $status -eq 1 ]]
}

unar_show_error() {
    local message=$1

    if command -v kdialog >/dev/null 2>&1; then
        kdialog --error "$message" >/dev/null 2>&1 || true
    else
        printf '%s\n' "$message" >&2
    fi
}

unar_show_success() {
    local message=$1

    if command -v kdialog >/dev/null 2>&1; then
        kdialog --passivepopup "$message" 3 >/dev/null 2>&1 || true
    fi
}

unar_remove() {
    local path="${1:-}"

    [[ -n $path ]] || return 0

    if [[ -e $path || -L $path ]]; then
        if command -v remove-without-permission >/dev/null 2>&1; then
            remove-without-permission -rf -- "$path" >/dev/null 2>&1 || true
        else
            # Keep the module usable outside this NixOS setup without calling
            # the interactive rm wrapper directly.
            python3 - "$path" <<'PY' >/dev/null 2>&1 || true
import os
import shutil
import sys

path = sys.argv[1]
if os.path.isdir(path) and not os.path.islink(path):
    shutil.rmtree(path)
else:
    os.unlink(path)
PY
        fi
    fi
}
