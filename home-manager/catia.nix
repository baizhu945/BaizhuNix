# CATIA V5 R20 (B20) —— 使用 home-manager 的声明式安装（Wine）
#
# 安装内容全部从原始安装介质推导，不使用 Windows 图形安装器：
#   * 安装树：cabextract 解包 WIN64/ 下全部 1376 个机柜包（全量安装，104,799 个文件）
#     + 安装器生成的 16 个派生文件 → 与官方安装器输出逐字节一致（已全量比对验证）。
#   * 破解：用「破解文件/JS0GROUP.dll」覆盖 win_b64/code/bin/JS0GROUP.dll。
#     逆向确认：该 DLL 相对原版仅 44 字节差异、涉及 21 个函数——多处 `jz/jnz`
#     被改为 `jmp`，若干许可校验函数被改写为 `xor eax,eax; ret`（恒返回 0），
#     因此全部产品/配置许可证在本地可用。
#   * Wine 前缀：完全按官方安装器的步骤搭建——
#       wineboot → 软链安装树 → setcatenv 生成环境文件
#       → 介质自带 MSI 安装 VC8 运行时与 VBA 运行时
#       → V5RegServer.exe 注册全部 COM 组件（等于安装器的注册阶段）
#   * 许可证：Licensing.CATSettings 由 CATIA 自己写出（153 个产品/配置全部勾选，
#     逆向出该 CATSettings 格式：`LICDEB_<名>` 属性第二值非空即已勾选），
#     首次安装时植入用户 CATSettings 目录，新前缀首次启动即为全功能状态。
#
# 固定输入（均在 /home/<yourusername>/Documents/Reproduce/CATIA/ 下）：
#   安装包/                     官方安装介质（1376 个机柜包 + VBA + 前置 MSI）
#   破解文件/JS0GROUP.dll        破解补丁
#   Licensing.CATSettings       CATIA 写出的“全部许可勾选”清单（作为默认设置植入）
#   PCFG.list / CAFPost.list / PRESENT / orbix/   安装器生成的派生文件，见 README.md
#   catia.png                   桌面图标（由安装树内 DS.ico 转换）
#
# 常用命令：`catia` 启动；`catia-setup` 幂等重跑安装（前缀缺失时自动重建）。
{ config, pkgs, lib, ... }:

let
  wine = pkgs.wineWow64Packages.stagingFull; # 与系统 wine 一致（wine 11.x staging）

  homeDir = config.home.homeDirectory;
  userName = config.home.username;

  envName = "CATIA.V5R20.B20";
  b20Dir = "C:\\Program Files\\Dassault Systemes\\B20";
  b20Bin = "${b20Dir}\\win_b64\\code\\bin";
  envDir = "C:\\ProgramData\\DassaultSystemes\\CATEnv";

  prefixDir = "${homeDir}/.local/share/catia/prefix";

  # Wine 的基准 DPI 为 96；144 DPI 对应 1.5 倍界面缩放。
  catiaScale = "1.5";
  catiaDpi = 144;

  # ---- 固定输入：安装介质 + 破解文件 + 安装器派生数据 ----------------------
  # 带 sha256：Nix 直接用已知哈希定位 store 路径，不再每次求值重新哈希介质。
  mediaSrc = builtins.path {
    path = "/home/<yourusername>/Documents/Reproduce/CATIA/安装包";
    name = "catia-v5r20-media";
    sha256 = "sha256:12zidmi5sjgpz0055qd9c7wsqwwp3wgqzf37pwcp3k4yfmjlggv4";
  };
  crackSrc = builtins.path {
    path = "/home/<yourusername>/Documents/Reproduce/CATIA/破解文件";
    name = "catia-v5r20-crack";
    sha256 = "sha256:1q0jf61n93sppvh2aim5j27a80mqvcarpd9k2w8m99y0hkp95j2g";
  };
  dataPcfg = /home/<yourusername>/Documents/Reproduce/CATIA/PCFG.list;
  dataCafPost = /home/<yourusername>/Documents/Reproduce/CATIA/CAFPost.list;
  dataPresent = /home/<yourusername>/Documents/Reproduce/CATIA/PRESENT;
  dataOrbix = /home/<yourusername>/Documents/Reproduce/CATIA/orbix;
  dataLicensing = /home/<yourusername>/Documents/Reproduce/CATIA/Licensing.CATSettings;
  dataIcon = /home/<yourusername>/Documents/Reproduce/CATIA/catia.png;

  # ---- 1. 完整安装树（B20）-------------------------------------------------
  # 与官方安装器产生的目录逐字节比对通过：104,799 个文件来自介质机柜包，
  # 另有 16 个安装器生成的派生文件在此复现（含 CORBARuntime 的 post-install 追加行）。
  catiaTree = pkgs.stdenv.mkDerivation {
    name = "catia-v5r20-b20";
    src = mediaSrc;
    crack = crackSrc;
    inherit dataPcfg dataCafPost dataPresent dataOrbix;
    nativeBuildInputs = [ pkgs.cabextract ];
    dontPatch = true;
    dontFixup = true;
    buildCommand = ''
      mkdir -p "$out"

      # (1) 找出全部机柜包（cab 魔数 MSCF）
      : > cablist
      for f in "$src"/WIN64/*; do
        [ -f "$f" ] || continue
        magic=$(dd if="$f" bs=1 count=4 2>/dev/null | tr -d '\000')
        [ "$magic" = MSCF ] && printf '%s\0' "$f" >> cablist
      done

      # (2) 解包全部机柜包：cab 内成员路径自带 win_b64/ 前缀，解包到 $out 即为安装树。
      #     跑两遍：第二遍补齐并发建目录时可能漏掉的极少数文件（cabextract 默认跳过已存在文件）。
      for pass in 1 2; do
        xargs -0 -r -n1 -P "''${NIX_BUILD_CORES:-8}" cabextract -q -d "$out" < cablist || true
      done

      # 完整性不变量：介质中全部产品包合计 104,799 个文件
      n=$(find "$out" -type f | wc -l)
      if [ "$n" -ne 104799 ]; then
        echo "解包文件数异常：$n（预期 104799）" >&2
        exit 1
      fi

      # (3) 安装器安装结束时生成的少量文件（原样取自官方安装器的输出，见 README.md）
      install -Dm644 "$dataPcfg"    "$out/win_b64/control/PCFG.list"
      install -Dm644 "$dataCafPost" "$out/win_b64/control/CAFPost.list"
      install -Dm644 "$dataPresent" "$out/win_b64/control/PRESENT"
      install -Dm644 "$src/OSNT"    "$out/OSNT"

      install -Dm644 "$dataOrbix/iona.cfg" "$out/win_b64/startup/orbix/iona.cfg"
      for f in common orbix3 orbixnames3 orbixweb3; do
        install -Dm644 "$dataOrbix/config/$f.cfg" "$out/win_b64/startup/orbix/config/$f.cfg"
      done
      install -Dm644 "$dataOrbix/config/Repositories/ImpRep/CATIAServerManager.IMP" \
        "$out/win_b64/startup/orbix/config/Repositories/ImpRep/CATIAServerManager.IMP"

      # (4) 安装参数相关的文本文件（CRLF 行尾，与官方安装器一致）
      printf '%s\r\n' 'C:\ProgramData\DassaultSystemes\CATEnv' > "$out/win_b64/EnvDir.txt"
      printf '%s\r\n' '${envName}' > "$out/win_b64/EnvName.txt"
      printf '%s\r\n' '${envName}' > "$out/win_b64/CATIA.lp"
      printf '%s\r\n\r\n' 'IT_DAEMON_PORT=1570' > "$out/win_b64/docs/java/OrbixPort.properties"

      # (5) 卸载脚本（安装器按安装路径与用户名生成）
      cat > "$out/win_b64/Uninstall.bat" <<'BAT'
@echo off
SET DS_UNINSTALL_BATCH=YES
if exist "C:\Program Files\Dassault Systemes\B20\EndBatch" del "C:\Program Files\Dassault Systemes\B20\EndBatch"
if exist "C:\Program Files\Dassault Systemes\B20\ErrorBatch" del "C:\Program Files\Dassault Systemes\B20\ErrorBatch"
"C:\Program Files\Dassault Systemes\B20\win_b64\code\bin\Uninstall.exe" "C:\Program Files\Dassault Systemes\B20" "CODE" "GUI" "B20" "0"
:wait
if  exist "C:\Program Files\Dassault Systemes\B20\ErrorBatch" goto error
if not exist "C:\Program Files\Dassault Systemes\B20\EndBatch" goto wait
goto end
:error
@echo Uninstall failed : see  C:\users\USERNAME\AppData\Local\Temp\cxinst.log
if exist "C:\Program Files\Dassault Systemes\B20\ErrorBatch" del "C:\Program Files\Dassault Systemes\B20\ErrorBatch"
goto exit
:end
del /Q  "C:\Program Files\Dassault Systemes\B20\win_b64\code\bin\Uninstall.exe" 2>nul
rmdir /Q /S "C:\Program Files\Dassault Systemes\B20" 2>nul
@echo End of uninstall
:exit
BAT
      sed -i "s/USERNAME/${userName}/g; s/\$/\r/" "$out/win_b64/Uninstall.bat"

      cat > "$out/DSUninstall.bat" <<'BAT'
@echo Uninstall is running ..
@echo off
if exist "C:\users\USERNAME\AppData\Local\Temp\Uninstall.bat" del "C:\users\USERNAME\AppData\Local\Temp\Uninstall.bat"
Move "C:\Program Files\Dassault Systemes\B20\win_b64\Uninstall.bat"  "C:\users\USERNAME\AppData\Local\Temp\Uninstall.bat" 1>nul 2>nul
"C:\users\USERNAME\AppData\Local\Temp\Uninstall.bat" 2>nul
BAT
      sed -i "s/USERNAME/${userName}/g; s/\$/\r/" "$out/DSUninstall.bat"

      # (6) CORBA 运行时清单：官方安装器 post-install 追加了下列 6 行
      for l in \
        '.\win_b64\startup\orbix\iona.cfg' \
        '.\win_b64\startup\orbix\config\common.cfg' \
        '.\win_b64\startup\orbix\config\orbix3.cfg' \
        '.\win_b64\startup\orbix\config\orbixnames3.cfg' \
        '.\win_b64\startup\orbix\config\orbixweb3.cfg' \
        '.\win_b64/docs/java/OrbixPort.properties'
      do
        printf '%s\r\n' "$l" >> "$out/win_b64/control/CORBARuntime"
      done

      # (7) 破解：替换 JS0GROUP.dll（21 处许可校验补丁，全部产品/配置可用）
      install -Dm755 "$crack/JS0GROUP.dll" "$out/win_b64/code/bin/JS0GROUP.dll"
    '';
  };

  # ---- 2. 前缀安装所需 MSI（介质自带：VC8 运行时 / VBA 运行时）-------------
  setupMedia = pkgs.stdenv.mkDerivation {
    name = "catia-v5r20-setup-media";
    src = mediaSrc;
    dontPatch = true;
    dontFixup = true;
    buildCommand = ''
      mkdir -p "$out"
      cp -r "$src/VBA" "$out/VBA"
      cp "$src/WIN64/InstallDSSoftwarePrerequisites_x86_x64.msi" "$out/"
    '';
  };

  # ---- 3. 前缀安装脚本（幂等；等价于官方安装器的安装步骤）-----------------
  catiaSetup = pkgs.writeShellApplication {
    name = "catia-setup";
    runtimeInputs = [ wine pkgs.coreutils ];
    text = ''
      export WINEPREFIX="''${WINEPREFIX:-${prefixDir}}"
      export WINEDEBUG=-all
      export WINEDLLOVERRIDES="mscoree,mshtml="
      export DISPLAY="''${DISPLAY:-:0}"

      B20='${b20Dir}'
      BIN="$B20\\win_b64\\code\\bin"
      ENVDIR='${envDir}'
      STATE="$WINEPREFIX/.catia-state"
      WANT='${catiaTree}-${envName}-v1'

      log() { printf '[catia] %s\n' "$*"; }

      # (0) Wine 前缀
      if [ ! -e "$WINEPREFIX/.catia-prefix" ]; then
        log "创建 Wine 前缀：$WINEPREFIX"
        mkdir -p "$WINEPREFIX"
        wineboot -i >/dev/null 2>&1 || true
        touch "$WINEPREFIX/.catia-prefix"
      fi

      # (1) 安装树（store 内只读，直接软链进前缀）
      mkdir -p "$WINEPREFIX/drive_c/Program Files/Dassault Systemes"
      ln -sfn '${catiaTree}' "$WINEPREFIX/drive_c/Program Files/Dassault Systemes/B20"

      # (2) 运行参数（图形驱动 / DPI）：只在值变化时写注册表。
      #     正常情况只需读一个标记文件，不再每次 switch/启动都起两个 wine 进程。
      #     Graphics=x11 强制 XWayland，避开 Wine Wayland 驱动下的 CATIA 黑屏；
      #     LogPixels 是 winecfg 的 DPI；96 × ${catiaScale} = ${toString catiaDpi}。
      ensure_wine_reg() {
        description="$1"
        shift
        for _ in 1 2 3; do
          if wine reg add "$@" /f >/dev/null 2>&1; then
            log "$description"
            return 0
          fi
          sleep 1
        done
        log "提示：未能写入 $description；将保留 Wine 当前设置"
        return 0
      }

      RUNCFG="$WINEPREFIX/.catia-runcfg"
      RUNCFG_WANT="x11-${toString catiaDpi}"
      if [ "$(cat "$RUNCFG" 2>/dev/null || true)" != "$RUNCFG_WANT" ]; then
        ensure_wine_reg "图形驱动：X11（XWayland）" \
          'HKCU\Software\Wine\Drivers' /v Graphics /t REG_SZ /d x11
        ensure_wine_reg "界面缩放：${catiaScale} 倍（${toString catiaDpi} DPI）" \
          'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d '${toString catiaDpi}'
        echo "$RUNCFG_WANT" > "$RUNCFG"
      fi

      if [ "$(cat "$STATE" 2>/dev/null || true)" = "$WANT" ]; then
        log "已安装（$WANT）"
        exit 0
      fi

      # (3) 环境文件 + “开始”菜单项（官方 setcatenv 工具）
      log "生成 CATIA 环境（setcatenv）"
      mkdir -p "$WINEPREFIX/drive_c/ProgramData/DassaultSystemes/CATEnv"
      wine "$BIN\\setcatenv.exe" -a global -d "$ENVDIR" -e '${envName}' -p "$B20" \
        -new yes -icon yes -menu yes -i yes -tools || log "setcatenv 返回 $?"

      # (4) VC8 运行时 + VBA 运行时（介质自带 MSI）
      if [ ! -e "$WINEPREFIX/.catia-msi" ]; then
        log "安装 VC8 运行时与 VBA 运行时（MSI）"
        for m in \
          '${setupMedia}/InstallDSSoftwarePrerequisites_x86_x64.msi' \
          '${setupMedia}/VBA/vba6.msi' \
          '${setupMedia}/VBA/VBAOF11.MSI' \
          '${setupMedia}/VBA/1033/VBAOF11I.MSI'
        do
          zpath=$(winepath -w "$m")
          wine msiexec /qn /i "$zpath" || log "MSI 返回 $?：$m"
        done
        touch "$WINEPREFIX/.catia-msi"
      fi

      # (5) COM 注册（V5RegServer 注册全部已安装组件，等价于安装器的注册阶段）
      log "注册 CATIA COM 组件（V5RegServer）"
      wine "$BIN\\V5RegServer.exe" -set CATIA -env '${envName}' -direnv "$ENVDIR" \
        || log "V5RegServer 返回 $?"

      # (6) 安装记录（与安装器一致）
      wine reg add 'HKLM\Software\Dassault Systemes\B20\0' /v DEST_FOLDER /t REG_SZ \
        /d "$B20" /f >/dev/null 2>&1 || true
      wine reg add 'HKLM\Software\Dassault Systemes\B20\0' /v DEST_FOLDER_OSDS /t REG_SZ \
        /d "$B20\\win_b64" /f >/dev/null 2>&1 || true

      # (7) 许可证：植入“全部启用”清单（不覆盖用户已有设置）
      SETTINGS="$WINEPREFIX/drive_c/users/${userName}/AppData/Roaming/DassaultSystemes/CATSettings"
      mkdir -p "$SETTINGS"
      if [ ! -e "$SETTINGS/Licensing.CATSettings" ]; then
        log "植入许可证清单（153 个产品/配置全部启用）"
        install -m644 '${dataLicensing}' "$SETTINGS/Licensing.CATSettings"
      fi

      echo "$WANT" > "$STATE"
      log "完成"
    '';
  };

  # ---- 4. 启动器 -----------------------------------------------------------
  # CATIA 继续使用 Wine X11 驱动（XWayland）；catia-setup 会在每次启动前把
  # Wine DPI 校正为 144（1.5 倍），无需依赖全局桌面缩放或原生 Wayland 驱动。
  catiaLauncher = pkgs.writeShellApplication {
    name = "catia";
    runtimeInputs = [ wine catiaSetup pkgs.coreutils ];
    text = ''
      export WINEPREFIX='${prefixDir}'
      export WINEDEBUG=-all
      export WINEDLLOVERRIDES="mscoree,mshtml="
      export DISPLAY="''${DISPLAY:-:0}"
      catia-setup >/dev/null 2>&1 || true
      exec wine '${b20Bin}\CNEXT.exe' -env '${envName}' -direnv '${envDir}' "$@"
    '';
  };

in
{
  home.packages = [ catiaLauncher catiaSetup ];

  # 首次 `home-manager switch` 即完成安装；后续命中标记后立即返回
  home.activation.catia = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${catiaSetup}/bin/catia-setup
  '';

  # 桌面入口（直接写文件，避免依赖 xdg.enable；Exec 用启动器的 store 路径）
  home.file = {
    ".local/share/applications/catia.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Version=1.0
      Name=CATIA V5R20
      GenericName=CAD/CAM/CAE
      Comment=CATIA V5 R20（Wine，全功能）
      Exec=${catiaLauncher}/bin/catia %F
      Icon=catia
      Terminal=false
      Categories=Graphics;Engineering;Science;
      StartupNotify=true
      StartupWMClass=CATIA V5
      MimeType=application/x-wine-extension-catpart;application/x-wine-extension-catproduct;application/x-wine-extension-catdrawing;application/x-wine-extension-catcatalog;application/x-wine-extension-catmaterial;application/x-wine-extension-catprocess;application/x-wine-extension-catshape;application/x-wine-extension-catscript;application/x-wine-extension-catanalysis;
    '';
    ".local/share/icons/hicolor/256x256/apps/catia.png".source = dataIcon;
  };
}
