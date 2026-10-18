# aptX Adaptive source for the Sennheiser MOMENTUM 5.
#
# Two pieces make up the working setup, and neither depends on a local working
# directory any more:
#
#  1. the encoder plugin.  It is this account's fork of theacrat/aptx-linux's
#     clean-room SPA codec (upstream is read-only, so the two fixes live in the
#     fork: SPA codec ABI 17 for PipeWire 1.7, and the alternate 44.1 kHz rate
#     bit plus 44.1 kHz on 2.2 sinks).  The system module
#     (/etc/nixos/pipewire-aptx-adaptive-module.nix) builds it and installs it
#     into PipeWire's bluez5 codec directory.  Nothing points SPA_PLUGIN_DIR at a
#     user directory: a store path in that variable replaces PipeWire's whole
#     plugin search path and goes stale on every system rebuild.
#
#  2. the WirePlumber guard (vendored next to this file) and `ad-ctl`, declared
#     below.
#
# Modes: hq = 427 kbps / 12 ms with ABR (204k/25 ms -> 427k/12 ms), ll = 270
# kbps / 10 ms.  Verified on air as SSRC 0xA3 with 668-byte packets for HQ and
# SSRC 0xA1 with 360-byte packets for Low latency.  A fresh connection starts
# in APTX_ADAPTIVE_DEFAULT_MODE (hq, set by the system module); `ad-ctl switch`
# only changes the running link.
#
# Sample rates: 44100, 48000 and 96000 Hz are all reachable (44.1 kHz needs the
# fork's rate fix; 96 kHz is HQ only, measured at 8 ms / 616-646 kbps).
#
# Switching the rate never reconnects the headset.  Two pieces make that work:
#
#  1. the fork reads the wanted rate from $XDG_RUNTIME_DIR/aptx-adaptive-rate on
#     every codec configuration (commit 889aab3), so no WirePlumber restart is
#     needed - a restart is what used to drop the Bluetooth link;
#  2. `ad-ctl` bounces the A2DP profile through another codec
#     (a2dp-sink-sbc -> a2dp-sink, PROFILE_SETTLE apart) to force a fresh AVDTP
#     SetConfiguration on the existing connection.  Cycling through "off" does
#     *not* renegotiate anything: BlueZ keeps the running configuration, which is
#     why earlier attempts appeared to do nothing.
#
# Measured after the change: 5-6 s per switch, zero HCI Disconnect/Connect
# events, headset Connected throughout; our configuration element carries the
# expected rate byte (0x12 = 48 kHz, 0x42 = 44.1 kHz, 0x22 = 96 kHz).
#
# Policy by mode: HQ follows the playing source (watcher below), low latency
# pins 48000 because the encoder refuses LL above 48 kHz.  `ad-ctl rate <hz>`
# pins explicitly, `ad-ctl rate auto` hands it back to the watcher, and
# `ad-ctl recover` is the heavy path (profile cycle, service restart, reconnect)
# for a link that is stuck on the hands-free profile.
{ pkgs, lib, ... }:

let
  watchEnable = false;

  ad-ctl = pkgs.writeShellApplication {
    name = "ad-ctl";
    runtimeInputs = with pkgs; [
      pipewire    # pw-cli, pw-dump
      wireplumber # wpctl
      bluez       # hciconfig, bluetoothctl
      procps      # pgrep
      util-linux  # flock
      python3
    ];
    text = builtins.readFile ./ad-ctl.sh;
  };
in
{
  home.packages = [ ad-ctl ];

  # The mode carries the rate policy: HQ follows the sample rate of whatever is
  # playing, low latency pins the link at 48 kHz (the encoder refuses LL above
  # it).  The watcher only acts while `ad-ctl rate` is in "auto" mode - and
  # `ad-ctl switch hq` puts it there, `ad-ctl switch ll` pins 48000 - so an
  # explicit `ad-ctl rate <hz>` always wins.
  #
  # Each change re-establishes the A2DP transport, which interrupts audio for a
  # few seconds; the watcher waits for a stable target and then holds off for
  # ~20 s before acting again.
  #
  # The watcher drives the same codec bounce the manual path uses: measured at
  # 5-6 s per change with zero HCI disconnect events, so the headset stays
  # connected while the link follows the source.
  systemd.user.services.aptx-adaptive-rate-watch = lib.mkIf watchEnable {
    Unit = {
      Description = "aptX Adaptive: follow the playing stream's sample rate";
      After = [ "pipewire.service" "wireplumber.service" ];
      PartOf = [ "pipewire.service" ];
    };
    Service = {
      ExecStart = "${ad-ctl}/bin/ad-ctl watch";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  home.file = {
    # The guard is part of the plugin's aptx-slot design
    # (theacrat/aptx-linux docs/adr/0004-aptx-slot.md): our entries share the
    # aptX HD and aptX codec ids, so a headset that configures the real aptX HD
    # endpoint itself leaves the card on a profile that looks like ours while
    # aptX HD runs.  The hook notices that and re-selects the profile through
    # "off", which switches the codec to our entry.
    ".local/share/wireplumber/scripts/aptx-linux/aptx-adaptive-guard.lua".source = ./aptx-adaptive-guard.lua;
    ".config/wireplumber/wireplumber.conf.d/90-aptx-adaptive-guard.conf".source = ./90-aptx-adaptive-guard.conf;
  };
}
