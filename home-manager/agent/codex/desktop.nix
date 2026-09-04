{ pkgs, lib, ... }:

let
  # The official Linux package currently uses a `latest` URL.  Keep the
  # extracted package version and fixed-output hash together so the result is
  # reproducible even if that URL is replaced upstream.
  version = "26.818.61809";
  src = pkgs.fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    hash = "sha256-QqZHfyL0E21iMh7ae0aXp52h62bWHcuFqwQghgoaUiM=";
  };

  chatgpt-desktop = pkgs.stdenv.mkDerivation {
    pname = "chatgpt-desktop";
    inherit version src;

    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      binutils
      makeWrapper
      xz
    ];

    # The .deb declares these as Debian runtime dependencies.  NixOS does not
    # provide a global /usr/lib, so autoPatchelfHook makes the bundled ELF and
    # native Node modules refer to these store paths instead.
    buildInputs = with pkgs; [
      alsa-lib
      atk
      at-spi2-atk
      at-spi2-core
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libglvnd
      libnotify
      libpulseaudio
      libsecret
      libusb1
      libxkbcommon
      libxshmfence
      mesa
      nspr
      nss
      pango
      systemd
      vulkan-loader
      wayland
      libx11
      libxcb
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxscrnsaver
      libxtst
    ];

    # The package ships both Qt5 and Qt6 shims.  Keep these as runtime
    # dependencies rather than buildInputs: nixpkgs intentionally rejects
    # mixing the two Qt setup hooks in one derivation.
    runtimeDependencies = [
      pkgs.qt5.qtbase.out
      pkgs.qt6.qtbase
    ];

    # The package carries unused musl prebuilds alongside the glibc ones.
    autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

    preFixup = ''
      # Qt5 is a multi-output package; its default `bin` output does not
      # contain the shared libraries needed by libqt5_shim.so.
      addAutoPatchelfSearchPath "${pkgs.qt5.qtbase.out}/lib"
      addAutoPatchelfSearchPath "${pkgs.qt6.qtbase}/lib"
    '';

    unpackPhase = ''
      runHook preUnpack
      mkdir source
      cd source
      ar x "$src"
      tar -xJf data.tar.xz
      cd ..
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -dm755 "$out/libexec" "$out/share/applications" "$out/share/pixmaps"
      cp -a source/usr/lib/chatgpt "$out/libexec/chatgpt"
      install -Dm644 source/usr/share/applications/chatgpt.desktop \
        "$out/share/applications/chatgpt.desktop"
      install -Dm644 source/usr/share/pixmaps/chatgpt.png \
        "$out/share/pixmaps/chatgpt.png"

      # The Debian launcher only resolves the adjacent ChatGPT binary.  A Nix
      # wrapper additionally exposes commands used by local-file/Codex flows.
      makeWrapper "$out/libexec/chatgpt/ChatGPT" "$out/bin/chatgpt" \
        --run '
          # Do not let a desktop launched from a Codex/IDE terminal inherit
          # the calling agent session.  Those variables bind the bundled
          # app-server to the calling user thread and its sandbox
          # permissions.
          unset CODEX_CI CODEX_SESSION_ID CODEX_THREAD_ID

          cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}"
          runtime_root="$cache_root/chatgpt-desktop/${version}-nix/bundled-resources"
          source_root="'$out'/libexec/chatgpt/resources"

          # Nix store files are read-only.  The desktop app materializes its
          # bundled plugins into CODEX_HOME and preserves source permissions,
          # so give it a writable, versioned copy before starting it.
          if [ ! -f "$runtime_root/.complete" ] \
            || [ ! -d "$runtime_root/plugins/openai-bundled" ] \
            || [ ! -e "$runtime_root/codex" ] \
            || [ ! -e "$runtime_root/cua_node/bin/node" ] \
            || [ ! -e "$runtime_root/cua_node/bin/node_repl" ]; then
            mkdir -p "$(dirname "$runtime_root")"
            staging_root="$(mktemp -d "$(dirname "$runtime_root")/.bundled-resources.XXXXXX")"
            mkdir -p "$staging_root/plugins"
            cp -R --no-preserve=mode,ownership \
              "$source_root/plugins/openai-bundled" "$staging_root/plugins/"
            chmod -R u+rwX,go+rX "$staging_root/plugins/openai-bundled"
            ln -s "$source_root/codex" "$staging_root/codex"
            ln -s "$source_root/codex-code-mode-host" "$staging_root/codex-code-mode-host"
            ln -s "$source_root/cua_node" "$staging_root/cua_node"
            ln -s "$source_root/rg" "$staging_root/rg"
            touch "$staging_root/.complete"
            if [ ! -e "$runtime_root" ]; then
              mv "$staging_root" "$runtime_root"
            fi
          fi

          if [ -d "$runtime_root/plugins/openai-bundled" ] \
            && [ -e "$runtime_root/codex" ] \
            && [ -e "$runtime_root/cua_node/bin/node" ]; then
            export CODEX_ELECTRON_BUNDLED_PLUGINS_RESOURCES_PATH="$runtime_root"
          fi
        ' \
        --prefix PATH : "${lib.makeBinPath [ pkgs.coreutils pkgs.git pkgs.glib pkgs.xdg-utils ]}"
      runHook postInstall
    '';

    meta = {
      description = "ChatGPT desktop application with Codex support";
      homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
      license = lib.licenses.unfree;
      mainProgram = "chatgpt";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  home.packages = [ chatgpt-desktop ];
}
