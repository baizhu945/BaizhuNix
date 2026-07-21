{ config, pkgs, lib, ... }:

let
  # linux-g14 打包仓库（只含 patch 文件和 config）
  linux-g14-repo = pkgs.fetchurl {
    url = "https://gitlab.com/asus-linux/linux-g14/-/archive/7.1/linux-g14-7.1.tar.gz";
    hash = "sha256-RSPB9jA502NruHVm0f0KIZMQgJEJw0z1QtnOaTTUWeg=";
  };

  # 解压为 derivation，使各 patch 文件可被引用
  linux-g14-files = pkgs.runCommand "linux-g14-files" {} ''
    mkdir -p $out
    tar -xzf ${linux-g14-repo} -C $out --strip-components=1
  '';

  # Patch 文件列表（按 PKGBUILD source 顺序）
  g14PatchFiles = [
    "sys-kernel_arch-sources-g14_files-0004-more-uarches-for-kernel-6.15.patch"
    "0003-platform-x86-asus-armoury-add-support-for-FA507UV.patch"
    "0003-platform-x86-asus-armoury-add-support-for-FA608UM.patch"
    "0003-platform-x86-asus-armoury-add-support-for-G615LR.patch"
    "0003-platform-x86-asus-armoury-add-support-for-G835LW.patch"
    "0003-platform-x86-asus-armoury-add-support-for-GA403WR.patch"
    "0003-0-4-platform-x86-asus-armoury-ppt-fixes-and-new-models.patch"
    "0001-acpi-proc-idle-skip-dummy-wait.patch"
    "0070-acpi-x86-s2idle-Add-ability-to-configure-wakeup-by-A.patch"
    "0040-workaround_hardware_decoding_amdgpu.patch"
    "0084-enable-steam-deck-hdr.patch"
    "sys-kernel_arch-sources-g14_files-0047-asus-nb-wmi-Add-tablet_mode_sw-lid-flip.patch"
    "sys-kernel_arch-sources-g14_files-0048-asus-nb-wmi-fix-tablet_mode_sw_int.patch"
    "ga403wr-fix-audio.patch"
    "0002-g614fp.patch"
    "v4-0001-lamparray.patch"
    "0001-platform-x86-asus-armoury-add-support-for-FX608JMR.patch"
  ];

  # Arch Linux 内核源码
  linux_arch_src = pkgs.fetchFromGitHub {
    owner = "archlinux";
    repo = "linux";
    rev = "v7.1.4-arch1";
    hash = "sha256-yZsVkoQWMbcPvReOU3c/6nt103u4U7gNW417vtSDTEM=";
  };

  # 预打补丁的内核源码：用 -F150 模糊匹配模拟 PKGBUILD 行为
  linux_g14_src = pkgs.runCommand "linux-g14-patched-src" {} ''
    cp -r ${linux_arch_src} $out
    chmod -R u+w $out

    cd $out
    for patch in ${lib.concatStringsSep " " (map (p: "${linux-g14-files}/${p}") g14PatchFiles)}; do
      echo "Applying patch: $(basename $patch)"
      patch -Np1 -F150 < "$patch" || echo "WARNING: patch $(basename $patch) failed to apply"
    done
  '';

  linux_g14_pkg = { buildLinux, ... } @ args:
    buildLinux (args // rec {
      version = "7.1.4";
      modDirVersion = "7.1.4-arch1";

      src = linux_g14_src;

      # 补丁已预打到源码中，不需要再单独应用
      kernelPatches = [];

      # PKGBUILD 里通过 scripts/config 设置了大量 config，
      # 用 structuredExtraConfig 对应最关键的选项
      structuredExtraConfig = with lib.kernel; {
        # AMD/ASUS 相关
        PINCTRL_AMD         = yes;
        X86_AMD_PSTATE      = yes;
        AMD_PMC             = module;
        # ASUS_WMI_BIOS       = yes;     # 7.1.4 中不存在
        # HID_ASUS_ALLY       = module;  # 7.1.4 中不存在
        # ASUS_ARMOURY        = yes;  # Nix config generator loop with FW_ATTR_CLASS select
        ASUS_WMI_DEPRECATED_ATTRS = yes;
        DRM_AMD_COLOR_STEAMDECK   = yes;

        # 调度
        SCHED_CLASS_EXT     = yes;

        # LRU
        LRU_GEN             = yes;
        LRU_GEN_ENABLED     = yes;
        LRU_GEN_STATS       = no;

        # NTSYNC
        NTSYNC              = yes;

        # EFI
        EFI_HANDOVER_PROTOCOL = yes;
        EFI_STUB            = yes;

        # 禁用 SELinux
        SECURITY_SELINUX    = no;

        # 禁用 TPM RNG（防止 ROG 笔记本卡顿）
        HW_RANDOM_TPM       = no;
      };

      extraMeta.branch = "7.1";
    } // (args.argsOverride or {}));

  linux_g14 = pkgs.callPackage linux_g14_pkg {};

in
{
  boot.kernelPackages =
    pkgs.lib.recurseIntoAttrs (pkgs.linuxPackagesFor linux_g14);
}
