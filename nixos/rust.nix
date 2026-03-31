{ config, pkgs, ... }:

let
  rust_overlay = import (builtins.fetchTarball "https://github.com/oxalica/rust-overlay/archive/master.tar.gz");
  
  nixpkgs_with_rust = import pkgs.path {
    overlays = [ rust_overlay ];
    inherit (pkgs) "stdenv.hostPlatform.system";
  };

  # 定义你想要的工具链（替代 rust-toolchain.toml 的功能）
  # 可以在这里精确控制版本和组件
  my_rust_toolchain = nixpkgs_with_rust.rust-bin.stable.latest.default.override {
    extensions = [ "rust-src" "rust-analyzer" "clippy" ];
  };
in
{
  environment.systemPackages = [
    my_rust_toolchain  # 这一个包就包含了 rustc, cargo, clippy 等所有东西
    pkgs.rustPlatform.bindgenHook
    pkgs.pkg-config
    pkgs.openssl
    pkgs.gcc
  ];

  # 只需要保留 cargo home 的 bin（用于安装本地工具）
  environment.interactiveShellInit = ''
    export PATH="$HOME/.cargo/bin:$PATH"
  '';

  # 如果需要 bindgen
  environment.variables = {
    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
  };
}
