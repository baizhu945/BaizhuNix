#!/usr/bin/env bash
# hermes wrapper —— desktop 子命令直接启动 Hermes Desktop GUI
#
# 背景：hermes 的 cmd_gui（`hermes desktop`）在启动前检查 Electron 的 setuid
# chrome-sandbox（要求 uid==0 且 4755）。nix store 无法创建 setuid 文件
# （nix 沙盒禁止 chmod +s），fixup 失败后 cmd_gui 直接 sys.exit(1)，导致
# `hermes desktop` 与桌面启动器都无法启动 GUI。
#
# 这里把 desktop 子命令路由到 nixpkgs electron 直接加载 renderer，
# 绕过该检查（electron 用自身的 sandbox helper，安全性不变）。
# 其余参数照常转发给真正的 hermes CLI（.hermes-real）。
if [[ "${1:-}" == "desktop" ]]; then
  shift
  export HERMES_DESKTOP_HERMES="@HERMES@"
  export HERMES_DESKTOP_CWD="${HERMES_DESKTOP_CWD:-$PWD}"
  exec "@ELECTRON@" "@APPDIR@" "$@"
fi
exec "@REAL@" "$@"
