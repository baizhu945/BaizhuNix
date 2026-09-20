# acm-ctl -- the ACM-equivalent display colour management tool.
#
# Builds the colour engine that was verified against Microsoft's own ACM
# implementation (../docs/ in the acm-re research project) together with the
# Linux appliers (KMS atomic + Wayland gamma-control).
{ pkgs ? import <nixpkgs> { }
, enginePath ? /home/<yourusername>/Code/acm-re/src
, linuxPath ? /home/<yourusername>/Code/acm-re/linux
}:

let
  lib = pkgs.lib;
  # Pin both source trees with content hashes; skip generated build dirs so the
  # derivation is reproducible from the declarative sources alone.
  engineSrc = builtins.path {
    path = enginePath;
    name = "src";
    filter = p: t: !(lib.hasInfix "build" (baseNameOf p));
  };
  linuxSrc = builtins.path {
    path = linuxPath;
    name = "linux";
    filter = p: t: !(lib.hasInfix "build" (baseNameOf p));
  };
in
pkgs.stdenv.mkDerivation {
  pname = "acm-ctl";
  version = "1.0";

  # the CMake project is the Linux applier tree; the colour engine is referenced
  # directly from its own pinned store path
  src = linuxSrc;

  nativeBuildInputs = with pkgs; [ cmake pkg-config wayland-scanner ];
  buildInputs = with pkgs; [ libdrm wayland wlr-protocols ];

  # build-time verification: the CMake test suite runs as part of the derivation
  doCheck = true;

  cmakeFlags = [
    "-DENGINE_DIR=${engineSrc}"
    "-DACMLIN_WLR_GAMMA_XML=${pkgs.wlr-protocols}/share/wlr-protocols/unstable/wlr-gamma-control-unstable-v1.xml"
  ];

  meta = with lib; {
    description = "ACM-equivalent automatic colour management for Linux (KMS + Wayland gamma-control)";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "acm-ctl";
  };
}
