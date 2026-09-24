# MATLAB R2024b（Windows 版，113 个产品全量）—— 使用 home-manager 的声明式安装（Wine）
#
# 思路与 catia.nix 一致：安装介质进 Nix store，安装/破解步骤写成幂等脚本，
# 首次 `home-manager switch` 自动完成全部安装，之后命中标记立即返回。
#
# 安装来源与教程（CSDN 152274319）一致，但全部自动化：
#   * 介质：R2024b_Windows/（官方 Windows DVD，Wine 下由安装器正常安装）
#   * 密钥：教程给出的文件安装密钥（FIK）→ 113 个产品（模板中 123 个减去
#     10 个 FIK 不覆盖的：Parallel Server / Polyspace 系列 / DO、IEC 认证套件等）
#   * 许可证：Crack/license.lic（安装器写入 <MWROOT>/licenses/）
#   * 破解：Crack/win64/matlab_startup_plugins/lmgrimpl/libmwlmgrimpl.dll
#     覆盖安装树的同名文件（许可证管理器启动插件），全部产品永久可用
#
# Wine 下官方安装器会漏做的收尾步骤（本模块补齐，否则 MATLAB 只有内置极小路径）：
#   1. toolbox/local/classpath.txt —— Java 类路径。用介质自带 ClassPathGenerator.exe，
#      按 toolbox/local/classpath/*.jcp（287 个）+ toolbox/local/reordered_list 生成。
#   2. toolbox/local/pathdef.m —— MATLAB 搜索路径。用介质自带 perl.exe 运行
#      toolbox/local/getphlpaths.pl（1713 个 .phl 文件 → 2481 条路径），再按
#      toolbox/local/template/pathdef.m 模板生成。缺失时 ver/initdesktoputils 等函数
#      都找不到（表现为“在 matlabrc 中初始化 Java 预加载器失败”）。
#   3. VC 运行时：MATLAB 自带 msvcp140/vcruntime140/concrt140 等；Wine 内置版本
#      缺 std::get_new_handler 等符号（libmx.dll 初始化失败），必须让 Wine 加载自带版本。
#   4. 硬件 OpenGL：Wine 下 MATLAB 的显卡检测（WMI）拿不到数据，启动时回退软件
#      OpenGL，图形里的文字会左右镜像。安装脚本在 MATLAB 用户路径写一个 startup.m
#      （仅在不存在或为本模块生成时），每次启动切回硬件 OpenGL（NVIDIA 硬件 GL 实测可用）。
#   5. 中文字体（最重要的一条）：Wine 前缀默认没有 CJK 字体，而 MATLAB 的 Java(Swing)
#      桌面只枚举 windows\Fonts 目录里的字体（已注册到 Wine 字体注册表但不在该目录的
#      字体它看不到）。因此安装脚本把：
#        * 微软雅黑（界面逻辑字体 Tahoma/MS Shell Dlg → 雅黑）
#        * 真实 Windows 字体 SimSun/SimHei/MS Gothic/MingLiU/Malgun 等（Java 复合字体
#          Monospaced/SansSerif/Serif/Dialog 的中文分段回退就靠这些名字，没有它们
#          命令行窗口的中文会变成方框）
#      链进前缀 windows\Fonts，缺什么字体就提示。Simulink 起始页是 Web(CEF) 渲染，
#      不受此影响（所以它一开始就能显示中文）。
#   6. 界面缩放：与 catia.nix 一致，Wine DPI 设为 144（1.5 倍）。
#   7. 剪贴板：Wine 应用写出的 X11 剪贴板里只有 UTF8_STRING/TEXT 是正确编码，
#      text/plain 与 STRING 是丢字符的副本（中文变问号），也没有 Wayland 应用需要的
#      text/plain;charset=utf-8。本模块额外提供一个用户服务（matlabClipboardFix），
#      剪贴板变化时发现这种不一致就用正确的 UTF-8 文本重新发布一次。
#
# 常用命令：`matlab` 启动图形界面；`matlab -batch "..."` 命令行执行；
#           `matlab-setup` 幂等重装/修复。
{ config, pkgs, lib, ... }:

let
  wine = pkgs.wineWow64Packages.stagingFull; # 与系统 wine 一致（wine 11.x staging）

  homeDir = config.home.homeDirectory;

  prefixDir = "${homeDir}/.local/share/matlab/prefix";
  mwWin = "C:\\MATLAB\\R2024b";

  # ---- 固定输入：Windows 安装介质 + 破解目录 ------------------------------
  # 注：带 sha256 时 Nix 直接用已知哈希定位 store 路径（存在则不再读取源目录），
  #     否则每次求值都要重新哈希 13 GB 介质，home-manager switch 会慢 1–2 分钟。
  #     哈希值 = 该 store 路径的 NAR 哈希（nix-store -q --hash），
  #     介质内容变化时也不会自动跟随（需要手动更新哈希）。
  mediaSrc = builtins.path {
    path = "/home/<yourusername>/Documents/Reproduce/MATLAB R2024b(64bit)/R2024b_Windows";
    name = "matlab-r2024b-windows-dvd";
    sha256 = "sha256:19wqhn0xj96fwc2s23bpgk7k7a7nz61bgx9gjkx1xg9g5sq51nrc";
  };
  crackSrc = builtins.path {
    path = "/home/<yourusername>/Documents/Reproduce/MATLAB R2024b(64bit)/Crack";
    name = "matlab-r2024b-crack";
    sha256 = "sha256:1823bg0nnhxs7y359df15q82qhyh6i1iridg542smdhnrwz200zl";
  };

  # 教程给出的文件安装密钥
  fik = "39676-02743-14813-63132-22122-21739-42724-01237-08353-51560-41813-30272-46436-42021-53831-05395-21684-43572-58789-40638-42099-40160-19797-60670-44428-39867";

  # FIK 覆盖的全部 113 个产品
  products = [
      "5G_Toolbox"
      "AUTOSAR_Blockset"
      "Aerospace_Blockset"
      "Aerospace_Toolbox"
      "Antenna_Toolbox"
      "Audio_Toolbox"
      "Automated_Driving_Toolbox"
      "Bioinformatics_Toolbox"
      "Bluetooth_Toolbox"
      "C2000_Microcontroller_Blockset"
      "Communications_Toolbox"
      "Computer_Vision_Toolbox"
      "Control_System_Toolbox"
      "Curve_Fitting_Toolbox"
      "DDS_Blockset"
      "DSP_HDL_Toolbox"
      "DSP_System_Toolbox"
      "Data_Acquisition_Toolbox"
      "Database_Toolbox"
      "Datafeed_Toolbox"
      "Deep_Learning_HDL_Toolbox"
      "Deep_Learning_Toolbox"
      "Econometrics_Toolbox"
      "Embedded_Coder"
      "Filter_Design_HDL_Coder"
      "Financial_Instruments_Toolbox"
      "Financial_Toolbox"
      "Fixed-Point_Designer"
      "Fuzzy_Logic_Toolbox"
      "GPU_Coder"
      "Global_Optimization_Toolbox"
      "HDL_Coder"
      "HDL_Verifier"
      "Image_Acquisition_Toolbox"
      "Image_Processing_Toolbox"
      "Industrial_Communication_Toolbox"
      "Instrument_Control_Toolbox"
      "LTE_Toolbox"
      "Lidar_Toolbox"
      "MATLAB"
      "MATLAB_Coder"
      "MATLAB_Compiler"
      "MATLAB_Compiler_SDK"
      "MATLAB_Report_Generator"
      "MATLAB_Test"
      "Mapping_Toolbox"
      "Medical_Imaging_Toolbox"
      "Mixed-Signal_Blockset"
      "Model-Based_Calibration_Toolbox"
      "Model_Predictive_Control_Toolbox"
      "Motor_Control_Blockset"
      "Navigation_Toolbox"
      "Optimization_Toolbox"
      "Parallel_Computing_Toolbox"
      "Partial_Differential_Equation_Toolbox"
      "Phased_Array_System_Toolbox"
      "Powertrain_Blockset"
      "Predictive_Maintenance_Toolbox"
      "RF_Blockset"
      "RF_PCB_Toolbox"
      "RF_Toolbox"
      "ROS_Toolbox"
      "Radar_Toolbox"
      "Reinforcement_Learning_Toolbox"
      "Requirements_Toolbox"
      "Risk_Management_Toolbox"
      "Robotics_System_Toolbox"
      "Robust_Control_Toolbox"
      "Satellite_Communications_Toolbox"
      "Sensor_Fusion_and_Tracking_Toolbox"
      "SerDes_Toolbox"
      "Signal_Integrity_Toolbox"
      "Signal_Processing_Toolbox"
      "SimBiology"
      "SimEvents"
      "Simscape"
      "Simscape_Battery"
      "Simscape_Driveline"
      "Simscape_Electrical"
      "Simscape_Fluids"
      "Simscape_Multibody"
      "Simulink"
      "Simulink_3D_Animation"
      "Simulink_Check"
      "Simulink_Code_Inspector"
      "Simulink_Coder"
      "Simulink_Compiler"
      "Simulink_Control_Design"
      "Simulink_Coverage"
      "Simulink_Design_Optimization"
      "Simulink_Design_Verifier"
      "Simulink_Desktop_Real-Time"
      "Simulink_Fault_Analyzer"
      "Simulink_PLC_Coder"
      "Simulink_Real-Time"
      "Simulink_Report_Generator"
      "Simulink_Test"
      "SoC_Blockset"
      "Spreadsheet_Link"
      "Stateflow"
      "Statistics_and_Machine_Learning_Toolbox"
      "Symbolic_Math_Toolbox"
      "System_Composer"
      "System_Identification_Toolbox"
      "Text_Analytics_Toolbox"
      "UAV_Toolbox"
      "Vehicle_Dynamics_Blockset"
      "Vehicle_Network_Toolbox"
      "Vision_HDL_Toolbox"
      "WLAN_Toolbox"
      "Wavelet_Toolbox"
      "Wireless_HDL_Toolbox"
      "Wireless_Testbench"
  ];
  productList = lib.concatStringsSep " " products;

  # 破解后的 libmwlmgrimpl.dll 校验值（防止介质被换）
  crackMd5 = "0473b1a05a20a4d276cf46f52f047269";

  # Wine 的基准 DPI 为 96；144 DPI 对应 1.5 倍界面缩放（与 catia.nix 保持一致）。
  # MATLAB 是 DPI 感知程序（Java + 原生控件均按系统 DPI 缩放）。
  matlabDpi = 144;
  matlabScale = "1.5";

  # ---- 中文字体（Wine 前缀里默认没有 CJK 字体，MATLAB 的 Java 界面会显示方框）----
  #   * Microsoft YaHei（微软雅黑）：Windows 中文系统的界面字体。
  #     Java/Swing 的逻辑字体（Tahoma / MS Shell Dlg …）本身没有中文字形，
  #     只有把 Windows 字体注册表登记完整、再用 Wine 的 Replacements 把逻辑字体
  #     换到雅黑，MATLAB 桌面的中文才能正常显示。
  #   * Noto Sans Mono CJK SC：中文等宽字体，作为命令行窗口/编辑器的代码字体。
  uiFont = "Microsoft YaHei";
  codeFont = "Noto Sans Mono CJK SC";
  # Java 的复合字体（Dialog/SansSerif/Monospaced）按下面的 Windows 字体名取 CJK 字形
  # （见 JRE 的 lib/fontconfig.properties.src），Wine 里这些字体都不存在，
  # 因此命令行窗口的中文会是方框；逐一映射到已安装的 Noto CJK 等宽字体。
  cjkFallbackFonts = {
    "SimSun" = "Noto Sans Mono CJK SC";
    "SimSun-18030" = "Noto Sans Mono CJK SC";
    "SimSun-ExtB" = "Noto Sans Mono CJK SC";
    "MingLiU" = "Noto Sans Mono CJK TC";
    "PMingLiU" = "Noto Sans Mono CJK TC";
    "MingLiU-ExtB" = "Noto Sans Mono CJK TC";
    "PMingLiU-ExtB" = "Noto Sans Mono CJK TC";
    "MS Gothic" = "Noto Sans Mono CJK JP";
    "MS UI Gothic" = "Noto Sans Mono CJK JP";
    "MS Mincho" = "Noto Sans Mono CJK JP";
    "Gulim" = "Noto Sans Mono CJK KR";
    "GulimChe" = "Noto Sans Mono CJK KR";
    "Batang" = "Noto Sans Mono CJK KR";
  };

  # Java 只枚举前缀 windows\Fonts 目录下的字体（已注册到 Wine 字体注册表但不在该目录
  # 的字体，MATLAB 的 Java 界面看不到），所以必须把需要的字体全部链进该目录：
  #   * nixpkgs 提供：微软雅黑（界面）、Noto CJK 等宽（代码）、文泉驿正黑
  #   * 用户字体目录里的真实 Windows 字体：SimSun/MS Gothic/MingLiU/Malgun
  #    （Java 复合字体的 CJK 回退靠 SimSun 等名字，换成 Noto 别名不行）
  wineFonts = pkgs.runCommand "matlab-wine-fonts" { } ''
    mkdir -p "$out"
    cp ${pkgs.vista-fonts-chs}/share/fonts/truetype/msyh.ttf "$out/"
    cp ${pkgs.vista-fonts-chs}/share/fonts/truetype/msyhbd.ttf "$out/"
    cp ${pkgs.noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk/NotoSansMonoCJK-VF.otf.ttc "$out/"
    cp ${pkgs.wqy_zenhei}/share/fonts/truetype/wqy-zenhei.ttc "$out/"
  '';
  userFontDir = "${homeDir}/.local/share/fonts";
  userFonts = [
    "simsun.ttc"
    "simsunb.ttf"
    "simhei.ttf"
    "simkai.ttf"
    "simfang.ttf"
    "msjh.ttc"
    "msgothic.ttc"
    "mingliub.ttc"
    "malgun.ttf"
    "malgunbd.ttf"
  ];
  # ---- 安装脚本（幂等）---------------------------------------------------
  matlabSetup = pkgs.writeShellApplication {
    name = "matlab-setup";
    runtimeInputs = [ wine pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gawk pkgs.gnused ];
    text = ''
      set -o pipefail

      export WINEPREFIX=''${WINEPREFIX:-${prefixDir}}
      export WINEDEBUG=-all
      # MATLAB 自带的 VC 运行时（Wine 内置 msvcp140 缺 std::get_new_handler）
      export WINEDLLOVERRIDES="msvcp140,msvcp140_1,msvcp140_2,msvcp140_atomic_wait,msvcp140_codecvt_ids,vcruntime140,vcruntime140_1,concrt140,vccorlib140=n;mscoree,mshtml="
      export DISPLAY="''${DISPLAY:-:0}"

      MEDIA='${mediaSrc}'
      CRACK='${crackSrc}'
      MWU="$WINEPREFIX/drive_c/MATLAB/R2024b"
      STATE="$WINEPREFIX/.matlab-state"
      READY="$WINEPREFIX/.matlab-prefix"
      WANT='${mediaSrc}-113-products-v1'
      RM='${pkgs.coreutils}/bin/rm'

      log() { printf '[matlab] %s\n' "$*"; }

      # Wine 注册表写入（该 Wine 版本偶发无关 winedbg 异常会让 reg 返回非 0，故重试）
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

      # 硬件 OpenGL：Wine 下 MATLAB 的显卡检测（WMI）拿不到数据，启动时会回退软件
      # OpenGL，导致图形中的文字左右镜像。在 MATLAB 用户路径放 startup.m（每次启动生效）。
      UPATH="$WINEPREFIX/drive_c/users/${config.home.username}"
      STARTUP="$UPATH/Documents/MATLAB/startup.m"
      ensure_startup_m() {
        mkdir -p "$UPATH/Documents/MATLAB"
        if [ ! -e "$STARTUP" ] || grep -q 'matlab.nix' "$STARTUP" 2>/dev/null; then
          cat > "$STARTUP" <<'M'
% 由 matlab.nix 生成：Wine 下强制硬件 OpenGL。
% Wine 里 MATLAB 的显卡检测拿不到数据，默认会回退软件 OpenGL，
% 后果是图形窗口/打印输出中的文字左右镜像。
% opengl hardware 会打印一条弃用警告（MATLAB:opengl:switchRendererDeprecated），
% 是这里主动调用造成的，先关掉再恢复，避免每次启动都弹警告。
if ispc
    try
        warnId = 'MATLAB:opengl:switchRendererDeprecated';
        warning('off', warnId);
        opengl hardware;
        warning('on', warnId);
    catch
    end
end
M
        fi
      }

      # 命令行/编辑器的代码字体：MATLAB 默认用 Java 逻辑字体
      # （codefont=Monospaced、editor=SansSerif），它们的中文分段靠 JRE 里写定的
      # Windows 字体名（SimSun/MingLiU/MS Gothic…）回退，所以把真实 SimSun 等字体
      # 放进前缀 windows\Fonts 即可，无需改动 MATLAB 偏好（实测：
      # Monospaced/SansSerif/Serif/Dialog/DialogInput 全部能显示中文）。

      # 桌面图标：安装树自带的 matlab.ico → PNG
      ICON="${homeDir}/.local/share/icons/hicolor/256x256/apps/matlab.png"
      ensure_icon() {
        [ -e "$MWU/bin/win64/matlab.ico" ] || return 0
        [ -e "$ICON" ] && return 0
        mkdir -p "$(dirname "$ICON")"
        ${pkgs.imagemagick}/bin/magick "$MWU/bin/win64/matlab.ico[0]" -resize 256x256 "$ICON" 2>/dev/null || true
      }

      # (0) Wine 前缀（首次创建；并关闭崩溃对话框，避免偶发 winedbg 阻塞命令）
      if [ ! -e "$READY" ]; then
        log "创建 Wine 前缀：$WINEPREFIX"
        mkdir -p "$WINEPREFIX"
        wineboot -u >/dev/null 2>&1 || true
        for _ in 1 2 3; do
          wine reg add 'HKCU\Software\Wine\WineDbg' /v ShowCrashDialog \
            /t REG_DWORD /d 0 /f >/dev/null 2>&1 && break
          sleep 1
        done
        touch "$READY"
      fi

      # (0.5) 界面缩放：与 catia.nix 一致，Wine DPI 96 × 1.5 = 144。
      #       只在值变化时写注册表（正常情况只读一个标记文件，不起 wine 进程）。
      RUNCFG="$WINEPREFIX/.matlab-runcfg"
      RUNCFG_WANT='${toString matlabDpi}'
      if [ "$(cat "$RUNCFG" 2>/dev/null || true)" != "$RUNCFG_WANT" ]; then
        ensure_wine_reg "界面缩放：${matlabScale} 倍（${toString matlabDpi} DPI）" \
          'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d '${toString matlabDpi}'
        echo "$RUNCFG_WANT" > "$RUNCFG"
      fi

      # (0.6) 中文字体：把 CJK 字体链进前缀的 windows/Fonts，并把 Java 的逻辑字体
      #       （Tahoma / MS Shell Dlg …）映射到微软雅黑，否则桌面中文全是方框。
      FONTS="$WINEPREFIX/drive_c/windows/Fonts"
      FONT_MARK="$WINEPREFIX/.matlab-fonts"
      FONT_WANT='${wineFonts}-${uiFont}-v3'
      if [ "$(cat "$FONT_MARK" 2>/dev/null || true)" != "$FONT_WANT" ]; then
        log "安装中文字体（${uiFont} + ${codeFont} + Windows 字体）"
        mkdir -p "$FONTS"
        for f in '${wineFonts}'/*; do
          ln -sf "$f" "$FONTS/$(basename "$f")"
        done
        # 用户字体目录里的真实 Windows 字体（Java 复合字体的 CJK 回退需要 SimSun 等）
        for n in ${lib.concatStringsSep " " userFonts}; do
          if [ -e '${userFontDir}'/"$n" ]; then
            ln -sf '${userFontDir}'/"$n" "$FONTS/$n"
          else
            log "提示：缺少字体 $n（${userFontDir}）"
          fi
        done
        # Java/Swing 的界面逻辑字体 → 微软雅黑
        for key in 'Tahoma' 'MS Shell Dlg' 'MS Shell Dlg 2' 'MS Sans Serif' 'Segoe UI' 'Arial'; do
          ensure_wine_reg "字体替换：$key → ${uiFont}" \
            'HKCU\Software\Wine\Fonts\Replacements' /v "$key" /t REG_SZ /d '${uiFont}'
        done
        # Java 复合字体的 CJK 分段字体名 → Noto CJK（命令行/编辑器中文）
${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v:
  "        ensure_wine_reg \"字体替换：${k} → ${v}\" 'HKCU\\Software\\Wine\\Fonts\\Replacements' /v '${k}' /t REG_SZ /d '${v}'"
) cjkFallbackFonts)}
        echo "$FONT_WANT" > "$FONT_MARK"
      fi

      # 字体 / 硬件 OpenGL / 图标这几项配置在已安装时也要保持生效
      ensure_startup_m
      ensure_icon

      if [ -x "$MWU/bin/matlab.exe" ] && [ "$(cat "$STATE" 2>/dev/null || true)" = "$WANT" ]; then
        exit 0
      fi

      # (3) 全量安装（约 25 GB，Wine 下约 10-20 分钟）
      #     setup.exe 会先返回（真正的安装在 MathWorksProductInstaller.exe 子进程里继续），
      #     所以用安装日志的结束标记判断完成；已完成的安装阶段用 marker 跳过。
      DONE="$WINEPREFIX/.matlab-install-done"
      LOGFILE="$WINEPREFIX/drive_c/mwinstall.log"
      if [ -x "$MWU/bin/matlab.exe" ] && [ "$(cat "$DONE" 2>/dev/null || true)" = "$WANT" ]; then
        log "安装阶段已完成（跳过）"
      else
        if [ -x "$MWU/bin/matlab.exe" ] && [ -d "$MWU/toolbox/matlab" ] \
           && grep -q 'End - Successful' "$LOGFILE" 2>/dev/null; then
          log "检测到已完成的安装器输出，沿用现有安装（不重装）"
        else
          if [ -d "$MWU" ]; then
            log "清理未完成的安装目录：$MWU"
            "$RM" -rf "$MWU"
          fi
          "$RM" -f "$LOGFILE" 2>/dev/null || true

          # (2) 生成静默安装输入文件（安装密钥 + 许可证文件 + 113 个产品）
          log "生成安装配置（113 个产品）"
          {
            printf 'destinationFolder=C:\\MATLAB\\R2024b\n'
            printf 'fileInstallationKey=%s\n' '${fik}'
            printf 'agreeToLicense=yes\n'
            printf 'outputFile=C:\\mwinstall.log\n'
            printf 'licensePath=%s\n' "$(winepath -w "$CRACK/license.lic")"
            printf 'mode=silent\nenableLNU=no\nimproveMATLAB=no\nsetFileAssoc=false\n'
            printf 'desktopShortcut=false\nstartMenuShortcut=false\ncreateAccelTask=false\n'
            printf 'product.%s\n' ${productList}
          } > "$WINEPREFIX/drive_c/mw_input.txt"

          log "运行 MATLAB 官方安装器（113 个产品，约 25 GB）…"
          ( cd "$MEDIA" && wine setup.exe -inputFile 'C:\mw_input.txt' -mode silent ) \
            >> "$WINEPREFIX/drive_c/mwsetup.log" 2>&1 || true

          # 轮询安装日志，直到出现结束标记（最多 90 分钟），每 60 秒报一次进度
          i=0
          while [ "$i" -lt 540 ]; do
            grep -q -E 'End - (Successful|Unsuccessful)' "$LOGFILE" 2>/dev/null && break
            if [ $((i % 6)) -eq 0 ]; then
              pct=$(grep -a -o -E '[0-9]+%[[:space:]]*$' "$LOGFILE" 2>/dev/null | tail -1 | tr -d '[:space:]')
              log "安装进度：''${pct:-准备中}（已等待 $((i * 10)) 秒）"
            fi
            i=$((i + 1))
            sleep 10
          done

          if ! grep -q 'End - Successful' "$LOGFILE" 2>/dev/null; then
            log "安装失败；日志末尾："
            tail -n 8 "$LOGFILE" 2>/dev/null | sed 's/^/    /' || true
            exit 1
          fi
          log "安装器完成"
        fi
        echo "$WANT" > "$DONE"
      fi

      # (4) 补齐 Java 类路径（Wine 下官方安装器跳过的收尾步骤）
      if [ ! -s "$MWU/toolbox/local/classpath.txt" ]; then
        log "生成 Java 类路径：toolbox/local/classpath.txt"
        find "$MWU/toolbox/local/classpath" -maxdepth 1 -name '*.jcp' -printf '%f\n' | sort \
          | sed 's|^|C:\\MATLAB\\R2024b\\toolbox\\local\\classpath\\|' \
          > "$WINEPREFIX/drive_c/jcplist.txt"
        wine "$MWU/bin/win64/ClassPathGenerator.exe" \
          -jcpList 'C:\jcplist.txt' \
          -reorderList 'C:\MATLAB\R2024b\toolbox\local\reordered_list' \
          -destination 'C:\MATLAB\R2024b\toolbox\local\classpath.txt' \
          -platform win64 || log "ClassPathGenerator 返回 $?"
      fi

      # (5) 补齐搜索路径 pathdef.m（同一个收尾步骤）
      if [ ! -s "$MWU/toolbox/local/pathdef.m" ]; then
        log "生成搜索路径：toolbox/local/pathdef.m"
        wine "$MWU/sys/perl/win32/bin/perl.exe" \
          'C:\MATLAB\R2024b\toolbox\local\getphlpaths.pl' 'C:\MATLAB\R2024b' \
          > "$WINEPREFIX/drive_c/phl.txt" 2>/dev/null || true
        tr ';' '\n' < "$WINEPREFIX/drive_c/phl.txt" | tr -d '\r' \
          | grep -v '^[[:space:]]*$' > "$WINEPREFIX/drive_c/phl-lines.txt"
        entries=$(wc -l < "$WINEPREFIX/drive_c/phl-lines.txt")
        if [ "$entries" -lt 1000 ]; then
          log "路径条目异常（$entries 条），跳过 pathdef.m 生成"
        else
          cat > "$WINEPREFIX/drive_c/gen-pathdef.awk" <<'AWK'
BEGIN { n = 0; while ((getline l < listfile) > 0) if (l != "") e[n++] = l }
/PLEASE FILL IN ONE DIRECTORY PER LINE/ {
  for (i = 0; i < n; i++) printf "        '%s;',...\n", e[i]
  next
}
{ print }
AWK
          awk -v listfile="$WINEPREFIX/drive_c/phl-lines.txt" \
            -f "$WINEPREFIX/drive_c/gen-pathdef.awk" \
            "$MWU/toolbox/local/template/pathdef.m" > "$MWU/toolbox/local/pathdef.m"
          log "搜索路径已写入（$entries 条）"
        fi
      fi

      # (6) 破解：覆盖许可证管理器启动插件
      log "写入破解文件（libmwlmgrimpl.dll）"
      install -m755 "$CRACK/win64/matlab_startup_plugins/lmgrimpl/libmwlmgrimpl.dll" \
        "$MWU/bin/win64/matlab_startup_plugins/lmgrimpl/libmwlmgrimpl.dll"
      got=$(md5sum "$MWU/bin/win64/matlab_startup_plugins/lmgrimpl/libmwlmgrimpl.dll" | cut -d' ' -f1)
      if [ "$got" != "${crackMd5}" ]; then
        log "破解文件校验失败：$got"
        exit 1
      fi

      # (7) 收尾配置：硬件 OpenGL 的 startup.m、桌面图标
      ensure_startup_m
      ensure_icon

      # (10) 验证：MATLAB 能跑、产品数、许可证、计算、图形
      log "验证安装（运行 MATLAB，首次启动会建工具箱缓存）"
      check=$(timeout 1200 wine "$MWU/bin/matlab.exe" -batch "fprintf('MWCHK_VERSION=%s\n', version); fprintf('MWCHK_PRODUCTS=%d\n', numel(ver)); fprintf('MWCHK_LICENSE=%d\n', license('test','MATLAB')); fprintf('MWCHK_MATH=%d\n', 6*7); d=opengl('data'); fprintf('MWCHK_GLHW=%d\n', 1-d.Software); fprintf('MWCHK_VENDOR=%s\n', d.Vendor); f=figure('Visible','off'); surf(peaks); print(f,'-dpng','C:\mwcheck.png'); fprintf('MWCHK_GRAPHICS=1\n')" 2>/dev/null | tr -d '\r') || true
      ok=1
      for marker in 'MWCHK_VERSION=24.2.0.2712019' 'MWCHK_PRODUCTS=113' 'MWCHK_LICENSE=1' 'MWCHK_MATH=42' 'MWCHK_GRAPHICS=1'; do
        if ! printf '%s\n' "$check" | grep -q "^$marker"; then
          log "验证未通过：缺少 $marker"
          ok=0
        fi
      done
      if [ "$ok" != "1" ]; then
        printf '%s\n' "$check" | sed 's/^/    /'
        exit 1
      fi
      if ! printf '%s\n' "$check" | grep -q '^MWCHK_GLHW=1$'; then
        log "提示：MATLAB 当前使用软件 OpenGL（图形文字可能镜像），不影响计算"
      fi

      echo "$WANT" > "$STATE"
      log "完成：$MWU"
    '';
  };

  # ---- 剪贴板修复 ----------------------------------------------------------
  # Wine 应用（MATLAB/Java）写出的 X11 剪贴板里只有 UTF8_STRING/TEXT 是正确编码，
  # text/plain 与 STRING 是丢字符的副本（中文变问号），并且没有 Wayland 应用
  # 需要的 text/plain;charset=utf-8。这个用户服务在剪贴板变化时用正确的 UTF-8
  # 文本补发一次；已带 charset=utf-8 时不做任何事（也就避免了自触发循环）。
  clipboardRepair = pkgs.writeShellApplication {
    name = "matlab-clipboard-repair";
    runtimeInputs = [ pkgs.wl-clipboard pkgs.coreutils ];
    text = ''
      set -uo pipefail
      export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"

      types=$(wl-paste --list-types 2>/dev/null || true)
      case "$types" in
        *'text/plain;charset=utf-8'*) exit 0 ;;
      esac

      text=$(wl-paste --type UTF8_STRING 2>/dev/null) || text=$(wl-paste --type TEXT 2>/dev/null) || exit 0
      [ -n "$text" ] || exit 0
      case "$text" in
        *[!\ -~]*) ;;
        *) exit 0 ;;
      esac

      printf '%s' "$text" | wl-copy --type 'text/plain;charset=utf-8'
    '';
  };

  clipboardWatch = pkgs.writeShellApplication {
    name = "matlab-clipboard-watch";
    runtimeInputs = [ pkgs.wl-clipboard pkgs.coreutils ];
    text = ''
      export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"
      exec wl-paste --watch '${clipboardRepair}/bin/matlab-clipboard-repair'
    '';
  };

  # ---- 启动器 ------------------------------------------------------------
  matlabLauncher = pkgs.writeShellApplication {
    name = "matlab";
    runtimeInputs = [ wine matlabSetup pkgs.coreutils ];
    text = ''
      export WINEPREFIX='${prefixDir}'
      export WINEDEBUG=-all
      export WINEDLLOVERRIDES="msvcp140,msvcp140_1,msvcp140_2,msvcp140_atomic_wait,msvcp140_codecvt_ids,vcruntime140,vcruntime140_1,concrt140,vccorlib140=n;mscoree,mshtml="
      export DISPLAY="''${DISPLAY:-:0}"
      matlab-setup >/dev/null 2>&1 || true
      exec wine "$WINEPREFIX/drive_c/MATLAB/R2024b/bin/matlab.exe" "$@"
    '';
  };

in
{
  home.packages = [ matlabLauncher matlabSetup ];

  # 首次 `home-manager switch` 即完成全量安装（约 10-20 分钟），之后立即返回
  home.activation.matlab = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${matlabSetup}/bin/matlab-setup
  '';

  # 剪贴板修复服务：随图形会话启动，剪贴板变化时触发
  systemd.user.services.matlabClipboardFix = {
    Unit = {
      Description = "修复 Wine/Java 剪贴板中的 UTF-8 文本（MATLAB 复制中文）";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${clipboardWatch}/bin/matlab-clipboard-watch";
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.file.".local/share/applications/matlab.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=MATLAB R2024b
    GenericName=Technical Computing
    Comment=MATLAB R2024b（Wine，113 个产品全量）
    Exec=${matlabLauncher}/bin/matlab
    Icon=matlab
    Terminal=false
    Categories=Development;Math;Science;
    StartupNotify=true
    StartupWMClass=MATLAB R2024b
    MimeType=text/x-matlab;
  '';
}
